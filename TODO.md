# What needs doing

## Goal: Handle empty yaml file
[ ] Bug: If the yaml file is empty, the program will crash.
    Even trying to re-init fails.

## Goal: Show config
[ ] Add a command to show the current config in the yaml file

## Goal: Branch logging
[ ] Display branches in a tree

    Break up branches by 'stack'. Write left-to-right, top-to-bottom
    The longest stack first, but interleaving the shared branches from 
    the shorter stacks.

## Goal: sync our yaml config on startup
After loading the yaml file, we need to see if our 
git 'knowledge' is up to date, handling a number of
potential cases:
- [x] Missing branch
- [ ] New branch - Currently breaks the config!
- [x] Updated branch (sha changed)

## Goal: Commit code changes
Adds a new commit to the branch, with the new changes
- [x] Add a new commit to the branch

## Goal: Rebase commits
Rebase all children on their parent branch
- [ ] Rebase all children on their parent branch using temp branches
- [ ] no conflicts
- [ ] conflicts
- [ ] run after 
  - [ ] commit
  - [ ] merge
  - [ ] pull