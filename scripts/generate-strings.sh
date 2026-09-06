#!/usr/bin/env bash
# Regenerates the string catalog and its accessors from the Android app's
# strings.xml, so the two apps say exactly the same things.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/strings2catalog.py \
  "${TRAINR_ANDROID:-../Trainr}/app/src/main/res/values/strings.xml" \
  Trainr/Resources/Localizable.xcstrings \
  Trainr/Localization/L10n.swift
