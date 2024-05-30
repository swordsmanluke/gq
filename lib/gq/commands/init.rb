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

    # Check for a valid set of environment vars
    # Right now, only GitHub is supported, so check for those env vars
    check_for_github_auth(config) if config.code_review_tool == "github"

    dist = 20
    puts "\nConfiguration:".green
    puts indent("Root branch:".ljust(dist) + config.root_branch.cyan)
    puts indent("Remote:".ljust(dist) + config.remote.cyan)
    puts indent("Code review tool:".ljust(dist) + config.code_review_tool.cyan)
    if config.code_review_tool != 'none'
      puts indent(indent("username:".ljust(dist) + config.cr_username.cyan)) if config.cr_username
      puts indent(indent("token:".ljust(dist) + (config.cr_token[0..10]+"[...]").cyan)) if config.cr_token
    end

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

  def check_for_github_auth(config)
    if (ENV["GITHUB_USER"] && ENV["GITHUB_PASS"]) || ENV["GITHUB_TOKEN"]
      puts "Found".green + " GitHub ".blue + "credentials in environment".green
      if Shell.prompt? "Would you like to use them?".yellow
        puts "Using GitHub credentials".green

        if ENV["GITHUB_USER"] && ENV["GITHUB_PASS"]
          config.cr_username = ENV["GITHUB_USER"]
          config.cr_password = ENV["GITHUB_PASS"]
          puts indent("username:   #{config.cr_username.cyan}")
          puts indent("password:   #{("********").yellow}")
        end

        if ENV["GITHUB_TOKEN"]
          config.cr_token = ENV["GITHUB_TOKEN"]
          puts indent("auth token: #{(config.cr_token[0..10] + "[...]").cyan}")
        end

        if config.cr_token && config.cr_username
          Shell.prompt("You have both a token and a username/password set. Which would you like to use?".yellow, options: ["token", "username/password"]) do |choice|
            case choice
            when "token"
              config.cr_username = nil
              config.cr_password = nil
            when "username/password"
              config.cr_token = nil
            end
          end
        end
      else
        prompt_for_cr_creds(config)
      end
    else
      prompt_for_cr_creds(config)
    end
    puts "GitHub credentials set! 🎉".green
  end

  def prompt_for_cr_creds(config)
    Shell.prompt("Select style of authentication: ".green, options: ["token", "username/password"]) do |choice|
      case choice
      when "token"
        config.cr_token = Shell.prompt("Enter your GitHub auth token: ".green, :secret)
      when "username/password"
        config.cr_username = Shell.prompt("Enter your GitHub username: ".green)
        config.cr_password = Shell.prompt("Enter your GitHub password: ".green, :secret)
      end
    end
  end

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
