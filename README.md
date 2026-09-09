# Clab-Ansible-group1

## Fedora 44 oder Nobara einrichten

Im geklonten Projektordner ausführen:

```bash
# Bisherige Einrichtung (zum Beispiel auf Fedora Asahi Remix):
./setup-fedora-44.sh

# Auf Intel-/AMD-Rechnern mit Fedora 44 oder Nobara stattdessen:
./setup-fedora-44-x86_64.sh
```

Das Skript benötigt Internet und fragt bei Bedarf nach dem sudo-Passwort.
Es unterstützt Fedora 44 Workstation/Server und Fedora Asahi Remix 44 auf
ARM64 sowie x86_64. Die x86_64-Variante unterstützt zusätzlich Nobara, ohne
dessen Versionsnummer auf 44 festzulegen. Atomic-/OSTree-Systeme werden nicht
unterstützt. Je nach vorhandenem Paketmanager nutzt das Skript DNF 5 oder DNF 4
mit den passenden Plugins. Docker CE kommt auch auf Nobara aus dem offiziellen
Fedora-Repository; die Paketversion richtet sich nach dem lokalen DNF-`$releasever`.

Installiert werden:

| Bestandteil | Zweck |
| --- | --- |
| Docker CE, CLI und containerd.io | Container-Laufzeit für das Lab |
| Docker Buildx und Compose | Ergänzende Werkzeuge der Docker-Installation |
| Containerlab | Router, Switch und Testgeräte bereitstellen |
| Ansible Core und python3-ansible-pylibssh | Cisco-Geräte über SSH konfigurieren |
| Collections aus `echt-hamburg/requirements.yml` | `ansible.netcommon`, `cisco.ios` und deren Abhängigkeiten |
| Git, curl, CA-Zertifikate, jq, tar und unzip | Downloads, Repository und Image-Import |
| SSH-Client, iproute, iputils, ethtool und iptables-nft | Zugriff und Netzwerkwerkzeuge |

Docker wird gestartet und für den Systemstart aktiviert. Dein Benutzer wird
den Gruppen `docker` und `clab_admins` hinzugefügt; diese erlauben administrativen
Zugriff auf den Host. **Danach vollständig ab- und wieder anmelden und die IDE
neu starten.** Ansible-Collections werden für den aufrufenden Benutzer installiert;
das Skript daher aus deinem normalen Benutzerkonto starten.

Das Skript kann erneut ausgeführt werden. Ein vorhandenes Containerlab bleibt
erhalten. Bei konfliktträchtigen alten Docker-/Container-Paketen bricht es mit
einer Paketliste ab, damit diese gezielt geprüft werden können. Zum Abschluss
prüft es Docker mit `hello-world` sowie die installierten Werkzeuge. Es startet
das eigentliche Lab noch nicht.

**Cisco-Images separat bereitstellen:** Die ursprüngliche Topologie und das
Importskript verwenden die Tags `cl-cisco-router:arm64` und
`containerlab-cisco-switch:arm64`. Die x86_64-Varianten stellen die beiden
Cisco-Einträge in `echt-hamburg/echt-hamburg.clab.yml` auf `:latest` um. Die
Installation der Host-Werkzeuge allein bestätigt nicht die Funktion der
Cisco-Images oder des VLAN-Datenverkehrs. Alpine und Nginx lädt Containerlab
beim ersten Deploy automatisch; DHCP-Client und Webserver laufen in den Containern.

Installationsquellen: [Docker CE für Fedora](https://docs.docker.com/engine/install/fedora/),
[Containerlab](https://containerlab.dev/install/),
[Ansible Core für Fedora](https://packages.fedoraproject.org/pkgs/ansible-core/ansible-core/)
und [Ansible SSH-Bibliothek für Fedora](https://packages.fedoraproject.org/pkgs/python-ansible-pylibssh/python3-ansible-pylibssh/).

## Cisco-Images

Die großen Cisco-Images werden aus Platzgründen nicht im Git-Repository
gespeichert. Sie müssen manuell heruntergeladen und in die folgenden Ordner
kopiert werden:

| Image-Typ | Zielordner |
| --- | --- |
| Router-Container (`CL-Cisco-Router.tar`) | `Cisco-CML-Images/CL-Images/Router/` |
| Switch-Container (`containerlab-cisco-switch.tar`) | `Cisco-CML-Images/CL-Images/Switch/` |
| Cisco IOL Router (`x86_64_crb_linux-adventerprisek9-ms.iol`) | `Cisco-CML-Images/iol-xe-17-15-01/` |
| Cisco IOL Layer-2 (`x86_64_crb_linux_l2-adventerprisek9-ms.iol`) | `Cisco-CML-Images/ioll2-xe-17-15-01/` |

Die Dateinamen müssen genau den oben angegebenen Namen entsprechen. Die
jeweiligen YAML-Dateien im Repository enthalten die zugehörigen Image-
Konfigurationen.

## Images für Echt Hamburg einrichten

Nach dem Git-Clone `Cisco-CML-Images.zip` in diesen Ordner legen, also neben
`echt-hamburg`. Danach werden die für das Lab benötigten Container-Images
einmalig importiert:

```bash
./setup-echt-hamburg-images.sh
```

Das Skript entpackt die ZIP-Datei nur temporär und importiert
`Cisco-CML-Images/CL-Images/Router/CL-Cisco-Router.tar` und
`Cisco-CML-Images/CL-Images/Switch/containerlab-cisco-switch.tar` in Docker.
Danach stehen `cl-cisco-router:arm64` und
`containerlab-cisco-switch:arm64` für das Projekt `echt-hamburg` bereit.
Die ZIP-Datei und die großen Archive bleiben lokal und werden nicht mit Git
versioniert. Ein bereits entpackter Ordner `Cisco-CML-Images` wird ebenfalls
weiterhin unterstützt.

## Einrichtung auf x86_64 (Intel/AMD)

Für Fedora 44 und Nobara gelten dieselben Befehle; die Skriptnamen bleiben gleich.

```bash
./setup-fedora-44-x86_64.sh
# Danach vollständig ab- und wieder anmelden.
# Cisco-CML-Images.zip oder den entpackten Ordner wie oben bereitstellen.
./setup-echt-hamburg-images-x86_64.sh
cd echt-hamburg
containerlab deploy -t echt-hamburg.clab.yml
ansible-playbook -i clab-echt-hamburg/ansible-inventory.yml \
  -e @playbooks/group_vars.yml playbooks/configure.yml
./scripts/request-dhcp.sh
```

Das Host-Setup verwendet die gemeinsame Paketinstallation und passt danach
die Topologie an. Der x86_64-Image-Import prüft den Docker-Daemon und die Images
auf AMD64, setzt `cl-cisco-router:latest` und
`containerlab-cisco-switch:latest` und passt nach erfolgreichem Import ebenfalls
die Topologie an. Bereits vorhandene Ziel-Images werden geprüft und wiederverwendet.
Die Archivnamen und Ordner bleiben gleich; ZIP-Dateien haben Vorrang vor dem
entpackten Ordner. Beide neuen Skripte unterstützen `--help`.

Die hier geprüften lokalen TAR-Archive enthalten bereits `linux/amd64`:
der Router ohne gespeicherten Tag, der Switch mit `containerlab-cisco-switch:v1`.
Deshalb vergibt das Importskript die gewünschten `:latest`-Tags ausdrücklich.
Ein Tag wie `:arm64`, `:aarch64` oder `:latest` bestimmt **nicht** die tatsächliche
Image-Architektur; andere Archive werden beim Import erneut geprüft.

Die Umstellung erfolgt beim Ausführen der neuen Skripte. Sie ändert nur die
beiden Cisco-Image-Einträge in der Quelltopologie. Ein bereits laufendes Lab
übernimmt die neuen Images erst nach `containerlab redeploy -t echt-hamburg.clab.yml`
(dabei wird es neu erstellt). Die bisherigen Skripte stellen eine bereits
geänderte Topologie nicht automatisch auf `:arm64` zurück.
