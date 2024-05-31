# frozen_string_literal: true
require_relative './code_reviewer'
require_relative '../shell'
require 'octokit'

class GithubReviewer < Gq::CodeReview::CodeReviewer

  def initialize(stack, git: Git)
    super
    @client = build_client
    @repo = git.remote_url(@stack.config.remote)
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

  def reviews(branch_name=nil, base = nil)
    # TODO: There's a 'head' filter, that takes a branch name, but prefixed
    # by a head 'user' or 'organization'. I'm not certain yet how to get that.
    @client.pull_requests(@repo, state: 'open', base: base)
           .then { |prs| branch_name ? prs.select { |pr| pr.head.ref == branch_name } : prs }
           .then { |prs| prs.select { |pr| @git.branches.map(&:name).include? pr.head.ref } } # Just my branches, plz
           .then { |prs| prs.map { |pr| to_gq_review(pr) } }
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
    pr_reviews = @client.pull_request_reviews(@repo, pr.number)
    approval_state = 'pending'
    pr_reviews.each do |review|
      approval_state = 'approved' if review.state == 'APPROVED'
      approval_state = 'changes requested' if review.state == 'CHANGES_REQUESTED'
    end

    ::Gq::CodeReview::Review.new(pr.number, pr.title, pr.html_url, approval_state, approval_state == 'approved', pr.body)
  end

  def merge_review(pr, title=nil, body=nil)
    args = { merge_method: 'squash'}
    args['commit_title'] = title if title
    args['commit_message'] = body if body

    @client.merge_pull_request(@repo, pr.id, **args)
  end

  protected

  def build_client
    # Try authenticating a few ways.
    # While a _token_ is the best, we'll prioritize by the following:
    # 1. github_user/github_password in the config
    # 2. github_token in the config
    # 3. GITHUB_USER/GITHUB_PASSWORD environment variables
    # 4. GITHUB_TOKEN environment variable
    #
    # e.g. values in the config file take precedence over environment variables
    #      and user/password take precedence over tokens.

    # The first non-nil client will be returned
    [
      -> { client_from_user_pass_config },
      -> { client_from_token_config },
      -> { client_from_user_pass_env },
      -> { client_from_token_env }
    ].find{|client_method| client_method.()}.call
  end

  def client_from_user_pass_config
    auth_with_user_pass(@stack.config.cr_username, @stack.config.cr_password)
  end

  def client_from_token_config
    auth_with_token(@stack.config.cr_token)
  end

  def client_from_user_pass_env
    auth_with_user_pass(ENV['GITHUB_USER'], ENV['GITHUB_PASSWORD'])
  end

  def client_from_token_env
    auth_with_token(ENV['GITHUB_TOKEN'])
  end

  def auth_with_user_pass(user, pass)
    return nil if user.nil? || user.empty? || pass.nil? || pass.empty?

    Octokit::Client.new(login: user, password: pass)
  end

  def auth_with_token(token)
    return nil if token.nil? || token.empty?

    Octokit::Client.new(access_token: token)
  end
end

class GithubMergeRequest < Gq::CodeReview::MergeRequest
  def initialize(client, pr, repo)
    @repo = repo
    # Convert our Gq::CodeReview::Review to an Octokit::PullRequest
    super(client, @client.pull_requests(@client.repo, pr.number))
  end

  def state
    @pr = @client.pull_requests(@repo, @pr.number).merged? ? 'success' : 'pending'
  end

  def refresh!
    @pr = @client.pull_requests(@repo, @pr.number)
  end
end