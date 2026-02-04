# Switest (2)

Switest2 lets you write functional tests for your voice applications,
using direct ESL (Event Socket Library) communication with FreeSWITCH.

## Example

To test your fancy new PBX and its phone menu, you could write the
following Switest2 scenario, which dials your number, presses "1"
and checks that Bob was called as a result of that:

```ruby
# test/scenario/pbx_scenario.rb

require "switest2"
require "switest2/autorun"

class PbxScenario < Switest2::Scenario
  def test_dial_and_press_1
    # First we make an outbound call. The destination is a FreeSWITCH dial string.
    alice = Agent.dial("sofia/gateway/your-provider/88888888")

    # We set up an agent that will listen for inbound calls.
    # Parameters are guards that match against call properties.
    bob = Agent.listen_for_call(to: /^22334455/)

    # Wait until the call has been answered by the PBX.
    alice.wait_for_answer

    # Send a DTMF
    alice.send_dtmf("1")

    # Check that the call to Bob has already arrived, or wait
    # up to five seconds for it to arrive.
    assert_call(bob)
  end
end
```

```
ruby test/scenario/pbx_scenario.rb
```

Or you might want to test that you can call Bob, and that Bob can
transfer the call to Charlie by pressing "#1#":

```ruby
# test/scenario/transfer_scenario.rb

require "switest2"
require "switest2/autorun"

class TransferScenario < Switest2::Scenario
  def test_transfer_call
    bob = Agent.listen_for_call(to: /^1000/)
    alice = Agent.dial("sofia/gateway/your-provider/1000")

    assert_call(bob)

    charlie = Agent.listen_for_call(to: /^2000/)

    bob.answer
    sleep 1
    bob.send_dtmf("#1#")

    assert_call(charlie)
    assert_hungup(bob)

    charlie.hangup
  end
end
```

## Configuration

You need:

1. FreeSWITCH instance with `mod_event_socket` enabled (this is the default)
2. Sofia profile for Switest2
3. Event Socket configuration in `event_socket.conf.xml`:

    ```xml
    <configuration name="event_socket.conf" description="Socket Client">
      <settings>
        <param name="nat-map" value="false"/>
        <param name="listen-ip" value="127.0.0.1"/>
        <param name="listen-port" value="8021"/>
        <param name="password" value="ClueCon"/>
      </settings>
    </configuration>
    ```

4. Dialplan for inbound calls to be parked (so Switest2 can control them):

    ```xml
    <context name="switest2">
      <extension name="switest2">
        <condition>
          <action application="park"/>
        </condition>
      </extension>
    </context>
    ```

### Ruby Configuration

You can configure the ESL connection in your test helper:

```ruby
Switest2.configure do |config|
  config.host = "127.0.0.1"  # FreeSWITCH host
  config.port = 8021          # ESL port
  config.password = "ClueCon" # ESL password
  config.default_timeout = 5  # Default timeout for assertions
end
```

## Provided assertions

`Switest2::Scenario` inherits from `Minitest::Test`, so all your regular
assertions are available. Switest2 provides a few custom assertions:

* `assert_call(agent, timeout: 5)` - Assert agent receives a call
* `assert_no_call(agent, timeout: 2)` - Assert agent does not receive a call
* `assert_hungup(agent, timeout: 5)` - Assert agent's call has ended
* `assert_not_hungup(agent, timeout: 2)` - Assert agent's call is still active
* `assert_dtmf(agent, dtmf, timeout: 5)` - Assert agent receives specific DTMF digits

## Dependencies

* Ruby >= 3.0
* concurrent-ruby ~> 1.2
* minitest >= 5.5, < 6.0

## License

```
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
```
