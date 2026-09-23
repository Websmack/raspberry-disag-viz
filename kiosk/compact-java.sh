#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
apt-get install -y --no-install-recommends openjdk-21-jdk-headless
cd /opt/DISAG-VIZ
jdeps --ignore-missing-deps --multi-release 21 --recursive --print-module-deps --class-path 'lib/*' classes lib/*.jar > /opt/java-modules.txt
modules=$(tail -n 1 /opt/java-modules.txt)
test -n "$modules"
jlink --module-path /usr/lib/jvm/java-21-openjdk-arm64/jmods --add-modules "$modules,jdk.charsets,jdk.unsupported,jdk.crypto.ec" --strip-debug --no-header-files --no-man-pages --compress=zip-6 --output /opt/java
cp --remove-destination /etc/ssl/certs/java/cacerts /opt/java/lib/security/cacerts
# Keep native libraries needed by the generated runtime when removing the JDK/JRE.
mapfile -t native < <(
  apt-cache depends openjdk-21-jre openjdk-21-jre-headless |
    awk '/^  (Pre)?Depends: [^<]/{print $2}' |
    grep -Ev '^(openjdk-|ca-certificates-java)' |
    sort -u
)
if ((${#native[@]})); then
  echo 'Zusätzliche native Java-Abhängigkeiten werden beibehalten:'
  printf '  %s\n' "${native[@]}"
  apt-mark manual "${native[@]}"
else
  echo 'Keine zusätzlichen nativen Java-Abhängigkeiten erkannt.'
fi
apt-get purge -y openjdk-21-jdk-headless openjdk-21-jre openjdk-21-jre-headless ca-certificates-java
apt-get autoremove --purge -y
java_library_path=$(find /opt/java/lib -type f -name '*.so' -printf '%h\n' | sort -u | paste -sd:)
missing=$(find /opt/java/lib -type f -name '*.so' -exec env LD_LIBRARY_PATH="$java_library_path" ldd {} \; 2>/dev/null | awk '/not found/{print $1}' | sort -u)
if [[ -n "$missing" ]]; then
  echo 'Fehlende native Bibliotheken der kompakten Java-Laufzeit:' >&2
  while IFS= read -r library; do printf '  %s\n' "$library"; done <<< "$missing" >&2
  exit 1
fi
/opt/java/bin/java -version
