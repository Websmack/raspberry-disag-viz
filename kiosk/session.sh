#!/bin/bash
set -uo pipefail
export DISPLAY=${DISPLAY:-:0}
echo "DISAG-Sitzung startet auf DISPLAY=$DISPLAY"
xset s off || true
xset -dpms || true
xset s noblank || true
xsetroot -solid black
xhost +SI:localuser:"#$(id -u kiosk)"
openbox --config-file /etc/xdg/openbox/kiosk.xml &
wm=$!
app=''
cleanup() { test -z "$app" || kill "$app" 2>/dev/null || true; kill "$wm" 2>/dev/null || true; }
trap cleanup EXIT
trap 'exit 0' TERM INT
cd /opt/DISAG-VIZ
heap=512M
memory_kib=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
[[ "$memory_kib" -ge 786432 ]] || heap=256M
last=''
display_snapshot() {
    xrandr --props 2>/dev/null || printf 'RandR ist mit diesem Bildschirmtreiber nicht verfügbar.\n'
}
while kill -0 "$wm" 2>/dev/null; do
    # Include EDID: a television connected to a forced-on output can still change.
    state=$(display_snapshot | sha256sum)
    if [[ "$state" != "$last" ]]; then
        /usr/local/bin/disag-display || true
        state=$(display_snapshot | sha256sum)
        last=$state
        if [[ -n "$app" ]]; then
            kill "$app" 2>/dev/null || true
            wait "$app" 2>/dev/null || true
            app=''
        fi
    fi
    if [[ -z "$app" ]] || ! kill -0 "$app" 2>/dev/null; then
        test -z "$app" || wait "$app" 2>/dev/null || true
        size=$(xrandr --query 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\),.*/\1 \2/p' || true)
        read -r width height <<< "${size:-1920 1080}"
        sed -i -e 's/^fullscreenmode=.*/fullscreenmode=true/' -e 's/^screenid=.*/screenid=1/' -e "s/^screensizex=.*/screensizex=$width/" -e "s/^screensizey=.*/screensizey=$height/" config/ressources.txt
        java=/opt/java/bin/java
        [[ -x "$java" ]] || java=/usr/bin/java
        echo "Starte DISAG-Anwendung mit ${width}x${height}, Java=$java"
        runuser -u kiosk -- env HOME=/home/kiosk USER=kiosk LOGNAME=kiosk DISPLAY="$DISPLAY" \
            "$java" -Xms32M -Xmx"$heap" -Dfile.encoding=UTF-8 \
            -classpath 'classes:lib/*' BeamerView ressources.txt &
        app=$!
    fi
    sleep 3
done
exit 1
