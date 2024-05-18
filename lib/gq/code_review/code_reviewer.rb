# frozen_string_literal: true
require_relative './code_review'

class Gq::CodeReview::CodeReviewer
  def review_exists?(branch_name, base = nil)
    raise NotImplementedError("This method must be implemented in a subclass.")
  end

  def find_reviews(branch_name, base = nil)
    raise NotImplementedError("This method must be implemented in a subclass.")
  end

  def create_review(branch_name, base = nil)
    raise NotImplementedError("This method must be implemented in a subclass.")
  end

  def update_review(branch_name, base = nil)
    raise NotImplementedError("This method must be implemented in a subclass.")
  end

  def approve_review(branch_name, base = nil)
    raise NotImplementedError("This method must be implemented in a subclass.")
  end
end
