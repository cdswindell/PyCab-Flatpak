#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <PyTrain-version>"
  echo "Example: $0 2.12.1"
  exit 2
fi

VERSION="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="$ROOT/requirements-lock.txt"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

python3 -m venv "$TMP/venv"
PYTHON="$TMP/venv/bin/python"
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install "pytrain-ogr-deck==$VERSION"

{
  echo "# Exact Python environment resolved for PyCab / pytrain-ogr-deck==$VERSION."
  echo "# Regenerate deliberately with ./update-lock.sh <PyTrain-version>."
  "$PYTHON" -m pip freeze | LC_ALL=C sort -f
} > "$LOCK"

echo
echo "Updated $LOCK for pytrain-ogr-deck==$VERSION"
echo "Review the diff, build/test PyCab, then commit the lock before tagging the release."
