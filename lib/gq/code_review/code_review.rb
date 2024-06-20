# frozen_string_literal: true

module Gq
module CodeReview
  Review = Struct.new(:id, :title, :url, :state, :mergeable, :message, :branch)

  class MergeRequest
    attr_reader :client, :pr
    def initialize(client, pr)
      @client = client
      @pr = pr
    end

    def mergeable?
      raise "Not implemented"
    end

    # Children must implement these methods
    def state
      raise "Not implemented"
    end

    def refresh!
      raise "Not implemented"
    end
  end
end
end
