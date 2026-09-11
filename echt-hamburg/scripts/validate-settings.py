#!/usr/bin/env python3
"""Prüft den Adressplan unabhängig von den Jinja-Vorlagen gegen den Auftrag."""
from ipaddress import IPv4Address, IPv4Network
from pathlib import Path
import sys
import yaml


def validate(settings):
    vlans = settings["vlans"]
    assert len(vlans) == 4 and {v["id"] for v in vlans} == {10, 20, 30, 99}, "Genau VLAN 10, 20, 30 und 99 erforderlich."
    assert len({v["node"] for v in vlans}) == 4, "Client-Namen müssen eindeutig sein."
    assert len({v["switch_port"] for v in vlans}) == 4, "Access-Ports müssen eindeutig sein."
    networks = []
    for vlan in vlans:
        network = IPv4Network(f'{vlan["network"]}/{settings["lan_prefix"]}')
        expected = IPv4Network(f'192.168.{vlan["id"]}.0/24')
        assert network == expected, f"VLAN {vlan['id']} muss das Netz {expected} verwenden."
        assert str(network.netmask) == settings["lan_netmask"], "Präfix und Netzmaske widersprechen sich."
        assert IPv4Address(vlan["gateway"]) == network.network_address + 1, "Gateway muss die erste Hostadresse sein."
        assert all(not network.overlaps(other) for other in networks), "VLAN-Subnetze dürfen sich nicht überlappen."
        networks.append(network)
    management = next(v for v in vlans if v["id"] == 99)
    mgmt_network = IPv4Network(f'{management["network"]}/{settings["lan_prefix"]}')
    assert IPv4Address(settings["switch_management_ip"]) == mgmt_network.network_address + 2, "Switch muss die zweite Management-Adresse erhalten."
    assert settings["domain_name"] == "echt-hamburg.de", "Falsche Domäne."
    assert settings["public_ip"] == "200.108.1.1" and settings["public_netmask"] == "255.255.255.240", "Uplink muss 200.108.1.1/28 sein."
    web = next(v for v in vlans if v['id'] == 30)
    web_network = IPv4Network(f'{web["network"]}/{settings["lan_prefix"]}')
    web_ip = IPv4Address(settings['webserver_ip'])
    assert web_ip in web_network and web_ip not in (web_network.network_address, web_network.broadcast_address, IPv4Address(web['gateway'])), "Webserver braucht eine freie Hostadresse in VLAN 30."
    client_id = bytes.fromhex(settings['webserver_client_id'].replace('.', ''))
    assert len(client_id) == 7 and client_id[0] == 1, "DHCP-Client-ID muss Ethernet-Typ und sechs Identifikationsbytes enthalten."
    assert settings['dhcp_dns_servers'], "DHCP-DNS-Server fehlen."
    for server in settings['dhcp_dns_servers']:
        IPv4Address(server)
    IPv4Address(settings['bootstrap_ssh_host'])
    used = [settings["switch_trunk_port"], *settings["switch_bootstrap_ports"], *(v["switch_port"] for v in vlans)]
    assert len(used) == len(set(used)), "Switch-Ports dürfen nicht mehrfach zugewiesen sein."
    assert not set(used) & set(settings["switch_unused_ports"]), "Benutzte Ports dürfen nicht deaktiviert werden."
    members = settings.get("group_members")
    assert isinstance(members, list) and members and all(isinstance(m, str) and m.strip() for m in members), "Echte Mitgliedernamen unter group_members eintragen."
    assert settings["franchise_name"].strip() and settings["group_name"].strip(), "Filial- und Gruppenname fehlen."


if __name__ == "__main__":
    try:
        validate(yaml.safe_load(Path(sys.argv[1]).read_text()))
    except (AssertionError, ValueError, KeyError, TypeError) as error:
        print(f"FEHLER: {error}", file=sys.stderr)
        sys.exit(1)
    print("OK: Adressplan, VLANs und Gruppenangaben entsprechen den Vorgaben.")
