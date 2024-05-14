# frozen_string_literal: true
require_relative '../shell'
require_relative 'command'

module Gq::Stack
class Commit < Command
  COMMAND = ["commit", "cc"]

  def self.documentation
    "Commit code to the current branch."
  end

  def call(*args)
    args.map! { |arg| arg.include?(' ') ? "\"#{arg}\"" : arg }

    unless args.include? '-m' or args.include? '--message' or args.include? '-am'
      args << '-m'
      args << ::Gq::Shell.prompt("Commit message", :multiline, placeholder: "Enter your commit message, CTRL-D to finish.")
                          .then { |msg| "\"#{msg}\"" } # quote the message
    end
    @git.commit(args.join(' '))
  end
end
end