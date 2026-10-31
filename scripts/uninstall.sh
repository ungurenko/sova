#!/bin/bash
# Removes Sova completely: gives sleep back, stops the guard, deletes the program,
# its folder, its log and the sudoers rule (asks for the Mac password once).
set -uo pipefail

LABEL=com.ungurenko.sova.guard
SUPPORT="$HOME/Library/Application Support/Sova"

pkill -TERM -x Sova 2>/dev/null
for _ in $(seq 50); do pgrep -qx Sova || break; sleep 0.2; done

# Everything that needs root is one password prompt, made before anything is deleted:
# if sleep cannot be given back, or the prompt is declined, nothing else is removed.
ROOT_CMD=""
[[ -f "$SUPPORT/session" ]] && ROOT_CMD="/usr/bin/pmset -a disablesleep 0"
[[ -e /etc/sudoers.d/sova ]] && ROOT_CMD="${ROOT_CMD:+$ROOT_CMD && }/bin/rm -f /etc/sudoers.d/sova"
if [[ -n "$ROOT_CMD" ]]; then
  echo "Нужен пароль Мака (один раз)."
  osascript -e 'on run argv' -e 'do shell script (item 1 of argv) with administrator privileges' -e 'end run' "$ROOT_CMD" >/dev/null \
    || { echo "Пароль не введён или команда не сработала: ничего не удалено." >&2; exit 1; }
fi

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/Library/Logs/Sova.log"
rm -rf "$HOME/Applications/Sova.app" "$SUPPORT"
echo "Sova удалена."
