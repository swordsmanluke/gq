# frozen_string_literal: true
require_relative '../shell'
require_relative '../code_review/github_reviewer'
require_relative '../code_review/null_reviewer'
require_relative 'command'

class Submit < Command
  include ResetableCommand
  COMMAND = ["submit"]

  def initialize(stack, git=Git)
    super(stack, git)
    case @stack.config.code_review_tool
    when 'github'
      @cr_client = GithubReviewer.new
    when 'none', nil, ''
      @cr_client = NullReviewer.new
    else
      self_destruct "Unknown code review tool: #{@stack.config.code_review_tool}"
    end
  end

  def self.documentation
    "Submit code for review"
  end

  def call(*args)
    @stack.config.remote.tap do |remote|
      @git.fetch(remote)
      @stack.current_stack.each do |branch_name|
        next if branch_name == @stack.config.root_branch # Skip the root branch

        puts "Pushing #{branch_name.cyan} to #{remote.cyan}..."
        @git.push(branch_name, remote: remote)
        parent = @git.parent_of(branch_name)
        update_code_review(branch_name, parent) if parent && parent != '' # We may be updating the root branch, which has no parent
      end
    end
  end

  def update_code_review(branch_name, parent)
    if @cr_client.review_exists?(branch_name, parent)
      puts "Updating code review for #{branch_name.cyan}"
      pr = @cr_client.update_review(branch_name, parent)
      puts "#{yellow("Updated")} Review at: #{pr.url.cyan}" unless pr.url.empty?
    else
      if Shell.prompt?("Create a new review for #{branch_name.cyan}?")
        puts "#{"Creating ".yellow} code review for #{branch_name.cyan}"
        puts tree(@git.commits(branch_name).first.split("\n")[4..].join("\n").grey, 1)

        pr = @cr_client.create_review(branch_name, parent)
        puts "#{green("New")} Review at: #{pr.url.cyan}"
      else
        puts "No PR created"
      end
    end
  end
end
