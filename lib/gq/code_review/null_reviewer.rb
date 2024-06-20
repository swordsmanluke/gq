# frozen_string_literal: true
require_relative './code_reviewer'

class NullReviewer < Gq::CodeReview::CodeReviewer
  
  def review_exists?(branch_name, base = nil)
    # We don't want to create reviews as the null reviewer, so we always return true to pretend it's already there
    true
  end

  def reviews(branch_name=nil, base = nil)
    []
  end

  def update_review(branch_name, base = nil)
    Gq::CodeReview::Review.new('n/a', "")
  end

  def create_review(branch_name, base = nil, title = nil, body = nil)
    Gq::CodeReview::Review.new('n/a', "")
  end

  def create_merge_request(pr, title=nil, message=nil)
    Gq::CodeReview::MergeRequest.new('n/a', "")
  end
end