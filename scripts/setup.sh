#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .venv
./.venv/bin/pip install --upgrade pip
./.venv/bin/pip install -r requirements.txt

cd mobile_app
flutter pub get

echo "Pocket Claude setup complete."
