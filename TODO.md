# What needs doing

## Bugfix: Github merge issues
- [ ] Context: Merging a stack of commits:
  - [ ] Bug: The base branch does not always get updated to point to master
       - This is a race condition caused by waiting for github to update the branch.
       - We need to wait for the branch to be updated before we can merge the next branch
       - OR we need to edit the PR to point to the correct branch before merging
  - [ ] Bug: Detecting merge status fails
       - we always think the merge failed, even when it succeeded
  - [ ] Bug: It's easy to get out of sync with the PR and fail to push
    - We need to detect PR state and push/pull to sync up before pushing
  - [ ] Add: Aggregate all the PR actions before pushing
  - [ ] Add: Edit PR message locally before committing

## Goal: Handle empty yaml file
[ ] Bug: If the yaml file is empty, the program will crash.
    Even trying to re-init fails.

## Goal: Show config
[ ] Add a command to show the current config in the yaml file

## Goal: Branch logging
[x] Display branches in a tree
[ ] Improve stack rendering/ordering
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
Rebase children on their ancestor's changes
- [ ] Pull, then rebase a branch on its parent
- 