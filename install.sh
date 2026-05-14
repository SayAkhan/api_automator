#!/usr/bin/env bash
# qa-jira-tracker installer
# - Copies the global slash command into ~/.claude/commands/
# - Prints the Claude Code commands needed to register the marketplace & install the plugin.
#
# This script does NOT modify ~/.claude/settings.json or ~/.claude/plugins/installed_plugins.json.
# Marketplace registration and plugin install must be done from inside Claude Code, because
# those flows depend on Claude Code's own auth and runtime state.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
COMMANDS_DIR="$CLAUDE_HOME/commands"
SRC_CMD="$SCRIPT_DIR/setup/api_automator.md"
DEST_CMD="$COMMANDS_DIR/api_automator.md"

echo "qa-jira-tracker installer"
echo "  script dir : $SCRIPT_DIR"
echo "  claude home: $CLAUDE_HOME"
echo

# 1) precondition
if [[ ! -d "$CLAUDE_HOME" ]]; then
  echo "ERROR: $CLAUDE_HOME does not exist. Install Claude Code first." >&2
  exit 1
fi

if [[ ! -f "$SRC_CMD" ]]; then
  echo "ERROR: $SRC_CMD not found. Run this script from the plugin repo root." >&2
  exit 1
fi

# 2) install global slash command
mkdir -p "$COMMANDS_DIR"
if [[ -f "$DEST_CMD" ]]; then
  echo "found existing $DEST_CMD"
  if cmp -s "$SRC_CMD" "$DEST_CMD"; then
    echo "  → identical, skipped."
  else
    cp "$DEST_CMD" "$DEST_CMD.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SRC_CMD" "$DEST_CMD"
    echo "  → backup taken, command updated."
  fi
else
  cp "$SRC_CMD" "$DEST_CMD"
  echo "installed: $DEST_CMD"
fi

# 3) tell the user what to do inside Claude Code
cat <<'EOF'

────────────────────────────────────────────────────────
Local files installed. Next steps inside Claude Code:

  /plugin marketplace add ~/.claude/plugins/marketplaces/qa-jira-tracker
  /plugin install qa-jira-tracker@qa-jira-tracker
  /reload-plugins

Then call:

  /api_automator

Done. To update later: git pull && ./install.sh && /reload-plugins (in Claude Code).
────────────────────────────────────────────────────────
EOF
