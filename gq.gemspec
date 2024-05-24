# frozen_string_literal: true
require_relative 'lib/gq/version'
Gem::Specification.new do |spec|
  spec.name = "gq"
  spec.version = Gq::VERSION
  spec.authors = ["Lucas Taylor"]
  spec.email = ["lucas@perfectlunacy.com"]

  spec.summary = "Stacked Commit management for Git"
  spec.description = "GQ is a tool for managing stacked commits in Git. It provides a simple interface for managing a commands of commits, allowing you to easily reorder, squash, and edit commits before pushing them to a remote repository. Gq is designed to be fast, lightweight, and easy to use, making it a great tool for developers who want to keep their commit history clean and organized."
  spec.homepage = "http://perfectlunacy.com"
  spec.license = "GPLV2"
  spec.required_ruby_version = ">= 3.1.4"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # GQ's dependencies
  spec.add_dependency "toml"
  spec.add_dependency "optparse"
  spec.add_dependency "octokit"
  spec.add_dependency "faraday-retry" # Shuts up a warning

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
