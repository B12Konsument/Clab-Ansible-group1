# Clab-Ansible-group1

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
