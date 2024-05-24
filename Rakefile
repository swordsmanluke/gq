# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
load File.expand_path('tasks/version_incrementer.rake', __dir__)

RSpec::Core::RakeTask.new(:spec)

task default: :spec

