#!/bin/sh
# Sova guard. Gives sleep back when a session was left behind: the program died,
# the Mac restarted, or the session time ran out without the program noticing.
# launchd runs it at login and every 60 seconds (installed by install.sh).
#
# It does nothing while there is no journal file, so a sleep setting that Sova
# did not make is never touched. The journal is one line, the session end in Unix
# seconds; Sources/SovaCore/SleepHold.swift writes it.
# The SOVA_* variables only exist so scripts/test-guard.sh can run this file safely.

SUPPORT="${SOVA_HOME:-$HOME/Library/Application Support/Sova}"
JOURNAL="$SUPPORT/session"
LOG="${SOVA_LOG:-$HOME/Library/Logs/Sova.log}"
SUDO="${SOVA_SUDO:-/usr/bin/sudo}"
PGREP="${SOVA_PGREP:-/usr/bin/pgrep}"

[ -f "$JOURNAL" ] || exit 0

read -r raw < "$JOURNAL"
ends="$raw"
case "$ends" in ''|*[!0-9]*) ends=0 ;; esac

# The session is still running and its program is alive: leave it alone.
if [ "$(date +%s)" -lt "$ends" ] && "$PGREP" -qx Sova; then
  exit 0
fi

if "$SUDO" -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
  # A new session may have started while this ran: keep its journal, delete only the one we acted on.
  again=""
  read -r again < "$JOURNAL" 2>/dev/null
  [ "$again" = "$raw" ] && rm -f "$JOURNAL"
  echo "$(date '+%F %T') guard: sleep restored" >> "$LOG"
else
  echo "$(date '+%F %T') guard: could not restore sleep (sudo refused); will retry" >> "$LOG"
fi
