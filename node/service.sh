#!/bin/bash

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# --- Functions ---

function require_root {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}[ERROR]${NC} This script must be run as root."
    exit 1
  fi
}

function get_default_interfaces {
  ip route show default | sed -n 's/.* dev \([^ ]*\).*/\1/p'
}

function get_ip_for_interface {
  local iface=$1
  ip -o -4 addr show "$iface" | \
  sed -n 's/.* inet \([^ ]*\).*/\1/p' | cut -d'/' -f1
}

function add_iptables_rule {
  local ip_addr=$1
  echo -e "${YELLOW}[*] Adding iptables rules for ${ip_addr}...${NC}"
  
  iptables -t nat -C OUTPUT -p udp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353 2>/dev/null || \
    iptables -t nat -A OUTPUT -p udp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353

  iptables -t nat -C OUTPUT -p tcp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353 2>/dev/null || \
    iptables -t nat -A OUTPUT -p tcp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353

  echo -e "${GREEN}[+] iptables rules added for ${ip_addr}${NC}"
}

function delete_iptables_rule {
  local ip_addr=$1
  echo -e "${YELLOW}[*] Removing iptables rules for ${ip_addr}...${NC}"
  
  iptables -t nat -D OUTPUT -p udp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353 2>/dev/null || true
  iptables -t nat -D OUTPUT -p tcp -d "$ip_addr" --dport 53 -j REDIRECT --to-ports 15353 2>/dev/null || true

  echo -e "${GREEN}[+] iptables rules removed for ${ip_addr}${NC}"
}

function update_dns_via_nmcli {
  local iface=$1
  local ip_addr=$2
  echo -e "${YELLOW}[*] Setting DNS on ${iface} to ${ip_addr}...${NC}"
  nmcli connection modify "$iface" ipv4.ignore-auto-dns yes
  nmcli connection modify "$iface" ipv4.dns "$ip_addr"
  echo -e "${GREEN}[+] DNS updated for ${iface}${NC}"
}

function restore_dns_via_nmcli {
  local iface=$1
  echo -e "${YELLOW}[*] Restoring DNS settings on ${iface} to automatic...${NC}"
  nmcli connection modify "$iface" ipv4.ignore-auto-dns no
  nmcli connection modify "$iface" ipv4.dns ""
  echo -e "${GREEN}[+] DNS settings restored for ${iface}${NC}"
}

# --- Entry Point ---

require_root

if [[ "${1:-}" == "--cleanup" ]]; then
  echo -e "${BOLD}🧹 Cleanup mode: Removing rules and restoring defaults...${NC}"
  DEFAULT_INTERFACES=$(get_default_interfaces)
  for iface in $DEFAULT_INTERFACES; do
    echo -e "${BOLD}→ Interface:${NC} $iface"
    IP_ADDR=$(get_ip_for_interface "$iface")
    echo -e "${BOLD}→ IP Address:${NC} $IP_ADDR"

    delete_iptables_rule "$IP_ADDR"
    restore_dns_via_nmcli "$iface"
  done
  echo -e "${GREEN}${BOLD}✅ Cleanup complete!${NC}"
  exit 0
fi

# Normal Setup Mode
echo -e "${BOLD}🌐 Setup mode: Configuring CoreDNS routing...${NC}"
DEFAULT_INTERFACES=$(get_default_interfaces)
for iface in $DEFAULT_INTERFACES; do
  echo -e "${BOLD}→ Interface:${NC} $iface"
  IP_ADDR=$(get_ip_for_interface "$iface")
  echo -e "${BOLD}→ IP Address:${NC} $IP_ADDR"

  add_iptables_rule "$IP_ADDR"
  update_dns_via_nmcli "$iface" "$IP_ADDR"
done

echo -e "${GREEN}${BOLD}✅ Setup complete! CoreDNS should now receive DNS traffic on port 15353.${NC}"
