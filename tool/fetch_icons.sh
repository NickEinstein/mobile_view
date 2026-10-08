#!/usr/bin/env bash
# Downloads the design's icons from Iconify into assets/icons/.
#
# Run once after adding or changing an icon, then commit the SVG files:
#   bash tool/fetch_icons.sh
# The app never contacts Iconify at runtime.
#
# Each line: <file name in assets/icons> <iconify id, as shown in Figma>.
# The file name is what AppIcons (lib/design_system/icons/app_icons.dart)
# refers to; keep the two in sync. Check the icon set's licence before adding
# a new set, and add its credit to assets/icons/LICENSES.txt.
set -euo pipefail

ICONS=(
  "menu          ci:menu-alt-04"
  "home          fluent:home-24-filled"
  "services      ic:round-space-dashboard"
  "applications  selfhst:docs-collaboration-dark"
  "profile       basil:user-solid"
  "log_out       ion:log-out"
  # Dashboard stat cards (the designer's files match these ids).
  "birth_registration  hugeicons:file-02"
  "birth_attestation   hugeicons:document-validation"
  "death_registration  hugeicons:add-to-list"
  "still_birth         hugeicons:file-01"
  # "New registration" sheet (the designer's files match these ids).
  "user            hugeicons:user-02"
  "document        hugeicons:file-01"
  "heart           hugeicons:heart"
  "laurel_wreath   hugeicons:laurel-wreath-01"
  "origin_health   arcticons:origin-health"
  "child_program   healthicons:child-program-outline"
  "parent          iconmind:parent-outline-thin"
  "redo            hugeicons:redo"
)

cd "$(dirname "$0")/.."
mkdir -p assets/icons

for entry in "${ICONS[@]}"; do
  read -r file id <<<"$entry"
  prefix="${id%%:*}"
  name="${id#*:}"
  curl -fsS --retry 3 --max-time 30 \
    "https://api.iconify.design/${prefix}/${name}.svg" \
    -o "assets/icons/${file}.svg"
  echo "  ${file}.svg  <-  ${id}"
done
