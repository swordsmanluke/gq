# frozen_string_literal: true

require_relative "../shell"
require_relative "../git"
require_relative "command"
require_relative "../config"

class Init < Command
  COMMAND = ["init"].freeze

  def self.documentation
    "Set up GQ locally - run once in your repo."
  end

  def call(*_args)
    if StackFile.exists?
      puts "GQ is Already initialized".yellow
      if Shell.prompt?("Would you like to".green + " reinitialize?".red, selected: "n")
        puts "Aborting reinitialization...".yellow
        exit
      end
    end

    puts "Initializing GQ...".green

    git = Git
    config = @stack.config

    config.root_branch = root_branch
    puts indent("Selected: #{config.root_branch.cyan}")

    Shell.prompt("Choose your remote: ".green, options: git.remotes) do |remote|
      self_destruct("Aborted".red) if remote.empty?
      config.remote = remote
      puts indent("Selected: #{config.remote.cyan}")
    end

    Shell.prompt("Choose your code review tool: ".green, options: %w[none github]) do |tool|
      self_destruct("Aborted".red) if tool.empty?
      config.code_review_tool = tool
      puts indent("Selected: #{config.code_review_tool.cyan}")
    end

    dist = 20
    puts "\nConfiguration:".green
    puts indent("Root branch:".ljust(dist) + config.root_branch.cyan)
    puts indent("Remote:".ljust(dist) + config.remote.cyan)
    puts indent("Code review tool:".ljust(dist) + config.code_review_tool.cyan)
    if Shell.prompt?("\nIs this correct?".green)
      @stack.refresh(config)

      puts "Discovered branches".cyan
      puts indent(@stack.to_s)
      StackFile.save(config)
      puts "Saved configuration! 🎉".green
    else
      puts "Aborted".red
      exit
    end
    puts "Run `gq help` to get started working on your stack.".cyan
  end

  protected

  def root_branch
    defaults = []
    defaults << "main" if @stack.branches.include? "main"
    defaults << "master" if @stack.branches.include? "master"
    Shell.prompt("Select the root branch: ".green, options: @stack.branches.keys.sort_by do
                                                              [(defaults.include?(_1) ? 0 : 100), _1.length]
                                                            end) do |branch|
      self_destruct("Aborted".red) if branch.empty?
      branch
    end
  end
end
