# frozen_string_literal: true
require_relative './code_reviewer'
require_relative '../shell'
require 'octokit'

class GithubReviewer < Gq::CodeReview::CodeReviewer

  def initialize(stack, git: Git)
    super
    @client = build_client
    raise "Could not authenticate with GitHub" if @client.nil?
    @repo = git.remote_url(@stack.config.remote)
               .split(?:)
               .last
               .split('.git')
               .first
  end

  def review_exists?(branch_name, base = nil)
    reviews(branch_name, base)
      .select { |pr| pr.branch == branch_name }
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
    reviews(branch_name, base).first
  end

  def to_gq_review(pr)
    pr_reviews = @client.pull_request_reviews(@repo, pr.number)
    approval_state = 'pending'
    pr_reviews.each do |review|
      approval_state = 'approved' if review.state == 'APPROVED'
      approval_state = 'changes requested' if review.state == 'CHANGES_REQUESTED'
    end

    mergeable = nil
    10.times do |i|
      gh_pr = @client.pull_request(@repo, pr.number)
      mergeable = gh_pr.mergeable
      break unless mergeable.nil?
      sleep(1)
    end
    if mergeable.nil?
      puts "Mergeability could not be determined.".yellow
    end

    ::Gq::CodeReview::Review.new(pr.number, # We'll use this as the ID
                                 pr.title,
                                 pr.html_url,   # This is the URL for humans
                                 approval_state,  # Has this PR been approved?
                                 mergeable,
                                 pr.body,
                                 pr.head.ref)  # Branch name
  end

  def merge_review(pr, title=nil, body=nil)
    args = { merge_method: 'squash'}
    args['commit_title'] = title if title
    @client.merge_pull_request(@repo, pr.id, body, **args)
    GithubMergeRequest.new(@client, pr, @repo)
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
    super(client, okto_pr(pr.id))
  end

  def state
    @pr.merged? ? 'success' : 'pending'
  end

  def refresh!
    @pr = ockt_pr(@pr.number)
  end

  private
  def okto_pr(id)
    @client.pull_request(@repo, id)
  end
end
