#!/usr/bin/env bash
set -euo pipefail

REPO=""
ASSET_PATTERN="wine-cellar-android-.*\.apk"
PACKAGE_NAME="com.maurice.wine_cellar"
INSTALL_MODE="update"
TAG_FILTER_REGEX='^v?[0-9]+\.[0-9]+\.[0-9]+'

print_usage() {
  cat <<EOF
Usage:
  scripts/install_android_apk_latest_tag.sh --repo <owner/repo> [--asset-pattern <regex>] [--tag-filter <regex>] [--package <package_name>] [--fresh-install]

Exemples:
  scripts/install_android_apk_latest_tag.sh --repo maurice/wine_cellar
  scripts/install_android_apk_latest_tag.sh --repo maurice/wine_cellar --tag-filter '^v[0-9]+\.[0-9]+\.[0-9]+$'

Modes d'installation:
  (defaut) update        Met a jour l'application sans desinstaller (donnees conservees)
  --fresh-install        Desinstalle puis reinstalle (donnees supprimees)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --asset-pattern)
      ASSET_PATTERN="$2"
      shift 2
      ;;
    --tag-filter)
      TAG_FILTER_REGEX="$2"
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

if [[ -z "$REPO" ]]; then
  echo "Erreur: fournissez --repo"
  print_usage
  exit 1
fi

for cmd in adb awk curl grep head mktemp sed sort; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Commande manquante: $cmd"
    exit 1
  fi
done

adb start-server >/dev/null

DEVICE_LINES="$(adb devices | sed '1d' | sed '/^$/d' || true)"
if [[ -z "$DEVICE_LINES" ]]; then
  echo "Aucun appareil detecte. Branche ton telephone puis reessaie."
  exit 1
fi

if echo "$DEVICE_LINES" | grep -q 'unauthorized$'; then
  echo "Appareil non autorise. Accepte la popup de debogage USB sur le telephone puis relance."
  exit 1
fi

if echo "$DEVICE_LINES" | grep -q 'offline$'; then
  echo "Appareil offline. Debranche/rebranche le cable USB puis relance."
  exit 1
fi

DEVICE_SERIAL="$(echo "$DEVICE_LINES" | grep 'device$' | head -n1 | awk '{print $1}')"
if [[ -z "$DEVICE_SERIAL" ]]; then
  echo "Aucun appareil en etat 'device'."
  exit 1
fi

echo "Appareil detecte: $DEVICE_SERIAL"

echo "Recuperation des tags pour $REPO..."
TAGS_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/tags?per_page=100")"

LATEST_TAG="$({
  echo "$TAGS_JSON" \
    | grep -Eo '"name"\s*:\s*"[^"]+"' \
    | sed -E 's/"name"\s*:\s*"([^"]+)"/\1/' \
    | grep -E "$TAG_FILTER_REGEX" || true
} | sort -V | tail -n1)"

if [[ -z "$LATEST_TAG" ]]; then
  echo "Aucun tag trouve avec le filtre: $TAG_FILTER_REGEX"
  exit 1
fi

echo "Dernier tag detecte: $LATEST_TAG"

echo "Recuperation de la release associee au tag..."
RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/$LATEST_TAG")"

DOWNLOAD_URL="$(
  echo "$RELEASE_JSON" \
    | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' \
    | sed -E 's/"browser_download_url"\s*:\s*"([^"]+)"/\1/' \
    | grep -E "$ASSET_PATTERN" \
    | head -n1 || true
)"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Aucun asset APK trouve pour le tag $LATEST_TAG (pattern: $ASSET_PATTERN)."
  echo "Verifie qu'une release existe pour ce tag avec un APK attache."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
APK_PATH="$TMP_DIR/app.apk"
cleanup() {
  if [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

echo "Telechargement: $DOWNLOAD_URL"
curl -fL "$DOWNLOAD_URL" -o "$APK_PATH"

if [[ "$INSTALL_MODE" == "update" ]]; then
  echo "Installation APK en mode mise a jour (donnees conservees)..."
  if ! adb -s "$DEVICE_SERIAL" install -r "$APK_PATH"; then
    echo "Echec de mise a jour."
    echo "Verifier que l'APK est signee avec la meme cle que l'application deja installee."
    exit 1
  fi
else
  echo "Installation APK en mode fresh-install (desinstallation prealable)..."
  adb -s "$DEVICE_SERIAL" uninstall "$PACKAGE_NAME" >/dev/null 2>&1 || true
  adb -s "$DEVICE_SERIAL" install "$APK_PATH"
fi

echo "Lancement de l'application..."
adb -s "$DEVICE_SERIAL" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo "Installation terminee depuis le tag $LATEST_TAG."
