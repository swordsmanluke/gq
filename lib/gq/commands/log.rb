# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Gq::Log < Gq::Command
  COMMAND = ["log"]

  def self.documentation
    "List the branches in the current commands."
  end

  def call(*args)
    @stack.current_stack.each do |name|
      puts name
    end
  end
end
