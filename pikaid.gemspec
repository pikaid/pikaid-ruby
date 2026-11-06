# frozen_string_literal: true

require_relative "lib/pikaid/version"

Gem::Specification.new do |spec|
  spec.name = "pikaid"
  spec.version = Pikaid::VERSION
  spec.authors = ["larananas (Lara G.)"]

  spec.summary = "Official Ruby implementation of pikaid"
  spec.description = "Compact 26-character sortable Base36 identifiers with " \
                     "96-bit cryptographic randomness and a 17-byte binary representation."
  spec.homepage = "https://github.com/pikaid/pikaid-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "README.md", "LICENSE"].sort
  end
  spec.require_paths = ["lib"]

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/releases",
    "rubygems_mfa_required" => "true"
  }

  spec.add_development_dependency "minitest", ">= 5.11", "< 6.0"
  spec.add_development_dependency "rake", ">= 12.0", "< 14.0"
end
