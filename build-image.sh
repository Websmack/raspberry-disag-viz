#!/bin/bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
CATALOG="$ROOT/config/platforms.conf"
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
  sudo ./build-image.sh --target ZIEL [--bootimage [--logo DATEI]]
  ./build-image.sh --download --target ZIEL
  ./build-image.sh --bootimage [--logo DATEI]
  ./build-image.sh --list-targets

Optionen:
  -t, --target ZIEL    Zielplattform auswählen
  --download           Offizielles DietPi-Image samt SHA256 ohne Rückfrage laden
  --bootimage          Bootgrafik erzeugen; mit --target anschließend Image bauen
  --logo DATEI         Logoquelle für --bootimage (Standard: images/BootLogo.png)
  --list-targets       Unterstützte Plattformen anzeigen
  -h, --help           Hilfe anzeigen
EOF
}

prepare_bootimage() {
  if [[ -n "$logo" ]]; then
    bash "$ROOT/tools/prepare-logo.sh" --logo "$logo"
  else
    bash "$ROOT/tools/prepare-logo.sh"
  fi
}

target=''; download=0; bootimage=0; logo=''
while (($#)); do
  case "$1" in
    --target|-t)
      [[ $# -ge 2 && -n "$2" ]] || { echo 'Nach --target fehlt das Ziel.' >&2; usage >&2; exit 2; }
      target=$2; shift 2
      ;;
    --download) download=1; shift ;;
    --bootimage) bootimage=1; shift ;;
    --logo)
      [[ $# -ge 2 && -n "$2" ]] || { echo 'Nach --logo fehlt die Datei.' >&2; usage >&2; exit 2; }
      logo=$2; shift 2
      ;;
    --list-targets) list_targets; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unbekanntes Argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
(( !download || !bootimage )) || { echo '--download und --bootimage können nicht kombiniert werden.' >&2; exit 2; }
[[ -z "$logo" || $bootimage -eq 1 ]] || { echo '--logo erfordert --bootimage.' >&2; exit 2; }
if [[ -z "$target" ]]; then
  (( bootimage && !download )) || { usage >&2; exit 2; }
  prepare_bootimage
  exit 0
fi

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
download_base_image() {
  local temp_dir temp_image temp_sha expected
  mkdir -p "$ROOT/cache"
  temp_dir=$(mktemp -d "$ROOT/cache/.download-$DISAG_TARGET.XXXXXX")
  temp_image="$temp_dir/$DIETPI_IMAGE"
  temp_sha="$temp_image.sha256"
  echo "Lade $DIETPI_IMAGE ..."
  if ! curl -fL --retry 3 "$DIETPI_BASE_URL/$DIETPI_IMAGE" -o "$temp_image" ||
     ! curl -fL --retry 3 "$DIETPI_BASE_URL/$DIETPI_IMAGE.sha256" -o "$temp_sha"; then
    rm -f -- "$temp_image" "$temp_sha"
    rmdir -- "$temp_dir"
    return 1
  fi
  expected=$(awk 'NR==1{print $1}' "$temp_sha")
  if ! printf '%s  %s\n' "$expected" "$temp_image" | sha256sum -c -; then
    rm -f -- "$temp_image" "$temp_sha"
    rmdir -- "$temp_dir"
    return 1
  fi
  mv -f -- "$temp_image" "$BASE_IMAGE"
  mv -f -- "$temp_sha" "$BASE_SHA256"
  rmdir -- "$temp_dir"
  if [[ $EUID -eq 0 && -n ${SUDO_UID:-} && -n ${SUDO_GID:-} ]]; then
    chown "$SUDO_UID:$SUDO_GID" "$ROOT/cache" "$BASE_IMAGE" "$BASE_SHA256" || true
  fi
  echo "Gespeichert: $BASE_IMAGE"
}

if (( download )); then
  download_base_image
  exit 0
fi

if [[ ! -s "$BASE_IMAGE" || ! -s "$BASE_SHA256" ]]; then
  echo "DietPi-Basisimage oder SHA256-Datei fehlt für $DISAG_TARGET."
  if [[ ! -t 0 ]]; then
    echo "Ohne interaktives Terminal bitte zuerst ./build-image.sh --download --target $DISAG_TARGET ausführen." >&2
    exit 1
  fi
  if ! read -r -p 'Jetzt herunterladen? [j/N] ' answer; then
    echo 'Keine Antwort erhalten; Build abgebrochen.' >&2
    exit 1
  fi
  case "${answer,,}" in
    j|ja|y|yes) download_base_image ;;
    *) echo 'Build abgebrochen.' >&2; exit 1 ;;
  esac
fi

if (( bootimage )); then
  prepare_bootimage
fi

export DISAG_TARGET PLATFORM_NAME DIETPI_IMAGE IMAGE_LAYOUT BASE_IMAGE BASE_SHA256
export OUTPUT_BASENAME="voelkersen-disag-$DISAG_TARGET"
echo "Zielplattform: $PLATFORM_NAME ($DISAG_TARGET)"
exec bash "$ROOT/build-image-platform.sh"
