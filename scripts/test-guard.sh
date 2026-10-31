#!/bin/sh
# Runs guard.sh against fake sudo and pgrep in a temp folder and checks what it decides.
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

printf '#!/bin/sh\necho "$@" >> "$T/calls"\n' > "$T/sudo-ok"
printf '#!/bin/sh\nexit 1\n' > "$T/sudo-refuses"
printf '#!/bin/sh\nexit 0\n' > "$T/alive"
printf '#!/bin/sh\nexit 1\n' > "$T/dead"
printf '#!/bin/sh\necho "$@" >> "$T/calls"\necho 9999999999 > "$SOVA_HOME/session"\n' > "$T/sudo-new-session"
chmod +x "$T"/sudo-ok "$T"/sudo-refuses "$T"/sudo-new-session "$T"/alive "$T"/dead

export T SOVA_HOME="$T/support" SOVA_LOG="$T/log"
mkdir -p "$SOVA_HOME"
now="$(date +%s)"
failures=0

# case NAME JOURNAL_CONTENT(or "none") PGREP SUDO EXPECT(restores|leaves|retries|keeps)
case_() {
  rm -f "$SOVA_HOME/session" "$T/calls" "$T/log"
  [ "$2" = none ] || echo "$2" > "$SOVA_HOME/session"
  SOVA_PGREP="$T/$3" SOVA_SUDO="$T/$4" sh "$HERE/guard.sh"
  calls=0; [ -f "$T/calls" ] && calls="$(wc -l < "$T/calls" | tr -d ' ')"
  journal=no; [ -f "$SOVA_HOME/session" ] && journal=yes
  case "$5" in
    restores) ok=$([ "$calls" = 1 ] && [ "$journal" = no ] && grep -q 'disablesleep 0' "$T/calls" && echo y) ;;
    leaves)   ok=$([ "$calls" = 0 ] && echo y) ;;
    retries)  ok=$([ "$journal" = yes ] && echo y) ;;
    keeps)    ok=$([ "$calls" = 1 ] && [ "$journal" = yes ] && echo y) ;;
  esac
  if [ "$ok" = y ]; then echo "ok   $1"; else echo "FAIL $1 (sudo calls: $calls, journal kept: $journal)"; failures=$((failures + 1)); fi
}

case_ "no journal: touches nothing"                      none              dead  sudo-ok       leaves
case_ "session running, program alive: leaves it"        $((now + 3600))   alive sudo-ok       leaves
case_ "session time is up: restores sleep"               $((now - 5))      alive sudo-ok       restores
case_ "program died mid-session: restores sleep"         $((now + 3600))   dead  sudo-ok       restores
case_ "app marked the journal expired (0): restores"     0                 alive sudo-ok       restores
case_ "sudo refuses: keeps the journal to retry"         $((now - 5))      dead  sudo-refuses  retries
case_ "new session began meanwhile: keeps its journal"   $((now - 5))      alive sudo-new-session keeps

exit $failures
