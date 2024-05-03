#!/usr/bin/env ruby

require 'optparse'
require 'toml'

# git wrapper that supports stack-oriented workflows
#
# Requirements: 
#   * gum (for TUI): https://github.com/charmbracelet/gum
#   * git (obvi)
#   * ruby (ditto)
#   * toml (ruby gem)


USAGE = """
Usage:
   gq <git command> | <gq command>

   gq commands:
     create <bn>: creates and switches to a new branch named <bn>
     
     up:     move away from the root

     down:   move toward the root

     sync:   pull root, then restack everything on the current stack

     move:   change the parent of the current branch and rebase this branch and its descendents

     squash: move the current branch's commits to its parent and delete this branch

  These override existing git commands:
     commit:                   create a new git commit

     checkout [bn]:            check out a branch - if no branch name provided, provides a UI for the checkout

     push [branch|down|stack]: push selected branch(es) to the repo. Defaults to `stack`
       * branch: Push just the current branch to `origin`
       * down:   Push the current branch and all modifications below it
       * stack:  Push the entirety of the current stack, including up-stack changes
"""

def self_destruct(msg)
  puts msg
  exit 1
end

def main
  if ARGV.size < 1
    puts USAGE
    exit 1
  end

  is_in_git_tree = `git rev-parse --is-inside-work-tree`
  if is_in_git_tree.strip != 'true'
    puts "Err: You are not in a git repository: #{is_in_git_tree} "
    exit 1
  end

  cmd = ARGV.shift
  puts "Operation: #{cmd}"

  self_destruct "gq has not been initialized - please run gq init" unless gq_stack or cmd == "init"

  case cmd
  in "init"
    init_stack
  in "create"
    create_branch
  else
    puts "Unhandled command #{cmd} - trying git #{cmd} #{ARGV.join(' ')}"
  end
end

### Stack tracking
StackNode = Struct.new(:branch_name, :head, :parent, :children) do
  def initialize(branch_name, head, parent=nil, children=[])
    super(branch_name, head, parent, children)
  end

  def add_child(child)
    if child.parent == branch_name
      children << child
      true
    else
      children.any? { |c| c.add_child(child) }
    end
  end

  def to_toml
    "[#{branch_name}]\nhead = \"#{head}\"\nparent = \"#{parent}\""
  end
end

class Stack
  attr_reader :root
  attr_reader :cur_branch

  def initialize(root, cur_branch)
    @root = root
    @cur_branch = cur_branch
  end

  def self.from_file(toml_file_path)
    self_destruct "No stack file found at #{toml_file_path}" unless File.exists? toml_file_path

    stack_str = File.read(toml_file_path)
    toml_data = TOML::Parser.new(stack_str).parsed
    cur_branch_name = `git branch --show-current`.chomp
    cur_branch = None
    root = nil

    toml_data.each do |bn, attrs|
      node = StackNode.new(bn, attrs['head'], attrs['parent'])
      if bn == cur_branch_name
      if root.nil?
        root = node
      else
        next if root.add_child(node)
        self_destruct "Invalid stack file: #{bn} has parent #{attrs['parent']} but no such branch exists"
      end
    end

    Stack.new(root, cur_branch)
  end

  def add_child(child)
    @root.add_child(child)
  end

  def checkout(branch_node)
    # TODO: Validate this cmd worked
    `git checkout #{branch_node.branch_name}`
    @cur_branch = branch_node
  end

  def up
    # Move away from the root, from the current node to a child
    self_destruct "Already at the top of the stack" if cur_branch.children.empty?

    if cur_branch.children.count == 1
      next_branch = cur_branch.children.first
      checkout(next_branch)
    end

    # TODO: Use gum to choose this
    self_destruct "Ambiguous stack - checkout the branch you want: [#{cur_branch.children.map(&:branch_name).join(', ')}]"
  end

  def down
    # Move toward the root
    self_destruct "Already at the root" if cur_branch.parent.nil?
    checkout(cur_branch.parent)
  end

  def save!(toml_file_path)
    nodes = [@root]
    File.open(toml_file_path, "w") do |f|
      while nodes.any?
        node = nodes.shift
        f.write(node.to_toml)
        f.write("\n\n")
        nodes += node.children
      end
    end
  end
end

### Environment management

def root_dir
  @root_dir ||= `git rev-parse --show-toplevel`.chomp
end

def gq_stack
  load_stack if File.exists?("#{root_dir}/.gq/stack.toml")
end

def cur_branch_to_node
  bn = `git branch --show-current`.chomp
  head = `git rev-parse --short HEAD`.chomp

  StackNode.new(bn, nil, head)
end

def init_stack
  self_destruct "Already initialized" if File.exists? "#{root_dir}/.gq/stack.toml"

  # TODO: Choose this with gum
  root = cur_branch_to_node
  root.parent = nil

  Dir.mkdir("#{root_dir}/.gq")
  File.open("#{root_dir}/.gq/stack.toml", "w") do |f|
    f.write(root.to_toml)
    f.write("\n")
  end
  `echo .gq/ >> #{root_dir}/.gitignore`
end

def create_branch
  bn = ARGV.shift
  parent = `git branch --show-current`.chomp!

  self_destruct "Specify a branch name: gq create <branch name>" if bn.nil? or bn == ""
  self_destruct "No parent!" if [nil, '', 'HEAD'].include? parent

  puts "Creating new branch <#{bn}>"
  puts "  parent: #{parent}"

  res = `git checkout -t #{parent} -b #{bn}`
  sn = cur_branch_to_node(parent)

  bn.add_child(sn)
end

main


# Design
#   gq adds a .gq/ directory to the root of your project which tracks branches in progress
#     (it also adds .gq/ to .gitignore - don't merge your stack config!)
#   in .gq/ there is a file which track the relationship between branches: stack.toml
#   
#   A structure like
#   main/master -> b1 -> b2
#                     \> b3 -> b4
#
#   Becomes: 
#   
#   [main]
#   head: cfa1092...
#   parent: "none"
#
#   [b1]
#   head: c10da...
#   parent: main
#
#   [b2]
#   head: ...
#   parent: b1
#
#   [b3]
#   head: ...
#   parent: b1
#
#   [b4]
#   head: ...
#   parent: b3


