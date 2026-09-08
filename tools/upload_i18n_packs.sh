#!/usr/bin/env bash
# Uploads the ten content translation packs to Firebase Storage.
#
# The Flutter app downloads these on demand from `i18n/<lang>.json` and caches
# them on device, which keeps the install small and lets a translation fix ship
# without an app release.
#
# Prerequisites:
#   npm i -g firebase-tools && firebase login
#   gcloud auth login   (gsutil is part of the Google Cloud SDK)
#
# Usage:
#   ./tools/upload_i18n_packs.sh <your-firebase-project-id>

set -euo pipefail

PROJECT="${1:-}"
if [[ -z "$PROJECT" ]]; then
  echo "usage: $0 <firebase-project-id>" >&2
  exit 1
fi

BUCKET="gs://${PROJECT}.firebasestorage.app"
SRC="$(cd "$(dirname "$0")/.." && pwd)/public/i18n"

if [[ ! -d "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

echo "Uploading packs from $SRC to $BUCKET/i18n/"
for f in "$SRC"/*.json; do
  name="$(basename "$f")"
  printf '  %-10s %s\n' "$name" "$(du -h "$f" | cut -f1)"
  gsutil -h "Content-Type:application/json" \
         -h "Cache-Control:public, max-age=604800" \
         cp "$f" "$BUCKET/i18n/$name"
done

echo
echo "Done. Verify one with:"
echo "  gsutil ls -l $BUCKET/i18n/"
