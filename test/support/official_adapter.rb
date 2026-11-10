# frozen_string_literal: true

# Test-only JSON-Lines bridge for the official PikaID conformance suite.
#
# This file is deliberately not part of the packaged gem and is not loaded by
# the native test suite. It translates the suite's protocol operations into
# calls to the real public Pikaid API (Pikaid.generate, Pikaid.parse,
# Pikaid.from_binary, Pikaid.valid?, Pikaid.well_formed?, Pikaid.compare, and
# Pikaid::Id accessors). It does not implement an independent codec and never
# synthesizes identifiers for operations that must use the library.
#
# Usage:
#   ruby -Ilib test/support/official_adapter.rb
#
# Protocol: see the pinned suite's docs/JSONL_ADAPTER_PROTOCOL.md.

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "json"
require "pikaid"
require "securerandom"

module OfficialAdapter
  PROTOCOL_VERSION = 1

  # Optional capabilities are advertised only where the public library API
  # actually exposes the behaviour. parse_datetime is intentionally absent:
  # the Ruby API exposes whole-second timestamps, not a datetime accessor, so
  # claiming it would promise behaviour the library does not provide.
  CAPABILITIES = [
    "generate_string",
    "text_to_binary",
    "binary_to_text",
    "boolean_validation",
    "format_only_validation",
    "parse_components",
    "generate_with_timestamp",
    "generate_binary",
    "generate_binary_with_timestamp",
    "public_compare",
    "csprng_failure_injection"
  ].freeze

  # Input that is syntactically wrong for the wire operation. This is distinct
  # from a valid argument that the library rejects, and both map to
  # invalid_input.
  class ArgumentError < StandardError; end

  # A protocol operation that this bridge does not implement.
  class UnsupportedOperation < StandardError; end

  # Test-only fault injection at the real CSPRNG boundary. The production
  # library is not modified: while active, SecureRandom.random_bytes raises and
  # the library's own error mapping must turn that into RandomnessError. This
  # does not prove CSPRNG quality; the suite still requires manual review.
  module FaultInjection
    class << self
      attr_accessor :active
    end
    self.active = false

    module SecureRandomFault
      def random_bytes(count)
        raise "injected CSPRNG failure" if FaultInjection.active

        super
      end
    end
  end
end

SecureRandom.singleton_class.prepend(OfficialAdapter::FaultInjection::SecureRandomFault)

module OfficialAdapter
  module_function

  HEX_34 = /\A[0-9a-f]{34}\z/n

  def hello
    {
      "protocol_version" => PROTOCOL_VERSION,
      "capabilities" => CAPABILITIES
    }
  end

  def dispatch(operation, arguments)
    case operation
    when "hello"
      hello
    when "generate_string"
      Pikaid.generate
    when "generate_with_timestamp"
      Pikaid.generate(timestamp: integer_argument(arguments, "timestamp_seconds"))
    when "generate_binary"
      Pikaid.generate_binary.unpack1("H*")
    when "generate_binary_with_timestamp"
      Pikaid.generate_binary(timestamp: integer_argument(arguments, "timestamp_seconds")).unpack1("H*")
    when "text_to_binary"
      Pikaid.to_binary(string_argument(arguments, "text")).unpack1("H*")
    when "binary_to_text"
      Pikaid.from_binary(strict_binary(string_argument(arguments, "binary_hex"))).to_s
    when "boolean_validation"
      Pikaid.valid?(string_argument(arguments, "text"))
    when "format_only_validation"
      Pikaid.well_formed?(string_argument(arguments, "text"))
    when "parse_components"
      id = Pikaid.parse(string_argument(arguments, "text"))
      {
        "timestamp_seconds" => id.timestamp,
        "randomness_hex" => id.randomness_hex
      }
    when "public_compare"
      Pikaid.compare(
        string_argument(arguments, "a"),
        string_argument(arguments, "b")
      )
    when "inject_fault"
      inject_fault(arguments)
    else
      raise UnsupportedOperation, "unsupported operation #{operation.inspect}"
    end
  end

  def inject_fault(arguments)
    fault = arguments["fault"]
    active = arguments["active"]
    unless fault == "csprng_failure"
      raise ArgumentError, "unsupported fault #{fault.inspect}"
    end
    unless active == true || active == false
      raise ArgumentError, "active must be a boolean"
    end

    FaultInjection.active = active
    { "fault" => fault, "active" => active }
  end

  def string_argument(arguments, name)
    value = arguments[name]
    return value if value.is_a?(String)

    raise ArgumentError, "#{name} must be a string"
  end

  def integer_argument(arguments, name)
    value = arguments[name]
    return value if value.is_a?(Integer)

    raise ArgumentError, "#{name} must be an integer"
  end

  def strict_binary(value)
    raise ArgumentError, "binary_hex must be exactly 17 bytes of lowercase hex" unless HEX_34.match?(value)

    [value].pack("H*")
  end

  def emit(request_id, payload)
    $stdout.write(JSON.generate(payload.merge("request_id" => request_id)))
    $stdout.write("\n")
    $stdout.flush
  end

  def success(request_id, value)
    emit(request_id, { "ok" => true, "value" => value })
  end

  def failure(request_id, category, message)
    emit(request_id, {
             "ok" => false,
             "error" => { "category" => category, "message" => message }
           })
  end

  def serve
    $stdout.sync = true
    $stdin.each_line do |line|
      line = line.strip
      next if line.empty?

      begin
        request = JSON.parse(line)
      rescue JSON::ParserError => error
        failure(0, "internal_error", "malformed JSON request (#{error.message})")
        next
      end

      unless request.is_a?(Hash) && request["request_id"].is_a?(Integer)
        failure(0, "internal_error", "request_id must be an integer")
        next
      end

      request_id = request["request_id"]
      operation = request["operation"]
      arguments = request["arguments"]

      unless operation.is_a?(String) && arguments.is_a?(Hash)
        failure(request_id, "internal_error", "operation must be a string and arguments an object")
        next
      end

      begin
        success(request_id, dispatch(operation, arguments))
      rescue UnsupportedOperation => error
        failure(request_id, "unsupported_operation", error.message)
      rescue ArgumentError, Pikaid::InvalidIdError, Pikaid::InvalidTimestampError => error
        failure(request_id, "invalid_input", error.message)
      rescue Pikaid::RandomnessError => error
        failure(request_id, "entropy_unavailable", error.message)
      rescue StandardError => error
        warn "official adapter internal error: #{error.class}: #{error.message}"
        failure(request_id, "internal_error", "#{error.class}: #{error.message}")
      end
    end
  end
end

OfficialAdapter.serve if $PROGRAM_NAME == __FILE__
