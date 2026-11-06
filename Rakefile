# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rbconfig"

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

desc "Check Ruby syntax for library, tests, and build files"
task :syntax do
  files = Dir["lib/**/*.rb", "test/**/*.rb", "Rakefile", "*.gemspec"]
  files.sort.each do |file|
    sh RbConfig.ruby, "-c", file
  end
end

desc "Run the test suite with line coverage for lib/pikaid"
task :coverage do
  ruby "-Ilib", "-Itest", "test/coverage_runner.rb"
end

task default: [:syntax, :test]
