#!/bin/sh
# Check or apply an upstream merge without rewriting the Android patch history.
set -eu
mode=check
upstream_ref=main
while [ "$#" -gt 0 ]; do
    case $1 in
        --check) mode=check; shift ;;
        --apply) mode=apply; shift ;;
        --ref) upstream_ref=${2:?missing upstream ref}; shift 2 ;;
        *) echo "Usage: $0 [--check|--apply] [--ref upstream-branch-or-tag]" >&2; exit 2 ;;
    esac
done
cd "$(git rev-parse --show-toplevel)"
[ "$(git branch --show-current)" = android ] || { echo "Run from the android branch" >&2; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "Requires a clean checkout" >&2; exit 2; }
# Fetch a supplied ref from the canonical URL; never trust a possibly repointed remote.
git fetch --no-tags https://github.com/can1357/oh-my-pi.git "$upstream_ref"
target=$(git rev-parse FETCH_HEAD)
if [ "$mode" = check ]; then
    # merge-tree writes Git objects but never changes HEAD, the index, or the worktree.
    if git merge-tree --write-tree HEAD "$target"; then
        echo "Upstream $upstream_ref ($target) merges without conflicts. Build and test the candidate before releasing."
    else
        echo "Upstream has conflicts; the Android checkout is unchanged." >&2
        exit 1
    fi
else
    git merge --no-ff "$target" -m "merge: synchronize OMP upstream $upstream_ref"
    echo "Upstream merged. Run Android build and runtime checks before releasing."
fi
