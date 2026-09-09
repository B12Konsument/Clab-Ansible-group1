# Abgleich mit dem Kriterienraster

Grundlage: das bereitgestellte Bild `Kriterienraster.png` und
[`Lernfeld-Vorgaben.txt`](../Lernfeld-Vorgaben.txt). Stand: 08.09.2026.
Die Funktionsbefunde beziehen sich auf die Lab-Prüfungen in dieser Arbeitssitzung.
Eine erfolgreiche Präsentation oder ein Hardware-Test ist damit nicht belegt.
Die Gewichtungen unten sind aus dem Raster übernommen, keine vergebenen Punkte.

## Technische Umsetzung (60 %)

| Zeile / Gewicht | Kriterium | Vorhandener Nachweis und verbleibende Aufgabe |
| --- | --- | --- |
| 2 / 5 | Aufbau der Containerlab-Topologie erklären | Topologie in `echt-hamburg.clab.yml`, Adressplan in der README. Router, Switch, vier VLAN-Endgeräte und simuliertes Internet zeigen; Trunk, Access-Ports sowie `eth0` und `eth1` erklären. Die mündliche Erklärung steht noch aus. |
| 3 / 8 | Vollständige Funktionsfähigkeit der Topologie | **Noch nicht erfüllt:** DHCP, Management-SSH und NAT bestehen; alle zwölf gerichteten Verbindungen zwischen VLAN-Clients und HTTP aus anderen VLANs scheitern. Erfolgreiches Deployment allein reicht nicht. |
| 4 / 5 | Ansible-Projekt erklären | Inventar mit Gruppen `routers`/`switches`, `playbooks/configure.yml`, `playbooks/group_vars.yml` und beide Jinja-Vorlagen zeigen. Es werden keine Rollen verwendet; das Raster verlangt Rollen nur, sofern verwendet. |
| 5 / 6 | Mindestens ein Playbook während der Präsentation erfolgreich ausführen | Befehl steht in der README. **Live-Nachweis offen:** `configure.yml` ausführen, passende Zielgeräte und einen Recap ohne `failed`/`unreachable` zeigen. Ein früherer Lauf oder ein Syntaxcheck ersetzt das nicht. |
| 6 / 5 | Korrekte VLAN-Konfiguration | VLANs, Access-Port-Zuordnung, Trunk und Management-SVI bestehen die Einzelprüfungen in `test-configuration.sh`. Bei der Erklärung auch `show vlan brief` und `show interfaces trunk` verwenden. |
| 7 / 5 | DHCP in allen VLANs | `request-dhcp.sh` besteht für alle vier Clients; `test-configuration.sh` prüft zusätzlich die Router-Pools. Die Abweichung des Adressplans von der Textvorgabe bleibt offen. |
| 8 / 6 | Inter-VLAN-Routing | **Fehlgeschlagen:** `test-routing.sh` erreicht alle vier Gateways, aber keine der zwölf Client-Verbindungen. Hin- und Rückrouten der Clients prüfen; aktuell wird für andere VLANs die Docker-Standardroute über `eth0` gewählt. |
| 9 / 4 | Managementzugang über SSH | `test-management.sh` besteht: authentifizierter administrativer Zugriff vom Management-Client auf die VLAN99-Adressen beider Geräte. |
| 10 / 6 | NAT-Konfiguration | `test-nat.sh` besteht: Testverkehr aus allen vier VLANs und passende Übersetzungen auf `200.108.1.1`. Das Ziel ist das simulierte Internet `200.108.1.2`. |
| 11 / 4 | MOTD und Hostnamen automatisiert setzen | Beide stehen in den Ansible-Vorlagen. MOTD und der ergänzte Hostnamenvergleich in `test-configuration.sh` bestehen auf beiden Geräten. Für den **Automatisierungsnachweis** zusätzlich Vorlage, Variablen und erfolgreichen Konfigurationslauf zeigen: Der Zustand allein beweist nicht, wie er gesetzt wurde. |
| 12 / 4 | Ungenutzte Switchports deaktivieren | Die Prüfung der vorhandenen unbenutzten Ethernet-Ports besteht. `Ethernet0/0` ist im Lab ein tatsächlich benutzter Bootstrap-Zugang. Bei realer Hardware müssen alle dort vorhandenen Ports neu zugeordnet werden. |
| 13 / 6 | Zwei Zusatzkriterien korrekt implementieren | **Noch nicht nachgewiesen.** Das Raster benennt die beiden Kriterien nicht. Website und Monitoring sind mögliche Kandidaten aus der Textvorgabe, aber nicht als Auswahl bestätigt. Die Website hat Inhalts- und Erreichbarkeitsmängel; Monitoring liegt nur als Konzept vor. Ob ein Konzept für dieses Rasterkriterium genügt, muss mit dem Lehrerteam geklärt werden. |
| 14 / 8 | Dieselben Playbooks auf reale Cisco-Hardware übertragen und Funktion zeigen | **Offen.** Ein Hardware-Inventar und ein dokumentierter Hardware-Prüflauf fehlen. Schnittstellennamen und Portbereiche sind derzeit auf IOL festgelegt, Anmeldewerte stehen im Playbook. Die Shell-Tests setzen Docker-Container voraus und sind kein Hardware-Nachweis. |

## Live-Demonstration / Fachgespräch (25 %)

Diese Punkte lassen sich durch Skripte vorbereiten, aber erst während der
Präsentation beurteilen.

| Zeile / Gewicht | Kriterium | Vorbereitung / Nachweis |
| --- | --- | --- |
| 19 / 4 | Klarer, logischer Ablauf | Ablauf unten proben: Topologie → Ansible → Konfiguration → Funktion → Zusatzkriterien und Hardware. |
| 20 / 5 | Alle Teammitglieder beteiligen sich | Namen und Beiträge vorab zuordnen; jedes Mitglied erklärt und demonstriert einen Teil. Die Mitgliederliste ist bisher leer. |
| 21 / 4 | Überwiegend frei sprechen, Fachsprache verwenden | Begriffe wie Access-Port, 802.1Q-Trunk, DHCP-Pool, Gateway, SVI und NAT/PAT am eigenen Netz erklären können. |
| 22 / 5 | Vorgehen nachvollziehbar und fachlich korrekt erklären | Jeweils Anforderung, Einstellung und zugehörigen Funktionstest miteinander verbinden. |
| 23 / 5 | Live-Demonstration vorbereitet und sicher durchführen | Lab und Inventar vorher prüfen, alle Befehle proben, bekannte Fehler beheben und die Nachweise bereithalten. Der aktuelle Stand ist wegen Routing/HTTP noch nicht vollständig funktionsfähig. |
| 24 / 5 | Rückfragen korrekt beantworten | Beispielsweise erklären: Warum genügt ein Gateway-Ping nicht? Wie unterscheiden sich VLAN-ID und IP-Subnetz? Was zeigt die NAT-Tabelle? Warum stört die zweite Standardroute? |

## Projektorganisation und Arbeitsweise (15 %)

| Zeile / Gewicht | Kriterium | Einschätzung / Nachweis |
| --- | --- | --- |
| 29 / 4 | Übersichtliche Ordnerstruktur | Im Projekt vorhanden: `configs/` für Startkonfiguration, `playbooks/` mit `templates/` und `tests/`, `scripts/` für Testaufrufe, `website/` für die Filialseite. Das lässt sich direkt zeigen. |
| 30 / 3 | Sinnvolle Dateinamen und Struktur | Die sechs Testthemen sind getrennt benannt. `test-common.sh` bündelt Hilfsfunktionen; die Cisco-Prüfungen liegen in thematischen Test-Playbooks. Keine zusätzlichen Rollen oder Skripte nur für Bewertungspunkte erforderlich. |
| 31 / 4 | Strukturiert und professionell zusammenarbeiten | Rollen und Übergaben für die Vorführung vereinbaren. Aus dem Repository allein nicht bewertbar. |
| 32 / 4 | Fehler systematisch analysieren und Maßnahmen ableiten | Das aktuelle Routingproblem eignet sich als dokumentierter Fall: Symptom → `ip route get` auf beiden Clients → Ursache → Korrektur → denselben Test wiederholen. Die Fehlerbehebung und erfolgreiche Wiederholungsprüfung stehen noch aus. |

## Kompakter Ablauf für die Vorführung

1. **Topologie zeigen:** R1 routet zwischen den VLANs und übernimmt DHCP/NAT.
   S1 verbindet die VLAN-Endgeräte über Access-Ports und den Router-Trunk.
   `eth0` dient Containerlab, `eth1` dem zu prüfenden Firmennetz.
2. **Ansible erklären:** Das Inventar legt die Zielgeräte und Gruppen fest.
   `configure.yml` enthält je einen Play für Router und Switch; `ios_config`
   überträgt die Jinja-Vorlagen. `group_vars.yml` wird hier ausdrücklich mit
   `-e @playbooks/group_vars.yml` geladen, nicht automatisch über seinen Namen.
3. **Konfigurations-Playbook live ausführen:** Den README-Befehl verwenden.
   Vorher prüfen, dass das Inventar erreichbare `ansible_host`-Werte und die
   richtigen Gruppen enthält. Anschließend Hostnamen und Banner mit ihren
   Vorlagen und Variablen vergleichen.
4. **Funktionen nachweisen:** Die sechs Testbefehle aus der README nacheinander
   ausführen. DHCP vor den Tests, die Client-Adressen benötigen. Auch
   Einzelergebnisse und Fehler erklären, nicht nur den letzten Exit-Code zeigen.
5. **Zwei vereinbarte Zusatzkriterien demonstrieren:** Auswahl und erwarteten
   Nachweis vorher festlegen; für eine Website Inhalt und Zugriff aus einem
   anderen VLAN zeigen.
6. **Hardware-Übertragung nachweisen:** Dasselbe Konfigurations-Playbook mit
   einem passenden Hardware-Inventar ausführen und DHCP, VLAN-Routing, SSH,
   NAT und Portzustände an den realen Geräten prüfen. IOL-Portnamen vorher
   durch Variablen für die jeweiligen Geräte ersetzen; alle ungenutzten
   Hardware-Ports erfassen. Die Lab-Ausnahme für `Ethernet0/0` nicht pauschal
   übernehmen.

## Offene Aufgaben vor einer vollständigen Abgabe

- Client-Routing korrigieren; anschließend alle zwölf Verbindungen und HTTP
  erneut erfolgreich testen.
- Den Adressplan mit `192.168.108.0/24` aus der Textvorgabe in Einklang bringen
  oder eine abweichende Vorgabe mit dem Lehrerteam klären.
- Verbleibende `secret`-Einträge anhand der Klartext-Passwortvorgabe klären.
- Filialseite und echte Mitgliederangaben vervollständigen; die zwei
  Zusatzkriterien und ihren erwarteten Umfang festlegen.
- Hardware-Inventar, gerätespezifische Variablen und realen Funktionstest
  vorbereiten. Ohne Angaben zu Geräten, Ports und Zugang ist dieser Nachweis
  hier noch nicht möglich.
- Präsentationsaufgaben verteilen und den vollständigen Ablauf proben.

Die Textvorgabe erlaubt eine virtuelle Demonstration, das Raster bewertet
zusätzlich ausdrücklich die Übertragung auf reale Hardware. Dieser zusätzliche
Nachweis sollte deshalb bei der Planung mit dem Lehrerteam berücksichtigt werden.
