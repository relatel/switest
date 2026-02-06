# Switest

Functional testing for voice applications via FreeSWITCH ESL.

Switest lets you write tests for your voice applications using direct
ESL (Event Socket Library) communication with FreeSWITCH. Tests run as
plain Minitest cases — no Adhearsion, no Rayo, just a TCP socket to
FreeSWITCH.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [Scenario](#scenario)
  - [Agent](#agent)
- [API Reference](#api-reference)
  - [Agent Class Methods](#agent-class-methods)
  - [Agent Instance Methods](#agent-instance-methods)
  - [Scenario Assertions](#scenario-assertions)
  - [Dial Options](#dial-options)
  - [Guards](#guards)
- [DTMF](#dtmf)
- [Docker / FreeSWITCH Setup](#docker--freeswitch-setup)
- [Configuration](#configuration)
- [Dependencies](#dependencies)
- [License](#license)

## Installation

Add to your Gemfile:

```ruby
gem "switest"
```

Then run `bundle install`.

## Quick Start

```ruby
require "minitest"
require "switest"

class MyScenario < Switest::Scenario
  def test_outbound_call
    alice = Agent.dial("sofia/gateway/provider/+4512345678")
    assert alice.wait_for_answer(timeout: 10), "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end
end
```

Run with Minitest's rake task:

```ruby
# Rakefile
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/**/*_test.rb"]
end
```

```bash
bundle exec rake test
```

## Core Concepts

### Scenario

`Switest::Scenario` is a Minitest::Test subclass that handles FreeSWITCH
connection lifecycle for you. Each test method gets a fresh ESL client that
connects on setup and disconnects on teardown.

```ruby
class MyTest < Switest::Scenario
  def test_something
    # Agent, assert_call, hangup_all, etc. are available here
  end
end
```

### Agent

An **Agent** represents a party in a call. There are two kinds:

**Outbound** — initiates a call:

```ruby
alice = Agent.dial("sofia/gateway/provider/+4512345678")
alice.wait_for_answer(timeout: 10)
alice.hangup
```

**Inbound** — listens for an incoming call matching a guard:

```ruby
bob = Agent.listen_for_call(to: /^1000/)
# ... something triggers an inbound call to 1000 ...
bob.wait_for_call(timeout: 5)
bob.answer
```

#### wait_for_answer vs answer

| Method                        | Direction    | What it does                                |
|-------------------------------|-------------|---------------------------------------------|
| `wait_for_answer(timeout:)`   | Outbound    | Passively waits for the remote to answer    |
| `answer(wait:)`               | Inbound     | Actively answers the call                   |

#### wait_for_end vs hangup

| Method                   | Use case              | What it does                         |
|--------------------------|-----------------------|--------------------------------------|
| `wait_for_end(timeout:)` | Remote hangs up       | Passively waits for the call to end  |
| `hangup(wait:)`          | You hang up           | Sends hangup and waits               |

## API Reference

### Agent Class Methods

```ruby
Agent.dial(destination, from: nil, timeout: nil, headers: {})
Agent.listen_for_call(guards)  # e.g. to: /pattern/, from: /pattern/
```

### Agent Instance Methods

#### Actions

```ruby
agent.answer(wait: 5)             # Answer an inbound call
agent.hangup(wait: 5)             # Hang up
agent.reject(reason = :decline)   # Reject inbound call (:decline or :busy)
agent.send_dtmf(digits)           # Send DTMF tones
agent.receive_dtmf(count:, timeout:)  # Receive DTMF digits
```

#### Waits

```ruby
agent.wait_for_call(timeout: 5)    # Wait for inbound call to arrive
agent.wait_for_answer(timeout: 5)  # Wait for call to be answered
agent.wait_for_bridge(timeout: 5)  # Wait for call to be bridged
agent.wait_for_end(timeout: 5)     # Wait for call to end
```

#### State

```ruby
agent.call?       # Has a call object?
agent.alive?      # Call exists and not ended?
agent.active?     # Answered and not ended?
agent.answered?   # Has been answered?
agent.ended?      # Has ended?
agent.start_time  # When call started
agent.answer_time # When answered
agent.end_reason  # e.g. "NORMAL_CLEARING"
```

### Scenario Assertions

`Switest::Scenario` provides these assertions:

```ruby
assert_call(agent, timeout: 5)         # Agent receives a call
assert_no_call(agent, timeout: 2)      # Agent does NOT receive a call
assert_hungup(agent, timeout: 5)       # Call has ended
assert_not_hungup(agent, timeout: 2)   # Call is still active
assert_dtmf(agent, "123", timeout: 5)  # Agent receives expected DTMF digits
```

The `hangup_all` helper ends all active calls (useful before CDR assertions):

```ruby
hangup_all(cause: "NORMAL_CLEARING", timeout: 5)
```

### Dial Options

```ruby
Agent.dial(
  "sofia/gateway/provider/+4512345678",
  from: "+4587654321",                  # Caller ID (number and name)
  timeout: 30,                          # Originate timeout in seconds
  headers: { "Privacy" => "user;id" }   # Custom SIP headers (auto-prefixed sip_h_)
)
```

The `from:` parameter accepts several formats:

| Format                                    | Effect                                   |
|-------------------------------------------|------------------------------------------|
| `"+4512345678"`                           | Sets caller ID number and name           |
| `"tel:+4512345678"`                       | Same, strips `tel:` prefix               |
| `"sip:user@host"`                         | Sets `sip_from_uri`                      |
| `"Display Name sip:user@host"`            | Sets display name + SIP URI              |
| `'"Display Name" <sip:user@host>'`        | Quoted display name + angle-bracketed URI|

### Guards

Guards filter which inbound calls match `listen_for_call`:

```ruby
Agent.listen_for_call(to: /^1000/)               # Regex on destination
Agent.listen_for_call(from: /^\+45/)              # Regex on caller ID
Agent.listen_for_call(to: "1000")                 # Exact match
Agent.listen_for_call(to: /^1000/, from: /^\+45/) # Multiple (AND logic)
```

## DTMF

Send DTMF tones on an active call:

```ruby
alice.send_dtmf("123#")
```

Receive DTMF from the remote party:

```ruby
digits = alice.receive_dtmf(count: 4, timeout: 5)
assert_equal "1234", digits
```

Or use the assertion helper:

```ruby
assert_dtmf(alice, "1234", timeout: 5)
```

DTMF events are routed per-call — concurrent calls each receive only their
own digits.

## Docker / FreeSWITCH Setup

The project includes a `compose.yml` for running FreeSWITCH locally:

```bash
docker compose up -d freeswitch          # start FreeSWITCH
docker compose run --rm test             # run integration tests
```

The compose file mounts three config files into FreeSWITCH:

| Local file                                    | Container path                                                  |
|-----------------------------------------------|-----------------------------------------------------------------|
| `docker/freeswitch/event_socket.conf.xml`     | `/etc/freeswitch/autoload_configs/event_socket.conf.xml`        |
| `docker/freeswitch/acl.conf.xml`              | `/etc/freeswitch/autoload_configs/acl.conf.xml`                 |
| `docker/freeswitch/dialplan.xml`              | `/etc/freeswitch/dialplan/public/00_switest.xml`                |

### FreeSWITCH Requirements

1. **mod_event_socket** must be loaded (default).

2. `event_socket.conf.xml` must allow connections:

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

3. A dialplan that parks inbound calls so Switest can control them:

```xml
<extension name="switest-park">
  <condition>
    <action application="park"/>
  </condition>
</extension>
```

## Configuration

```ruby
Switest.configure do |config|
  config.host = "127.0.0.1"     # FreeSWITCH host
  config.port = 8021             # ESL port
  config.password = "ClueCon"   # ESL password
  config.default_timeout = 5    # Default timeout for waits
end
```

Or via environment variables (used by the integration test helper):

```bash
FREESWITCH_HOST=127.0.0.1
FREESWITCH_PORT=8021
FREESWITCH_PASSWORD=ClueCon
```

## Dependencies

- Ruby >= 3.0
- concurrent-ruby ~> 1.2
- minitest >= 5.5, < 7.0

## License

MIT License - see [LICENSE](LICENSE) for details.
