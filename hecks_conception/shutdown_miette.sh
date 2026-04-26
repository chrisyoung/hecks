#!/bin/sh
# Shutdown Miette — thin transitional adapter for capabilities/shutdown/.
#
# Source-of-truth declaration : capabilities/shutdown/shutdown.bluebook
# + shutdown.hecksagon (six declared :daemon adapters, action: :stop).
# Until run_shutdown lands as a Rust runner mirroring run_boot/run_status,
# this shell walks the same six daemons via the kernel-surface
# `hecks-life daemon stop` primitive (i108).
#
# [antibody-exempt: hecks_conception/shutdown_miette.sh — transitional
#  adapter for capabilities/shutdown/shutdown.bluebook. Each `daemon
#  stop` invocation matches a `:daemon` adapter row in shutdown.hecksagon.
#  Retires when run_shutdown lands as a Rust runner walking the bluebook
#  end-to-end. Same i80 retirement contract.]

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
INFO="${HECKS_INFO:-$DIR/information}"
HECKS="$DIR/../hecks_life/target/release/hecks-life"

# Six daemons mirror shutdown.hecksagon's `adapter :daemon, name: …,
# pidfile: "{info}/.<name>.pid", action: :stop` rows. Order is leaf →
# parent (sleep_cycle / ultradian / circadian / breath / heart →
# mindstream) so children stop before parents. Same order boot uses
# in reverse.
DAEMONS="sleep_cycle ultradian circadian breath heart mindstream"

echo "shutting down Miette daemons…"
for daemon in $DAEMONS ; do
  pidfile="$INFO/.${daemon}.pid"
  [ -f "$pidfile" ] || continue
  result=$("$HECKS" daemon stop "$pidfile" 2>&1 || true)
  case "$result" in
    stopped:*) echo "  stopped $daemon (${result#stopped: })" ;;
    "not running") echo "  $daemon: no live process for pidfile" ;;
    "no pidfile") ;; # silent — already cleaned up
    *) echo "  $daemon: $result" ;;
  esac
done
# Sweep for any unknown pidfiles the bluebook doesn't yet declare.
# When all daemons are bluebook-declared this loop becomes empty.
for pidfile in "$INFO"/.*.pid; do
  [ -f "$pidfile" ] || continue
  name=$(basename "$pidfile" .pid | sed 's/^\.//')
  case " $DAEMONS " in *" $name "*) continue ;; esac
  result=$("$HECKS" daemon stop "$pidfile" 2>&1 || true)
  echo "  ${name}: $result (undeclared in shutdown.bluebook)"
done
echo "✓ shutdown complete"
