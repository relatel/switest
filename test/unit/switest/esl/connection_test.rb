# frozen_string_literal: true

require_relative "../../../test_helper"

class Switest::ESL::ConnectionTest < Minitest::Test
  # Build a Connection wired to IO pipes instead of a real socket.
  # Returns [connection, write_io] so tests can feed ESL protocol data.
  # When writable: true, a second pipe is used so send_command can write.
  def build_connection(writable: false)
    read_io, write_io = IO.pipe
    conn = Switest::ESL::Connection.allocate
    conn.instance_variable_set(:@host, "127.0.0.1")
    conn.instance_variable_set(:@port, 8021)
    conn.instance_variable_set(:@password, "ClueCon")
    conn.instance_variable_set(:@socket, read_io)
    conn.instance_variable_set(:@running, true)
    conn.instance_variable_set(:@reader_task, nil)
    conn.instance_variable_set(:@pending_responses, [])
    conn.instance_variable_set(:@event_handlers, [])

    if writable
      # Use a dual-stream setup: read from the pipe, write to a discard pipe
      _discard_read, discard_write = IO.pipe
      conn.instance_variable_set(:@stream, DualStream.new(read_io, discard_write))
    else
      conn.instance_variable_set(:@stream, IO::Stream::Buffered.new(read_io))
    end

    [conn, write_io]
  end

  # Minimal wrapper that reads from one IO and writes to another,
  # satisfying the stream interface used by Connection.
  class DualStream
    def initialize(read_io, write_io)
      @reader = IO::Stream::Buffered.new(read_io)
      @writer = IO::Stream::Buffered.new(write_io)
    end

    def gets(...) = @reader.gets(...)
    def read_exactly(...) = @reader.read_exactly(...)
    def write(...) = @writer.write(...)
    def flush = @writer.flush
    def close = (@reader.close rescue nil; @writer.close rescue nil)
    def closed? = @reader.closed?
  end

  # --- read_response / reader_loop tests ---

  def test_read_response_parses_command_reply
    conn, writer = build_connection

    writer.write("Content-Type: command/reply\nReply-Text: +OK\n\n")

    response = conn.send(:read_response)

    assert_equal "command/reply", response[:headers]["Content-Type"]
    assert_equal "+OK", response[:headers]["Reply-Text"]
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_response_parses_api_response_with_body
    conn, writer = build_connection

    writer.write("Content-Type: api/response\nContent-Length: 3\n\n+OK")

    response = conn.send(:read_response)

    assert_equal "api/response", response[:headers]["Content-Type"]
    assert_equal "+OK", response[:body]
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_response_parses_event_with_body
    conn, writer = build_connection

    event_body = "Event-Name: CHANNEL_ANSWER\nUnique-ID: abc123\n"
    writer.write("Content-Type: text/event-plain\nContent-Length: #{event_body.bytesize}\n\n#{event_body}")

    response = conn.send(:read_response)

    assert_equal "text/event-plain", response[:headers]["Content-Type"]
    assert_includes response[:body], "CHANNEL_ANSWER"
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_response_raises_on_closed_connection
    conn, writer = build_connection

    writer.close

    assert_raises(Switest::ConnectionError) do
      conn.send(:read_response)
    end
  ensure
    conn.instance_variable_get(:@socket).close
  end

  # --- send_command tests ---

  def test_send_command_returns_response
    conn, writer = build_connection(writable: true)
    conn.instance_variable_set(:@reader_task, Async { conn.send(:reader_loop) })

    # Write the reply that the reader task will deliver
    writer.write("Content-Type: command/reply\nReply-Text: +OK\n\n")

    response = conn.send_command("api status")

    assert_equal "command/reply", response[:headers]["Content-Type"]
    assert_equal "+OK", response[:headers]["Reply-Text"]
  ensure
    conn.disconnect
    writer.close rescue nil
    conn.instance_variable_get(:@socket)&.close rescue nil
  end

  def test_send_command_raises_on_timeout
    conn, writer = build_connection(writable: true)
    conn.instance_variable_set(:@reader_task, Async { conn.send(:reader_loop) })

    # Don't write any reply — command should time out
    error = assert_raises(Switest::Error) do
      conn.send_command("api status", timeout: 0.2)
    end

    assert_match(/timed out/, error.message)
    assert_empty conn.instance_variable_get(:@pending_responses),
      "Timed-out condition should be cleaned up"
  ensure
    conn.disconnect
    writer.close rescue nil
    conn.instance_variable_get(:@socket)&.close rescue nil
  end

  def test_send_command_raises_on_disconnect
    conn, writer = build_connection

    # Pre-register a pending condition as send_command would, then run the
    # reader loop in a task. Closing the writer causes the reader loop to
    # exit, which signals nil to the waiting condition.
    condition = Async::Condition.new
    conn.instance_variable_get(:@pending_responses) << condition

    conn.instance_variable_set(:@reader_task, Async { conn.send(:reader_loop) })
    writer.close

    # Waiting yields to the reader loop task, which detects the closed
    # connection and signals nil — no sleep needed.
    response = condition.wait
    assert_nil response, "Expected nil signal on disconnect"
  ensure
    conn.disconnect
    conn.instance_variable_get(:@socket)&.close rescue nil
  end

  # --- reader_loop integration ---

  def test_reader_loop_dispatches_events
    conn, writer = build_connection

    dispatched_events = []
    conn.on_event { |e| dispatched_events << e }

    event_body = "Event-Name: CHANNEL_ANSWER\nUnique-ID: abc123\n"
    writer.write(
      "Content-Type: text/event-plain\nContent-Length: #{event_body.bytesize}\n\n" \
      "#{event_body}"
    )
    writer.close

    conn.send(:reader_loop)

    assert_equal 1, dispatched_events.size
    assert_includes dispatched_events[0][:body], "CHANNEL_ANSWER"
  ensure
    conn.instance_variable_get(:@socket).close rescue nil
  end

  def test_reader_loop_skips_orphaned_command_reply
    conn, writer = build_connection

    dispatched_events = []
    conn.on_event { |e| dispatched_events << e }

    # Write an orphaned command/reply followed by a real event, then close
    event_body = "Event-Name: CHANNEL_ANSWER\nUnique-ID: abc123\n"
    writer.write(
      "Content-Type: command/reply\nReply-Text: +OK\n\n" \
      "Content-Type: text/event-plain\nContent-Length: #{event_body.bytesize}\n\n" \
      "#{event_body}"
    )
    writer.close

    conn.send(:reader_loop)

    # The command/reply should have been skipped, only the event dispatched
    assert_equal 1, dispatched_events.size
    assert_includes dispatched_events[0][:body], "CHANNEL_ANSWER"
  ensure
    conn.instance_variable_get(:@socket).close rescue nil
  end
end
