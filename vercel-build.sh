#!/usr/bin/env bash
# Script de build usado pelo Vercel (ver vercel.json → buildCommand).
# O Vercel não tem Flutter pré-instalado, então este script baixa o
# SDK (versão fixa 3.35.4, igual ao ambiente de desenvolvimento) e
# gera o build web estático em build/web.
set -euo pipefail

FLUTTER_VERSION="3.35.4"
FLUTTER_DIR="$HOME/flutter"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Descargando Flutter SDK $FLUTTER_VERSION..."
  curl -sSL "$ARCHIVE_URL" -o /tmp/flutter.tar.xz
  mkdir -p "$HOME"
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
  rm -f /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "==> flutter --version"
flutter --version

echo "==> flutter config --no-analytics"
flutter config --no-analytics >/dev/null 2>&1 || true

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build web --release"
flutter build web --release

echo "==> Build concluido: build/web"
