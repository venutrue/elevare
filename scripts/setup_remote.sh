#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <github-repo-url>"
  echo "Example: $0 https://github.com/acme/elevar.git"
  exit 1
fi

repo_url="$1"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$repo_url"
  echo "Updated origin -> $repo_url"
else
  git remote add origin "$repo_url"
  echo "Added origin -> $repo_url"
fi

echo "Current remotes:"
git remote -v

echo
echo "Next steps:"
echo "  1) git push -u origin $(git rev-parse --abbrev-ref HEAD)"
echo "  2) Open GitHub and create PR to main"
