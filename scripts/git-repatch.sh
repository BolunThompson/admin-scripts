#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: git repatch <base-commit>

Replays every commit in <base-commit>..HEAD, dropping you into `git add -p`
on that commit's own diff. Stage the hunks you want the commit to keep --
press `e` to hand-edit a hunk. Anything you leave unstaged is dropped from
the commit.

The original message, author, and author date are preserved. A commit whose
hunks you drop entirely becomes an empty commit rather than disappearing.

Bail out at any point with `git rebase --abort`.
EOF
  exit 129
}

# ---- per-commit step, invoked by `git rebase -x` ---------------------------
step() {
  # rebase normally hands us the terminal, but be defensive about stdin.
  if [ ! -t 0 ] && (exec 3</dev/tty) 2>/dev/null; then
    exec </dev/tty
  fi

  local orig parent f
  orig=$(git rev-parse HEAD)

  if ! parent=$(git rev-parse -q --verify 'HEAD^'); then
    echo "git-repatch: skipping root commit ${orig:0:9}" >&2
    return 0
  fi

  echo >&2
  git --no-pager log -1 --format='=== %h %s' "$orig" >&2

  # Files this commit creates become untracked after the reset below, so
  # `add -p` would never show them. Intent-to-add makes them visible.
  local added=()
  mapfile -t added < <(git diff --name-only --no-renames --diff-filter=A "$parent" "$orig")

  git reset -q "$parent"
  if [ ${#added[@]} -gt 0 ]; then
    git add -N -- "${added[@]}"
  fi

  git add -p || true

  # An intent-to-add path with nothing staged was declined. Unregister and
  # delete it; otherwise it lingers as an untracked file and blocks any
  # later commit that touches the same path.
  for f in "${added[@]}"; do
    if git diff --cached --quiet -- "$f"; then
      git rm -q --cached --force -- "$f" >/dev/null 2>&1 || true
      rm -f -- "$f"
    fi
  done

  git commit -q --no-verify --allow-empty -C "$orig"
  git reset -q --hard # discard the hunks we didn't keep
}

# ---- entry point ----------------------------------------------------------
if [ "${1-}" = "--step" ]; then
  step
  exit 0
fi

[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac

git rev-parse --verify -q "$1^{commit}" >/dev/null ||
  {
    echo "git-repatch: not a commit: $1" >&2
    exit 1
  }

self=$(command -v -- "$0" || true)
[ -n "$self" ] || self=$0
case "$self" in /*) ;; *) self="$PWD/$self" ;; esac

exec git rebase --exec "$(printf '%q --step' "$self")" "$1"
