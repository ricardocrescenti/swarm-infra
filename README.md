# Swarm Infrastructure - Infraestrutura Base Compartilhada

**Projeto independente** para gerenciar a infraestrutura base do Docker Swarm compartilhada entre múltiplas aplicações.

## 📦 O que este projeto fornece

- **Traefik**: Reverse proxy e load balancer com SSL automático (Let's Encrypt)
- **Portainer**: Interface web para gerenciar o Docker Swarm
- **Rede compartilhada**: `traefik_public` usada por todas as aplicações
- **CLI de automação**: setup, init, start, stop, add-app, remove-app

## 🚀 Como usar (Linux)

### 1. Deploy inicial (primeira vez)

```bash
# No diretório swarm-infra/
./swarm-infra.sh init
```

Isso irá:
- Criar a rede `traefik_public`
- Fazer deploy do Traefik com SSL Let's Encrypt
- Fazer deploy do Portainer
- Configurar acesso via subdomínios

### 2. Adicionar nova aplicação

Depois de fazer deploy de uma aplicação no Swarm, ela automaticamente será detectada pelo Traefik **se tiver as labels corretas**.

**Exemplo de labels no docker-compose da aplicação:**

```yaml
services:
  api:
    image: minha-app:latest
    networks:
      - traefik_public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.minha-api.rule=Host(`api.exemplo.com`)
        - traefik.http.routers.minha-api.entrypoints=websecure
        - traefik.http.routers.minha-api.tls.certresolver=letsencrypt
        - traefik.http.services.minha-api.loadbalancer.server.port=8080

networks:
  traefik_public:
    external: true
```

### 3. Usar o helper (recomendado)

```bash
# Adicionar configuracao para um app completo
./swarm-infra.sh add-app
```

Este comando ira:
- Criar um arquivo JSON em `data/apps/`
- Gerar as labels Traefik para cada servico
- Sugerir subdominios padronizados (ex: app1, app1-api, app1-postgres)

## 🌐 URLs de Acesso

### Infraestrutura (após deploy)

- **Traefik Dashboard**: `https://traefik.seudominio.com`
- **Portainer**: `https://portainer.seudominio.com`

### Aplicações (exemplos)

- **APP1 API**: `https://api-app1.seudominio.com`
- **APP1 Frontend**: `https://app1.seudominio.com`
- **APP2 API**: `https://api-app2.seudominio.com`
- **APP2 Frontend**: `https://app2.seudominio.com`

## 📋 Pré-requisitos

1. Docker Swarm inicializado
2. Domínio configurado com DNS apontando para o servidor
3. Portas 80 e 443 abertas no firewall
4. Email válido para Let's Encrypt

## ⚙️ Configuração

Copie o arquivo de exemplo e edite as variáveis:

```bash
cp .env.example .env
nano .env
```

**Variáveis principais:**

```env
# Domínio base
DOMAIN=seudominio.com

# Email para certificados SSL
LETSENCRYPT_EMAIL=admin@seudominio.com

# Auth do Traefik Dashboard
TRAEFIK_AUTH=admin:$$apr1$$xyz$$abc123
```

## 📁 Estrutura do Projeto

```
swarm-infra/
├── README.md                      # Este arquivo
├── .env.example                   # Exemplo de configuração
├── .env                          # Configuração (não versionado)
├── docker-compose.yml            # Stack principal (Traefik + Portainer)
├── swarm-infra.sh                # CLI principal (Linux)
├── data/
│   └── apps/                      # Configuracoes JSON dos apps
└── docs/
    ├── traefik-labels.md         # Referência de labels Traefik
    └── troubleshooting.md        # Solução de problemas comuns
```

## 🔧 Comandos Úteis

```bash
# Ver status da stack
docker stack ps swarm-infra

# Ver logs do Traefik
docker service logs -f swarm-infra_traefik

# Ver logs do Portainer
docker service logs -f swarm-infra_portainer

# Listar todas as rotas ativas
docker service inspect swarm-infra_traefik --format='{{json .Spec.Labels}}' | jq

# Parar a stack
./swarm-infra.sh stop

# Re-deploy (atualizações)
./swarm-infra.sh start
```

## 🔐 Segurança

### Traefik Dashboard

Protegido com autenticação básica. Para gerar nova senha:

```bash
# Instalar htpasswd (se necessário)
sudo apt-get install apache2-utils

# Gerar hash (copie o output para TRAEFIK_AUTH no .env)
echo $(htpasswd -nb admin sua-senha)
```

### Portainer

Primeira configuração via interface web em `https://portainer.seudominio.com`

## 📦 Aplicações Compatíveis

Qualquer aplicação que:
1. Roda no mesmo Docker Swarm
2. Está conectada à rede `traefik_public`
3. Tem labels Traefik configuradas

### Exemplos de stacks compatíveis:
- ✅ APP1 Platform (este repositório)
- ✅ APIs Node.js / Go / Python
- ✅ Frontends React / Vue / Angular
- ✅ WordPress, Ghost, etc
- ✅ Bases de dados expostas (com cautela)
- ✅ Ferramentas de monitoramento (Grafana, Prometheus)

## 🤝 Como outras aplicações devem se conectar

### No docker-compose da aplicação:

```yaml
version: '3.8'

networks:
  traefik_public:
    external: true  # ← Usa a rede criada por este projeto

services:
  meu-servico:
    image: minha-image
    networks:
      - traefik_public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.meu-router.rule=Host(`meu-app.${DOMAIN}`)
        - traefik.http.routers.meu-router.entrypoints=websecure
        - traefik.http.routers.meu-router.tls.certresolver=letsencrypt
        - traefik.http.services.meu-service.loadbalancer.server.port=8080
```

## 📚 Referências

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Docker Swarm Networking](https://docs.docker.com/engine/swarm/networking/)

## 🐛 Troubleshooting

### Traefik não detecta meu serviço

1. Verifique se o serviço está na rede `traefik_public`
2. Verifique se tem `traefik.enable=true`
3. Verifique se o Traefik foi reiniciado após mudanças

### SSL não funciona

1. Verifique se o DNS está apontando corretamente
2. Verifique se as portas 80/443 estão abertas
3. Verifique logs: `docker service logs swarm-infra_traefik`

### Portainer não carrega

1. Aguarde 1-2 minutos após deploy inicial
2. Verifique healthcheck: `docker service ps swarm-infra_portainer`

---

**Projeto independente** - Pode ser usado com qualquer aplicação no mesmo Docker Swarm.
