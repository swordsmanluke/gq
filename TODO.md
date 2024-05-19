# What needs doing

## Goal: sync our yaml config on startup
After loading the yaml file, we need to see if our 
git 'knowledge' is up to date, handling a number of
potential cases:
- [ ] Missing branch 
  - [ ] merged to parent
  - [ ] not merged to parent, just deleted
  - [ ] with child branches
- [ ] New branch
  - [ ] with child branches
- [ ] Updated branch (sha changed)
  - [ ] with child branches

## Goal: Commit code changes
Adds a new commit to the branch, with the new changes
- [ ] Add a new commit to the branch

## Goal: Rebase commits
Rebase all children on their parent branch

- [ ] no conflicts
- [ ] conflicts
- [ ] run after 
  - [ ] commit
  - [ ] merge
  - [ ] pull