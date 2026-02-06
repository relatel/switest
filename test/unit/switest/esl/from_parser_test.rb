# frozen_string_literal: true

require_relative "../../../switest_test_helper"

class Switest::ESL::FromParserTest < Minitest::Test
  FromParser = Switest::ESL::FromParser

  def test_plain_number_sets_number_and_name
    result = FromParser.parse("+4512345678")

    assert_equal "+4512345678", result[:origination_caller_id_number]
    assert_equal "+4512345678", result[:origination_caller_id_name]
    refute result.key?(:sip_from_uri)
    refute result.key?(:sip_from_display)
  end

  def test_display_name_with_sip_uri
    result = FromParser.parse("gibberish sip:+4522334455@abc.qq")

    assert_equal "sip:+4522334455@abc.qq", result[:sip_from_uri]
    assert_equal "gibberish", result[:sip_from_display]
    assert_equal "sip:+4522334455@abc.qq", result[:origination_caller_id_number]
    assert_equal "gibberish", result[:origination_caller_id_name]
  end

  def test_sip_uri_only
    result = FromParser.parse("sip:anonymous@anonymous.invalid")

    assert_equal "sip:anonymous@anonymous.invalid", result[:sip_from_uri]
    assert_equal "sip:anonymous@anonymous.invalid", result[:origination_caller_id_number]
    refute result.key?(:sip_from_display)
    refute result.key?(:origination_caller_id_name)
  end

  def test_tel_uri_strips_prefix
    result = FromParser.parse("tel:+4512345678")

    assert_equal "+4512345678", result[:origination_caller_id_number]
    assert_equal "+4512345678", result[:origination_caller_id_name]
    refute result.key?(:sip_from_uri)
    refute result.key?(:sip_from_display)
  end

  def test_display_name_with_tel_uri
    result = FromParser.parse("John Doe tel:+4512345678")

    assert_equal "+4512345678", result[:origination_caller_id_number]
    assert_equal "John Doe", result[:origination_caller_id_name]
    refute result.key?(:sip_from_uri)
    refute result.key?(:sip_from_display)
  end

  def test_quoted_display_name_with_sip_uri
    result = FromParser.parse('"John Doe" sip:user@host')

    assert_equal "sip:user@host", result[:sip_from_uri]
    assert_equal "John Doe", result[:sip_from_display]
    assert_equal "sip:user@host", result[:origination_caller_id_number]
    assert_equal "John Doe", result[:origination_caller_id_name]
  end

  def test_angle_bracketed_sip_uri
    result = FromParser.parse("Name <sip:user@host>")

    assert_equal "sip:user@host", result[:sip_from_uri]
    assert_equal "Name", result[:sip_from_display]
    assert_equal "sip:user@host", result[:origination_caller_id_number]
    assert_equal "Name", result[:origination_caller_id_name]
  end

  def test_angle_bracketed_plain_number
    result = FromParser.parse("Name <+4512345678>")

    assert_equal "+4512345678", result[:origination_caller_id_number]
    assert_equal "Name", result[:origination_caller_id_name]
    refute result.key?(:sip_from_uri)
    refute result.key?(:sip_from_display)
  end

  def test_nil_returns_empty_hash
    assert_equal({}, FromParser.parse(nil))
  end

  def test_empty_string_returns_empty_hash
    assert_equal({}, FromParser.parse(""))
  end

  def test_whitespace_only_returns_empty_hash
    assert_equal({}, FromParser.parse("   "))
  end

  def test_sips_uri
    result = FromParser.parse("sips:secure@example.com")

    assert_equal "sips:secure@example.com", result[:sip_from_uri]
    assert_equal "sips:secure@example.com", result[:origination_caller_id_number]
    refute result.key?(:sip_from_display)
    refute result.key?(:origination_caller_id_name)
  end

  def test_quoted_display_name_angle_bracketed_sip_uri
    result = FromParser.parse('"Henrik" <sip:1234@example.com>')

    assert_equal "sip:1234@example.com", result[:sip_from_uri]
    assert_equal "Henrik", result[:sip_from_display]
    assert_equal "sip:1234@example.com", result[:origination_caller_id_number]
    assert_equal "Henrik", result[:origination_caller_id_name]
  end
end
