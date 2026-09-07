#!/usr/bin/env bash
# Host-Werkzeuge fuer das Echt-Hamburg-Lab installieren.
# Quellen und weitere Schritte: README.md
set -Eeuo pipefail
trap 'printf "Fehler in Zeile %s. Installation abgebrochen.\n" "$LINENO" >&2' ERR

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
x86_64_mode=false

if [[ "${1:-}" == "--help" ]]; then
  echo "Aufruf: ./setup-fedora-44.sh"
  echo "Installiert Docker CE, Containerlab und Ansible fuer Fedora 44."
  echo "Benoetigt Internet und sudo; Cisco-Images werden separat importiert."
  exit 0
fi
if [[ "${1:-}" == "--x86_64" && $# == 1 ]]; then
  x86_64_mode=true
elif (( $# > 0 )); then
  echo "Unbekannte Argumente. Hilfe: $0 --help" >&2
  exit 1
fi

# Auch Fedora Asahi Remix 44 auf ARM64 unterstuetzen.
# shellcheck disable=SC1091
source /etc/os-release
if [[ "$VERSION_ID" != "44" || ( "$ID" != "fedora" && "$ID" != "fedora-asahi-remix" ) ]]; then
  echo "Dieses Skript ist fuer Fedora 44 (einschliesslich Asahi Remix)." >&2
  exit 1
fi
if [[ -e /run/ostree-booted ]]; then
  echo "Fedora Atomic wird von diesem DNF-Skript nicht unterstuetzt." >&2
  exit 1
fi
case "$(uname -m)" in
  aarch64) clab_arch=arm64 ;;
  x86_64) clab_arch=amd64 ;;
  *) echo "Nicht unterstuetzte Architektur: $(uname -m)" >&2; exit 1 ;;
esac
if "$x86_64_mode" && [[ "$clab_arch" != "amd64" ]]; then
  echo "Die x86_64-Variante benoetigt einen Intel-/AMD-Linux-Host (x86_64)." >&2
  exit 1
fi
[[ -f "$script_dir/echt-hamburg/requirements.yml" ]] || {
  echo "Das Skript muss neben dem Ordner echt-hamburg liegen." >&2
  exit 1
}

if (( EUID != 0 )); then
  exec sudo -- bash "$script_dir/setup-fedora-44.sh" "$@"
fi
target_user="${SUDO_USER:-root}"

# Bestehende alternative Container-Installationen nicht ungeprueft entfernen.
conflicts=()
for package in docker docker-client docker-client-latest docker-common \
  docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
  docker-engine-selinux docker-engine podman-docker moby-engine moby-cli \
  containerd runc; do
  if rpm -q "$package" >/dev/null 2>&1; then
    conflicts+=("$package")
  fi
done
if (( ${#conflicts[@]} )); then
  printf 'Konfliktpakete vor der Docker-CE-Installation pruefen: %s\n' "${conflicts[*]}" >&2
  echo "Gegebenenfalls gezielt mit sudo dnf remove entfernen, dann erneut starten." >&2
  exit 1
fi

echo "Installiere Basiswerkzeuge und Ansible ..."
dnf install -y dnf5-plugins ca-certificates git jq tar unzip \
  openssh-clients iproute iputils ethtool iptables-nft \
  ansible-core python3-ansible-pylibssh
if ! command -v curl >/dev/null 2>&1; then
  dnf install -y curl-minimal
fi

echo "Installiere Docker CE ..."
if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
  dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
fi
dnf install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "Installiere Containerlab ..."
if ! command -v containerlab >/dev/null 2>&1; then
  # Offizielles Release-RPM; Architektur entsprechend dem Host auswaehlen.
  release_url="$(curl --fail --silent --show-error --location --retry 3 \
    --output /dev/null --write-out '%{url_effective}' \
    https://github.com/srl-labs/containerlab/releases/latest)"
  clab_version="${release_url##*/v}"
  if [[ ! "$clab_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Containerlab-Version konnte nicht ermittelt werden: $release_url" >&2
    exit 1
  fi
  dnf install -y "https://github.com/srl-labs/containerlab/releases/download/v${clab_version}/containerlab_${clab_version}_linux_${clab_arch}.rpm"
fi

if [[ "$target_user" != "root" ]]; then
  getent group docker >/dev/null || groupadd --system docker
  getent group clab_admins >/dev/null || groupadd --system clab_admins
  usermod -aG docker,clab_admins "$target_user"
fi

echo "Installiere Ansible-Collections fuer $target_user ..."
cd "$script_dir/echt-hamburg"
sudo -H -u "$target_user" /usr/bin/ansible-galaxy collection install -r requirements.yml

echo "Pruefe Installation ..."
docker --host unix:///var/run/docker.sock info >/dev/null
docker --host unix:///var/run/docker.sock run --rm hello-world
docker compose version
containerlab version
/usr/bin/ansible --version
/usr/bin/python3 -c 'import pylibsshext; print("Ansible-SSH-Bibliothek vorhanden")'
sudo -H -u "$target_user" /usr/bin/ansible-galaxy collection list

image_setup=setup-echt-hamburg-images.sh
if "$x86_64_mode"; then
  image_setup=setup-echt-hamburg-images-x86_64.sh
  sudo -H -u "$target_user" bash "$script_dir/$image_setup" --configure-only
fi

echo
echo "Host-Werkzeuge installiert."
echo "Einmal vollstaendig ab- und wieder anmelden (auch die IDE neu starten)."
echo "Die Gruppen docker und clab_admins ermoeglichen administrativen Host-Zugriff."
if [[ "$clab_arch" == "amd64" ]] && ! "$x86_64_mode"; then
  echo "Fuer AMD64-Images mit :latest und die passende Topologie anschliessend"
  echo "./setup-echt-hamburg-images-x86_64.sh ausfuehren."
fi
echo "Danach Cisco-Archive laut README bereitstellen und im Projektordner ausfuehren:"
echo "  ./$image_setup"
echo "  cd echt-hamburg"
echo "  containerlab deploy -t echt-hamburg.clab.yml"
echo '  ansible-playbook -i clab-echt-hamburg/ansible-inventory.yml -e @playbooks/group_vars.yml playbooks/configure.yml'
echo "  ./scripts/request-dhcp.sh"
