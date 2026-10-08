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
IMAGE="python:3.14.8-slim"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to generate the Linux/x86_64 dependency lock."
  echo "Install/start Docker Desktop and try again."
  exit 1
fi

echo "Resolving pytrain-ogr-deck==$VERSION in Linux/x86_64 using $IMAGE..."

docker run --rm \
  --platform linux/amd64 \
  -e VERSION="$VERSION" \
  -v "$TMP:/out" \
  "$IMAGE" \
  /bin/sh -c '
    set -eu
    python -m pip install --disable-pip-version-check "pytrain-ogr-deck==$VERSION"
    {
      echo "# Exact Python environment resolved for PyCab / pytrain-ogr-deck==$VERSION."
      echo "# Generated in Linux/x86_64 with Python 3.14.8."
      echo "# Regenerate deliberately with ./update-lock.sh <PyTrain-version>."
      python -m pip freeze | LC_ALL=C sort -f
    } > /out/requirements-lock.txt
  '

mv "$TMP/requirements-lock.txt" "$LOCK"

echo
echo "Updated $LOCK for pytrain-ogr-deck==$VERSION"
echo "Review the diff, build/test PyCab, then commit the lock before tagging the release."
