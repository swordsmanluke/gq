# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Log < Command
  COMMAND = ["log"]

  def self.documentation
    "List the branches in the current commands."
  end

  def call(*args)
    @stack.branches.each do |name, node|
      puts "#{name} -> #{node.parent}"
    end
  end
end
end