# Clab-Ansible-group1

## Fedora 44 einrichten

Im geklonten Projektordner ausführen:

```bash
./setup-fedora-44.sh
```

Das Skript benötigt Internet und fragt bei Bedarf nach dem sudo-Passwort.
Es unterstützt Fedora 44 Workstation/Server und Fedora Asahi Remix 44 auf
ARM64 sowie x86_64; Fedora Atomic wird nicht unterstützt.

Installiert werden:

| Bestandteil | Zweck |
| --- | --- |
| Docker CE, CLI und containerd.io | Container-Laufzeit für das Lab |
| Docker Buildx und Compose | Ergänzende Werkzeuge der Docker-Installation |
| Containerlab | Router, Switch und Testgeräte bereitstellen |
| Ansible Core und python3-ansible-pylibssh | Cisco-Geräte über SSH konfigurieren |
| Collections aus `echt-hamburg/requirements.yml` | `ansible.netcommon`, `cisco.ios` und deren Abhängigkeiten |
| Git, curl, CA-Zertifikate, jq und tar | Downloads, Repository und Image-Import |
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

**Cisco-Images separat bereitstellen:** Die aktuelle Topologie und das
Importskript verwenden `cl-cisco-router:arm64` und
`containerlab-cisco-switch:arm64`. Auf Intel-/AMD-Rechnern sind passende
AMD64-Images und entsprechende Image-Namen in beiden Dateien nötig. Die
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

Nach dem Git-Clone den Ordner `Cisco-CML-Images` in diesen Ordner legen,
also neben `echt-hamburg`. Danach werden die für das Lab benötigten
Container-Images einmalig importiert:

```bash
./setup-echt-hamburg-images.sh
```

Das Skript importiert
`Cisco-CML-Images/CL-Images/Router/CL-Cisco-Router.tar` und
`Cisco-CML-Images/CL-Images/Switch/containerlab-cisco-switch.tar` in Docker.
Danach stehen `cl-cisco-router:arm64` und
`containerlab-cisco-switch:arm64` für das Projekt `echt-hamburg` bereit.
Die großen Archive bleiben lokal und werden nicht mit Git versioniert.
