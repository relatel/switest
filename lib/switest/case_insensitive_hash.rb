# frozen_string_literal: true

module Switest
  # Hash subclass with case-insensitive key lookup
  class CaseInsensitiveHash < Hash
    def self.from(hash)
      new.merge!(hash)
    end

    def [](key)
      return super if key?(key)
      key_downcase = key.downcase
      found_key = keys.find { |k| k.downcase == key_downcase }
      found_key ? super(found_key) : nil
    end
  end
end
