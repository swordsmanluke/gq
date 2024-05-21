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
    stack_id = 0
    sorted_branches.map do |b|
      "o #{b[:name]}".tap do |strbrn|
        stack_id.times { |i| strbrn = indent(strbrn, b[:stacks].include?(i) ? ' | ' : '   ') }
        stack_id += 1
      end
    end
  end

  def sorted_branches
    @stack
      .stacks
      .map { |s| s.map { |b| { depth: s.index(b), name: b, stacks: [] } } }
      .each_with_index
      .reduce({}, &method(:track_stack_presence))
      .values
  end

  protected

  def track_stack_presence(all_branches, (stack, stack_id))
    stack.each do |branch|
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
