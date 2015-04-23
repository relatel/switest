# SWITEST

Switest lets you write functional tests for your voice applications,
using Adhearsion to drive calls via FreeSWITCH.

## Example

To test your fancy new PBX and its phone menu, you could write the
following Switest scenario, which dials your number, presses "1"
and checks that Bob was called as a result of that:

```ruby
# test/scenario/pbx_scenario.rb

require "switest"
require "switest/autorun"

class PbxScenario < Switest::Scenario
  def test_dial_and_press_1
    alice = Agent.dial("sofia/gateway/your-provider/88888888")
    bob = Agent.listen_for_call(to: /^22334455@/)

    alice.wait_for_answer
    alice.send_dtmf("1")

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

require "switest"
require "switest/autorun"

class TransferScenario < Switest::Scenario
  def test_transfer_call
    bob = Agent.listen_for_call to: /^1000@/
    alice = Agent.dial("sofia/gateway/your-provider/1000")
    
    assert_call(bob)
    
    charlie = Agent.listen_for_call to: /^2000@/
    
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

1. FreeSWITCH instance with mod_rayo configured
2. Sofia profile for Switest
3. The following dialplan for the Switest profile:
    
    ```xml
    <context name="switest">
      <extension name="switest">
        <condition>
          <action application="rayo" data="switest"/>
        </condition>
      </extension>
    </context>
    ```

## Provided assertions

`Switest::Scenario` inherits from `Minitest::Test`, so all your regular
assertions are available. Switest provides a few custom assertions:

* `assert_call`
* `assert_no_call`
* `assert_hungup`
* `assert_not_hungup`
* `assert_dtmf`

## Limitations

Due to limitations in `mod_rayo` the only way to send a DTMF at the
moment, is by playing the tones, so the endpoint you are testing
must support inband DTMF for the DTMF features to work.

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
