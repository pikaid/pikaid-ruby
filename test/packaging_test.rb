# frozen_string_literal: true

require_relative "test_helper"
require "rubygems"

# Guards the release manifest. Anything shipped in the gem must be an
# intentional distributable, and local workspace artifacts must never leak into
# a package or a source archive.
class PackagingTest < PikaidTest
  ROOT = File.expand_path("..", __dir__)
  SPEC = Gem::Specification.load(File.join(ROOT, "pikaid.gemspec"))
  ALLOWED_ROOT_FILES = %w[README.md LICENSE CHANGELOG.md].freeze

  def test_gemspec_loads_and_matches_the_library_version
    refute_nil SPEC
    assert_equal "pikaid", SPEC.name
    assert_equal Pikaid::VERSION, SPEC.version.to_s
    assert_equal ["lib"], SPEC.require_paths
    assert_equal Gem::Requirement.new(">= 2.6.0"), SPEC.required_ruby_version
    assert_equal "MIT", SPEC.license
  end

  def test_packaged_files_are_only_distributable_sources
    files = SPEC.files
    refute_empty files

    files.each do |file|
      next if file.start_with?("lib/") && file.end_with?(".rb")

      assert_includes ALLOWED_ROOT_FILES, file, "unexpected packaged file: #{file}"
    end
  end

  def test_packaged_files_exclude_local_workspace_and_development_files
    files = SPEC.files

    refute(files.any? { |file| file == ".ai" || file.start_with?(".ai/") },
           "local .ai/ workspace must never be packaged")
    refute(files.any? { |file| file.start_with?("test/") }, "tests must not be packaged")
    refute(files.any? { |file| file.start_with?(".") }, "dotfiles must not be packaged")
    refute_includes files, "Gemfile"
    refute_includes files, "Gemfile.lock"
    refute_includes files, "Rakefile"
    refute_includes files, "pikaid.gemspec"
    refute(files.any? { |file| file.end_with?(".gem") }, "built gems must not be packaged")
  end

  def test_packaged_files_include_every_library_source_and_metadata
    files = SPEC.files
    expected = Dir[File.join(ROOT, "lib", "**", "*.rb")].map do |path|
      path.sub("#{ROOT}/", "")
    end

    expected.sort.each { |file| assert_includes files, file }
    %w[README.md LICENSE CHANGELOG.md].each { |file| assert_includes files, file }
  end
end
