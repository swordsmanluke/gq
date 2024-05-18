# frozen_string_literal: true
require_relative './code_reviewer'
require_relative '../shell'

class Gq::CodeReview::GithubReviewer < Gq::CodeReview::CodeReviewer

  def initialize
    super
    token = ENV['GITHUB_TOKEN']
    self_destruct "GITHUB_TOKEN environment variable not set" if token.nil?
    @client = Octokit::Client.new(access_token: token)
    repo_name = @git.remotes.first.split(?:).last.split('.git').first
    @repo = @client
              .repos
              .map { |repo| repo.full_name }
              .find { |name| name == repo_name }

    self_destruct "cannot find a matching github repo with remote name #{repo_name}" if @repo.nil?
  end

  def review_exists?(branch_name, base = nil)
    reviews(branch_name, base)
           .select { |pr| pr.head.ref == branch_name }
           .any?
  end

  def reviews(branch_name, base = nil)
    # TODO: There's a 'head' filter, that takes a branch name, but prefixed
    # by a head 'user' or 'organization'. I'm not certain yet how to get that.
    @client.pull_requests(@repo, state: 'open', base: base)
           .select { |pr| pr.head.ref == branch_name }
  end

  def create_review(branch_name, base = nil, title = nil, body = nil)
    parent = @git.parent_of(branch_name)
    title ||= @git.commits(branch_name).first.message.split("\n").first
    body ||= @git.commits(branch_name).first.message.split("\n").last
    pr = @client.create_pull_request(
      @repo,
      parent,
      branch_name,
      "Created by gq",
      "Created by gq"
    )
  end

  def update_review(branch_name, base = nil)
    puts "updated (mock) review"
    true
  end

  def approve_review(branch_name, base = nil)
    puts "approved (mock) review"
    true
  end
end