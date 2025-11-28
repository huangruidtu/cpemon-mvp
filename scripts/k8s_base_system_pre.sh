set -euo pipefail
echo "[*] Installing base tools..."
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release apt-transport-https jq net-tools iproute2

echo "[*] Disabling swap (temp & persistent)..."
swapoff -a || true
cp /etc/fstab /etc/fstab.bak-$(date +%Y%m%d%H%M%S)
sed -ri 's/^(.*\s+swap\s+.*)$/# \1/' /etc/fstab

echo "[*] Enabling kernel modules: overlay, br_netfilter..."
cat >/etc/modules-load.d/k8s.conf <<'EOM'
overlay
br_netfilter
EOM
modprobe overlay || true
modprobe br_netfilter || true

echo "[*] Setting sysctl for Kubernetes & networking..."
cat >/etc/sysctl.d/99-k8s.conf <<'EOM'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOM
sysctl --system

echo "[*] Done. Summary:"
echo "  - swap: $(free -h | awk '/Swap:/ {print $2}') total (should be 0)"
echo "  - ip_forward: $(sysctl -n net.ipv4.ip_forward)"
echo "  - br_nf iptables: $
