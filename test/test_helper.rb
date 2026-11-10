# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "pikaid"
require "minitest/autorun"
require "minitest/mock"
require "json"
require "securerandom"

require_relative "support/reference"

module PikaidTestHelpers
  VECTORS = JSON.parse(
    File.read(File.expand_path("vectors/pikaid-v1.json", __dir__))
  ).freeze

  def with_random_bytes(value)
    SecureRandom.stub(:random_bytes, value) { yield }
  end
end

# Base test class with shared fixture and stubbing helpers.
class PikaidTest < Minitest::Test
  include PikaidTestHelpers
end
