#!/bin/sh
# inbox.sh — thin transitional wrapper over `hecks-life inbox`.
#
# [antibody-exempt: i80 cli-routing-as-bluebook + i107 capability-
#  bluebook-end-to-end-dispatch. The brain (Item shape, lifecycle,
#  five queries, the durability protocol) lives in
#  aggregates/inbox.bluebook + capabilities/inbox/inbox.bluebook +
#  capabilities/inbox/inbox.hecksagon. The runner that walks that
#  shape lives in hecks_life/src/run_inbox.rs (named in main.rs as
#  the `inbox` route, marked TRANSITIONAL alongside speak/status/
#  musings/boot/daemon/loop pending i80's cli.bluebook). This file
#  collapses to the one-liner below — pure shell carrier so call
#  sites (`./inbox.sh add high "foo"`, mindstream's `inbox.sh list
#  all`, the dream-wish receipt mechanism's `inbox.sh add
#  --wish=<id>`) keep working. Retires entirely when capability
#  bluebooks dispatch end-to-end through `hecks-life run`.]
#
# Usage (mirror of `hecks-life inbox` — see hecks_life/src/run_inbox.rs):
#   inbox.sh add [--wish=<id>] <priority> <body>
#   inbox.sh list [queued|done|all]
#   inbox.sh show <ref>             (alias: get)
#   inbox.sh done <ref> [resolution] (alias: close)
#   inbox.sh reopen <ref>
#   inbox.sh archive <ref>          (alias: drop)
#   inbox.sh next-ref

DIR="$(cd "$(dirname "$0")" && pwd)"
HECKS="$DIR/../hecks_life/target/release/hecks-life"
[ -x "$HECKS" ] || HECKS=hecks-life
exec "$HECKS" inbox "$@"
