# DISAG VIZ Raspberry-Pi-Kiosk

Ich nutze dieses Projekt, um die DISAG-OpticScore-Visualisierung als kleines Kiosk-Image auf einem Raspberry Pi 3, 4 oder 5 zu betreiben. Das Image startet direkt in die Visualisierung, zeigt beim Booten das Vereinslogo und startet die Anwendung nach einem Absturz neu.

Erstellt von **Websmack** für den Schützenverein Völkersen.

## Aufbau

```mermaid
flowchart LR
    OSS[DISAG OpticScore Server] -->|LAN / TCP 7934| VIZ
    VIZ -->|HDMI-Ausgabe| TV[TV oder Beamer]
    subgraph KIOSK[Raspberry Pi Kiosk]
        OS[Raspberry Pi OS Lite] --> X[Xorg / KMS]
        X --> JAVA[reduzierte Java-21-Laufzeit]
        JAVA --> VIZ[DISAG VIZ]
        SYSTEMD[systemd] -->|Start und Neustart| X
    end
```

Der Fernseher wird über KMS/DRM erkannt. Beim Pi 5 wird die DRM-Karte mit HDMI-Anschluss dynamisch ausgewählt, weil sich die Kartennummern ändern können. Netzwerk wird per LAN und DHCP eingerichtet. Die Vorgabe für den DISAG-Server steht in `kiosk/disag.txt`.

## Projektdateien

| Pfad | Zweck |
|---|---|
| `build-image.sh` | Einziger Einstiegspunkt für einen vollständigen Build. |
| `DISAG-VIZ/` | Lokal abgelegte DISAG-Anwendung. Wird nicht in Git aufgenommen. |
| `cache/` | Raspberry-Pi-OS-Basisimage und dessen SHA256-Datei. Wird nicht in Git aufgenommen. |
| `images/SVV_Logo.png` | Originales Vereinslogo. |
| `tools/prepare-logo.ps1` | Erstellt daraus die zentrierte 1920×1080-Bootgrafik. |
| `kiosk/install.sh` | Installiert Xorg, Java, Plymouth, Netzwerk und systemd-Dienste ins Image. |
| `kiosk/session.sh` | Startet Openbox und die DISAG-Anwendung und überwacht beide. |
| `kiosk/disag-kiosk.service` | systemd-Dienst für Autostart und Neustart. |
| `kiosk/wait-display.sh` | Findet die zum HDMI-Anschluss gehörende DRM-Karte. |
| `kiosk/display.py` | Wählt den aktiven HDMI-Ausgang und dessen bevorzugte Auflösung. |
| `kiosk/settings.py` | Übernimmt Server-IP, Port und VIZ-Namen von der Bootpartition. |
| `kiosk/compact-java.sh` | Erzeugt mit `jdeps` und `jlink` eine kleine Java-Laufzeit. |
| `kiosk/minimize.sh` | Entfernt Entwicklungs-, Cloud- und nicht benötigte Pakete. |
| `kiosk/finish-logo.sh` | Baut Logo und Plymouth-Theme in beide Initramfs-Varianten ein. |
| `kiosk/smoke-test.sh` | Prüft ARM-Java-Start und Neustart nach einem simulierten Absturz. |
| `kiosk/finalize.sh` | Verkleinert das Dateisystem und erzeugt `.img.xz` samt SHA256. |
| `output/` | Lokale Buildausgabe und späteres Release-Asset. Bleibt außerhalb von Git. |

Die übrigen Dateien in `kiosk/` sind Konfigurationen oder kleine Prüfwerkzeuge, die von diesen Schritten verwendet werden.

## Voraussetzungen

Ich baue das Image unter Linux oder WSL mit Root-Rechten. Benötigt werden:

- `qemu-aarch64-static` ab Version 8
- `e2fsprogs` ab Version 1.47.2
- `parted`, `zerofree`, `xz`, Python 3
- OpenJDK 17 oder neuer, Xvfb und X11-Werkzeuge für den Starttest
- mindestens 12 GB freier Speicher

Beispiel für Debian 13:

```bash
sudo apt update
sudo apt install qemu-user-static binfmt-support e2fsprogs parted zerofree xz-utils \
  python3 openjdk-17-jdk-headless xvfb x11-utils
```

## Image bauen

1. Repository auschecken und in das Projekt wechseln.
2. Im DISAG-Kundenbereich die lizenzierte VIZ-Software herunterladen und den **Inhalt** des ZIP-Archivs nach `DISAG-VIZ/` entpacken. Danach muss `DISAG-VIZ/classes/BeamerView.class` existieren.
3. Das aktuelle **Raspberry Pi OS Lite ARM64** von [Raspberry Pi](https://www.raspberrypi.com/software/operating-systems/) herunterladen. Das Image als `cache/base.img.xz` und die zugehörige SHA256-Datei als `cache/base.sha256` speichern.
4. Bei Bedarf `kiosk/disag.txt` bearbeiten:

   ```ini
   serverip=192.168.0.101
   serverport=7934
   vizname=SV-Völkersen-VIZ
   ```

5. Bootlogo vorbereiten:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\prepare-logo.ps1
   ```

6. Build in Linux beziehungsweise WSL starten:

   ```bash
   chmod +x build-image.sh kiosk/*.sh
   sudo ./build-image.sh
   ```

7. Ergebnis prüfen:

   ```bash
   cd output
   sha256sum -c voelkersen-disag-pi3-pi5.img.xz.sha256
   ```

Der Build entfernt einen alten Arbeitsstand unter `/var/tmp/disag-kiosk-build`, prüft aber vorher, dass davon nichts mehr eingehängt ist. Das fertige Image liegt ausschließlich unter `output/voelkersen-disag-pi3-pi5.img.xz`.

## Auf den Raspberry Pi übertragen

1. [Raspberry Pi Imager](https://www.raspberrypi.com/software/) öffnen.
2. Unter „Betriebssystem wählen“ ein eigenes Image auswählen.
3. `output/voelkersen-disag-pi3-pi5.img.xz` auswählen; Entpacken ist nicht nötig.
4. microSD-Karte wählen und schreiben. Dabei wird ihr bisheriger Inhalt gelöscht.
5. Keine zusätzlichen Benutzer- oder WLAN-Einstellungen im Imager setzen.
6. SD-Karte, LAN und HDMI anschließen und den Pi starten.

Die sichtbare `bootfs`-Partition enthält `disag.txt`. Damit lassen sich Server-IP, Port und Anzeigename ohne neuen Build ändern. Der lokale Diagnosezugang liegt auf `Strg`+`Alt`+`F2`:

```text
Benutzer: svvdiag
Passwort: SVV1905!
```

Das Konto besitzt keine `sudo`-Rechte. Kiosk-Protokoll:

```bash
journalctl -u disag-kiosk -b
```

## DISAG-Version austauschen

1. Neue VIZ-Version aus dem [DISAG-Kundenbereich](https://www.disag.de/login/) herunterladen.
2. Den bisherigen lokalen Ordner `DISAG-VIZ/` sichern und anschließend vollständig leeren. Alte Klassen oder Bibliotheken sollen nicht mit einer neuen Version vermischt werden.
3. Den Inhalt des neuen VIZ-ZIP-Archivs nach `DISAG-VIZ/` entpacken.
4. Prüfen, ob `classes/`, `lib/`, `config/` und `classes/BeamerView.class` vorhanden sind.
5. `sudo ./build-image.sh` erneut ausführen.
6. Anwendung und Verbindung zum echten OpticScore-Server testen.

`jdeps` ermittelt bei jedem Build die benötigten Java-Module neu. Falls DISAG den Startklassennamen oder das Verzeichnislayout ändert, müssen `kiosk/session.sh` und die Dateiprüfung in `build-image.sh` angepasst werden.

## Linux-Basisimage aktualisieren

1. Neues Raspberry Pi OS Lite ARM64 samt offizieller SHA256-Datei herunterladen.
2. `cache/base.img.xz` und `cache/base.sha256` ersetzen.
3. Versionen von QEMU und e2fsprogs prüfen.
4. Image mit `sudo ./build-image.sh` komplett neu bauen.
5. Start, Logo, HDMI-Hotplug, LAN, App-Neustart und Verbindung zum DISAG-Server auf realer Hardware testen.

Der Build erwartet die übliche Raspberry-Pi-OS-Aufteilung: FAT-Bootpartition 1 und ext4-Rootpartition 2. Ändert Raspberry Pi dieses Layout oder Paketnamen, müssen die Buildskripte angepasst werden.

## Eigenes Vereinslogo

1. Eigenes Logo als PNG unter `images/SVV_Logo.png` ablegen.
2. `tools/prepare-logo.ps1` ausführen.
3. Die erzeugte Datei `kiosk/boot-splash.png` kontrollieren.
4. Image neu bauen.

Das Logo wird proportional auf höchstens 60 Prozent der 1920×1080-Bootfläche skaliert und auf schwarzem Hintergrund zentriert.

## GitHub-Release

Images gehören nicht in die Git-Historie. Nach geklärten Weitergaberechten kann das lokale Image als Release-Asset hochgeladen werden, zum Beispiel:

```bash
gh release create v1.0.0 \
  output/voelkersen-disag-pi3-pi5.img.xz \
  output/voelkersen-disag-pi3-pi5.img.xz.sha256 \
  --title "DISAG VIZ Raspberry Pi Kiosk v1.0.0"
```

## Herkunft und Rechte

Die Visualisierungssoftware stammt von [DISAG](https://www.disag.de), laut [Impressum](https://www.disag.de/impressum/) von der **DISAG GmbH & Co KG**. Der offizielle Bezug und die Aktualisierung erfolgen über den DISAG-Kundenbereich; nach der [DISAG-Dokumentation](https://dokumentation.disag.de/dokumentation/anleitung/anleitung-visualisierungssoftware/) kann dafür eine passende Lizenz erforderlich sein.

Dieses Projekt ist ein privates, inoffizielles Kiosk-Buildprojekt von Websmack und steht in keiner geschäftlichen Verbindung zu DISAG. DISAG, OpticScore, die Software, Logos und weitere Kennzeichen gehören ihren jeweiligen Rechteinhabern. Ich verteile im Git-Repository keine DISAG-Programmdateien und beanspruche daran keine Rechte. Vor einer öffentlichen Veröffentlichung des fertigen Images muss geklärt sein, dass die enthaltene DISAG-Software und das verwendete Vereinslogo weitergegeben werden dürfen. Für Betrieb, Datenverlust und Kompatibilität übernehme ich keine Gewähr.
