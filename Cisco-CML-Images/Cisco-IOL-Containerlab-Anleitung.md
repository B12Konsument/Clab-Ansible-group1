# Cisco-IOL-Image mit Containerlab verwenden

Diese Anleitung zeigt, wie ein vorhandenes Cisco-IOL-Docker-Image importiert, sinnvoll benannt und in einem Containerlab-Lab verwendet wird.

<mark>**Wichtig:** Verwende nur Cisco-IOL-Images, die von der Schule bzw. Cisco
rechtmäßig bereitgestellt wurden. </mark>

## Voraussetzungen

- Docker ist installiert und läuft.
- Containerlab ist installiert.
- Die Image-Datei liegt lokal vor, zum Beispiel `CL-Cisco-Router.tar`.

## 1. Cisco-Image importieren

In das Verzeichnis mit der TAR-Datei wechseln und das Image laden:

```bash
docker image load --input CL-Cisco-Router.tar
```

Bei einem Image ohne hinterlegten Namen/Tag sieht die Erfolgsmeldung etwa so aus:

```text
Loaded image ID: sha256:5e8ff88c...
```

Die vollständige Image-ID aus dieser Ausgabe für den nächsten Schritt kopieren.

## 2. Import prüfen

Ein ungetaggtes Image wird bei `docker image ls` nicht immer angezeigt. Deshalb alle Images einschließlich ungetaggter Einträge anzeigen:

```bash
docker images --all --no-trunc
```

Ein importiertes, noch namenloses Image erscheint als:

```text
REPOSITORY   TAG       IMAGE ID
<none>       <none>    sha256:5e8ff88c...
```

Alternativ gezielt nach ungetaggten Images suchen:

```bash
docker image ls --filter dangling=true --no-trunc
```

Details eines bestimmten Images lassen sich so prüfen:

```bash
docker image inspect sha256:5e8ff88c52ed2e6a7c9752187319fa4fe029d111dc8d6215ce4646ade8dd5176
```

> Die Beispiel-ID bitte durch die eigene Image-ID ersetzen.

## 3. Image benennen (taggen)

Damit Containerlab das Image eindeutig verwenden kann, einen Namen und Tag vergeben:

```bash
docker tag sha256:5e8ff88c52ed2e6a7c9752187319fa4fe029d111dc8d6215ce4646ade8dd5176 cl-cisco-router:latest
```

Danach kontrollieren:

```bash
docker image ls
```

Erwartete Ausgabe:

```text
REPOSITORY        TAG      IMAGE ID
cl-cisco-router   latest   sha256:5e8ff88c...
```

## 4. Containerlab-Topologie anlegen

Beispiel für zwei über ein Ethernet-Kabel verbundene Cisco-IOL-Router. Die Datei heißt hier `cisco-router.clab.yml`.

Der Wert bei `name:` ist der eigentliche Labname. Er darf keine Punkte enthalten, damit die aus ihm gebildeten Knotennamen auch per DNS auflösbar sind:

```yaml
name: cisco-router

topology:
  nodes:
    R1:
      kind: cisco_iol
      image: cl-cisco-router:latest
    R2:
      kind: cisco_iol
      image: cl-cisco-router:latest

  links:
    - endpoints: ["R1:e0/1", "R2:e0/1"]
```

Der Eintrag bei `image:` muss exakt dem mit `docker tag` vergebenen Namen entsprechen.

## 5. Topologie prüfen und starten

Zuerst die Datei validieren:

```bash
sudo containerlab validate -t cisco-router.clab.yml
```

Anschließend das Lab starten:

```bash
sudo containerlab deploy -t cisco-router.clab.yml
```

Den Status der Knoten anzeigen:

```bash
sudo containerlab inspect -t cisco-router.clab.yml
```

## 6. Mit einem Router verbinden

Für die Cisco-IOL-CLI per SSH:

```bash
ssh admin@clab-cisco-router-R1
```

Bei einem Standard-Cisco-IOL-Image sind die Zugangsdaten `admin` / `admin`.

Für eine Linux-Bash-Shell *im Container* (nicht für die Cisco-IOS-CLI):

```bash
sudo docker exec -it clab-cisco-router-R1 bash
```

Falls ein eigener vollständiger Startup-Config verwendet wird, müssen darin SSH-Server, Benutzer und die Management-Konfiguration selbst eingerichtet sein.

 

## 7. Für Ansible nutzen

Nach dem Deployment legt Containerlab im Lab-Ordner automatisch eine
Ansible-Inventardatei an:

```bash
ls clab-cisco-iol/ansible-inventory.yml
ansible-inventory -i clab-cisco-iol/ansible-inventory.yml --graph
```

Damit können Playbooks die Geräte über ihre Management-IP adressieren. Vor dem
Einsatz im Unterricht sollten die Standardzugangsdaten geändert oder sicher
verwaltet werden.

## 8. Lab beenden und entfernen

Wenn das Lab nicht mehr benötigt wird:

```bash
sudo containerlab destroy -t cisco-router.clab.yml
```

Das entfernt die zu diesem Lab gehörenden Container und Netzwerkverbindungen, aber nicht das Docker-Image. Das Image `cl-cisco-router:latest` bleibt für weitere Labs verfügbar.

## Hinweis zu Labnamen

Der Dateiname `cisco-router.clab.yml` ist unproblematisch. Entscheidend ist der YAML-Wert `name:`: Verwende dort keine Punkte (`.`), Sternchen (`*`) oder andere Sonderzeichen. Mit `name: cisco-router` entstehen Knotennamen wie `clab-cisco-router-R1`, die Containerlab per DNS auflösen kann.

In einer Datei mit `name: cisco-router.clab.yml` wäre der Punkt weiterhin Teil des Labnamens; dadurch können die bekannten DNS-Warnungen erneut auftreten.

## Wenn etwas nicht funktioniert

- **`image not found`:** `docker image ls` prüfen und den Wert bei `image:`
  exakt anpassen.
- **SSH nicht erreichbar:** Mit `containerlab inspect -t cisco-iol.clab.yml`
  prüfen, ob der Knoten läuft, und die dort angezeigte Management-IP verwenden.
- **Mehrere Topologien im Ordner:** Immer `-t <datei>.clab.yml` angeben.

Weiterführend: [Cisco IOL in Containerlab](https://containerlab.dev/manual/kinds/cisco_iol/),
[Containerlab-Ansible-Inventar](https://containerlab.dev/manual/inventory/).
