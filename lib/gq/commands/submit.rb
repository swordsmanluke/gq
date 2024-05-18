# frozen_string_literal: true
require_relative '../shell'
require_relative '../code_review/mock_reviewer'
require_relative 'command'

module Gq
  class Submit < Command
    COMMAND = ["submit"]

    def initialize(stack, git=Git, code_review_client=CodeReview::MockReviewer)
      super(stack, git)
      @cr_client = code_review_client
    end

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
        @git.push(branch_name, remote: origin)
        # TODO: Create (or update) code review request based on remote API
        # against the remote parent - assuming it exists, otherwise we err
        parent = @git.parent_of(branch_name).name
        next if parent == '' # We may be updating the root branch, which has no parent
        update_code_review(branch_name, parent)
      end
    end

    def update_code_review(branch_name, parent)
      if @cr_client.review_exists?(branch_name, parent)
        puts "Updating code review"
        @cr_client.update_review(branch_name, parent)
      else
        if Shell.prompt("Create a new review for #{branch_name.cyan}?", options: ["y", "n"]) == 'y'
          @cr_client.create_review(branch_name, parent)
        else
          puts "No PR created"
        end
      end
    end
  end
end