# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Merge < Command
  COMMAND = ["merge", "m"]

  def initialize(stack, git=Git)
    super
    # TODO: Factory this
    case @stack.config.code_review_tool
    when 'github'
      @cr_client = GithubReviewer.new(@stack)
    when 'none', nil, ''
      @cr_client = NullReviewer.new(@stack)
    else
      self_destruct "Unknown code review tool: #{@stack.config.code_review_tool}"
    end
  end

  def self.documentation
    "Merge the current stack of approved PRs"
  end

  def call(*args)
    # Make sure we're up to date
    cb = @stack.current_branch.name
    begin
      @stack.sync
    ensure
      @git.checkout cb
    end

    # Merge all of our PR approved parents!
    stack = @stack.current_stack
    stack = stack[0..stack.index(@stack.current_branch.name)] # Only merge up to the current branch
    stack = stack.reverse  # We want to start from the root and work our way up
    puts "Merging stack"
    stack.each { puts indent _1.cyan }

    stack.each do |branch_name|
      next if branch_name == @stack.config.root_branch # Skip the root branch

      parent = @git.parent_of(branch_name)

      review = @cr_client.reviews(branch_name, parent).first
      if review.nil?
        puts "No review found for #{branch_name.cyan}. Skipping."
        next
      end

      if review.state != 'approved'
        self_destruct "Review for #{branch_name.cyan} is not approved."
      end

      puts "Commit title: #{review.title.green} (##{review.id.to_s.green})"
      title = `gum input --width 50 --value "#{review.title}"`.strip

      puts "Commit message:\n#{review.message.green}"
      body = review.message # `gum write --width 80 --value "#{review.message}"`.strip

      self_destruct("aborted".red) unless Shell.prompt?("Merge it?")

      merge_request = @cr_client.merge_review(review, title, body)
      while merge_request.state == 'pending'
        sleep 0.25
        merge_request.refresh!
      end

      if merge_request.state == 'success'
        puts CHECKMARK + " #{branch_name.cyan} (##{review.id.gold})"
        next
      else
        self_destruct RED_X + " #{branch_name.cyan} (##{review.id.gold})\n#{review.url.cyan}"
      end
    end
  end
end
