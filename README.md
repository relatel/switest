# Switest2

Switest2 lets you write functional tests for your voice applications,
using direct ESL (Event Socket Library) communication with FreeSWITCH.

## Installation

Add to your Gemfile:

```ruby
gem "switest2"
```

## Quick Start

```ruby
# test/my_scenario_test.rb
require "minitest"
require "switest2"

class MyScenario < Switest2::Scenario
  def test_outbound_call
    alice = Agent.dial("sofia/gateway/provider/+4512345678")
    assert alice.wait_for_answer(timeout: 10), "Call should be answered"

    alice.hangup(wait: true)
    assert alice.ended?, "Call should be ended"
  end
end
```

## Running Tests

Use Minitest's rake task to run your tests:

```ruby
# Rakefile
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/**/*_test.rb"]
end
```

Then run with:

```bash
bundle exec rake test
```

## Core Concepts

### Agents

An **Agent** represents a party in a call. There are two types:

```ruby
# Outbound agent - initiates a call
alice = Agent.dial("sofia/gateway/provider/+4512345678")

# Inbound agent - listens for incoming calls
bob = Agent.listen_for_call(to: /^1000/)
```

### Outbound Calls

When you dial, the agent initiates a call and waits for the remote party to answer:

```ruby
alice = Agent.dial("sofia/gateway/provider/+4512345678")

# Check if call exists
assert alice.call?, "Agent should have a call"

# Wait for remote party to answer (passive - you're waiting for them)
assert alice.wait_for_answer(timeout: 10), "Remote should answer"

# Now the call is connected
assert alice.answered?

# Hangup when done
alice.hangup(wait: true)
```

### Inbound Calls

When listening for calls, the agent waits for a matching call to arrive, then you answer it:

```ruby
bob = Agent.listen_for_call(to: /^1000/)

# No call yet
refute bob.call?

# ... something triggers an inbound call to 1000 ...

# Wait for the call to arrive
assert bob.wait_for_call(timeout: 5), "Should receive inbound call"

# Now answer it (active - you're answering)
bob.answer(wait: true)

# Call is now connected
assert bob.answered?
```

### Understanding wait_for_answer vs answer(wait:)

This is a critical distinction:

| Method | Use Case | What Happens |
|--------|----------|--------------|
| `wait_for_answer(timeout:)` | **Outbound calls** | Passively waits for the remote party to answer |
| `answer(wait:)` | **Inbound calls** | Actively answers the call and waits for confirmation |

**Example - Outbound call:**
```ruby
alice = Agent.dial("sofia/gateway/provider/+4512345678")
# Alice is calling someone - wait for THEM to answer
alice.wait_for_answer(timeout: 10)
```

**Example - Inbound call:**
```ruby
bob = Agent.listen_for_call(to: /^1000/)
bob.wait_for_call(timeout: 5)
# Bob received a call - BOB needs to answer it
bob.answer(wait: true)
```

### Understanding wait_for_end vs hangup(wait:)

Similar distinction for ending calls:

| Method | Use Case | What Happens |
|--------|----------|--------------|
| `wait_for_end(timeout:)` | Waiting for remote to hangup | Passively waits for the call to end |
| `hangup(wait:)` | You want to hangup | Actively hangs up and waits for confirmation |

**Example - You hangup:**
```ruby
alice.hangup(wait: true)  # Hangup and wait for confirmation
assert alice.ended?
```

**Example - Wait for remote to hangup:**
```ruby
# Remote party hangs up
assert alice.wait_for_end(timeout: 10), "Remote should hangup"
```

## Complete API Reference

### Agent Class Methods

```ruby
# Dial an outbound call
Agent.dial(destination, from: nil, headers: {})

# Listen for inbound calls matching guards
Agent.listen_for_call(to: /pattern/, from: /pattern/)
```

### Agent Instance Methods

#### Actions

```ruby
agent.answer(wait: false)           # Answer inbound call
agent.hangup(wait: false)           # Hangup the call
agent.reject(reason = :decline)     # Reject inbound call (:decline or :busy)
agent.send_dtmf(digits)             # Send DTMF tones
agent.receive_dtmf(count:, timeout:) # Receive DTMF digits
```

#### Wait Methods

```ruby
agent.wait_for_call(timeout: 5)    # Wait for inbound call to arrive
agent.wait_for_answer(timeout: 5)  # Wait for call to be answered
agent.wait_for_end(timeout: 5)     # Wait for call to end
```

#### State Queries

```ruby
agent.call?      # Has a call object?
agent.alive?     # Call exists and not ended?
agent.active?    # Call is answered and not ended?
agent.answered?  # Call has been answered?
agent.ended?     # Call has ended?
```

#### Timing

```ruby
agent.start_time   # When call started
agent.answer_time  # When call was answered
agent.end_reason   # Why call ended (e.g., "NORMAL_CLEARING")
```

### Dial Options

```ruby
Agent.dial(
  "sofia/gateway/provider/+4512345678",
  from: "+4587654321",                    # Caller ID (sets both number and name)
  headers: { "Privacy" => "user;id" }     # Custom SIP headers
)
```

**Note:** Headers are automatically prefixed with `sip_h_` to be sent as SIP headers.

### Guards for listen_for_call

Guards filter which inbound calls match:

```ruby
# Match by destination number (regex)
Agent.listen_for_call(to: /^1000/)

# Match by caller ID (regex)
Agent.listen_for_call(from: /^\+45/)

# Match both
Agent.listen_for_call(to: /^1000/, from: /^\+45/)

# Match exact value
Agent.listen_for_call(to: "1000")
```

### Scenario Helper Methods

```ruby
# Hangup all active calls (useful for cleanup before CDR writes)
hangup_all(cause: "NORMAL_CLEARING", timeout: 5)
```

## Provided Assertions

`Switest2::Scenario` inherits from `Minitest::Test` and provides:

```ruby
assert_call(agent, timeout: 5)         # Assert agent receives a call
assert_no_call(agent, timeout: 2)      # Assert agent does NOT receive a call
assert_hungup(agent, timeout: 5)       # Assert call has ended
assert_not_hungup(agent, timeout: 2)   # Assert call is still active
assert_dtmf(agent, "123", timeout: 5)  # Assert agent receives DTMF digits
```

## Example Scenarios

### Basic Outbound Call

```ruby
class OutboundTest < Switest2::Scenario
  def test_dial_and_hangup
    alice = Agent.dial("loopback/echo/default")

    assert alice.call?, "Should have a call"
    assert alice.wait_for_answer(timeout: 5), "Should be answered"

    alice.hangup(wait: true)
    assert alice.ended?, "Should be ended"
  end
end
```

### Inbound Call with Answer

```ruby
class InboundTest < Switest2::Scenario
  def test_receive_and_answer
    bob = Agent.listen_for_call(to: /^1000/)

    # Trigger inbound call somehow (e.g., another agent dials)
    alice = Agent.dial("loopback/1000/default")

    assert bob.wait_for_call(timeout: 5), "Bob should receive call"
    assert bob.call.inbound?, "Should be inbound"

    bob.answer(wait: true)
    assert bob.answered?, "Bob should be answered"

    # Cleanup
    alice.hangup(wait: true)
    bob.wait_for_end(timeout: 5)
  end
end
```

### DTMF Testing

```ruby
class DtmfTest < Switest2::Scenario
  def test_send_and_receive_dtmf
    alice = Agent.dial("sofia/gateway/provider/+4512345678")
    assert alice.wait_for_answer(timeout: 10)

    # Send DTMF
    alice.send_dtmf("123#")

    # Or receive DTMF from remote
    digits = alice.receive_dtmf(count: 4, timeout: 5)
    assert_equal "1234", digits

    alice.hangup(wait: true)
  end
end
```

### Call Transfer

```ruby
class TransferTest < Switest2::Scenario
  def test_transfer_with_dtmf
    bob = Agent.listen_for_call(to: /^1000/)
    alice = Agent.dial("sofia/gateway/provider/1000")

    assert bob.wait_for_call(timeout: 5)
    bob.answer(wait: true)

    charlie = Agent.listen_for_call(to: /^2000/)

    # Bob transfers by pressing ##2000#
    bob.send_dtmf("##2000#")

    assert charlie.wait_for_call(timeout: 5), "Charlie should receive transfer"
    assert bob.wait_for_end(timeout: 5), "Bob should be disconnected"

    charlie.answer(wait: true)
    alice.hangup(wait: true)
  end
end
```

### Reject Inbound Call

```ruby
class RejectTest < Switest2::Scenario
  def test_reject_call
    bob = Agent.listen_for_call(to: /^1000/)
    alice = Agent.dial("loopback/1000/default")

    assert bob.wait_for_call(timeout: 5)

    bob.reject(:busy)  # or :decline

    assert bob.wait_for_end(timeout: 5)
    assert alice.wait_for_end(timeout: 5)
  end
end
```

## Configuration

### FreeSWITCH Setup

1. Enable `mod_event_socket` (default)

2. Configure `event_socket.conf.xml`:
```xml
<configuration name="event_socket.conf" description="Socket Client">
  <settings>
    <param name="nat-map" value="false"/>
    <param name="listen-ip" value="0.0.0.0"/>
    <param name="listen-port" value="8021"/>
    <param name="password" value="ClueCon"/>
  </settings>
</configuration>
```

3. Add dialplan for parking inbound calls:
```xml
<extension name="switest2">
  <condition>
    <action application="park"/>
  </condition>
</extension>
```

### Ruby Configuration

```ruby
Switest2.configure do |config|
  config.host = "127.0.0.1"     # FreeSWITCH host
  config.port = 8021            # ESL port
  config.password = "ClueCon"   # ESL password
  config.default_timeout = 5    # Default timeout for waits
end
```

### Docker Setup

Example `compose.yml`:

```yaml
services:
  freeswitch:
    image: ghcr.io/patrickbaus/freeswitch-docker
    ports:
      - "8021:8021"
    volumes:
      - ./freeswitch/event_socket.conf.xml:/etc/freeswitch/autoload_configs/event_socket.conf.xml:ro
      - ./freeswitch/dialplan.xml:/etc/freeswitch/dialplan/public/00_switest.xml:ro
    healthcheck:
      test: ["CMD", "fs_cli", "-x", "status"]
      interval: 10s
      timeout: 5s
      retries: 5

  test:
    image: ruby:3.2
    working_dir: /app
    volumes:
      - .:/app
    depends_on:
      freeswitch:
        condition: service_healthy
    environment:
      FREESWITCH_HOST: freeswitch
      FREESWITCH_PORT: 8021
      FREESWITCH_PASSWORD: ClueCon
    command: bundle exec rake test
```

## Dependencies

* Ruby >= 3.0
* concurrent-ruby ~> 1.2
* minitest >= 5.5, < 7.0

## Migration from Switest (Adhearsion)

Switest2 replaces the Adhearsion/Rayo backend with direct ESL communication.
The Agent API is compatible:

```ruby
# Before (Switest with Adhearsion)
require "switest"
class MyTest < Switest::Scenario

# After (Switest2 with ESL)
require "switest2"
class MyTest < Switest2::Scenario
```

Key differences:
- No Adhearsion/Rayo dependency
- Direct ESL connection (simpler, fewer dependencies)
- Same Agent API (`dial`, `listen_for_call`, `answer`, `hangup`, etc.)

## License

The MIT License (MIT)

Copyright (c) 2015 Firmafon ApS, Harry Vangberg <hv@firmafon.dk>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
