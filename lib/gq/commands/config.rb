# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

class Config < Command
  COMMAND = ["configuration", "cfg"]

  def self.documentation
    "Show the current configuration."
  end

  def call(*args)
    self_destruct "No config file found - have you run `gq init`?" unless StackFile.exists?

    cmd = args.length > 0 ? args.shift : ""
    case cmd
    when "show", "s", ""
      pp @stack.config.to_h
    when "delete", "d"
      if Shell.prompt?("Are you sure you want to delete the config file?")
        File.delete(StackFile.config_file_path)
        puts "Deleted config file from #{StackFile.config_file_path.cyan}"
      else
        puts "Aborted".green
      end
    when "reset", "r"
      puts "Resetting config from Git...".green
      File.delete(StackFile.config_file_path)
      @stack.refresh
    end
  end
end
