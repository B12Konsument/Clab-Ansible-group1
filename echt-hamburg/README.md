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

Danach besitzen alle vier Testgeräte eine DHCP-Adresse. Die Adresse des
Webservers lässt sich so anzeigen:

```bash
docker exec clab-echt-hamburg-webserver ip -4 addr show eth1
```

## Nachweise

```bash
# DHCP-Leases und NAT auf dem Router
ssh admin@clab-echt-hamburg-r1 "show ip dhcp binding"
ssh admin@clab-echt-hamburg-r1 "show ip nat translations"

# VLANs und deaktivierte Ports auf dem Switch
ssh admin@clab-echt-hamburg-s1 "show vlan brief"
ssh admin@clab-echt-hamburg-s1 "show interfaces status"
```

Die Standardanmeldung der IOL-Images ist `admin` / `admin`. Die Passwörter
bleiben gemäß Vorgabe unverschlüsselt (`no service password-encryption`). Vor
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
