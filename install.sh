#!/usr/bin/env bash
# bugbuster installer. Requires the GitHub CLI (gh), logged in.
#   curl -fsSL https://raw.githubusercontent.com/fireinbelly/bugbuster/main/install.sh | bash
# While the repo is private:
#   gh api repos/fireinbelly/bugbuster/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
set -euo pipefail

REPO="${BUGBUSTER_REPO:-fireinbelly/bugbuster}"
REF="${BUGBUSTER_REF:-main}"

command -v gh >/dev/null 2>&1 || { echo "bugbuster needs the GitHub CLI (gh): https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in — run: gh auth login" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "bugbuster needs python3" >&2; exit 1; }

# fetch through the GitHub API so the same installer works while the repo is private
fetch() { gh api "repos/$REPO/contents/$1?ref=$REF" -H "Accept: application/vnd.github.raw"; }

mkdir -p "$HOME/.bugbuster/bin"
fetch bin/bugbuster > "$HOME/.bugbuster/bin/bugbuster"
chmod +x "$HOME/.bugbuster/bin/bugbuster"

gh extension list 2>/dev/null | grep -q "cli/gh-webhook" || gh extension install cli/gh-webhook

# Claude Code skill -> /bugbuster
mkdir -p "$HOME/.claude/skills/bugbuster"
fetch skills/claude/SKILL.md > "$HOME/.claude/skills/bugbuster/SKILL.md"
INSTALLED="Claude Code (/bugbuster)"

# SessionEnd hook so /clear and /exit stop the listener + webhook of that session
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    s = json.load(open(p))
except (OSError, ValueError):
    s = {}
cmd = "$HOME/.bugbuster/bin/bugbuster stop-owned"
entries = s.setdefault("hooks", {}).setdefault("SessionEnd", [])
if not any(cmd in json.dumps(e) for e in entries):
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
    with open(p, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("registered Claude Code SessionEnd hook (auto-stop on /clear, /exit)")
PY

# Codex prompt -> /bugbuster, only when Codex is present
if command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex/prompts"
  fetch skills/codex/bugbuster.md > "$HOME/.codex/prompts/bugbuster.md"
  INSTALLED="$INSTALLED and Codex (/bugbuster)"
fi

echo "bugbuster installed: ~/.bugbuster/bin/bugbuster + $INSTALLED"
echo "In an agent session inside (or pointing at) the repo to watch, run: /bugbuster [repo-path]"
