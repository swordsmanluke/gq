# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Merge < Command
  COMMAND = ["merge", "m"]
  SPINNER_CYCLE = ['-', '\\', '|', '/']

  def initialize(stack, git=Git)
    super
    # TODO: Factory this
    case @stack.config.code_review_tool
    when 'github'
      puts "Using GitHub code review tool"
      @cr_client = GithubReviewer.new(@stack)
    when 'none', nil, ''
      puts "No code review client present"
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
      do_merge
    ensure
      @git.checkout cb
    end
  end

  protected

  def prepare_stack_for_merge(stack)
    approved_stack = []

    stack.each do |branch_name|
      next if branch_name == @stack.config.root_branch # Skip the root branch

      parent = @git.parent_of(branch_name)

      review = cr_client.reviews(branch_name, parent).first
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

      approved_stack << [review, title, body] if Shell.prompt?("Merge it?")
    end
    approved_stack
  end

  private

  def do_merge
    # Merge all of our PR approved parents!
    stack = @stack.current_stack
    stack = stack[0..stack.index(@stack.current_branch.name)] # Only merge up to the current branch
    puts "Merge stack:\n-----------------"
    stack.each { puts indent _1.cyan }

    approved_stack = prepare_stack_for_merge(stack)

    puts "\nMerging #{approved_stack.size} commits".yellow unless approved_stack.empty?

    approved_stack.each do |review, title, body|
      print indent("#{review.id.to_s.cyan} (#{title.green}): #{SPINNER_CYCLE[0]}")
      merge_request = cr_client.merge_review(review, title, body)
      while merge_request.state == 'pending'
        sleep 0.25
        merge_request.refresh!
        print "\b#{SPINNER_CYCLE.rotate!.first}"
      end

      if merge_request.state == 'success'
        print "\b#{CHECKMARK}\n"
        next
      else
        print "\b#{RED_X}\n"
        puts tree("State: #{merge_request.state}\n#{review.url.cyan}\n", 2)
        self_destruct "Merge failed for #{review.id.to_s.cyan}"
      end
    end
  end

  def cr_client
    @cr_client
  end
end
