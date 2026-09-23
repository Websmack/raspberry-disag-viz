#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "=== Verify JDK ==="

dpkg-query -W -f='${Status}\n' openjdk-21-jdk-headless \
    | grep -qx 'install ok installed'

cd /opt/DISAG-VIZ

echo "=== Analyze required Java modules ==="

jdeps \
    --ignore-missing-deps \
    --multi-release 21 \
    --recursive \
    --print-module-deps \
    --class-path 'lib/*' \
    classes \
    lib/*.jar \
    > /opt/java-modules.txt

modules="$(tail -n 1 /opt/java-modules.txt)"

if [[ -z "$modules" ]]; then
    echo "ERROR: jdeps returned no Java modules."
    cat /opt/java-modules.txt
    exit 1
fi

echo "Required Java modules:"
echo "$modules"

echo "=== Locate JMODs ==="

jmods="$(
    dirname "$(
        dirname "$(
            readlink -f "$(command -v jlink)"
        )"
    )"
)/jmods"

if [[ ! -d "$jmods" ]]; then
    echo "ERROR: JMOD directory not found: $jmods"
    exit 1
fi

echo "JMOD path: $jmods"

echo "=== Build custom Java runtime ==="

rm -rf /opt/java

jlink \
    --module-path "$jmods" \
    --add-modules "$modules,jdk.charsets,jdk.unsupported,jdk.crypto.ec" \
    --strip-debug \
    --no-header-files \
    --no-man-pages \
    --compress=zip-6 \
    --output /opt/java

echo "=== Preserve CA certificates ==="

if [[ -f /etc/ssl/certs/java/cacerts ]]; then
    cp --remove-destination \
        /etc/ssl/certs/java/cacerts \
        /opt/java/lib/security/cacerts
else
    echo "WARNING: Java CA certificate store not found."
fi

echo "=== Preserve native Java dependencies ==="

mapfile -t native < <(
    apt-cache depends \
        openjdk-21-jre \
        openjdk-21-jre-headless |
    awk '/^  (Pre)?Depends: [^<]/{print $2}' |
    grep -Ev '^(openjdk-|ca-certificates-java)' |
    sort -u
)

if ((${#native[@]})); then
    echo "Keeping native packages:"
    printf '  %s\n' "${native[@]}"

    apt-mark manual "${native[@]}"
else
    echo "No additional native Java dependencies detected."
fi

echo "=== Remove build JDK/JRE ==="

apt-get purge -y \
    binutils \
    openjdk-21-jdk-headless \
    openjdk-21-jre \
    openjdk-21-jre-headless \
    ca-certificates-java

echo "=== Remove unused dependencies ==="

apt-get autoremove --purge -y

java_library_path="$(find /opt/java/lib -type f -name '*.so' -printf '%h\n' | sort -u | paste -sd:)"
missing="$(find /opt/java/lib -type f -name '*.so' -exec env LD_LIBRARY_PATH="$java_library_path" ldd {} \; 2>/dev/null | awk '/not found/{print $1}' | sort -u)"

if [[ -n "$missing" ]]; then
    echo "ERROR: Missing native libraries required by the custom Java runtime:" >&2
    while IFS= read -r library; do printf '  %s\n' "$library"; done <<< "$missing" >&2
    exit 1
fi

echo "=== Verify custom Java runtime ==="

/opt/java/bin/java -version

echo "=== Custom Java runtime successfully created ==="
