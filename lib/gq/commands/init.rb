# frozen_string_literal: true
require_relative '../shell'
require_relative '../git'
require_relative 'command'
require_relative '../config'

class Init < Command
  COMMAND = ["init"]

  def self.documentation
    "Set up GQ locally - run once in your repo."
  end

  def call(*args)
    if StackFile.exists?
      puts "GQ is Already initialized".yellow
      if Shell.prompt?("Would you like to".green + " reinitialize?".red, selected: 'n')
        puts "Aborting reinitialization...".yellow
        exit
      end
    end

    puts "Initializing GQ...".green

    git = Git
    config = @stack.config

    config.root_branch = root_branch
    puts indent("Root branch: #{root_branch.green}".cyan)

    Shell.prompt("Choose your remote: ".green, options: git.remotes) do |remote|
      config.remote = remote
    end

    Shell.prompt("Choose your code review tool: ".green, options: ["none", "github"]) do |tool|
      config.code_review_tool = tool
    end

    puts "\nConfiguration:".green
    puts indent("Root branch: #{config.root_branch.cyan}")
    puts indent("Remote: #{config.remote.cyan}")
    puts indent("Code review tool: #{config.code_review_tool.cyan}")
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
    if @stack.branches.include? "main"
      "main"
    elsif @stack.branches.include? "master"
      "master"
    else
      Shell.prompt("Select the root branch: ".green, options: @stack.branches.keys)
    end
  end
end
