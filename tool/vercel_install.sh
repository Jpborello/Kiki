#!/usr/bin/env bash
# Instala Flutter en el build de Vercel (su imagen no lo trae).
# Usa el tarball oficial de la misma versión que en desarrollo, con su
# checksum, así el build web de Vercel sale igual que el local.
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_SHA256="af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230"
FLUTTER_DIR="$PWD/.flutter-sdk"

if [ ! -x "$FLUTTER_DIR/flutter/bin/flutter" ]; then
  # La imagen de Vercel (Amazon Linux 2023) puede no traer xz para el .tar.xz.
  command -v xz >/dev/null || dnf install -y xz
  archive="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  curl -fsSL -o "/tmp/$archive" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$archive"
  echo "$FLUTTER_SHA256  /tmp/$archive" | sha256sum -c -
  mkdir -p "$FLUTTER_DIR"
  tar -xf "/tmp/$archive" -C "$FLUTTER_DIR"
  rm "/tmp/$archive"
fi

# El SDK viene de un tarball con otro dueño: sin esto git (que Flutter usa
# internamente) se queja de "dubious ownership".
git config --global --add safe.directory '*'

"$FLUTTER_DIR/flutter/bin/flutter" --disable-analytics
"$FLUTTER_DIR/flutter/bin/flutter" config --no-cli-animations
"$FLUTTER_DIR/flutter/bin/flutter" pub get
