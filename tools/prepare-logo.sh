#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
usage() {
    echo 'Verwendung: ./tools/prepare-logo.sh [--logo DATEINAME|BILDPFAD]'
    echo 'Ein Dateiname ohne Verzeichnis wird unter images/ gesucht.'
}

case $# in
    0) input=BootLogo.png ;;
    1)
        case $1 in
            -h|--help) usage; exit 0 ;;
            --logo) echo 'Nach --logo fehlt der Dateiname.' >&2; exit 2 ;;
            *) input=$1 ;;
        esac
        ;;
    2)
        [[ $1 == --logo && -n $2 ]] || { usage >&2; exit 2; }
        input=$2
        ;;
    *) usage >&2; exit 2 ;;
esac

if [[ $input == */* ]]; then
    INPUT_PATH=$input
else
    INPUT_PATH="$ROOT/images/$input"
fi
OUTPUT_PATH="$ROOT/kiosk/boot-splash.png"
LOGO_PATH="$ROOT/kiosk/logo.png"

for command in ffmpeg ffprobe; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Benötigtes Programm fehlt: $command" >&2
        exit 1
    }
done

[[ -f "$INPUT_PATH" ]] || {
    echo "Eingabedatei nicht gefunden: $INPUT_PATH" >&2
    exit 1
}

dimensions=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=p=0:s=x -- "$INPUT_PATH")
IFS=x read -r source_width source_height <<< "$dimensions"

if [[ ! "$source_width" =~ ^[1-9][0-9]*$ || ! "$source_height" =~ ^[1-9][0-9]*$ ]]; then
    echo "Bildgröße konnte nicht ermittelt werden: $INPUT_PATH" >&2
    exit 1
fi

# Scale the logo proportionally to at most 60 percent of a 1920x1080 canvas.
max_width=1152
max_height=648
if (( max_width * source_height <= max_height * source_width )); then
    width=$max_width
    height=$(( (source_height * max_width + source_width / 2) / source_width ))
else
    height=$max_height
    width=$(( (source_width * max_height + source_height / 2) / source_height ))
fi

x=$(( (1920 - width) / 2 ))
y=$(( (1080 - height) / 2 ))

ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i 'color=c=black:s=1920x1080' -i "$INPUT_PATH" \
    -filter_complex "[1:v]scale=${width}:${height}:flags=lanczos[logo];[0:v][logo]overlay=${x}:${y}:format=auto,format=rgb24[out]" \
    -map '[out]' -frames:v 1 "$OUTPUT_PATH"

cp -- "$INPUT_PATH" "$LOGO_PATH"
echo "Bootlogo erstellt: ${width}x${height} Pixel bei ${x},${y}."
