# bugbuster — autonomous GitHub ticket fixer

Repo to watch: `$ARGUMENTS` (if empty, use the current working directory). Call it REPO.
The `bugbuster` CLI at `~/.bugbuster/bin/bugbuster` handles the webhook plumbing
(GitHub webhook via `gh webhook forward` — no tunnels, no open ports).

Setup: verify `git -C REPO rev-parse --show-toplevel` works. Then ASK the user
(and wait for their reply before doing anything else): "Each new issue will be
handled with the default pipeline (fix → PR → merge → close). Reply 'default' to
use it, or type a custom instruction or slash command to run for every ticket
instead — it will be followed exactly." Store the reply as HANDLER. Then run
`~/.bugbuster/bin/bugbuster listen REPO` and tell the user which `owner/repo` slug
is being watched and which handler is active.

Then loop until told to stop:

1. Run `~/.bugbuster/bin/bugbuster wait "REPO"` with no timeout — it blocks
   (possibly for a long time) until a new issue is opened, then prints one JSON
   ticket (number, title, body, html_url, labels, author) and exits. Never invent
   a ticket; only act on what it prints. Nonzero exit → report the error and stop.
2. `gh issue view N --json state` — if already closed, go back to 1.
   If HANDLER is custom, it is authoritative and REPLACES steps 3-7: execute the
   user's instruction exactly, 100% as given, with the ticket JSON as its
   argument/context (substitute a literal `{ticket}` placeholder if present); no
   claiming/PR/merge/close unless the handler asks. Then report one line and go
   back to 1. Steps 3-7 below are the default pipeline only.
3. `gh issue comment N --body "🤖 bugbuster is on it."`
4. `git fetch origin`, branch `bugbuster/issue-N` off `origin/<default-branch>`
   (never local state — the clone may hold unpushed work; delete the branch first
   if a stuck earlier attempt left it behind); implement exactly what
   the ticket asks with a minimal diff. Unclear ticket → comment asking for detail,
   change nothing, go back to 1.
5. Run the repo's own checks (test/lint/build that exist); all must pass.
6. Commit `fix: <title> (#N)`, push, `gh pr create` with body containing `Fixes #N`
   plus what changed and how it was verified.
7. `gh pr merge --squash --delete-branch`; confirm the issue closed, close it
   manually if the merge didn't. If merging is blocked, comment the PR link on the
   issue and tell the user.
8. One-line report, back to 1.

On stop: `~/.bugbuster/bin/bugbuster stop "REPO"` (kills the listener and removes
the forwarding webhook). If the Codex process itself dies (exit, terminal closed),
the listener's owner watchdog removes the webhook and stops on its own.
