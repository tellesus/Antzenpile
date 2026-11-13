#!/bin/sh
# Packs the tracked 2.0 working files (everything except archive/) into a zip
# used to refresh the local play folder.
set -e
out="${1:-/mnt/user-data/outputs/antzenpile2_sync.zip}"
rm -f "$out"
{ git ls-files; git ls-files --others --exclude-standard; } | grep -v '^archive/' | sort -u | zip -q "$out" -@
echo "$out"
