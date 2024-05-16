# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Init < Command
  COMMAND = ["init"]

  def self.documentation
    "Set up GQ locally - run once in your repo."
  end

  def call(*args)
    self_destruct "Already initialized" if StackFile.exists?
    @stack = Stack.refresh(@git)
    @git.ignore('.gq/stack.toml')
  end
end
end