# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Checkout < Command
  COMMAND = ["bco"]

  def self.documentation
    "Interactive branch checkout"
  end

  def call(*args)
    Shell.prompt("Branch to checkout: ", options: @git.branches.map(&:name) ) do |branch|
      checkout_branch(branch)
      puts `git status`
    end
  end
end