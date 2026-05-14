#!/usr/bin/env bash
# qa-jira-tracker bootstrap installer
#
# 새 PC에서 한 줄 설치:
#   curl -fsSL https://raw.githubusercontent.com/SayAkhan/api_automator/main/bootstrap.sh | bash
#
# 또는 로컬에서 직접:
#   ./bootstrap.sh
#
# 동작:
#   1. ~/.claude 디렉토리 존재 확인 (Claude Code 설치 전제)
#   2. ~/.claude/plugins/marketplaces/qa-jira-tracker/ 가 없으면 git clone, 있으면 git pull
#   3. install.sh 실행 → 글로벌 슬래시 명령어(~/.claude/commands/api_automator.md) 설치
#   4. Claude Code 안에서 실행할 명령 안내
#
# 이 스크립트는 ~/.claude/settings.json 이나 plugin DB 를 건드리지 않습니다.

set -euo pipefail

REPO_URL="https://github.com/SayAkhan/api_automator.git"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TARGET_DIR="$CLAUDE_HOME/plugins/marketplaces/qa-jira-tracker"

echo "qa-jira-tracker bootstrap"
echo "  repo       : $REPO_URL"
echo "  target dir : $TARGET_DIR"
echo

# 1) precondition
if [[ ! -d "$CLAUDE_HOME" ]]; then
  echo "ERROR: $CLAUDE_HOME does not exist. Install Claude Code first." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: 'git' is not installed." >&2
  exit 1
fi

# 2) clone or pull
mkdir -p "$(dirname "$TARGET_DIR")"
if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "→ existing repo found, pulling latest..."
  git -C "$TARGET_DIR" pull --ff-only
elif [[ -e "$TARGET_DIR" ]]; then
  echo "ERROR: $TARGET_DIR exists but is not a git repo. Remove or rename it and retry." >&2
  exit 1
else
  echo "→ cloning..."
  git clone "$REPO_URL" "$TARGET_DIR"
fi

# 3) run install.sh (copies global slash command)
if [[ -x "$TARGET_DIR/install.sh" ]]; then
  echo
  bash "$TARGET_DIR/install.sh"
else
  echo "ERROR: $TARGET_DIR/install.sh not found or not executable." >&2
  exit 1
fi

# 4) final note
cat <<'EOF'

────────────────────────────────────────────────────────
Bootstrap complete. Now open Claude Code and run:

  /plugin marketplace add ~/.claude/plugins/marketplaces/qa-jira-tracker
  /plugin install qa-jira-tracker@qa-jira-tracker
  /reload-plugins

Then call:

  /api_automator

To update later, just re-run this bootstrap script (or `git pull && ./install.sh`).
────────────────────────────────────────────────────────
EOF
