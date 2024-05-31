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
    list(args)
  end

  protected

  def list(args)
    branch = args.shift
    base = args.shift
    @review_tool.reviews(branch, base).each do |pr|
      puts "#{pr.title} [merge #{pr.mergeable ? "ready".green : "blocked".orange}]"
      puts indent(pr.url.cyan)
    end
  end
end
