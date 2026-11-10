# frozen_string_literal: true

# Line-coverage runner using only the Ruby standard library.
#
# Usage: ruby -Ilib -Itest test/coverage_runner.rb
#
# Starts Coverage before the library is loaded, runs the full Minitest suite,
# reports per-file and total line coverage for lib/pikaid, and exits non-zero
# when total coverage is below the documented 90% threshold.

require "coverage"

THRESHOLD = 90.0
LIB_ROOT = File.expand_path("../lib", __dir__)
LIB_FILES = Dir[File.join(LIB_ROOT, "**", "*.rb")].sort.freeze

Coverage.start(lines: true)

# `bundle exec` evaluates pikaid.gemspec, and the gemspec reads
# Pikaid::VERSION, so lib/pikaid/version.rb is already loaded before
# Coverage.start. Re-load such files under coverage so the measured set is the
# same however the runner was started. The integrity check below fails the run
# if any library file still ends up unmeasured.
LIB_FILES.select { |path| $LOADED_FEATURES.include?(path) }.each do |path|
  verbose, $VERBOSE = $VERBOSE, nil
  begin
    load path
  ensure
    $VERBOSE = verbose
  end
end

Dir[File.expand_path("*_test.rb", __dir__)].sort.each { |file| require file }

Minitest.after_run do
  result = Coverage.result
  files = result.keys.select { |path| path.start_with?(LIB_ROOT + File::SEPARATOR) }.sort

  missing = LIB_FILES - files
  unless missing.empty?
    missing.each { |path| warn "Not instrumented: #{path}" }
    warn "Coverage is incomplete; every file under lib/ must be measured."
    exit 1
  end

  total_executable = 0
  total_covered = 0

  puts
  puts "Line coverage for lib/pikaid (threshold #{THRESHOLD}%):"

  files.each do |path|
    lines = result.fetch(path).fetch(:lines)
    executable = lines.count { |count| !count.nil? }
    covered = lines.count { |count| count && count.positive? }
    percentage = executable.zero? ? 100.0 : (covered * 100.0 / executable)

    total_executable += executable
    total_covered += covered

    puts format("  %-42s %6.2f%% (%d/%d)", path.sub(LIB_ROOT + File::SEPARATOR, ""), percentage, covered, executable)
  end

  total_percentage = total_executable.zero? ? 100.0 : (total_covered * 100.0 / total_executable)
  puts format("  %-42s %6.2f%% (%d/%d)", "TOTAL", total_percentage, total_covered, total_executable)

  if total_percentage < THRESHOLD
    warn "Coverage #{format('%.2f', total_percentage)}% is below the required #{THRESHOLD}%"
    exit 1
  end
end
