# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq
class Submit < Command
  COMMAND = ["submit"]

  def self.documentation
    "Submit code for review"
  end

  def call(*args)
    # Use the origin and push each branch to it
    origin = case @git.remotes.size
             when 1
               @git.remotes.first
             when 0
               self_destruct "No remotes found! Use #{green("gq squish")} instead"
             else
                Shell.prompt("Multiple remotes found - which remote should we use?", options: @git.remotes)
             end

    @git.fetch
    @stack.current_stack.each do |branch_name|
      @git.checkout(branch_name)
      @git.push(branch_name, remote: origin)
      # TODO: Create PR based on remote API
    end
  end
end
end