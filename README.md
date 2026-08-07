# git-sync

Keeps every git repository in a directory (by default `~/dev`) up to date with
its remote, automatically, in the background, on macOS via `launchd`.

It only ever does a `git pull --ff-only --prune`. It never touches a repo that
isn't safely fast-forwardable, and it never switches branches for you:

- Repos on a branch other than `main`/`master` are left alone.
- Repos whose current branch has no upstream (or a deleted/gone upstream) are
  left alone.
- If a fast-forward pull would conflict with local changes, git aborts on its
  own — nothing is overwritten.

Every skip/failure is written to a log file. Instead of firing a system
notification on every single run (every 5 minutes, forever), it batches
everything into **one notification per day**, sent the first time the job
runs after a configurable hour (default: 9am local time) if — and only if —
there's something to report. No news, no notification.

## Why

If you keep long-lived clones of your repos around (for example, one base
clone per project, with actual work happening in separate worktrees or
branches elsewhere), the base clones tend to drift out of date. This just
keeps them current so `git pull` is never something you have to remember to
do.

## Install

Requires macOS (`launchd`, `osascript`), `bash`, and `git`.

```sh
git clone git@github.com:wdsrocha/git-sync.git
cd git-sync
./bin/git-sync install
```

This will:

1. Symlink `git-sync.sh` and `bin/git-sync` into `~/.local/bin/`.
2. Generate a `launchd` job from `launchd/git-sync.plist.template` into
   `~/Library/LaunchAgents/`.
3. Load the job with `launchctl`.

Since the installed script is a symlink back into this clone, `git pull`-ing
this repo picks up updates automatically — no need to reinstall after every
change (unless you changed configuration that only takes effect at install
time, like the interval or the launchd label).

## Configuration

Set any of these as environment variables before running `bin/git-sync
install`, or put them in `~/.config/git-sync/config.sh` (sourced by both the
worker script and the CLI):

| Variable                 | Default          | Meaning                                                   |
| ------------------------ | ---------------- | ---------------------------------------------------------- |
| `GIT_SYNC_DEV_DIR`        | `$HOME/dev`      | Directory to scan for repositories (one level deep)        |
| `GIT_SYNC_EXCLUDE_DIRS`   | `wt`             | Space-separated directory names to skip entirely           |
| `GIT_SYNC_NOTIFY_HOUR`    | `9`              | Earliest local hour (0-23) to send the daily digest        |
| `GIT_SYNC_LABEL`          | `local.git-sync` | launchd label, and therefore the plist filename            |
| `GIT_SYNC_INTERVAL`       | `300`            | Seconds between runs (`install`-time only)                 |
| `GIT_SYNC_LOG_FILE`       | `$GIT_SYNC_DEV_DIR/sync_errors.log` | Where events are logged                  |

`GIT_SYNC_EXCLUDE_DIRS` is meant for directories that intentionally don't
follow the "one clean base clone per repo" convention — e.g. a directory
where you keep ad hoc worktrees for whatever you're actively working on.

Example config file:

```sh
# ~/.config/git-sync/config.sh
GIT_SYNC_DEV_DIR="$HOME/code"
GIT_SYNC_EXCLUDE_DIRS="worktrees scratch"
GIT_SYNC_NOTIFY_HOUR=8
```

## Usage

```sh
git-sync status   # is the launchd job loaded? last log lines?
git-sync logs      # follow the log file
git-sync run       # run the sync once, right now, outside of launchd
git-sync uninstall # unload the job, remove the symlinks
```

## How it decides what to skip

For every immediate subdirectory of `GIT_SYNC_DEV_DIR` that isn't in
`GIT_SYNC_EXCLUDE_DIRS` and contains a `.git` directory:

1. If the current branch has no valid upstream, skip and log `no_upstream`.
2. If the current branch isn't `main` or `master`, skip and log
   `non_main_branch`.
3. Otherwise, run `git pull --ff-only --prune --quiet`. If that fails, log
   `pull_failed`.

All three cases feed into the same once-a-day notification digest.

## License

MIT, see [LICENSE](LICENSE).
