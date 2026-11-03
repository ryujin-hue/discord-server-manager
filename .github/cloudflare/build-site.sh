#!/usr/bin/env bash
#
# Builds the static site of the project for Cloudflare Pages.
#
# The Flutter application is built for Android and released as an APK, the
# pages project serves the landing page of the project. When the web build of
# the app is added later, only the two commands below have to change.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

OUT="dist"
rm -rf "${OUT}"
mkdir -p "${OUT}"

cp -R site/. "${OUT}/"

echo "The site is ready in ${OUT}"
