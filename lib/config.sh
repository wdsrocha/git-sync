# Shared configuration for git-sync. Sourced by both the worker script and the CLI.
#
# Override any of these by exporting the variable before running git-sync, or by
# creating a config file at $HOME/.config/git-sync/config.sh (or a custom path via
# GIT_SYNC_CONFIG) that sets them.

CONFIG_FILE="${GIT_SYNC_CONFIG:-$HOME/.config/git-sync/config.sh}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

: "${GIT_SYNC_DEV_DIR:=$HOME/dev}"
: "${GIT_SYNC_EXCLUDE_DIRS:=wt}"
: "${GIT_SYNC_NOTIFY_HOUR:=9}"
: "${GIT_SYNC_STATE_DIR:=$HOME/.local/state/git-sync}"
: "${GIT_SYNC_LOG_FILE:=$GIT_SYNC_DEV_DIR/sync_errors.log}"
: "${GIT_SYNC_MAX_LOG_LINES:=1000}"
