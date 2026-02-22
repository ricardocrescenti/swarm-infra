# Quick Start - Início Rápido

Guia visual rápido para começar a usar a infraestrutura compartilhada.

## Docker

### 1. Instalação do Docker
```sh
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl start docker
```

### 2. Atualizar o Docker
```sh
sudo apt-get update
sudo apt-get install --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl restart docker
```

## Dependencias

### 1. Dependencias para geração Hash
```sh
apt install apache2-utils
```

## 🧑‍🚀 Login no GitHub

### 1. Gere uma chave no terminal:
```sh
ssh-keygen -t ed25519 -C "ricardo.crescenti@gmail.com"
```

### 2. Copie a chave gerada:
```sh
cat ~/.ssh/id_ed25519.pub
```

### 3. Insira a chave gerada no GitHub
Vá no seu GitHub Settings > SSH keys e clique em New SSH Key para colar o código lá
Utilize o Key type `Authentication Key`

## 🚀 Setup Inicial (5 minutos)

### 1. Clone/Configure este projeto
```bash
cd /root
git clone git@github.com:ricardocrescenti/swarm-infra.git
cd swarm-infra
cp .env.example .env
nano .env  # Edite DOMAIN, LETSENCRYPT_EMAIL, TRAEFIK_AUTH
```

### 2. Tornar script executável
```bash
chmod +x swarm-infra.sh
```

### 3. Setup + init
```bash
./swarm-infra.sh init
```

### 4. Aguarde e acesse
- ⏳ Aguarde 1-2 minutos
- 🌐 Traefik: `https://traefik.seudominio.com`
- 🐳 Portainer: `https://portainer.seudominio.com`

---

## 📦 Adicionar Nova Aplicação

### Metodo 1: Helper (Recomendado)

```bash
./swarm-infra.sh add-app
```

O comando gera o JSON do app e imprime as labels Traefik para cada servico.

### Método 2: Manual

Adicione ao seu `docker-compose.yml`:

```yaml
version: '3.8'

networks:
  traefik_public:
    external: true  # ← Rede compartilhada

services:
  meu-servico:
    image: minha-imagem:latest
    networks:
      - traefik_public  # ← Conectar à rede
    deploy:
      labels:
        # Labels Traefik
        - traefik.enable=true
        - traefik.http.routers.meu-servico.rule=Host(`app.seudominio.com`)
        - traefik.http.routers.meu-servico.entrypoints=websecure
        - traefik.http.routers.meu-servico.tls.certresolver=letsencrypt
        - traefik.http.services.meu-servico.loadbalancer.server.port=8080
```

Deploy:
```bash
docker stack deploy -c docker-compose.yml minha-app
```

---

## 💡 Padrões Comuns

### Frontend (React/Vue/Angular)
```yaml
- traefik.http.routers.frontend.rule=Host(`app.com`)
- traefik.http.routers.frontend.entrypoints=websecure
- traefik.http.routers.frontend.tls.certresolver=letsencrypt
- traefik.http.services.frontend.loadbalancer.server.port=80
```

### API Backend
```yaml
- traefik.http.routers.api.rule=Host(`api.app.com`)
- traefik.http.routers.api.entrypoints=websecure
- traefik.http.routers.api.tls.certresolver=letsencrypt
- traefik.http.services.api.loadbalancer.server.port=3000
```

### Com CORS
```yaml
- traefik.http.routers.api.middlewares=cors
- traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE
- traefik.http.middlewares.cors.headers.accesscontrolalloworiginlist=https://app.com
```

---

## 🔍 Comandos Úteis

### Ver status
```bash
docker stack ps swarm-infra
docker stack ps minha-app
```

### Ver logs
```bash
docker service logs -f swarm-infra_traefik
docker service logs -f minha-app_meu-servico
```

### Restart serviço
```bash
docker service update --force minha-app_meu-servico
```

### Remover aplicação
```bash
docker stack rm minha-app
```

### Remover infraestrutura
```bash
# Linux
./swarm-infra.sh stop
```

---

## ⚠️ Checklist de Problemas

Aplicação não funciona? Verifique:

- ✅ DNS aponta para o servidor? (`nslookup app.com`)
- ✅ Portas 80/443 abertas no firewall?
- ✅ Serviço tem `traefik.enable=true`?
- ✅ Serviço está na rede `traefik_public`?
- ✅ Porta do loadbalancer está correta?
- ✅ Aguardou 1-2 minutos para SSL?

Ver mais: [docs/troubleshooting.md](docs/troubleshooting.md)

---

## 📚 Documentação Completa

- [README.md](README.md) - Visão geral e instruções detalhadas
- [docs/traefik-labels.md](docs/traefik-labels.md) - Referência de labels
- [docs/troubleshooting.md](docs/troubleshooting.md) - Solução de problemas

---

## 🎯 Casos de Uso

### Cenário 1: Duas apps no mesmo servidor

```yaml
# App 1: Aplicativo 1
api-app1.seudominio.com → app1_api (porta 4101)
app1.seudominio.com → app1_frontend (porta 80)

# App 2: Aplicativo 2
api-app2.seudominio.com → app2_api (porta 5000)
app2.seudominio.com → app2_frontend (porta 3000)
```

Ambas compartilham o mesmo Traefik! 🎉

### Cenário 2: Múltiplos ambientes

```yaml
# Dev
dev-api.com → app1-dev stack
dev.app.com → app1-dev frontend

# Staging
staging-api.com → app1-staging stack
staging.app.com → app1-staging frontend

# Prod
api.app.com → app1-prod stack
app.com → app1-prod frontend
```

Todas usam o mesmo Traefik! 🚀

---

## 💬 Fluxo Visual

```
Internet (porta 80/443)
    ↓
[Traefik] (swarm-infra stack)
    ├── traefik.seudominio.com → Traefik Dashboard
    ├── portainer.seudominio.com → Portainer
    ├── api-app1.seudominio.com → APP1 API (stack: app1)
    ├── app1.seudominio.com → APP1 Frontend (stack: app1)
    ├── api-app2.seudominio.com → APP2 API (stack: app2)
    └── app2.seudominio.com → APP2 Frontend (stack: app2)
```

---

**Pronto! Agora você tem uma infraestrutura profissional e escalável! 🎉**
