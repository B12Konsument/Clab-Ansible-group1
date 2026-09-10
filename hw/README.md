# Echt Hamburg auf echter Hardware

Eigenständige Vorbereitung für Cisco 4221 (Router) und Cisco 881 (Switch-Rolle).
`../echt-hamburg` bleibt unverändert. Containerlab, Docker und Cisco-Images
werden hierfür nicht benötigt. Die Templates sind noch nicht auf den Geräten
getestet; vor dem ersten Ausrollen `show version` und `show ip interface brief`
beider Geräte prüfen. Die Portnamen sind vorläufige Annahmen.

## Verkabelung

| Cisco 4221 | Gegenstelle |
| --- | --- |
| GigabitEthernet0/0/0 | Cisco 881 FastEthernet0, VLAN-Trunk |

| Cisco 881 | Verwendung |
| --- | --- |
| FastEthernet0 | Trunk zum 4221 |
| FastEthernet1 | Customer Support, VLAN 10 |
| FastEthernet2 | Testclient, VLAN 20 (wahlweise VLAN 30) |
| FastEthernet3 | Ansible-PC, VLAN 99 |

Der WAN-Port des 881 wird nicht verwendet. Ein Trunk plus drei Clients belegen
alle vier Switchports. Für den Webserver-Test `switch_test_vlan` in
`group_vars/all.yml` auf `30` setzen und das Playbook erneut ausführen.
Danach am Testclient den DHCP-Lease erneuern. Für den IT-Test wieder `20` setzen.

## Netze

| VLAN | Netz | Gateway |
| --- | --- | --- |
| 10 | 192.168.10.0/24 | 192.168.10.1 |
| 20 | 192.168.20.0/24 | 192.168.20.1 |
| 30 | 192.168.30.0/24 | 192.168.30.1 |
| 99 | 192.168.99.0/24 | 192.168.99.1 |

Der 4221 übernimmt DHCP und Routing. Der 881 erhält nur die Management-IP
192.168.99.2/24 und routet nicht. Der Ansible-PC nutzt statisch
192.168.99.10/24; Gateway 192.168.99.1. Adressen .1 bis .10 sind im
Management-DHCP-Pool reserviert.

Der erste Aufbau testet das lokale Netzwerk. NAT und Internet-Uplink sind
nicht enthalten, weil Anschlussdaten fehlen. Das Playbook ergänzt eine
Konfiguration; es entfernt keine vorhandenen NAT-, DHCP-, ACL- oder
Interface-Konfigurationen. Deshalb einen dedizierten Lab-Aufbau verwenden
und die vorhandene Gerätekonfiguration zuvor sichern und auf Konflikte prüfen.

## Einmalige Vorbereitung über die Konsole

Wenn SSH bereits eingerichtet ist, können Modell, IOS-Version, Schnittstellen
und erkannte Nachbarn mit einem lesenden Playbook ermittelt werden. Vorher die
Zieladressen und Benutzernamen in `inventory.yml` auf die echten Geräte setzen:

```bash
ansible-playbook playbooks/inspect.yml --ask-pass
```

Die Übersicht erscheint im Terminal; Details werden lokal unter
`reports/r1.json` und `reports/s1.json` gespeichert. Das Playbook ändert keine
Gerätekonfiguration. Die Berichte werden nicht versioniert.

Ansible benötigt bereits funktionierenden SSH-Zugriff. Auf beiden Geräten
zunächst Hostname, Domain, einen Benutzer mit Privilege 15 und eigenem Secret,
RSA-Schlüssel sowie SSH auf den VTY-Leitungen einrichten. Beispiel, Platzhalter
vorher ersetzen (vorhandene RSA-Schlüssel können weiterverwendet werden):

```text
configure terminal
hostname R1-HW
ip domain name echt-hamburg.de
username netadmin privilege 15 secret EIGENES_PASSWORT
crypto key generate rsa modulus 2048
ip ssh version 2
line vty 0 4
 login local
 transport input ssh
end
```

Auf dem 881 `S1-HW` als Hostname verwenden. IOS-Version und unterstützte
SSH-Verfahren müssen zum Ansible-Rechner passen.

Auf dem 4221 zusätzlich:

```text
configure terminal
interface GigabitEthernet0/0/0
 no ip address
 no shutdown
interface GigabitEthernet0/0/0.99
 encapsulation dot1Q 99
 ip address 192.168.99.1 255.255.255.0
end
```

Auf dem 881 zusätzlich:

```text
configure terminal
no ip routing
vtp mode transparent
vlan 99
 name MANAGEMENT
interface FastEthernet0
 switchport mode trunk
 switchport trunk native vlan 1
 switchport trunk allowed vlan 10,20,30,99
 no shutdown
interface FastEthernet3
 switchport mode access
 switchport access vlan 99
 spanning-tree portfast
 no shutdown
interface Vlan99
 ip address 192.168.99.2 255.255.255.0
 no shutdown
ip default-gateway 192.168.99.1
end
```

PC anschließen und dessen statische IP setzen. Beide Geräte per Ping und SSH
prüfen (`ssh netadmin@192.168.99.1` und `ssh netadmin@192.168.99.2`), dabei die
Hostschlüssel prüfen und übernehmen. Nach erfolgreicher Prüfung die
Grundkonfiguration mit `copy running-config startup-config` sichern.

## Ansible ausführen

Aus diesem Verzeichnis:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/configure.yml --syntax-check
ansible-playbook playbooks/configure.yml --ask-pass --check --diff
ansible-playbook playbooks/configure.yml --ask-pass
```

`--check` zeigt geplante Änderungen, garantiert aber nicht, dass die jeweilige
IOS-Version jeden Befehl unterstützt. `--ask-pass` setzt für diesen Aufruf
dasselbe SSH-Passwort auf beiden Geräten voraus. Abweichende Zugangsdaten
lassen sich separat über Ansible Vault hinterlegen. Die Templates ändern
die bestehenden Benutzer und Passwörter nicht. Das Playbook speichert Änderungen.

## Funktion prüfen

Auf dem Router: `show ip interface brief`, `show ip route`,
`show ip dhcp binding`. Auf dem 881: `show vlan-switch brief`,
`show interfaces trunk`, `show ip interface brief` (Befehle können je nach IOS
abweichen). Auf Clients DHCP aktivieren und das jeweilige Gateway anpingen.
Mit Clients in VLAN 10 und 20 zusätzlich gegenseitige Pings testen;
lokale Host-Firewalls berücksichtigen. Anschließend VLAN 30 testen.

Herstellerreferenz: [Cisco 880 Datenblatt](https://www.cisco.com/c/en/us/products/collateral/routers/887-integrated-services-router-isr/data_sheet_c78_459542.html).
