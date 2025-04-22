- [🧩 Goal Recap](#-goal-recap)
- [🐳 Deploy to node using `compose`](#-deploy-to-node-using-compose)
  - [Prerequisites:](#prerequisites)
  - [🛠️ Docker configuration](#️-docker-configuration)
    - [🌐 Adjust `ip/port` configuration for the container](#-adjust-ipport-configuration-for-the-container)
    - [📦 Mount volume binds referencing repository/local files](#-mount-volume-binds-referencing-repositorylocal-files)
  - [⚙️ Deploy](#️-deploy)
  - [✅ Step 4: Test It](#-step-4-test-it)

# 🧩 Goal Recap

- Rapid `CoreDNS` service creation
- Maintain records using code
- Cross platform/architecture compatibility

# 🐳 Deploy to node using `compose`

## Prerequisites:
- Files configured:
  - `# Zone configuration` at `./zones/`
    - **Note:** it is generally a good idea to keed zones in separate files  
  - `# Corefile` at `./config/`

## 🛠️ Docker configuration

### 🌐 Adjust `ip/port` configuration for the container

* 📡 Service top-level `port` binding reference

```yml
service:
 ---
    ports:
      - name: interface-dns-tcp
        target: 53
        host_ip: <host_ip>
        published: "53"
        protocol: tcp
        app_protocol: dns
      - name: interface-dns-udp
        target: 53
        host_ip: <host_ip>
        published: "53"
        protocol: udp
```

### 📦 Mount volume binds referencing repository/local files

* Service top-level volume bind reference

```yml
service:
 ---
    volumes:
      - ./config/Corefile:/Corefile
      - ./zones/db.singleton.kube.internal:/zones/db.singleton.kube.internal
      - ./zones/db.55.211.10.in-addr.arpa:/zones/db.55.211.10.in-addr.arpa

```

## ⚙️ Deploy

```bash
docker compose up -d
```

## ✅ Step 4: Test It

```bash
dig api.singleton.kube.internal
dig google.com
```