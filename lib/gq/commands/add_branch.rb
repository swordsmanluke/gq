# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
  class AddBranch < Command
    COMMAND = ["create", "bc"]

    def self.documentation
      "Create a new branch and add it to the current commands."
    end

    def call(*args)
      branch_name = args.shift
      self_destruct "Branch name required" if branch_name.nil?
      self_destruct "Branch already exists: #{branch_name}" if @stack.branches.key?(branch_name)

      parent = @stack.current_branch.name
      new_branch = @git.new_branch(branch_name, tracking: parent)
      @stack.add_branch(new_branch, @stack.branches[parent])
    end
  end
end