#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <branch-name> [base-branch]"
  echo "Example: $0 feature/db-foundation-pr-ready main"
  exit 1
fi

branch_name="$1"
base_branch="${2:-main}"

# If base branch exists locally, rebase start from it; otherwise keep current HEAD.
if git show-ref --verify --quiet "refs/heads/${base_branch}"; then
  git checkout "${base_branch}"
  git checkout -b "${branch_name}"
else
  git checkout -b "${branch_name}"
fi

echo "Created and switched to branch: ${branch_name}"

if [[ -n "$(git remote)" ]]; then
  echo "Remote detected. To publish branch:"
  echo "  git push -u origin ${branch_name}"
else
  echo "No remote configured. Add one first:"
  echo "  git remote add origin <repo-url>"
  echo "Then publish branch:"
  echo "  git push -u origin ${branch_name}"
fi
