# frozen_string_literal: true

require_relative "../shell"
require_relative "command"

module Gq
  class Log < Gq::Command
    COMMAND = ["log"].freeze

    def self.documentation
      "List the branches in the current commands."
    end

    def call(*_args)
      @stack.current_stack.each_with_index do |cur_branch, i|
        parent_branch = @stack.branches[cur_branch].parent
        formatted_name = i.zero? ? " o #{cur_branch}".yellow : " o #{cur_branch}".green

        puts tree(formatted_name, 0)
        if cur_branch != 'master' && @git.branches.map(&:name).include?(cur_branch) && @git.branches.map(&:name).include?(parent_branch)
          formatted_diff(cur_branch, parent_branch, 5).tap do |diff|
            puts tree(diff, 1, " | ".green) unless diff.empty?
          end
        end
      end
    end

    private

    def formatted_diff(cur_branch, parent_branch, max_len=5)
      return "" if parent_branch.nil? || cur_branch.nil?

      @git.commit_diff(cur_branch, parent_branch)
          .map { |(sha, msg)| "#{sha[0..6].grey} #{msg}" }
          .then { |commits| commits.size > max_len ? commits[0..max_len] + ["    ... (#{commits.size - max_len} more)".grey] : commits[0..max_len] }
          .join("\n")
    end
  end
end
