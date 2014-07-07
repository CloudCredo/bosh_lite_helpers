require 'bundler'
require 'rubocop/rake_task'

require 'rspec/core/rake_task'

Bundler.setup
Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new

desc 'Run RuboCop'
RuboCop::RakeTask.new(:rubocop)

task default: ['spec', :rubocop]
