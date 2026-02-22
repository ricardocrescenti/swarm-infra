# Troubleshooting - Resolução de Problemas

Guia para diagnosticar e resolver problemas comuns com Traefik e Docker Swarm.

## 🔍 Comandos de Diagnóstico

### Verificar status da infraestrutura
```bash
# Status geral
docker stack ps swarm-infra

# Status detalhado
docker stack ps swarm-infra --no-trunc

# Logs do Traefik
docker service logs -f swarm-infra_traefik

# Logs do Portainer
docker service logs -f swarm-infra_portainer

# Inspecionar Traefik
docker service inspect swarm-infra_traefik
```

### Verificar rotas ativas
```bash
# Ver todas as configurações do Traefik
docker service inspect swarm-infra_traefik --format='{{json .Spec.Labels}}' | jq

# Verificar providers
curl http://localhost:8080/api/http/routers

# Ver certificados SSL
docker exec $(docker ps -q -f name=swarm-infra_traefik) cat /letsencrypt/acme.json
```

### Verificar rede
```bash
# Listar redes
docker network ls

# Inspecionar rede traefik_public
docker network inspect traefik_public

# Ver containers conectados
docker network inspect traefik_public --format='{{range .Containers}}{{.Name}} {{end}}'
```

## ❌ Problemas Comuns

### 1. Traefik não detecta meu serviço

**Sintomas:**
- Serviço deployado mas não acessível
- "404 Not Found" ou "Service Unavailable"

**Diagnóstico:**
```bash
# 1. Verificar se serviço está rodando
docker service ls | grep meu-servico

# 2. Ver logs do serviço
docker service logs meu-servico

# 3. Ver logs do Traefik
docker service logs swarm-infra_traefik | grep meu-servico

# 4. Verificar labels
docker service inspect meu-servico --format='{{json .Spec.Labels}}' | jq
```

**Soluções:**
- ✅ Verificar se tem `traefik.enable=true`
- ✅ Verificar se serviço está na rede `traefik_public`
- ✅ Verificar se a porta está correta
- ✅ Aguardar alguns segundos para Traefik detectar

```yaml
# Certifique-se de ter:
services:
  meu-servico:
    networks:
      - traefik_public  # ← IMPORTANTE
    deploy:
      labels:
        - traefik.enable=true  # ← IMPORTANTE
        - traefik.docker.network=traefik_public  # ← IMPORTANTE para múltiplas redes
        - traefik.http.services.meu-service.loadbalancer.server.port=8080  # ← Porta correta

networks:
  traefik_public:
    external: true  # ← IMPORTANTE
```

### 2. Certificado SSL não é gerado

**Sintomas:**
- "Your connection is not private"
- Certificado auto-assinado do Traefik
- Erro "acme: error: 400"

**Diagnóstico:**
```bash
# Ver logs de certificados
docker service logs swarm-infra_traefik | grep -i acme

# Verificar se DNS aponta corretamente
nslookup app.seudominio.com

# Verificar porta 80 acessível (necessária para challenge)
curl -I http://app.seudominio.com
```

**Soluções:**
1. **DNS não configurado:**
   - Configure A record apontando para IP do servidor
   - Aguarde propagação (pode levar minutos/horas)
   - Teste: `ping app.seudominio.com`

2. **Porta 80 bloqueada:**
   - Firewall deve permitir portas 80 e 443
   - Verificar security groups (cloud providers)

3. **Email inválido:**
   - Verificar LETSENCRYPT_EMAIL no .env
   - Deve ser email válido

4. **Rate limit Let's Encrypt:**
   - Limite: 5 falhas por hora
   - Aguarde 1 hora e tente novamente

5. **Forçar renovação:**
   ```bash
   # Remover certificado antigo
   docker service scale swarm-infra_traefik=0
   docker volume rm swarm-infra_traefik_letsencrypt
   docker service scale swarm-infra_traefik=1
   ```

### 3. "502 Bad Gateway"

**Sintomas:**
- Traefik responde mas backend não
- Erro 502

**Diagnóstico:**
```bash
# 1. Verificar se backend está rodando
docker service ps meu-servico

# 2. Testar porta diretamente
docker exec $(docker ps -q -f name=meu-servico) wget -O- http://localhost:8080/health

# 3. Verificar healthcheck
docker service inspect meu-servico --format='{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}'
```

**Soluções:**
- ✅ Verificar se porta está correta nas labels
- ✅ Verificar se aplicação está escutando em 0.0.0.0 (não 127.0.0.1)
- ✅ Verificar se healthcheck path existe
- ✅ Aumentar timeout do healthcheck

### 4. "404 Page Not Found"

**Sintomas:**
- DNS resolve, SSL funciona, mas rota não encontrada

**Diagnóstico:**
```bash
# Ver rotas configuradas
docker service inspect swarm-infra_traefik | grep -A 10 "routers"

# Verificar rule
docker service inspect meu-servico | grep "rule"
```

**Soluções:**
- ✅ Verificar Host() na rule
- ✅ Verificar PathPrefix() se aplicável
- ✅ Verificar typo no domínio

### 5. CORS Errors

**Sintomas:**
- "Access-Control-Allow-Origin" error no browser
- API funciona com curl mas não no browser

**Solução:**
```yaml
deploy:
  labels:
    - traefik.http.routers.api.middlewares=cors
    - traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE,OPTIONS
    - traefik.http.middlewares.cors.headers.accesscontrolalloworiginlist=https://frontend.exemplo.com
    - traefik.http.middlewares.cors.headers.accesscontrolallowcredentials=true
    - traefik.http.middlewares.cors.headers.accesscontrolmaxage=100
```

### 6. Redirect Loop (Muitos Redirecionamentos)

**Sintomas:**
- ERR_TOO_MANY_REDIRECTS
- Página não carrega

**Causas comuns:**
- Dois redirecionamentos HTTP→HTTPS configurados
- Backend fazendo redirect

**Solução:**
```yaml
# Remover redirect do router HTTP se já tiver no middleware
# OU
# Verificar se backend não está forçando HTTPS
```

### 7. Portainer não carrega

**Diagnóstico:**
```bash
# Status
docker service ps swarm-infra_portainer

# Logs
docker service logs swarm-infra_portainer

# Healthcheck
docker service inspect swarm-infra_portainer --format='{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}'
```

**Soluções:**
- ✅ Aguardar 1-2 minutos após deploy
- ✅ Verificar se tem /var/run/docker.sock montado
- ✅ Restart: `docker service update --force swarm-infra_portainer`

### 8. Múltiplos serviços no mesmo host

**Problema:** Dois serviços com mesmo Host() causam conflito

**Solução:**
```yaml
# Usar PathPrefix para diferenciar
- traefik.http.routers.api.rule=Host(`app.com`) && PathPrefix(`/api`)
- traefik.http.routers.frontend.rule=Host(`app.com`) && PathPrefix(`/`)

# OU usar priority
- traefik.http.routers.api.priority=200  # Maior prioridade
- traefik.http.routers.frontend.priority=100
```

### 9. Volume permissions

**Sintomas:**
- "Permission denied" nos logs
- acme.json não pode ser escrito

**Solução:**
```bash
# Verificar permissões do volume
docker volume inspect swarm-infra_traefik_letsencrypt

# Se necessário, recriar com permissões corretas
docker service scale swarm-infra_traefik=0
docker volume rm swarm-infra_traefik_letsencrypt
docker volume create swarm-infra_traefik_letsencrypt
docker service scale swarm-infra_traefik=1
```

## 🔧 Comandos de Recuperação

### Restart Traefik
```bash
docker service update --force swarm-infra_traefik
```

### Restart Portainer
```bash
docker service update --force swarm-infra_portainer
```

### Redeploy completo
```bash
./swarm-infra.sh stop
./swarm-infra.sh init
```

### Limpar certificados e reiniciar
```bash
docker service scale swarm-infra_traefik=0
docker volume rm swarm-infra_traefik_letsencrypt
./swarm-infra.sh init
```

## 📊 Verificação de Saúde

### Checklist Completo
```bash
# 1. Swarm ativo?
docker info | grep "Swarm: active"

# 2. Rede existe?
docker network ls | grep traefik_public

# 3. Stack rodando?
docker stack ps swarm-infra

# 4. Traefik respondendo?
curl -k https://traefik.seudominio.com/api/rawdata

# 5. DNS configurado?
nslookup app.seudominio.com

# 6. Portas abertas?
nc -zv seuservidor.com 80
nc -zv seuservidor.com 443

# 7. Certificado válido?
openssl s_client -connect app.seudominio.com:443 -servername app.seudominio.com
```

## 🆘 Quando Nada Funciona

1. **Coletar informações:**
   ```bash
   docker service ls > debug-services.txt
   docker stack ps swarm-infra --no-trunc > debug-stack.txt
   docker service logs swarm-infra_traefik > debug-traefik.log
   docker network inspect traefik_public > debug-network.json
   ```

2. **Deploy limpo:**
   ```bash
   # Remover tudo
   ./swarm-infra.sh stop
   
   # Limpar volumes órfãos
   docker volume prune -f
   
   # Redeploy
   ./swarm-infra.sh init
   ```

3. **Verificar documentação:**
   - [Traefik Documentation](https://doc.traefik.io/traefik/)
   - [Docker Swarm Troubleshooting](https://docs.docker.com/engine/swarm/swarm-tutorial/)

## 📞 Suporte

Se o problema persistir:
1. Verifique logs completos
2. Teste com configuração mínima
3. Verifique GitHub Issues do Traefik
4. Stack Overflow com tag [traefik] [docker-swarm]
