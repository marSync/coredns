- [🧩 Goal Recap](#-goal-recap)
- [Set compose `Port` configuration](#set-compose-port-configuration)
- [Manual setup](#manual-setup)
  - [✅ Step 1: Redirect 53 → 15353 Using `iptables`](#-step-1-redirect-53--15353-using-iptables)
  - [✅ Step 2: Point `systemd-resolved` to `<host_ip>` Only](#-step-2-point-systemd-resolved-to-host_ip-only)
  - [✅ Step 3: Restart Services](#-step-3-restart-services)
  - [✅ Step 4: Test It](#-step-4-test-it)
- [Automated setup](#automated-setup)
  - [Run network setup script](#run-network-setup-script)
  - [Cleanup previous configuration](#cleanup-previous-configuration)

# 🧩 Goal Recap

- CoreDNS container listens on `<host_ip>:15353`.
- **All DNS queries** on the system to be resolved **only through CoreDNS**.
- Avoid port binding 53 (due to `systemd-resolved` or `avahi-daemon` already using it).
- **Redirect** DNS traffic from `:53` → `:15353` on `<host_ip>`.

# Set compose `Port` configuration

* Docker Compose code snippet  

```yml
service:
 ---
    ports:
      - name: dns-tcp
        target: 53
        host_ip: <host_ip>
        published: "<published_port | 15353>"
        protocol: tcp
        app_protocol: dns
      - name: dns-udp
        target: 53
        host_ip: <host_ip>
        published: "<published_port | 15353>"
        protocol: udp
```

# Manual setup

## ✅ Step 1: Redirect 53 → 15353 Using `iptables`

```bash
# Redirect UDP DNS queries
sudo iptables -t nat -A OUTPUT -p udp -d <host_ip> --dport 53 -j REDIRECT --to-ports <published_port | 15353>

# Redirect TCP DNS queries (some apps use this)
sudo iptables -t nat -A OUTPUT -p tcp -d <host_ip> --dport 53 -j REDIRECT --to-ports <published_port | 15353>
```

---

## ✅ Step 2: Point `systemd-resolved` to `<host_ip>` Only

Configure `resolved` to use single `<host_ip>` as its upstream DNS server:

```bash
sudo resolvectl dns <listen_interface> <host_ip>
```

Alternatively, can set interface DNS resolution using `nmcli`:

```bash
sudo nmcli connection modify <listen_interface> ipv4.dns <host_ip>
```

---

## ✅ Step 3: Restart Services

Make sure everything reloads correctly:

```bash
sudo systemctl restart systemd-resolved
```

You can also check your DNS setup:

```bash
resolvectl status
```

---

## ✅ Step 4: Test It

```bash
dig api.singleton.kube.internal
dig google.com
```

# Automated setup

- Prerequisites:
  - `# Zone configuration`
  - `# Corefile`
  - privileged rights

## Run network setup script

```bash
chmod +x ./node/service.sh
sudo ./node/service.sh
```

## Cleanup previous configuration

```bash
sudo ./node/service.sh --cleanup
```
