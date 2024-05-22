# frozen_string_literal: true
require_relative './code_reviewer'
require_relative '../shell'
require 'octokit'

class GithubReviewer < Gq::CodeReview::CodeReviewer

  def initialize(stack, git: Git)
    super
    token = ENV['GITHUB_TOKEN']
    self_destruct "GITHUB_TOKEN environment variable not set" if token.nil?
    @client = Octokit::Client.new(access_token: token)
    @repo = git.remote_url(@config.remote)
               .split(?:)
               .last
               .split('.git')
               .first
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
    message = @git.commits(branch_name).first.split("\n")[4..].map(&:strip).join("\n")
    title ||= message.split("\n").shift
    body ||= message.split("\n")[1..].join("\n")

    to_gq_review @client.create_pull_request(
      @repo,
      parent,
      branch_name,
      title,
      body)
  end

  def update_review(branch_name, base = nil)
    # No action needed here - pushing is all that's required. Just return the pr
    to_gq_review reviews(branch_name, base).first
  end

  def to_gq_review(pr)
    ::Gq::CodeReview::Review.new(pr.id, pr.html_url)
  end

  def merge_review(branch_name, base = nil)
    # TODO
    super
  end
end