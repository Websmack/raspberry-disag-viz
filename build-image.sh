#!/bin/bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
CATALOG="$ROOT/platforms.conf"
DIETPI_BASE_URL=https://dietpi.com/downloads/images

list_targets() {
  printf '%-24s %-26s %s\n' ZIEL PLATTFORM ARCHITEKTUR
  while IFS='|' read -r id name image _ _; do
    [[ -n "$id" && "$id" != \#* ]] || continue
    arch=${image#*-}; arch=${arch%%-*}
    printf '%-24s %-26s %s\n' "$id" "$name" "$arch"
  done < "$CATALOG"
}

usage() {
  cat <<'EOF'
Verwendung:
  sudo ./build-image.sh --target ZIEL
  ./build-image.sh --download --target ZIEL
  ./build-image.sh --list-targets

Optionen:
  -t, --target ZIEL   Zielplattform auswählen
  --download          Offizielles DietPi-Image samt SHA256 herunterladen
  --list-targets      Unterstützte Plattformen anzeigen
  -h, --help          Hilfe anzeigen
EOF
}

target=''; download=0
while (($#)); do
  case "$1" in
    --target|-t)
      [[ $# -ge 2 && -n "$2" ]] || { echo 'Nach --target fehlt das Ziel.' >&2; usage >&2; exit 2; }
      target=$2; shift 2
      ;;
    --download) download=1; shift ;;
    --list-targets) list_targets; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unbekanntes Argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$target" ]] || { usage >&2; exit 2; }

found=0
while IFS='|' read -r id name image layout aliases; do
  [[ -n "$id" && "$id" != \#* ]] || continue
  if [[ "$target" == "$id" || ",$aliases," == *",$target,"* ]]; then
    DISAG_TARGET=$id; PLATFORM_NAME=$name; DIETPI_IMAGE=$image; IMAGE_LAYOUT=$layout
    found=1; break
  fi
done < "$CATALOG"
(( found )) || { echo "Unbekannte Zielplattform: $target" >&2; list_targets >&2; exit 2; }

BASE_IMAGE="$ROOT/cache/$DISAG_TARGET.img.xz"
BASE_SHA256="$BASE_IMAGE.sha256"
if (( download )); then
  mkdir -p "$ROOT/cache"
  echo "Lade $DIETPI_IMAGE ..."
  curl -fL --retry 3 "$DIETPI_BASE_URL/$DIETPI_IMAGE" -o "$BASE_IMAGE"
  curl -fL --retry 3 "$DIETPI_BASE_URL/$DIETPI_IMAGE.sha256" -o "$BASE_SHA256"
  expected=$(awk 'NR==1{print $1}' "$BASE_SHA256")
  echo "$expected  $BASE_IMAGE" | sha256sum -c -
  echo "Gespeichert: $BASE_IMAGE"
  exit 0
fi

export DISAG_TARGET PLATFORM_NAME DIETPI_IMAGE IMAGE_LAYOUT BASE_IMAGE BASE_SHA256
export OUTPUT_BASENAME="voelkersen-disag-$DISAG_TARGET"
echo "Zielplattform: $PLATFORM_NAME ($DISAG_TARGET)"
case "$IMAGE_LAYOUT" in
  rpi) exec bash "$ROOT/build-image-raspberrypi.sh" ;;
  sbc) exec bash "$ROOT/build-image-dietpi-sbc.sh" ;;
  *) echo "Unbekanntes Image-Layout: $IMAGE_LAYOUT" >&2; exit 2 ;;
esac
