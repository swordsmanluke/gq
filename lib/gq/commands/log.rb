require_relative "../shell"
require_relative "command"

class Log < Command
  COMMAND = ["log"].freeze

  COLOR_CYCLE = %w[cyan magenta orange blue yellow lime bright_yellow red].cycle

  def self.documentation
    "List the branches in the current commands."
  end

  def call(*_args)
    puts as_string
  end

  def as_string
    @stack.roots.map(&method(:root_as_string)).join("\n----------------\n")
  end

  def track_stack_presence(all_branches, (stack, stack_id))
    stack.each do |branch|
      all_branches[branch[:name]] = branch unless all_branches.key?(branch[:name])
      all_branches[branch[:name]][:stacks] << stack_id
      all_branches[branch[:name]][:stacks].uniq! # Remove any dupes!
    end
    all_branches
  end

  def root_as_string(root)
    # For display, I want a stack to have
    #   a color - unique to the branches in the stack from a leaf to it's parent root or split
    #   a depth - what level of indentation should this be shown at?
    #   branches - the name, sha, and a list of commit messages ahead of its parent

    # Let's work backward. From the root, we can find all the branches in the stack.
    # Each branch is either a leaf, a pipe or a split.
    # A leaf is a branch with no children.
    # A pipe is a branch with one child.
    # A split is a branch with multiple children.

    # We color branches by their parent _or_ by taking a new color if their parent branch is a split.

    branches = set_color_and_depth(root)
    branches.reverse.map(&:to_s).join("\n")
  end

  def formatted_diff(cur_branch, parent_branch, max_len = 5)
    return "" if parent_branch.nil? || cur_branch.nil?

    @git.commit_diff(parent_branch, cur_branch)
        .map { |(sha, msg)| "#{sha[0..6].grey} #{msg}" }
        .then { |commits| commits.size > max_len ? commits[0..max_len] + ["    ... (#{commits.size - max_len} more)".grey] : commits[0..max_len] }
        .join("\n")
  end

  LogBranch = Struct.new(:name, :sha, :color, :depth, :commits, :children) do
    def initialize(name, sha, children: [], color: :cyan, depth: 0, commits: [])
      super(name, sha, color, depth, commits, children)
    end

    def leaf?
      children.empty?
    end

    def pipe?
      children.size == 1
    end

    def split?
      children.size > 1
    end

    def to_s
      selected = name == Git.current_branch.name
      dot = selected ? "●" : "○"
      pretty_branch = "#{dot} #{name}".send(color)
      pretty_sha = "#{sha[0..6]}".green

      branch_line = "#{pretty_branch} (#{pretty_sha})"
      diff = indent(formatted_diff, "|  ")
      line = [branch_line, diff].reject(&:empty?).join("\n")
      split? ? tree(line, depth, "|-") : tree(line, depth, "| ")
    end

    def formatted_diff
      commits
        .map { |(sha, msg)| "#{sha[0..6].grey} #{msg}" }
        .then { |commits| commits.size > 5 ? commits[0..5] + ["    ... (#{commits.size - 5} more)".grey] : commits }
        .join("\n")
    end
  end

  protected

  def set_color_and_depth(root)
    root_branch = @stack.branches[root]

    branches = { }
    dfs_branch(root_branch, nil, branches)
    max_depth = branches.values.map(&:depth).min.abs # depths start as negative offset - we want the max abs value
    branches.transform_values! { |branch| branch.tap { _1.depth += max_depth } } # Now our depth values are positive offsets!
    branches.values.group_by { |branch| branch.depth }.values.reduce(:+)
  end

  def dfs_branch(branch, parent, branches)
    color = branch_color(parent)
    depth = depth(branch, parent)
    commits = @git.commit_diff(parent&.name, branch.name)
    children = branch.children

    log_branch = LogBranch.new(branch.name, branch.sha,
                               color: color,
                               depth: depth,
                               children: children,
                               commits: commits)

    branches[branch.name] = log_branch

    branch.children.each { |child| dfs_branch(@stack.branches[child], log_branch, branches) }
  end

  def branch_color(parent)
    parent&.split? ? COLOR_CYCLE.next : parent&.color || :cyan
  end

  def depth(branch, parent)
    parent&.split? ? parent.depth - parent.children.index(branch.name) : parent&.depth || 0
  end
end
