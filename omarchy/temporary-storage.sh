# shellcheck shell=sh
# Large builds belong on disk, away from the shared RAM-backed /tmp quota.
if mkdir -p -m 700 "$HOME/.cache/tmp"; then
  export TMPDIR="$HOME/.cache/tmp"
  export TMP="$TMPDIR"
  export TEMP="$TMPDIR"
fi
