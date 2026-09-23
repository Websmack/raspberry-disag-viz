# DISAG VIZ DietPi-Kiosk

Dieses Projekt erzeugt ein minimales, direkt startendes Kiosk-Image für die
DISAG-OpticScore-Visualisierung. Als Basis dienen offizielle
[**DietPi Trixie ARM64**-Images](https://dietpi.com/#download). Der Builder unterstützt derzeit 42 Profile für Raspberry Pi,
Orange Pi, ODROID, Radxa/ROCK, NanoPi/NanoPC und Pine64.

Das fertige System:

- startet die DISAG-VIZ automatisch auf dem angeschlossenen HDMI-Bildschirm,
- verwendet Xorg, Openbox und eine mit `jlink` reduzierte Java-21-Laufzeit,
- verwendet standardmäßig Ethernet mit DHCP,
- unterstützt konfigurierbares LAN und WLAN, einzeln oder gleichzeitig,
- startet die Anwendung nach einem Absturz automatisch neu,
- zeigt beim Booten ein anpassbares Vereinslogo,
- hält Protokolle im begrenzten RAM-Journal statt dauerhaft auf der SD-Karte.

Erstellt von **Websmack** für den Schützenverein Völkersen.

## Schnellstart

Der eigentliche Image-Build benötigt Linux und Root-Rechte. Download und
Prüfung des DietPi-Basisimages laufen ohne `sudo`.

```bash
./build-image.sh --list-targets
./build-image.sh --download --target raspberry-pi-5
./tools/prepare-logo.sh
sudo ./build-image.sh --target raspberry-pi-5
```

Das Ergebnis liegt anschließend hier:

```text
output/voelkersen-disag-raspberry-pi-5.img.xz
output/voelkersen-disag-raspberry-pi-5.img.xz.sha256
```

## Unterstützte Plattformen

Die verbindliche Liste wird direkt aus [`platforms.conf`](platforms.conf)
erzeugt:

```bash
./build-image.sh --list-targets
```

Enthalten sind:

| Familie | Profile |
|---|---|
| Raspberry Pi | 3B+, 4, 5 |
| Orange Pi | 3, 3B, 3 LTS, 4A, 4 LTS, 4 Pro, 5, 5B, 5 Plus, 5 Max, 5 Pro, 5 Ultra, CM5 |
| ODROID | C2, C4, N2/N2+, M1, M1S, M2 |
| Radxa/ROCK | ROCK 3A, Pi 4, 4C+, 4 SE, 5A, 5B, Radxa Zero, ZERO 3 |
| Pine64 | A64, H64, ROCK64, ROCKPro64, Quartz64 A/B |
| FriendlyElec | NanoPC-T4/T6, NanoPi M4/M4V2/M5/M6 |

Ein Profil bedeutet, dass ein offizielles DietPi-Image vorhanden und der
passende Buildpfad implementiert ist. Bootloader, HDMI/KMS, Netzwerk und die
DISAG-Anwendung müssen trotzdem auf dem jeweiligen echten Board geprüft
werden. Images verschiedener Boards sind nicht austauschbar.

Der Banana Pi M1 ist nicht enthalten, weil DietPi dafür derzeit kein
offizielles Downloadimage anbietet.

## Voraussetzungen

Der Build verwendet Loop-Geräte, Mounts, `chroot` und bei nicht nativen
ARM64-Hosts QEMU. Unterstützt werden:

- Debian 13 oder eine vergleichbare Linux-Distribution,
- WSL2 mit Debian unter Windows,
- eine Linux-VM unter macOS.

Ein direkter Build unter Windows, PowerShell oder macOS wird nicht unterstützt.
Docker Desktop ist wegen der benötigten privilegierten Mount- und
Loop-Geräte-Zugriffe ebenfalls nicht vorgesehen.

Benötigte Pakete unter Debian:

```bash
sudo apt update
sudo apt install qemu-user-static binfmt-support e2fsprogs parted zerofree \
  xz-utils python3 ffmpeg curl openjdk-17-jdk-headless xvfb x11-utils git
```

Zusätzlich werden mindestens 12 GB freier Speicher empfohlen.

## Projekt vorbereiten

### 1. DISAG-VIZ bereitstellen

Die lizenzierte Visualisierungssoftware wird nicht mit diesem Repository
verteilt. Den Inhalt des von DISAG bezogenen ZIP-Archivs nach `DISAG-VIZ/`
entpacken. Danach muss mindestens diese Datei vorhanden sein:

```text
DISAG-VIZ/classes/BeamerView.class
```

### 2. Verbindung konfigurieren

Die Vorgaben für den OpticScore-Server stehen in [`kiosk/disag.txt`](kiosk/disag.txt):

```ini
serverip=192.168.0.101
serverport=7934
vizname=SV-Völkersen-VIZ
```

Die Datei wird in die Bootpartition übernommen und kann dort später ohne
erneuten Build angepasst werden.

### 3. Netzwerk konfigurieren

LAN und WLAN werden über [`kiosk/network.txt`](kiosk/network.txt) konfiguriert.
Beide Schnittstellen können einzeln oder gleichzeitig aktiviert werden. Im
Auslieferungszustand ist LAN mit DHCP aktiv und WLAN deaktiviert:

```ini
lan_enabled=yes
lan_method=dhcp
lan_address=
lan_gateway=
lan_dns=

wifi_enabled=no
wifi_ssid=Mein-WLAN
wifi_password=BITTE-AENDERN
wifi_country=DE
wifi_method=dhcp
wifi_address=
wifi_gateway=
wifi_dns=
```

Für eine statische Adresse `method=static` setzen und Adresse inklusive
CIDR-Präfix, Gateway und mindestens einen DNS-Server eintragen:

```ini
lan_enabled=yes
lan_method=static
lan_address=192.168.10.20/24
lan_gateway=192.168.10.1
lan_dns=1.1.1.1,9.9.9.9
```

Für WLAN mindestens `wifi_enabled=yes`, SSID, Passwort und den
zweistelligen ISO-Ländercode setzen. Ein leeres `wifi_password` konfiguriert
ein offenes WLAN. Das WLAN-Passwort steht im Klartext auf der Bootpartition;
der Zugriff auf die Speicherkarte ist daher entsprechend abzusichern.

Die Datei wird als `network.txt` in die Bootpartition kopiert. Änderungen
werden bei jedem Start vor NetworkManager eingelesen. LAN erhält standardmäßig
die niedrigere Route-Metrik und wird bei gleichzeitig aktiven Verbindungen
bevorzugt; WLAN bleibt als zweite Verbindung aktiv.

### 4. Bootlogo erzeugen

Das Quelllogo liegt unter `images/SVV_Logo.png`. Unter Linux oder WSL:

```bash
./tools/prepare-logo.sh
```

Unter Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare-logo.ps1
```

Dabei wird `kiosk/boot-splash.png` als zentrierte 1920×1080-Bootgrafik
erzeugt.

### 5. Skripte ausführbar machen

```bash
chmod +x build-image.sh build-image-raspberrypi.sh build-image-dietpi-sbc.sh \
  kiosk/*.sh sbc/*.sh tools/*.sh
```

## Image erstellen

Zuerst das offizielle DietPi-Image samt SHA256-Datei herunterladen:

```bash
./build-image.sh --download --target orange-pi-5
```

Der Download wird unter `cache/` gespeichert und unmittelbar geprüft. Danach
den Build mit demselben Ziel starten:

```bash
sudo ./build-image.sh --target orange-pi-5
```

Kurzformen wie `rpi5`, `opi5`, `c4` oder `rock5b` werden ebenfalls
akzeptiert. Die kanonischen Namen aus `--list-targets` sind für Skripte und
Dokumentation vorzuziehen.

Der Build:

1. prüft die SHA256-Summe des DietPi-Basisimages,
2. vergrößert dessen Arbeitskopie,
3. installiert Xorg, Openbox, Plymouth, NetworkManager und Java 21,
4. erzeugt eine reduzierte Java-Laufzeit,
5. führt einen GUI- und Neustart-Smoke-Test unter Xvfb aus,
6. entfernt Buildwerkzeuge, Paketlisten und unnötige Dateien,
7. verkleinert das Dateisystem,
8. erzeugt ein komprimiertes Image und dessen Prüfsumme unter `output/`.

Die gewählte Plattform wird im Image unter `/etc/disag-target` hinterlegt.

## Prüfsumme kontrollieren

```bash
cd output
sha256sum -c voelkersen-disag-orange-pi-5.img.xz.sha256
```

## Image schreiben

Das erzeugte `.img.xz` kann ohne vorheriges Entpacken beispielsweise mit
Raspberry Pi Imager oder balenaEtcher auf eine microSD-Karte geschrieben
werden.

1. Eigenes Image auswählen.
2. `output/voelkersen-disag-ZIEL.img.xz` auswählen.
3. Passende microSD-Karte auswählen und schreiben.
4. Karte, Ethernet und HDMI am Zielboard anschließen.
5. Board starten und die automatische DietPi-Ersteinrichtung abwarten.

Beim Schreiben wird der bisherige Inhalt der Speicherkarte gelöscht. Das Image
darf nur für das im Dateinamen angegebene Board verwendet werden.

## Erster Start und Diagnose

DietPi wird beim ersten Start automatisch und ohne Dialoge eingerichtet:

- LAN und WLAN entsprechend `network.txt`,
- Zeitzone `Europe/Berlin`,
- Hostname `disag-viz`,
- kein SSH-Server,
- keine DietPi-Telemetrie.

Der Kiosk-Dienst wartet auf DietPi-Firstboot und die Netzwerkverfügbarkeit.
Danach startet die Visualisierung auf `tty1`.

Die Meldung `Setting maximal mount count to -1` stammt von `tune2fs` und ist
für sich kein Fehler. Aktuelle Builds legen das ext4-Journal bereits beim
Erstellen des Images an und vermeiden damit DietPis zusätzlichen
Journal-/Neustart-Schritt. Falls diese Meldung mit einem älteren Image dauerhaft
stehen bleibt, das Image neu bauen und erneut auf die Karte schreiben.

Lokaler Diagnosezugang über `Strg`+`Alt`+`F2`:

```text
Benutzer: svvdiag
Passwort: SVV1905!
```

Das Konto besitzt keine `sudo`-Rechte. Das voreingestellte Passwort sollte
vor einem produktiven Einsatz in `kiosk/install.sh` geändert werden.

Kiosk-Protokoll anzeigen:

```bash
journalctl -u disag-kiosk -b
```

Gewählte Zielplattform anzeigen:

```bash
cat /etc/disag-target
```

## Build unter Windows

PowerShell als Administrator öffnen:

```powershell
wsl --install -d Debian
```

Nach dem Neustart Debian öffnen, die Pakete aus
[Voraussetzungen](#voraussetzungen) installieren und das Projekt im
Linux-Dateisystem ablegen, beispielsweise unter
`~/raspberry-disag-viz`. Ein Verzeichnis unter `/mnt/c/` ist für den Build
nicht empfehlenswert.

Das fertige Image kann anschließend nach Windows kopiert werden:

```bash
cp output/voelkersen-disag-raspberry-pi-5.img.xz \
  /mnt/c/Users/DEIN-BENUTZERNAME/Downloads/
```

## Build unter macOS

Unter macOS wird eine Debian-VM benötigt, beispielsweise mit UTM, VMware Fusion
oder Parallels. Empfohlen sind mindestens vier CPU-Kerne, 8 GB RAM und 25 GB
freier VM-Speicher. Der Build wird vollständig innerhalb der VM ausgeführt.

Auf einem ARM64-Linux-Gastsystem läuft der Zielcode nativ. Auf einem
x86_64-Gastsystem registriert der Builder QEMU für ARM64.

## Basisimage aktualisieren

```bash
./build-image.sh --download --target ZIEL
sudo ./build-image.sh --target ZIEL
```

`--download` überschreibt den vorhandenen Cache für dieses Ziel und prüft
anschließend die neue offizielle SHA256-Datei.

Raspberry-Pi-Profile erwarten eine FAT-Bootpartition und eine
ext4-Rootpartition. Die übrigen Profile erwarten das von den ausgewählten
DietPi-SBC-Images verwendete Layout mit einer ext4-Partition und einem
reservierten Bootloaderbereich. Änderungen an den offiziellen
Partitionslayouts können Anpassungen am Builder erforderlich machen.

## Projektstruktur
| Pfad | Im Git | Zweck |
|---|:---:|---|
| `build-image.sh` | ✅ | Zielauswahl, DietPi-Download und Dispatcher |
| `platforms.conf` | ✅ | Plattformname, DietPi-Dateiname, Layout und Kurzformen |
| `build-image-raspberrypi.sh` | ✅ | Raspberry-Pi-Backend |
| `build-image-dietpi-sbc.sh` | ✅ | Gemeinsames Backend der übrigen SBCs |
| `kiosk/` | ✅ | Gemeinsame Anwendung, Dienste und Raspberry-Pi-Schritte |
| `sbc/` | ✅ | Installations- und Finalisierungsschritte für DietPi-SBCs |
| `tools/` | ✅ | Vorbereitung des Bootlogos |
| `images/` | ✅ | Logo-Quelldateien |
| `DISAG-VIZ/` | ❌ | Lokale proprietäre Anwendung |
| `cache/` | ❌ | Heruntergeladene DietPi-Images |
| `output/` | ❌ | Fertige Images, Prüfsummen und Prüfberichte |

## DISAG-Version austauschen

1. Neue Version aus dem DISAG-Kundenbereich herunterladen.
2. Den bisherigen lokalen Ordner `DISAG-VIZ/` sichern.
3. Alte Dateien vollständig entfernen, damit keine Klassen vermischt werden.
4. Den Inhalt des neuen ZIP-Archivs nach `DISAG-VIZ/` entpacken.
5. `DISAG-VIZ/classes/BeamerView.class` prüfen.
6. Das gewünschte Ziel erneut bauen und auf echter Hardware testen.

`jdeps` ermittelt bei jedem Build die benötigten Java-Module neu. Ändert
DISAG den Startklassennamen oder das Verzeichnislayout, müssen
`kiosk/session.sh` und die Eingangsprüfung des Backends angepasst werden.

## GitHub-Release

Images gehören nicht in die Git-Historie. Nach geklärten Weitergaberechten kann
ein Image beispielsweise so als Release-Asset veröffentlicht werden:

```bash
gh release create v1.0.0 \
  output/voelkersen-disag-raspberry-pi-5.img.xz \
  output/voelkersen-disag-raspberry-pi-5.img.xz.sha256 \
  --title "DISAG VIZ DietPi Kiosk v1.0.0"
```

## Grenzen und Hardwaretests

- Die Buildskripte und DietPi-Dateinamen werden automatisiert geprüft.
- Der interne Xvfb-Test prüft Java-Start und Prozessneustart, emuliert aber
  keinen realen HDMI-/DRM-Ausgang.
- Bootlogo, Auflösung, HDMI-Hotplug, Ethernet und Bootloader müssen je
  Boardmodell auf echter Hardware getestet werden.
- Bei Compute-Modulen hängt die Funktion zusätzlich vom verwendeten
  Carrierboard ab.

## Herkunft und Rechte

Die Visualisierungssoftware stammt von
[DISAG](https://www.disag.de). Bezug und Aktualisierung erfolgen über den
DISAG-Kundenbereich; abhängig vom Produkt kann eine passende Lizenz
erforderlich sein.

Dieses Repository enthält keine DISAG-Programmdateien. Das Projekt ist ein
privates, inoffizielles Kiosk-Buildprojekt und steht in keiner geschäftlichen
Verbindung zu DISAG oder DietPi. DISAG, OpticScore, DietPi, Logos und weitere
Kennzeichen gehören ihren jeweiligen Rechteinhabern.

Vor einer öffentlichen Veröffentlichung eines fertigen Images muss geklärt
sein, ob die enthaltene DISAG-Software und das verwendete Vereinslogo
weitergegeben werden dürfen. Für Betrieb, Datenverlust und
Hardwarekompatibilität wird keine Gewähr übernommen.
