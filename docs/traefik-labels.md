# Referência de Labels Traefik

Guia completo de labels Traefik para configurar rotas no Docker Swarm.

## 📋 Labels Básicas

### Habilitar Traefik
```yaml
- traefik.enable=true
```

### Especificar Rede
```yaml
- traefik.docker.network=traefik_public
```

## 🌐 Routers (Roteamento)

### Router Simples (HTTPS)
```yaml
- traefik.http.routers.meu-router.rule=Host(`app.exemplo.com`)
- traefik.http.routers.meu-router.entrypoints=websecure
- traefik.http.routers.meu-router.tls=true
- traefik.http.routers.meu-router.tls.certresolver=letsencrypt
```

### Router com Path Prefix
```yaml
- traefik.http.routers.meu-router.rule=Host(`app.exemplo.com`) && PathPrefix(`/api`)
```

### Router com Múltiplos Hosts
```yaml
- traefik.http.routers.meu-router.rule=Host(`app1.exemplo.com`) || Host(`app2.exemplo.com`)
```

### Router HTTP (sem SSL)
```yaml
- traefik.http.routers.meu-router.rule=Host(`app.exemplo.com`)
- traefik.http.routers.meu-router.entrypoints=web
```

## 🔀 Services (Backend)

### Especificar Porta
```yaml
- traefik.http.services.meu-service.loadbalancer.server.port=8080
```

### Healthcheck
```yaml
- traefik.http.services.meu-service.loadbalancer.healthcheck.path=/health
- traefik.http.services.meu-service.loadbalancer.healthcheck.interval=10s
- traefik.http.services.meu-service.loadbalancer.healthcheck.timeout=5s
```

### Sticky Sessions
```yaml
- traefik.http.services.meu-service.loadbalancer.sticky=true
- traefik.http.services.meu-service.loadbalancer.sticky.cookie.name=lb_sticky
- traefik.http.services.meu-service.loadbalancer.sticky.cookie.secure=true
- traefik.http.services.meu-service.loadbalancer.sticky.cookie.httpOnly=true
```

## 🔧 Middlewares

### CORS
```yaml
- traefik.http.routers.meu-router.middlewares=cors
- traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE,OPTIONS
- traefik.http.middlewares.cors.headers.accesscontrolalloworiginlist=https://exemplo.com
- traefik.http.middlewares.cors.headers.accesscontrolallowcredentials=true
- traefik.http.middlewares.cors.headers.accesscontrolmaxage=100
```

### Strip Prefix
```yaml
- traefik.http.routers.meu-router.middlewares=strip
- traefik.http.middlewares.strip.stripprefix.prefixes=/api
```

### Redirect HTTP → HTTPS
```yaml
- traefik.http.routers.meu-router-http.rule=Host(`app.exemplo.com`)
- traefik.http.routers.meu-router-http.entrypoints=web
- traefik.http.routers.meu-router-http.middlewares=redirect-https
- traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
- traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
```

### Basic Auth
```yaml
- traefik.http.routers.meu-router.middlewares=auth
- traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz$$abc123
```

### Rate Limiting
```yaml
- traefik.http.routers.meu-router.middlewares=ratelimit
- traefik.http.middlewares.ratelimit.ratelimit.average=100
- traefik.http.middlewares.ratelimit.ratelimit.burst=50
```

### Headers de Segurança
```yaml
- traefik.http.routers.meu-router.middlewares=security
- traefik.http.middlewares.security.headers.sslredirect=true
- traefik.http.middlewares.security.headers.stsSeconds=31536000
- traefik.http.middlewares.security.headers.stsIncludeSubdomains=true
- traefik.http.middlewares.security.headers.stsPreload=true
- traefik.http.middlewares.security.headers.frameDeny=true
- traefik.http.middlewares.security.headers.contentTypeNosniff=true
- traefik.http.middlewares.security.headers.browserXssFilter=true
```

### Compressão
```yaml
- traefik.http.routers.meu-router.middlewares=compress
- traefik.http.middlewares.compress.compress=true
```

### Múltiplos Middlewares
```yaml
- traefik.http.routers.meu-router.middlewares=cors,strip,compress
```

## 📝 Exemplos Completos

### API Backend
```yaml
services:
  api:
    image: minha-api:latest
    networks:
      - traefik_public
    deploy:
      labels:
        # Habilitar Traefik
        - traefik.enable=true
        - traefik.docker.network=traefik_public
        
        # Router HTTPS
        - traefik.http.routers.api.rule=Host(`api.exemplo.com`)
        - traefik.http.routers.api.entrypoints=websecure
        - traefik.http.routers.api.tls=true
        - traefik.http.routers.api.tls.certresolver=letsencrypt
        
        # Middlewares
        - traefik.http.routers.api.middlewares=api-cors
        - traefik.http.middlewares.api-cors.headers.accesscontrolallowmethods=GET,POST,PUT,DELETE,OPTIONS
        - traefik.http.middlewares.api-cors.headers.accesscontrolalloworiginlist=https://app.exemplo.com
        - traefik.http.middlewares.api-cors.headers.accesscontrolallowcredentials=true
        
        # Service
        - traefik.http.services.api.loadbalancer.server.port=8080
        - traefik.http.services.api.loadbalancer.healthcheck.path=/health
        - traefik.http.services.api.loadbalancer.healthcheck.interval=10s

networks:
  traefik_public:
    external: true
```

### Frontend SPA
```yaml
services:
  frontend:
    image: meu-frontend:latest
    networks:
      - traefik_public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.docker.network=traefik_public
        
        # Router HTTPS
        - traefik.http.routers.frontend.rule=Host(`app.exemplo.com`)
        - traefik.http.routers.frontend.entrypoints=websecure
        - traefik.http.routers.frontend.tls=true
        - traefik.http.routers.frontend.tls.certresolver=letsencrypt
        
        # Headers de segurança
        - traefik.http.routers.frontend.middlewares=security
        - traefik.http.middlewares.security.headers.sslredirect=true
        - traefik.http.middlewares.security.headers.stsSeconds=31536000
        - traefik.http.middlewares.security.headers.frameDeny=true
        
        # Service
        - traefik.http.services.frontend.loadbalancer.server.port=80

networks:
  traefik_public:
    external: true
```

### Múltiplas Rotas (API + Frontend na mesma stack)
```yaml
services:
  api:
    image: backend:latest
    networks:
      - traefik_public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.myapp-api.rule=Host(`api.exemplo.com`)
        - traefik.http.routers.myapp-api.entrypoints=websecure
        - traefik.http.routers.myapp-api.tls.certresolver=letsencrypt
        - traefik.http.services.myapp-api.loadbalancer.server.port=8080

  frontend:
    image: frontend:latest
    networks:
      - traefik_public
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.myapp-frontend.rule=Host(`app.exemplo.com`)
        - traefik.http.routers.myapp-frontend.entrypoints=websecure
        - traefik.http.routers.myapp-frontend.tls.certresolver=letsencrypt
        - traefik.http.services.myapp-frontend.loadbalancer.server.port=80

networks:
  traefik_public:
    external: true
```

## 🔍 Regras de Roteamento Avançadas

### Por Hostname e Path
```yaml
- traefik.http.routers.api.rule=Host(`exemplo.com`) && PathPrefix(`/api`)
```

### Por Header
```yaml
- traefik.http.routers.api.rule=Host(`exemplo.com`) && Headers(`X-API-Key`, `secret`)
```

### Por Query String
```yaml
- traefik.http.routers.api.rule=Host(`exemplo.com`) && Query(`version`, `v2`)
```

### Regex
```yaml
- traefik.http.routers.api.rule=Host(`exemplo.com`) && PathPrefix(`/api/{version:[0-9]+}`)
```

## 🚀 Dicas de Performance

### Prioridade de Routers
Router mais específico tem prioridade maior:
```yaml
- traefik.http.routers.api.priority=100
```

### Timeout
```yaml
- traefik.http.services.api.loadbalancer.responseForwarding.flushInterval=100ms
```

## 📚 Documentação Oficial

- [Traefik Routers](https://doc.traefik.io/traefik/routing/routers/)
- [Traefik Services](https://doc.traefik.io/traefik/routing/services/)
- [Traefik Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)
- [Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
