# frozen_string_literal: true

require 'rake/testtask'

task default: %w[sft]

desc 'Run Simple Flight Tracker (default)'
task :sft do
  ruby 'app.rb'
end

desc 'Run tests'
task :test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end
