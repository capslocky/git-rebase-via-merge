## git rebase via merge ##

Have you ever rebased a branch resolving many conflicts on multiple commits?  
Yes, that's a sad story.  
It wouldn't be so sad, if it was a merge instead, because in case of merge 
we have to fix only final conflicts in just one step.

## method ##

So here is an idea how to how make potentially hard rebase easier:
1. Start a hidden merge
2. Resolve conflicts and save hidden merge result
3. Perform a standard branch rebase, but with automatic conflict resolution
4. Restore hidden result as single additional commit

This script implements this approach as simple dialog and applicable on Linux / Mac / Windows (git-bash).

## setup ##

First, get the script and make it executable

```bash
curl -L https://git.io/fpNiY -o ~/git-rebase-via-merge.sh
chmod +x ~/git-rebase-via-merge.sh
```

Change default base branch if needed by editing this line

```bash
nano ~/git-rebase-via-merge.sh
```
```bash
default_base_branch='origin/master'
```

## usage ##

Every time you want to do rebase, just run

```bash
~/git-rebase-via-merge.sh
```

instead of

```bash
git rebase origin/master
```

## notes ##

If you want to test this script, just run it on temp branch

```bash
git checkout -b test-of-rebase-via-merge
```

Also you can specify base branch like this:

```bash
~/git-rebase-via-merge.sh origin/develop
```