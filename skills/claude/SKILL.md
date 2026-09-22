---
name: bugbuster
description: "Autonomous GitHub ticket fixer. /bugbuster [repo-path] watches a repo for newly opened issues (GitHub webhook via gh), then for each ticket: implement the fix, verify, open a PR, merge it, close the issue, and keep watching. Use when the user runs /bugbuster or asks to auto-fix incoming GitHub issues."
---

# bugbuster

Turn this session into an autonomous ticket-fixing loop for one GitHub repository.
The `bugbuster` CLI (installed at `~/.bugbuster/bin/bugbuster`) handles the webhook
plumbing; your job is the engineering.

## Setup (once)

1. REPO = the argument given after `/bugbuster`, else the current working directory.
   Resolve to an absolute path. Sanity check: `git -C REPO rev-parse --show-toplevel`
   succeeds. If not, show the error and stop.
2. **Ask the user for the per-ticket handler** (plain text question, then end your
   turn and wait for their reply — do not start the loop before they answer):
   "Each new issue will be handled with the default pipeline (fix → PR → merge →
   close the ticket). Reply **default** to use it, or type a custom instruction or
   slash command to run for every ticket instead — it will be followed exactly.
   (Tip: a slash command works with or without the leading `/`, e.g. `gsc-report`.)"
   Store the reply as HANDLER. Empty / "default" → default pipeline.
3. Start watching: `~/.bugbuster/bin/bugbuster listen REPO` (it prints the
   `owner/repo` slug). If it fails, show the error and stop. Tell the user in one
   line which repo is watched and which handler is active, then enter the loop.

## Loop (repeat until the user says stop)

1. **Wait for a ticket.** Run in background Bash (`run_in_background: true`):
   `~/.bugbuster/bin/bugbuster wait "REPO"`
   It blocks — possibly for hours — until a new issue is opened, then exits printing
   one JSON ticket (`number`, `title`, `body`, `html_url`, `labels`, `author`) on
   stdout. Do NOT poll it and do NOT invent tickets; end your turn and the harness
   re-invokes you when it exits. Nonzero exit → report the error to the user and stop.
2. **Guard.** `gh issue view N --json state` (run inside REPO). Already closed →
   skip straight back to step 1. (Covers webhook redeliveries and manually
   handled tickets.)

**If HANDLER is custom, it is authoritative and REPLACES steps 3-7 entirely:**
execute the user's instruction exactly as given, 100% — no default pipeline steps
(no claiming, no PR, no merge, no closing) unless the handler itself asks for them.
If HANDLER is (or names) a slash command, invoke that skill/command, passing the
ticket as its argument/context. If HANDLER contains a literal `{ticket}`
placeholder, substitute the ticket JSON; otherwise provide the ticket JSON
(number, title, body, url) as context alongside. When done, report one line and
go back to step 1. The steps below apply only to the default pipeline.
3. **Claim it.** `gh issue comment N --body "🤖 bugbuster is on it."`
4. **Fix it.** `git fetch origin`, then create `bugbuster/issue-N` from
   `origin/<default-branch>` — never from local state (the clone may hold
   unpushed or dirty work that must not leak into the PR). If the branch
   already exists from a stuck earlier attempt, delete and recreate it.
   Implement exactly what the ticket asks — minimal diff, match the codebase style.
   Unclear or out of scope → comment on the issue asking for detail, do NOT change
   code, return to step 1.
5. **Verify.** Run the repo's own checks (test / lint / build scripts that exist in
   package.json, Makefile, CI config…). Everything you run must pass before shipping.
6. **Ship.** Commit (`fix: <title> (#N)`), push the branch, then
   `gh pr create --title "Fix #N: <title>" --body "Fixes #N\n\n<what changed and how it was verified>"`.
7. **Merge & close.** `gh pr merge --squash --delete-branch`. If merging is blocked
   (protections, failing checks), comment the PR link on the issue and tell the user;
   otherwise confirm the issue auto-closed (`gh issue view N --json state`) and
   `gh issue close N` yourself if it did not.
8. **Report** one line to the user (issue → PR → merged), then go to step 1.

## Stopping

When the user says stop: kill the background wait task, then run
`~/.bugbuster/bin/bugbuster stop "REPO"` (stops the listener and deletes the
forwarding webhook from the repo).

You do not need to handle `/clear`, `/exit`, or the terminal closing — a
SessionEnd hook runs `bugbuster stop-owned`, and the listener's own watchdog
stops it and deletes the webhook if this session's process dies.
