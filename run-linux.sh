#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROTON_FORCE_LARGE_ADDRESS_AWARE=0
exec "$DIR/run-linux-desktop.sh"
