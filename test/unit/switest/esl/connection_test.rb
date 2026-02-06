# frozen_string_literal: true

require_relative "../../../test_helper"

class Switest::ESL::ConnectionTest < Minitest::Test
  # Build a Connection wired to an IO.pipe instead of a real socket.
  # Returns [connection, write_io] so tests can feed ESL protocol data.
  def build_connection
    read_io, write_io = IO.pipe
    conn = Switest::ESL::Connection.allocate
    conn.instance_variable_set(:@host, "127.0.0.1")
    conn.instance_variable_set(:@port, 8021)
    conn.instance_variable_set(:@password, "ClueCon")
    conn.instance_variable_set(:@socket, read_io)
    conn.instance_variable_set(:@running, true)
    conn.instance_variable_set(:@reader_thread, nil)
    conn.instance_variable_set(:@command_queue, Queue.new)
    conn.instance_variable_set(:@event_handlers, [])
    conn.instance_variable_set(:@mutex, Mutex.new)
    [conn, write_io]
  end

  # --- read_command_response tests ---

  def test_read_command_response_returns_command_reply
    conn, writer = build_connection

    writer.write("Content-Type: command/reply\nReply-Text: +OK\n\n")

    response = conn.send(:read_command_response)

    assert_equal "command/reply", response[:headers]["Content-Type"]
    assert_equal "+OK", response[:headers]["Reply-Text"]
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_command_response_returns_api_response
    conn, writer = build_connection

    writer.write("Content-Type: api/response\nContent-Length: 3\n\n+OK")

    response = conn.send(:read_command_response)

    assert_equal "api/response", response[:headers]["Content-Type"]
    assert_equal "+OK", response[:body]
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_command_response_dispatches_interleaved_event
    conn, writer = build_connection

    dispatched_events = []
    conn.on_event { |e| dispatched_events << e }

    event_body = "Event-Name: CHANNEL_ANSWER\nUnique-ID: abc123\n"
    writer.write(
      "Content-Type: text/event-plain\nContent-Length: #{event_body.bytesize}\n\n" \
      "#{event_body}" \
      "Content-Type: command/reply\nReply-Text: +OK\n\n"
    )

    response = conn.send(:read_command_response)

    assert_equal "command/reply", response[:headers]["Content-Type"]
    assert_equal 1, dispatched_events.size
    assert_equal "text/event-plain", dispatched_events[0][:headers]["Content-Type"]
    assert_includes dispatched_events[0][:body], "CHANNEL_ANSWER"
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_command_response_dispatches_multiple_interleaved_events
    conn, writer = build_connection

    dispatched_events = []
    conn.on_event { |e| dispatched_events << e }

    event1_body = "Event-Name: CHANNEL_CREATE\nUnique-ID: id1\n"
    event2_body = "Event-Name: DTMF\nUnique-ID: id2\n"
    writer.write(
      "Content-Type: text/event-plain\nContent-Length: #{event1_body.bytesize}\n\n" \
      "#{event1_body}" \
      "Content-Type: text/event-plain\nContent-Length: #{event2_body.bytesize}\n\n" \
      "#{event2_body}" \
      "Content-Type: command/reply\nReply-Text: +OK\n\n"
    )

    response = conn.send(:read_command_response)

    assert_equal "command/reply", response[:headers]["Content-Type"]
    assert_equal 2, dispatched_events.size
    assert_includes dispatched_events[0][:body], "CHANNEL_CREATE"
    assert_includes dispatched_events[1][:body], "DTMF"
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  def test_read_command_response_raises_on_disconnect_notice
    conn, writer = build_connection

    writer.write("Content-Type: text/disconnect-notice\n\n")

    assert_raises(Switest::ConnectionError) do
      conn.send(:read_command_response)
    end
  ensure
    writer.close
    conn.instance_variable_get(:@socket).close
  end

  # --- reader_loop defensive behavior ---

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

    # Run reader_loop in a thread — it will exit when socket closes
    thread = Thread.new { conn.send(:reader_loop) }
    thread.join(2)

    # The command/reply should have been skipped, only the event dispatched
    assert_equal 1, dispatched_events.size
    assert_includes dispatched_events[0][:body], "CHANNEL_ANSWER"
  ensure
    conn.instance_variable_get(:@socket).close rescue nil
  end
end
