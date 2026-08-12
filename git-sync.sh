#!/bin/bash
# Pulls every git repository directly under GIT_SYNC_DEV_DIR, skipping anything
# that isn't safely fast-forwardable. Meant to be run on a timer (see
# launchd/), but safe to run by hand too.
set -uo pipefail
PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH

# Resolve the real path of this file, following symlinks, so git-sync.sh
# keeps working correctly once `install` symlinks it into ~/.local/bin.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/config.sh"

if [ -z "${GIT_SYNC_DEV_DIR:-}" ]; then
  echo "GIT_SYNC_DEV_DIR is not set. Set it via env var or \$HOME/.config/git-sync/config.sh, then run 'git-sync install' again." >&2
  exit 1
fi

mkdir -p "$GIT_SYNC_STATE_DIR"
STATE_FILE="$GIT_SYNC_STATE_DIR/last_notified_date"
ISSUES_FILE=$(mktemp)
trap 'rm -f "$ISSUES_FILE"' EXIT

is_excluded() {
  local name="$1"
  for excluded in $GIT_SYNC_EXCLUDE_DIRS; do
    [ "$name" = "$excluded" ] && return 0
  done
  return 1
}

log_event() {
  local line="$1"
  echo "$line" >> "$GIT_SYNC_LOG_FILE"
  [ "${GIT_SYNC_FOREGROUND:-0}" = "1" ] && echo "$line"
}

trim_log() {
  [ -f "$GIT_SYNC_LOG_FILE" ] || return 0
  local lines
  lines=$(wc -l < "$GIT_SYNC_LOG_FILE" | tr -d ' ')
  [ "$lines" -gt "$GIT_SYNC_MAX_LOG_LINES" ] || return 0
  tail -n "$GIT_SYNC_MAX_LOG_LINES" "$GIT_SYNC_LOG_FILE" > "$GIT_SYNC_LOG_FILE.tmp" && mv "$GIT_SYNC_LOG_FILE.tmp" "$GIT_SYNC_LOG_FILE"
}

for repo in "$GIT_SYNC_DEV_DIR"/*/; do
  repo="${repo%/}"
  name=$(basename "$repo")

  is_excluded "$name" && continue
  [ -d "$repo/.git" ] || continue

  (
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
    upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)

    if [ -z "$upstream" ]; then
      log_event "$(date '+%Y-%m-%d %H:%M:%S') - NO UPSTREAM for: $name (branch=$branch) - pull skipped"
      echo "no_upstream:$name" >> "$ISSUES_FILE"
      exit 0
    fi

    if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
      log_event "$(date '+%Y-%m-%d %H:%M:%S') - NON-MAIN BRANCH for: $name (branch=$branch) - pull skipped"
      echo "non_main_branch:$name" >> "$ISSUES_FILE"
      exit 0
    fi

    if ! git -C "$repo" pull --ff-only --prune --quiet > /dev/null 2>&1; then
      log_event "$(date '+%Y-%m-%d %H:%M:%S') - FAST-FORWARD FAILED for: $name"
      echo "pull_failed:$name" >> "$ISSUES_FILE"
    fi
  ) &
done
wait

trim_log

if [ -s "$ISSUES_FILE" ]; then
  today=$(date '+%Y-%m-%d')
  hour=$((10#$(date '+%H')))
  last_notified=""
  [ -f "$STATE_FILE" ] && last_notified=$(cat "$STATE_FILE")

  if [ "$last_notified" != "$today" ] && [ "$hour" -ge "$GIT_SYNC_NOTIFY_HOUR" ]; then
    total=$(wc -l < "$ISSUES_FILE" | tr -d ' ')
    repos=$(cut -d: -f2 "$ISSUES_FILE" | sort -u | paste -sd ', ' -)
    osascript -e "display notification \"$total repo(s) need attention: $repos. See $GIT_SYNC_LOG_FILE\" with title \"git-sync\"" 2>/dev/null || true
    echo "$today" > "$STATE_FILE"
  fi
fi
