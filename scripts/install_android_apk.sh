#!/usr/bin/env bash
set -euo pipefail

REPO=""
TAG="latest"
ASSET_PATTERN="wine-cellar-android-.*\.apk"
APK_FILE=""
PACKAGE_NAME="com.maurice.wine_cellar"
INSTALL_MODE="update"

print_usage() {
  cat <<EOF
Usage:
  scripts/install_android_apk.sh --repo <owner/repo> [--tag <tag>] [--asset-pattern <regex>] [--package <package_name>] [--fresh-install]
  scripts/install_android_apk.sh --apk-file <path_to_apk> [--package <package_name>] [--fresh-install]

Examples:
  scripts/install_android_apk.sh --repo maurice/wine_cellar
  scripts/install_android_apk.sh --repo maurice/wine_cellar --tag v0.2.0
  scripts/install_android_apk.sh --apk-file ./wine-cellar-android-v0.2.0.apk

Modes d'installation:
  (défaut) update        Met à jour l'application sans désinstaller (données conservées)
  --fresh-install        Désinstalle puis réinstalle (données supprimées)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --asset-pattern)
      ASSET_PATTERN="$2"
      shift 2
      ;;
    --apk-file)
      APK_FILE="$2"
      shift 2
      ;;
    --package)
      PACKAGE_NAME="$2"
      shift 2
      ;;
    --fresh-install)
      INSTALL_MODE="fresh"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Argument inconnu: $1"
      print_usage
      exit 1
      ;;
  esac
done

if [[ -z "$APK_FILE" && -z "$REPO" ]]; then
  echo "Erreur: fournissez --repo ou --apk-file"
  print_usage
  exit 1
fi

for cmd in adb grep sed mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Commande manquante: $cmd"
    exit 1
  fi
done

if [[ -z "$APK_FILE" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "Commande manquante: curl"
    exit 1
  fi
fi

adb start-server >/dev/null

DEVICE_LINES="$(adb devices | sed '1d' | sed '/^$/d' || true)"
if [[ -z "$DEVICE_LINES" ]]; then
  echo "Aucun appareil détecté. Branche ton téléphone puis réessaie."
  exit 1
fi

if echo "$DEVICE_LINES" | grep -q 'unauthorized$'; then
  echo "Appareil non autorisé. Accepte la popup de débogage USB sur le téléphone puis relance."
  exit 1
fi

if echo "$DEVICE_LINES" | grep -q 'offline$'; then
  echo "Appareil offline. Débranche/rebranche le câble USB puis relance."
  exit 1
fi

DEVICE_SERIAL="$(echo "$DEVICE_LINES" | grep 'device$' | head -n1 | awk '{print $1}')"
if [[ -z "$DEVICE_SERIAL" ]]; then
  echo "Aucun appareil en état 'device'."
  exit 1
fi

echo "Appareil détecté: $DEVICE_SERIAL"

TMP_DIR=""
APK_PATH=""

if [[ -n "$APK_FILE" ]]; then
  if [[ ! -f "$APK_FILE" ]]; then
    echo "Fichier APK introuvable: $APK_FILE"
    exit 1
  fi
  APK_PATH="$APK_FILE"
else
  if [[ "$TAG" == "latest" ]]; then
    API_URL="https://api.github.com/repos/$REPO/releases/latest"
  else
    API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
  fi

  RELEASE_JSON="$(curl -fsSL "$API_URL")"

  DOWNLOAD_URL="$(echo "$RELEASE_JSON" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' | sed -E 's/"browser_download_url"\s*:\s*"([^"]+)"/\1/' | grep -E "$ASSET_PATTERN" | head -n1 || true)"

  if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Aucun asset APK trouvé pour $REPO (tag: $TAG, pattern: $ASSET_PATTERN)."
    exit 1
  fi

  TMP_DIR="$(mktemp -d)"
  APK_PATH="$TMP_DIR/app.apk"

  echo "Téléchargement: $DOWNLOAD_URL"
  curl -fL "$DOWNLOAD_URL" -o "$APK_PATH"
fi

if [[ "$INSTALL_MODE" == "update" ]]; then
  echo "Installation APK en mode mise à jour (données conservées)..."
  if ! adb -s "$DEVICE_SERIAL" install -r "$APK_PATH"; then
    echo "Échec de mise à jour. Vérifie que l'APK est signée avec la même clé que l'app déjà installée."
    exit 1
  fi
else
  echo "Installation APK en mode fresh-install (désinstallation préalable)..."
  adb -s "$DEVICE_SERIAL" uninstall "$PACKAGE_NAME" >/dev/null 2>&1 || true
  adb -s "$DEVICE_SERIAL" install "$APK_PATH"
fi

echo "Lancement de l'application..."
adb -s "$DEVICE_SERIAL" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo "Installation terminée."

if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
  rm -rf "$TMP_DIR"
fi
