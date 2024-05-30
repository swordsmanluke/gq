# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Review < Command
  COMMAND = ["review", "rv"]

  def initialize(stack, git=Git)
    super(stack, git)
    @review_tool = case @stack.config.code_review_tool
                   when 'github'
                     GithubReviewer.new(@stack)
                   else
                     NullReviewer.new(@stack)
                   end
  end

  def self.documentation
    "List open PRs for this project"
  end

  def call(*args)
    @review_tool.reviews.each do |pr|
      puts "#{pr.title} (#{pr.url})"
    end
  end
end
