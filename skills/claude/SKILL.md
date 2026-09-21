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
   Resolve to an absolute path.
2. Sanity check: `git -C REPO rev-parse --show-toplevel` succeeds, and
   `~/.bugbuster/bin/bugbuster listen REPO` starts (it prints the `owner/repo` slug
   it is watching). If either fails, show the error and stop.
3. Tell the user in one line which repo slug is being watched, then enter the loop.

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
3. **Claim it.** `gh issue comment N --body "🤖 bugbuster is on it."`
4. **Fix it.** From the latest default branch, create `bugbuster/issue-N`.
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
