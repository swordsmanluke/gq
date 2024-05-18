# frozen_string_literal: true
require_relative './code_reviewer'

class Gq::CodeReview::MockReviewer < Gq::CodeReview::CodeReviewer
  
  def review_exists?(branch_name, base = nil)
    false
  end

  def find_reviews(branch_name, base = nil)
    []
  end

  def create_review(branch_name, base = nil)
    puts "created (mock) review"
    true
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