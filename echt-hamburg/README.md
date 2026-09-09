# Echt Hamburg – Netzwerk mit Ansible

Dieses Projekt setzt die Lernfeld-Vorgaben für eine Franchise-Filiale um.
Containerlab stellt die Testumgebung bereit, Ansible konfiguriert Router und
Switch.

## Netzwerk

| VLAN | Bereich | Netz | Gateway |
| --- | --- | --- | --- |
| 10 | Customer Support | 192.168.10.0/24 | 192.168.10.1 |
| 20 | IT | 192.168.20.0/24 | 192.168.20.1 |
| 30 | Webserver | 192.168.30.0/24 | 192.168.30.1 |
| 99 | Management | 192.168.99.0/24 | 192.168.99.1 |

Der Switch verwendet im Management-VLAN die statische Adresse
`192.168.99.2/24`.

Der Router nutzt am simulierten Internet-Uplink `200.108.1.1/28`. NAT/PAT
verbirgt die privaten Adressen. Je ein Testgerät prüft DHCP in den vier VLANs.

## Voraussetzungen

Benötigt werden Docker, Containerlab und Ansible. Die einmalige Einrichtung
der lokalen Cisco-Images ist in der übergeordneten README beschrieben.

Für Fedora 44 installiert `../setup-fedora-44.sh` alle Host-Werkzeuge und die
Ansible-Collections. Anleitung: [Fedora 44 einrichten](../README.md#fedora-44-einrichten).

Auf Intel-/AMD-Rechnern `../setup-fedora-44-x86_64.sh` und anschließend
`../setup-echt-hamburg-images-x86_64.sh` verwenden. Diese Varianten stellen die
Cisco-Images in der Topologie auf `:latest` um und prüfen beim Import auf AMD64.

Die Ansible-Collections werden einmalig installiert:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Ausführen

```bash
containerlab deploy -t echt-hamburg.clab.yml
ansible-playbook -i clab-echt-hamburg/ansible-inventory.yml \
  -e @playbooks/group_vars.yml playbooks/configure.yml
./scripts/request-dhcp.sh
```

Ansible und das DHCP-Skript sind zwei getrennte Befehle. Der Backslash muss
bei einem mehrzeiligen Befehl das letzte Zeichen der Zeile sein.

Das DHCP-Skript sendet je Gerät bis zu 15 Anfragen im Abstand von drei
Sekunden, damit das Netz nach der Konfiguration Zeit zum Bereitwerden hat.
Es prüft alle vier Geräte auch dann, wenn eines fehlschlägt, und beendet sich
bei mindestens einem Fehler mit Exit-Code 1. Zusätzlich prüft es die Adresse,
die /24-Netzmaske und den DHCP-Gateway-Eintrag gegen den aktuellen Adressplan.

Nach erfolgreichem Durchlauf besitzen alle vier Testgeräte eine DHCP-Adresse. Die Adresse des
Webservers lässt sich so anzeigen:

```bash
docker exec clab-echt-hamburg-webserver ip -4 addr show eth1
```

Bei `udhcpc: no lease, failing` hat der Client keine DHCP-Zuweisung erhalten.
Ein erfolgreiches Ansible-Playbook bestätigt nur die Konfiguration, nicht
die Erreichbarkeit des DHCP-Servers. Das Skript kann erneut gestartet werden.
Bleibt der Fehler bestehen, auf S1 `show interfaces trunk` und
`show spanning-tree vlan 10` prüfen; VLAN 10 muss auf Ethernet0/1 aktiv und
im Forwarding-Zustand sein. Auf R1 zeigen `show ip interface brief`,
`show ip dhcp pool` und `show ip dhcp binding` den Zustand der
Subinterfaces und DHCP-Pools. Für die übrigen Clients gelten VLAN 20, 30 und 99.

## Anforderungen testen

Nur eine erfolgreiche DHCP-Anfrage reicht für die Lernfeld-Anforderungen nicht
aus. Die Tests sind deshalb in sechs Themen aufgeteilt:

Der [Abgleich mit dem Kriterienraster](KRITERIENRASTER.md) ordnet zusätzlich
alle Bewertungspunkte den Nachweisen zu und enthält die noch offenen Aufgaben
für Präsentation und reale Cisco-Hardware.

| Skript in `scripts/` | Geprüfte Anforderungen |
| --- | --- |
| `request-dhcp.sh` | Must: echte DHCP-Anfrage in allen vier VLANs, Adresse, Netzmaske und Gateway-Eintrag |
| `test-routing.sh` | Must: eigenes Gateway und alle zwölf gerichteten Client-Verbindungen zwischen den VLANs |
| `test-configuration.sh` | Must/Rahmenvorgaben und Raster: VLANs, Access-Ports, Trunk, Router-DHCP-Pools, erste Gateway-Adresse, Hostnamen und MOTD gemäß Ansible-Vorlagen, unverschlüsselte Passwörter, deaktivierte ungenutzte Ports, Domäne, öffentliche IP und Adressbereich; außerdem NAT-Konfiguration |
| `test-management.sh` | Rahmenvorgabe: tatsächliche SSH-Anmeldung mit Administratorrechten an Router und Switch über VLAN 99 |
| `test-nat.sh` | Should: Erreichbarkeit des simulierten Internets aus allen VLANs und passende NAT/PAT-Übersetzungen auf `200.108.1.1` |
| `test-webserver.sh` | Should: HTTP aus Support, IT und Management; ausgelieferte Website mit Filialname, Gruppenname und Mitgliedern |

Nach Deployment und Ansible-Konfiguration im Verzeichnis `echt-hamburg`
nacheinander ausführen. Die übrigen Tests können auch nach einem fehlgeschlagenen
Einzeltest gestartet werden:

```bash
./scripts/request-dhcp.sh
./scripts/test-configuration.sh
./scripts/test-routing.sh
./scripts/test-management.sh
./scripts/test-nat.sh
./scripts/test-webserver.sh
```

Exit-Code `0` bedeutet erfolgreich, ein anderer Wert einen Fehler. Die
Konfigurationsprüfung sammelt einzelne Abweichungen und meldet am Ende einen
Fehler, auch wenn Ansible zwischendurch `...ignoring` ausgibt. Sie liest die
laufende Konfiguration; sie spielt keine Änderungen auf Router oder Switch ein.
`Ethernet0/0` des Switches ist als benutzter Containerlab-/Ansible-Zugang von
der Prüfung ungenutzter Ports ausgenommen.

Benötigt werden zusätzlich Bash, Python 3 mit PyYAML und für die Cisco-Tests
Ansible mit `ansible.netcommon`, `cisco.ios` und `ansible-pylibssh` (in der
Fedora-Einrichtung enthalten). `test-common.sh` enthält nur gemeinsame
Hilfsfunktionen. Die drei YAML-Dateien unter `playbooks/tests/` enthalten die
lesenden Cisco-Prüfungen, die von den jeweiligen Shell-Skripten aufgerufen werden.
Die Cisco-Tests erstellen ein temporäres Inventar mit den festen VLAN99-Adressen
`192.168.99.1` und `192.168.99.2`. SSH läuft für Konfiguration, Management und NAT
über den Management-Client. Dafür muss VLAN 99 bereits konfiguriert sein und der
Client seine DHCP-Adresse besitzen. Docker-Adressen werden nicht als Cisco-Ziele
verwendet: Nach einem erneuten Deployment können sie von den gespeicherten
IOS-Management-Adressen abweichen und auf ein anderes Gerät führen. Diese
Abweichung muss für den Bootstrap-/Konfigurationszugang gesondert behoben werden.
Standardzugang ist der vom Projekt konfigurierte Benutzer `netadmin` / `admin`;
abweichende Werte sind über `LAB_USER` und `LAB_PASSWORD` möglich, ein anderer
Lab-Name über `LAB_NAME`.

Für die Inhaltsprüfung in `playbooks/group_vars.yml` die echten Namen unter
`group_members` als YAML-Liste eintragen. `franchise_name`, `group_name` und
diese Namen müssen auch in der ausgelieferten Website stehen. Eine leere
Mitgliederliste wird als fehlender Nachweis gemeldet.

### Bekannte Abweichungen und Grenzen

- Die Vorgabe nennt `192.168.108.0/24`. Der aktuelle Adressplan oben liegt
  außerhalb dieses Bereichs. `test-configuration.sh` meldet das ausdrücklich
  als Fehler. Für vier VLANs wären getrennte Subnetze innerhalb dieses Bereichs
  nötig. Bei einer Umstellung müssen auch die bisherigen Test-Sollwerte für
  Netze, Gateways und Management-Adressen angepasst werden.
- Die Linux-Container besitzen zusätzlich `eth0` für Containerlab. Dessen
  Standardroute kann Vorrang vor der DHCP-Route auf `eth1` haben. Die Ping-Tests
  senden ausdrücklich über `eth1`; Antworten müssen ebenfalls über das
  Firmennetz zurückkommen. Der HTTP-Test verlangt eine Route über `eth1` und
  verändert die Routingtabellen nicht. Bei Fehlern auf **beiden** beteiligten
  Clients `ip route get <IP-des-anderen-Clients>` prüfen. Eine erreichbare
  Gateway-Adresse allein beweist noch kein funktionierendes Inter-VLAN-Routing.
- Die vorhandene Website nennt „Team Netzwerk“, während `group_name` auf
  „Gruppe 1“ steht; Mitglieder fehlen bislang. Die Inhaltsprüfung soll bis zur
  Ergänzung fehlschlagen. Sie prüft zusätzlich die lokal per HTTP ausgelieferte
  Seite, damit ein Routingproblem die Inhaltsprüfung nicht verhindert.
- Auf den laufenden Geräten sind neben den unverschlüsselten Projekt-Passwörtern
  noch `secret`-Einträge vorhanden. Auch diese meldet die Prüfung entsprechend
  der Klartext-Vorgabe. `no service password-encryption` entfernt bestehende
  Secrets oder bereits verschlüsselte Passwörter nicht.
- NAT wird gegen den Lab-Knoten `internet` geprüft; eine Verbindung ins echte
  Internet oder eine öffentliche DNS-Auflösung von `echt-hamburg.de` ist damit
  nicht nachgewiesen und in diesem Lab auch nicht eingerichtet.
- Das Could-Kriterium verlangt ein **Monitoring-Konzept**. Dazu den folgenden
  Abschnitt bei der Abgabe inhaltlich prüfen; ein zusätzliches Skript würde
  die Qualität eines Konzepts nicht nachweisen. HTTP-, Ping- und SSH-Tests
  demonstrieren die dort genannten Messungen.
- Die Remote-Konfiguration durch Ansible wird durch den dokumentierten
  Deployment-/Playbook-Lauf nachgewiesen. Vor der Abgabe außerdem die realen
  Filial-/Gruppendaten, die Website-Präsentation und die Reproduzierbarkeit
  dieses Ablaufs manuell prüfen.

## Zusätzliche manuelle Nachweise

```bash
# DHCP-Leases und NAT auf dem Router
ssh admin@clab-echt-hamburg-r1 "show ip dhcp binding"
ssh admin@clab-echt-hamburg-r1 "show ip nat translations"

# VLANs und deaktivierte Ports auf dem Switch
ssh admin@clab-echt-hamburg-s1 "show vlan brief"
ssh admin@clab-echt-hamburg-s1 "show interfaces status"
```

Die Standardanmeldung der IOL-Images ist `admin` / `admin`. Die Vorlagen setzen
die Projekt-Passwörter unverschlüsselt (`no service password-encryption`);
bestehende `secret`-Einträge werden dadurch nicht entfernt. Vor
der Abgabe müssen `franchise_name`, `group_name` und `enable_password` in
`playbooks/group_vars.yml` angepasst werden.

## Optionales Monitoring

Für einen Standort kann ein zentraler Monitoring-Server regelmäßig per ICMP,
HTTP und SSH die Erreichbarkeit von Router, Switch und Webserver prüfen.
Geeignet sind etwa Zabbix, Icinga oder Prometheus mit Blackbox Exporter.
Alarmieren sollte er bei fehlender HTTP-Antwort, hoher Antwortzeit, nicht
erreichbarem Management-VLAN oder knappem DHCP-Adresspool.

## Lab beenden

```bash
containerlab destroy -t echt-hamburg.clab.yml
```
