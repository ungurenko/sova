#!/bin/bash
# Builds Sova, puts it in ~/Applications, starts the guard, and (once) allows
# exactly two pmset commands without a password. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$HOME/Applications/Sova.app"
SUPPORT="$HOME/Library/Application Support/Sova"
LABEL=com.ungurenko.sova.guard
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
SUDOERS=/etc/sudoers.d/sova
ME="$(id -un)"
[[ "$ME" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Unexpected user name: $ME" >&2; exit 1; }

./scripts/build.sh

# 1. Permission. The rule is built and checked as root in a private temp file,
#    so nobody can swap its content before it is installed.
if [[ ! -e "$SUDOERS" ]]; then
  echo "Нужен пароль Мака (один раз): разрешаю Sova две команды pmset."
  RULE="$ME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
  CMD="f=\$(/usr/bin/mktemp /tmp/sova.XXXXXX) && echo '$RULE' > \$f && /usr/sbin/visudo -cf \$f && /usr/bin/install -m 0440 -o root -g wheel \$f $SUDOERS; r=\$?; /bin/rm -f \$f; exit \$r"
  osascript -e 'on run argv' -e 'do shell script (item 1 of argv) with administrator privileges' -e 'end run' "$CMD" >/dev/null
fi
[[ -e "$SUDOERS" ]] || { echo "Разрешение не установлено, останавливаюсь." >&2; exit 1; }

# 2. Stop the running copy (SIGTERM makes it give sleep back first).
pkill -TERM -x Sova 2>/dev/null || true
for _ in $(seq 50); do pgrep -qx Sova || break; sleep 0.2; done
if pgrep -qx Sova; then echo "Sova не закрылась за 10 секунд, останавливаюсь." >&2; exit 1; fi

# 3. Program, guard script, guard schedule.
mkdir -p "$HOME/Applications" "$SUPPORT" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$APP"
cp -R dist/Sova.app "$APP"
install -m 0755 scripts/guard.sh "$SUPPORT/guard.sh"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>$SUPPORT/guard.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>60</integer>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
# A bootstrap right after a bootout can fail with "Input/output error": retry, then check it is loaded.
for _ in 1 2 3 4 5; do launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null && break; sleep 1; done
launchctl print "gui/$(id -u)/$LABEL" >/dev/null || { echo "Сторож не загрузился." >&2; exit 1; }

open "$APP"
echo "Sova установлена: $APP"
