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
    prs = @review_tool.reviews(branch, base)

    if prs.empty?
      puts "No open reviews"
    else
      puts "Review Mergeability\n====================".bright_yellow
    end
    prs.each do |pr|
      dot = pr.mergeable ? CHECKMARK : RED_X
      title = pr.title.cyan
      puts "#{dot} #{title}"
      puts indent(pr.url.bright_white, "|   ")
      puts
    end
  end
end
