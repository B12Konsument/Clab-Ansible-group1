# Echt Hamburg – Netzwerk mit Ansible

Containerlab stellt Router, Switch, vier VLAN-Endgeräte und ein simuliertes
Internet bereit. Ansible konfiguriert die Cisco-Geräte, erzeugt die Website
und richtet DHCP sowie die Routen der Linux-Clients ein.

## Adressplan

Jedes VLAN verwendet ein eigenes Netz nach dem Schema `192.168.x.0/24`,
wobei `x` der VLAN-ID entspricht. Die Netzmaske ist `255.255.255.0`.
Der Router erhält jeweils die erste Hostadresse; Netz- und Broadcastadressen
werden nicht vergeben.

| VLAN | Bereich | Subnetz | Gateway | DHCP-Adressen |
| --- | --- | --- | --- | --- |
| 10 | Customer Support | 192.168.10.0/24 | 192.168.10.1 | 192.168.10.2–192.168.10.254 |
| 20 | IT | 192.168.20.0/24 | 192.168.20.1 | 192.168.20.2–192.168.20.254 |
| 30 | Webserver | 192.168.30.0/24 | 192.168.30.1 | .2 fest per DHCP reserviert; .3–.254 dynamisch |
| 99 | Management | 192.168.99.0/24 | 192.168.99.1 | 192.168.99.3–192.168.99.254 |

Der Switch erhält `192.168.99.2/24` auf `Vlan99`; diese Adresse und alle
Gateways sind von DHCP ausgeschlossen. Der Router verwendet `200.108.1.1/28`
am Internet-Uplink. Der Lab-Knoten `internet` hat `200.108.1.2/28`.

Der Webserver erhält über die feste DHCP-Client-ID in `group_vars.yml` immer
`192.168.30.2`. `request-dhcp.sh` sendet diese als DHCP-Option 61; die manuelle
IOS-Bindung reserviert die Adresse auch gegenüber den dynamischen Clients.
TCP-Port 80 und 443 von `200.108.1.1` werden auf diesen Webserver weitergeleitet.
Die HTTP-/HTTPS-Verwaltungsdienste des Routers sind dafür deaktiviert, damit
sie diese Ports nicht selbst belegen.
nginx liefert HTTP; Port 443 ist für HTTPS vorbereitet, ein TLS-Zertifikat und
HTTPS-Dienst sind damit noch nicht eingerichtet.

Die Ergänzungen aus `hw` sind an die Lab-Ports und den Lab-Adressplan angepasst:
`INTER-VLAN-WEB` sperrt neue HTTP-/HTTPS-Verbindungen mit Ziel VLAN 10, 20 oder
99 und erlaubt sie zu VLAN 30. TCP-Antworten bestehender Verbindungen bleiben
erlaubt. Gleiches VLAN durchläuft den Router und dessen ACL nicht.
`WAN-IN` erlaubt TCP-Antworten, DNS-Antworten über UDP, HTTP/HTTPS und ICMP;
sonstiger eingehender IP-Verkehr wird verworfen.

Router-SSH ist aus VLAN99 und vom separaten Ansible-Host `172.20.20.1` erlaubt.
`vrf-also` erhält den Zugang über die Containerlab-Management-VRF. Der IOL-Switch
behält IP-Routing für seinen Bootstrap-Port; `no ip routing` aus `hw` würde
diesen Zugang unterbrechen. Die Port-Security-Zeilen am Support-Port bleiben
wie in `hw` auskommentierte Beispiele. Das Lab hat eigene Ports für alle vier
VLANs und benötigt daher keinen umschaltbaren Hardware-Testport.

DHCP verteilt `1.1.1.1` und `8.8.8.8` statt der Schul-DNS-Adressen aus `hw`.
Das DHCP-Skript übernimmt die empfangenen Resolver und die Suchdomäne in die
Docker-eigene `resolv.conf`, ohne die eingebundene Datei umzubenennen.
Der simulierte Internet-Knoten stellt keine Weiterleitung ins echte Internet
bereit; die Erreichbarkeit dieser Resolver ist somit kein bestandener Lab-Nachweis.

Der gemeinsame Adressplan steht in `playbooks/group_vars.yml`. Vorlagen und
Tests lesen daraus. `scripts/validate-settings.py` prüft unabhängig davon die
Vorgaben: vier unterschiedliche `/24`-Netze passend zur VLAN-ID, erste
Gateway-Adresse, reservierte Switchadresse, VLANs, Portzuordnung und Gruppendaten.

## Voraussetzungen

Benötigt werden Docker, Containerlab, Ansible, Python 3 mit PyYAML sowie
`ansible-pylibssh`. Die Cisco-Images aus der Topologie müssen lokal vorhanden sein.
Die Einrichtung für Fedora/Nobara und die Image-Importe stehen in der
[übergeordneten README](../README.md).

```bash
cd echt-hamburg
ansible-galaxy collection install -r requirements.yml
```

Docker muss für den ausführenden Benutzer erreichbar sein. Alle folgenden
Befehle werden im Verzeichnis `echt-hamburg` ausgeführt.

## Deployment und Konfiguration

```bash
containerlab deploy -t echt-hamburg.clab.yml
ansible-playbook -i clab-echt-hamburg/ansible-inventory.yml \
  -e @playbooks/group_vars.yml playbooks/configure.yml
```

Das Playbook wartet auf SSH und die IOS-CLI. Es setzt Router- und
Switchkonfiguration, speichert sie und führt die DHCP-Einrichtung für alle vier
Clients aus. Ein zusätzlicher manueller DHCP-Schritt ist nicht erforderlich.
Die Website wird mit Filialname, „Gruppe 1“ sowie Sascha, Jona und Florian aus
`group_vars.yml` erzeugt. Änderungen am Inhalt gehören in die Variablen bzw.
`playbooks/templates/website.html.j2`; `website/index.html` ist die erzeugte Seite.

Die festen Docker-Adressen von R1 (`172.20.20.2`) und S1 (`172.20.20.3`) dienen
Ansible als Bootstrap-Zugang. Sie bleiben bei erneutem Deployment gleich.
Die Funktionsprüfungen melden sich dagegen vom Management-Client über VLAN99
an `192.168.99.1` und `192.168.99.2` an.

Die Geräteübersicht aus `hw` steht ebenfalls zur Verfügung:

```bash
ansible-playbook -i clab-echt-hamburg/ansible-inventory.yml playbooks/inspect.yml
```

Das lesende Playbook speichert Modelle, IOS-Versionen und Schnittstellen unter
`reports/`, ohne die laufende Konfiguration zu exportieren.

Die Lernfeld-Vorgabe verlangt Klartext-Passwörter. Ansible ersetzt deshalb den
von Containerlab erzeugten `admin`-Secret-Eintrag durch ein Passwort und entfernt
ein bestehendes Enable-Secret. Die Lab-Zugänge bleiben `admin` / `admin` und
`netadmin` / `admin`; das Enable-Passwort steht in `group_vars.yml`.

Für einen vollständigen Neubeginn zuerst den generierten Lab-Zustand entfernen:

```bash
containerlab destroy -t echt-hamburg.clab.yml --cleanup
```

Anschließend die beiden Deployment-/Konfigurationsbefehle erneut ausführen.
Dabei gehen laufende Container und gespeicherte Gerätekonfigurationen verloren;
die Projektdateien bleiben erhalten. Ein erneuter Playbook-Lauf auf dem bereits
konfigurierten aktuellen Lab ist ebenfalls möglich.

## Alle Tests ausführen und Ausgaben ansehen

```bash
./scripts/run-tests.sh
```

Der Aufruf führt alle sieben Prüfungen aus, auch wenn eine davon fehlschlägt.
Er zeigt die Ausgabe im Terminal und schreibt sie nach
`logs/testlauf-YYYYMMDD-HHMMSS/`:

- `gesamt.log`: vollständige Ausgabe aller Prüfungen.
- `<skriptname>.log`: Ausgabe einer einzelnen Prüfung.
- `ergebnisse.tsv`: Exit-Code jedes Skripts.

Exit-Code `0` bedeutet, dass alle Prüfungen bestanden sind. Bei einem Fehler
endet auch der Gesamtlauf mit einem Fehlercode. Logs und generierte
Containerlab-Dateien werden nicht versioniert.

| Skript | Geprüfte Anforderungen |
| --- | --- |
| `request-dhcp.sh` | DHCP in allen vier VLANs, Hostadresse, `/24`-Maske, Gateway, DNS-Optionen und Webserver-Reservierung; richtet auch die Client-Routen ein |
| `test-configuration.sh` | Adressplan, Hostnamen, Domäne, SSHv2, MOTD, Klartext-Passwörter, VLANs, Access-Ports, Trunk, ungenutzte Ports, DHCP inklusive DNS und Webserver-Reservierung, Gateways, NAT und ACL-Zuordnung |
| `test-routing.sh` | Vier Gateway-Pings und alle zwölf gerichteten Verbindungen zwischen den VLAN-Clients |
| `test-management.sh` | SSH-Anmeldung mit Administratorrechten an Router und Switch über VLAN99 |
| `test-nat.sh` | Simuliertes Internet aus allen VLANs und passende NAT/PAT-Übersetzungen auf `200.108.1.1` |
| `test-webserver.sh` | HTTP aus Support, IT und Management sowie lokal und vom Internet-Knoten über Portweiterleitung; ausgelieferter Filialname, Gruppenname und alle Mitglieder |
| `test-access.sh` | Router-SSH nur aus Management, HTTP-/HTTPS-Sperren zu VLAN 10/20/99, TCP 443 zu VLAN 30 einschließlich WAN-Portweiterleitung, WAN-Sperre für andere Ports; mit laufenden Testdiensten als Positivkontrolle |

`test-access.sh` startet temporäre TCP-Echo-Dienste und fügt für den WAN-Negativtest
eine temporäre Hostroute hinzu. Beides wird beim Beenden wieder entfernt.
Die Port-443-Prüfung weist TCP-Erreichbarkeit nach, keinen TLS-Handshake.

Einzeln lassen sich die Skripte mit `./scripts/<name>.sh` starten.
`test-common.sh` enthält gemeinsame Hilfsfunktionen und ist kein eigener Test.
Die Konfigurationsprüfung liest nur den Gerätezustand; `...ignoring` ermöglicht
das Sammeln weiterer Abweichungen, die abschließende Prüfung bleibt bei Fehlern rot.

## Warum die Client-Routen nötig sind

Die Linux-Container haben `eth0` für Docker und `eth1` für das Firmennetz.
Docker setzt eine bevorzugte Standardroute über `eth0`. Nur `ping -I eth1`
zu verwenden genügt nicht: Antworten anderer VLAN-Clients können weiterhin den
falschen Weg nehmen. Nach erfolgreichem DHCP setzt `request-dhcp.sh` deshalb
auf jedem Client spezifische Routen zu den drei anderen VLAN-Netzen und zum
simulierten Internet. Beispiel für den Support-Client in VLAN 10:

```text
192.168.20.0/24 via 192.168.10.1 dev eth1
192.168.30.0/24 via 192.168.10.1 dev eth1
192.168.99.0/24 via 192.168.10.1 dev eth1
200.108.1.0/28  via 192.168.10.1 dev eth1
```

Die direkt angeschlossene Route des eigenen VLANs bleibt erhalten;
Docker-Zugriffe bleiben über `eth0` möglich. Diese Einrichtung ist Teil des Konfigurationslaufs.
Routing-, HTTP- und NAT-Tests verändern die Routingtabellen nicht.

Bei Fehlern zuerst DHCP-Ausgabe sowie `ip -4 addr` und `ip route get <Ziel-IP>`
auf beiden beteiligten Clients ansehen. Auf S1 helfen `show interfaces trunk`
und `show spanning-tree vlan 10`, auf R1 `show ip dhcp binding` und
`show ip interface brief`. Der DHCP-Aufruf wartet je Client bis zu etwa
45 Sekunden auf die Bereitschaft des Netzes.

## Monitoring-Konzept und zusätzliche Nachweise

Ein zentraler Monitoring-Server im Management-VLAN kann alle 60 Sekunden
ICMP für Router/Switch und HTTP für den Webserver prüfen. Alarmierung erfolgt
nach drei aufeinanderfolgenden Fehlschlägen; zusätzlich werden Antwortzeiten,
HTTP-Status und DHCP-Pool-Auslastung erfasst. Geeignet ist beispielsweise ein
im Unterricht vorhandenes Monitoring-System. Zuständig ist die IT-Gruppe;
bei Alarm prüft sie zuerst Client-Routen, VLAN/Trunk, dann DHCP und Webdienst.
Ein absichtlich gestoppter Webdienst mit anschließender Wiederherstellung dient
als Abnahmetest für Alarmierung und Entwarnung. Das ist ein Konzept, kein bereits
installierter Monitoring-Dienst.

Der [Abgleich mit dem Kriterienraster](KRITERIENRASTER.md) enthält sämtliche
Kriterien und Gewichtungen sowie den Ablauf der Vorführung. Live-Präsentation,
Mitarbeit und Tests auf realer Cisco-Hardware bleiben gesonderte Nachweise.
Portnamen und ungenutzte Ports sind dafür in `group_vars.yml` anpassbar; der
Bootstrap-Port `Ethernet0/0` ist ausschließlich im Lab von der Abschaltung
ungenutzter Ports ausgenommen. Für Hardware kann derselbe Cisco-Konfigurationsplay
mit einem passenden Inventar und `-e configure_lab_clients=false` ausgeführt
werden. Zugangsdaten lassen sich mit `bootstrap_user`/`bootstrap_password`
überschreiben. Die Docker-Testskripte sind kein Hardware-Nachweis.

NAT wird zum simulierten Internet-Knoten geprüft. Öffentliches DNS für
`echt-hamburg.de` und Zugang ins echte Internet sind damit nicht nachgewiesen.

## Lab beenden

```bash
containerlab destroy -t echt-hamburg.clab.yml
```
