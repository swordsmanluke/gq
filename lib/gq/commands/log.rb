require_relative "../shell"
require_relative "command"

class Log < Command
  COMMAND = ["log"].freeze

  def self.documentation
    "List the branches in the current commands."
  end

  def call(*_args)
    puts as_string
  end

  def as_string
    out = []
    sorted_branches.each do |b|
      out << tree("o #{b[:name].cyan}", b[:stacks].max)
    end
    out.join"\n"
  end

  def sorted_branches
    max_depth = @stack.stacks.map(&:size).max
    @stack
      .stacks
      .map { |s| s.map { |b| { depth: s.index(b), name: b, stacks: [] } } }
      .each_with_index
      .reduce({}, &method(:track_stack_presence))
      .values
      .sort_by{ [max_depth - _1[:depth], _1[:stacks].min] }
  end

  protected

  def track_stack_presence(all_branches, (stack, stack_id))
    stack.each do |branch|
      puts "#{stack_id.to_s.green}: #{branch[:name].cyan}"
      all_branches[branch[:name]] = branch unless all_branches.key?(branch[:name])
      all_branches[branch[:name]][:stacks] << stack_id
      all_branches[branch[:name]][:stacks].uniq!  # Remove any dupes!
    end
    all_branches
  end

  private

  def formatted_diff(cur_branch, parent_branch, max_len=5)
    return "" if parent_branch.nil? || cur_branch.nil?

    @git.commit_diff(cur_branch, parent_branch)
        .map { |(sha, msg)| "#{sha[0..6].grey} #{msg}" }
        .then { |commits| commits.size > max_len ? commits[0..max_len] + ["    ... (#{commits.size - max_len} more)".grey] : commits[0..max_len] }
        .join("\n")
  end
end
