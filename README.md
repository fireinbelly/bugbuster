# bugbuster

Open a GitHub issue → your local coding agent fixes it, opens a PR, merges it, and
closes the issue. Automatically.

bugbuster wires a GitHub webhook to a Claude Code / Codex session running on your
machine, using nothing but the GitHub CLI — no server, no tunnel, no ngrok, no
exposed ports.

```
new issue ──GitHub webhook──▶ gh webhook forward ──▶ local ticket queue
                                                          │
   issue closed ◀── PR merged ◀── fix + verify ◀── /bugbuster agent session
```

## Install (one line)

```sh
curl -fsSL https://raw.githubusercontent.com/fireinbelly/bugbuster/main/install.sh | bash
```

While this repo is private, use the gh-authenticated form instead:

```sh
gh api repos/fireinbelly/bugbuster/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

Requirements: [GitHub CLI](https://cli.github.com) logged in (`gh auth login`) with
**admin access to the repo you want to watch** (webhook creation needs it), and
`python3`. The installer adds:

- `~/.bugbuster/bin/bugbuster` — the listener/queue CLI
- the [`cli/gh-webhook`](https://github.com/cli/gh-webhook) gh extension
- a Claude Code skill (`~/.claude/skills/bugbuster/`) → `/bugbuster`
- a Codex prompt (`~/.codex/prompts/bugbuster.md`) → `/bugbuster` (only if Codex is installed)

## Use

In a Claude Code or Codex session:

```
/bugbuster [repo-path]     # path defaults to the current working directory
```

The session first asks how each ticket should be handled:

- **default** — the built-in pipeline: block until a new issue is opened →
  implement the fix on a `bugbuster/issue-N` branch → run the repo's own
  tests/build → push → open a PR with `Fixes #N` → squash-merge → confirm the
  issue closed → wait for the next ticket.
- **anything else** — a custom instruction or slash command (e.g. `gsc-report`,
  with or without the leading `/`) that is executed *exactly as you wrote it* for
  every incoming ticket, with the ticket JSON as its input (use a `{ticket}`
  placeholder to control where it goes). The default pipeline is skipped entirely.

Tickets that arrive while one is being handled are queued and picked up next.
Unclear tickets (default pipeline) get a comment asking for detail instead of
code changes.

Say `stop` to end the loop (the listener is stopped and the webhook removed).
The webhook is also cleaned up automatically when the session ends any other way:
a Claude Code SessionEnd hook fires on `/clear` and `/exit`, and the listener's
own watchdog notices the owning agent process dying (terminal closed, crash) and
removes the webhook itself within seconds.

### CLI (what the skill drives)

```sh
~/.bugbuster/bin/bugbuster wait   [path]  # ensure listener, block until a ticket, print it as JSON
~/.bugbuster/bin/bugbuster listen [path]  # start the background listener only
~/.bugbuster/bin/bugbuster stop   [path]  # stop listener + delete the forwarding webhook
~/.bugbuster/bin/bugbuster stop-owned     # stop listeners owned by this agent session (used by the SessionEnd hook)
~/.bugbuster/bin/bugbuster status         # list listeners, owners, and queue depths
```

`wait`/`listen` record the claude/codex process they run under as the listener's
*owner*; the listener self-stops (and deletes the webhook) when that process dies.
A listener started manually from a plain shell has no agent owner and runs until
`bugbuster stop`.

## Security model

- The webhook GitHub creates points at `webhook-forwarder.github.com` (GitHub's own
  CLI forwarding service), never at your machine. Events reach you over the gh CLI's
  authenticated outbound connection. Nothing on your machine listens on any port.
- Only `issues` events are subscribed, and only `action: opened` is queued.
- All repo writes (branch, PR, merge, close) happen through your own `gh` auth,
  with whatever permissions it already has. bugbuster stores no credentials.
- `bugbuster stop` deletes the forwarding webhook, leaving the repo as it was.
- Caveat: the agent implements whatever new issues ask for. Point it only at repos
  where everyone who can open issues is trusted (issue text is effectively a prompt).

## Limits

- Only issues opened **while the listener is running** are captured; there is no
  backfill of pre-existing open issues.
- The listener survives network blips (auto-restart), but after a long laptop sleep
  restart it with `bugbuster stop && bugbuster listen` if the log shows no traffic.
- Runtime state lives in `~/.bugbuster/{queue,run,log}/`.

## Uninstall

```sh
~/.bugbuster/bin/bugbuster status   # stop any listeners first: bugbuster stop <path>
rm -rf ~/.bugbuster ~/.claude/skills/bugbuster ~/.codex/prompts/bugbuster.md
gh extension remove gh-webhook      # optional
```

Also remove the `bugbuster stop-owned` entry from `hooks.SessionEnd` in
`~/.claude/settings.json`.

## License

[MIT](LICENSE)
