# frozen_string_literal: true

require_relative "../../switest2_test_helper"

class Switest2::CaseInsensitiveHashTest < Minitest::Test
  def test_exact_key_match
    hash = Switest2::CaseInsensitiveHash.new
    hash["Content-Type"] = "text/plain"

    assert_equal "text/plain", hash["Content-Type"]
  end

  def test_case_insensitive_lookup
    hash = Switest2::CaseInsensitiveHash.new
    hash["Content-Type"] = "text/plain"

    assert_equal "text/plain", hash["content-type"]
    assert_equal "text/plain", hash["CONTENT-TYPE"]
    assert_equal "text/plain", hash["CoNtEnT-TyPe"]
  end

  def test_missing_key_returns_nil
    hash = Switest2::CaseInsensitiveHash.new
    hash["Content-Type"] = "text/plain"

    assert_nil hash["X-Custom"]
    assert_nil hash["x-custom"]
  end

  def test_from_creates_from_hash
    source = { "Privacy" => "user;id", "X-Custom" => "value" }
    hash = Switest2::CaseInsensitiveHash.from(source)

    assert_equal "user;id", hash["Privacy"]
    assert_equal "user;id", hash["privacy"]
    assert_equal "value", hash["x-custom"]
  end

  def test_sip_header_variable_lookup
    hash = Switest2::CaseInsensitiveHash.new
    hash["variable_sip_P-Asserted-Identity"] = "sip:+4512345678@example.com"

    # Both cases should work
    assert_equal "sip:+4512345678@example.com", hash["variable_sip_P-Asserted-Identity"]
    assert_equal "sip:+4512345678@example.com", hash["variable_sip_p-asserted-identity"]
  end

  def test_inherits_hash_methods
    hash = Switest2::CaseInsensitiveHash.new
    hash["Key1"] = "value1"
    hash["Key2"] = "value2"

    assert_equal 2, hash.size
    assert_equal %w[Key1 Key2], hash.keys
    assert_equal %w[value1 value2], hash.values
    assert hash.key?("Key1")
  end
end
