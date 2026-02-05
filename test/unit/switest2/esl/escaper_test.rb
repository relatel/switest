# frozen_string_literal: true

require_relative "../../../switest2_test_helper"

class Switest2::ESL::EscaperTest < Minitest::Test
  Escaper = Switest2::ESL::Escaper

  # escape_value tests

  def test_escape_value_simple_string
    assert_equal "+4512345678", Escaper.escape_value("+4512345678")
  end

  def test_escape_value_nil
    assert_nil Escaper.escape_value(nil)
  end

  def test_escape_value_empty_string
    assert_equal "", Escaper.escape_value("")
  end

  def test_escape_value_with_spaces
    assert_equal "'John Doe'", Escaper.escape_value("John Doe")
  end

  def test_escape_value_with_angle_brackets
    assert_equal "'<sip:user@host>'", Escaper.escape_value("<sip:user@host>")
  end

  def test_escape_value_with_spaces_and_angle_brackets
    assert_equal "'Display Name <sip:user@host>'", Escaper.escape_value("Display Name <sip:user@host>")
  end

  def test_escape_value_gibberish_sip_format
    # This is the actual format used in tests
    assert_equal "'gibberish sip:+4512345678@example.com'", Escaper.escape_value("gibberish sip:+4512345678@example.com")
  end

  def test_escape_value_with_commas_uses_delimiter_syntax
    result = Escaper.escape_value("one,two,three")
    # Should use ^^<delim> syntax
    assert_match(/^\^\^.one.two.three$/, result)
    refute_includes result, ","
  end

  def test_escape_value_with_single_quote
    assert_equal "'it\\'s working'", Escaper.escape_value("it's working")
  end

  # escape_header_value tests

  def test_escape_header_value_simple_string
    assert_equal "simple", Escaper.escape_header_value("simple")
  end

  def test_escape_header_value_nil
    assert_nil Escaper.escape_header_value(nil)
  end

  def test_escape_header_value_with_commas
    assert_equal "one\\,two\\,three", Escaper.escape_header_value("one,two,three")
  end

  def test_escape_header_value_with_spaces
    assert_equal "'value with spaces'", Escaper.escape_header_value("value with spaces")
  end

  def test_escape_header_value_with_commas_and_spaces
    assert_equal "'Hello\\, World'", Escaper.escape_header_value("Hello, World")
  end

  def test_escape_header_value_sip_uri
    assert_equal "'<sip:+1234@example.com>'", Escaper.escape_header_value("<sip:+1234@example.com>")
  end

  # build_var_string tests

  def test_build_var_string_empty
    assert_equal "", Escaper.build_var_string({}, {})
  end

  def test_build_var_string_with_nil_vars
    assert_equal "", Escaper.build_var_string(nil, nil)
  end

  def test_build_var_string_with_nil_sip_headers
    result = Escaper.build_var_string({ foo: "bar" }, nil)
    assert_equal "{foo=bar}", result
  end

  def test_build_var_string_single_var
    result = Escaper.build_var_string({ foo: "bar" }, {})
    assert_equal "{foo=bar}", result
  end

  def test_build_var_string_multiple_vars
    result = Escaper.build_var_string({ foo: "bar", baz: "qux" }, {})
    assert_includes result, "foo=bar"
    assert_includes result, "baz=qux"
    assert result.start_with?("{")
    assert result.end_with?("}")
  end

  def test_build_var_string_with_sip_headers
    result = Escaper.build_var_string({}, { "X-Custom" => "value" })
    assert_equal "{sip_h_X-Custom=value}", result
  end

  def test_build_var_string_escapes_values
    result = Escaper.build_var_string({ name: "John Doe" }, {})
    assert_equal "{name='John Doe'}", result
  end

  def test_build_var_string_escapes_header_values
    result = Escaper.build_var_string({}, { "X-List" => "a,b,c" })
    assert_equal "{sip_h_X-List=a\\,b\\,c}", result
  end

  def test_build_var_string_skips_nil_values
    result = Escaper.build_var_string({ foo: "bar", skip: nil }, {})
    assert_equal "{foo=bar}", result
  end

  def test_build_var_string_full_example
    result = Escaper.build_var_string(
      {
        origination_uuid: "abc-123",
        origination_caller_id_name: "John Doe",
        origination_caller_id_number: "+4512345678"
      },
      { "Privacy" => "id" }
    )

    assert_includes result, "origination_uuid=abc-123"
    assert_includes result, "origination_caller_id_name='John Doe'"
    assert_includes result, "origination_caller_id_number=+4512345678"
    assert_includes result, "sip_h_Privacy=id"
  end

  # find_delimiter tests

  def test_find_delimiter_prefers_colon
    assert_equal ":", Escaper.find_delimiter("hello")
  end

  def test_find_delimiter_avoids_chars_in_string
    assert_equal "|", Escaper.find_delimiter("hello:world")
  end

  def test_find_delimiter_tries_multiple
    assert_equal "#", Escaper.find_delimiter("hello:world|test")
  end
end
