#!/usr/bin/env bash
# =============================================================================
# Swarm Infra - Command Line Interface (Linux only)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
STACK_NAME_DEFAULT="swarm-infra"
DATA_DIR="$SCRIPT_DIR/data"
APPS_DIR="$DATA_DIR/apps"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[OK] $*"; }

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
require_linux() {
    if [ "$(uname -s)" != "Linux" ]; then
        log_error "Este comando suporta apenas Linux."
        exit 1
    fi
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

ensure_dirs() {
    : # Diretório de apps não mais necessário
}

sanitize_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//'
}

json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer
    while true; do
        read -r -p "$prompt" answer
        if [ -z "$answer" ]; then
            answer="$default"
        fi
        case "$answer" in
            y|Y|yes|YES) echo "yes"; return 0 ;;
            n|N|no|NO) echo "no"; return 0 ;;
            *) echo "Digite yes ou no." ;;
        esac
    done
}



set_env_var() {
    local key="$1"
    local value="$2"

    if [ -f "$ENV_FILE" ] && grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|g" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +a
    fi
}



ensure_swarm_active() {
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        return 0
    fi

    log_warn "Docker Swarm nao esta ativo. Inicializando..."

    # Tentar sem advertise-addr primeiro
    if docker swarm init 2>/dev/null; then
        log_success "Swarm inicializado"
        return 0
    fi

    # Se falhar por já estar em um Swarm, deixar e reiniciar
    if docker swarm leave --force 2>/dev/null; then
        log_warn "Deixando Swarm anterior..."
    fi

    # Se falhar, tentar com advertise-addr detectado automaticamente
    local advertise_ip
    advertise_ip=$(hostname -I | awk '{print $1}')
    
    if [ -z "$advertise_ip" ]; then
        log_error "Nao foi possivel detectar o endereco IP da VM"
        log_error "Use manualmente: docker swarm init --advertise-addr <SEU_IP>"
        exit 1
    fi

    log_warn "Tentando com advertise-addr: $advertise_ip"
    if ! docker swarm init --advertise-addr "$advertise_ip" 2>/dev/null; then
        log_error "Falha ao iniciar o Swarm com advertise-addr: $advertise_ip"
        exit 1
    fi

    log_success "Swarm inicializado com advertise-addr: $advertise_ip"
}

ensure_env_configured() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            log_info "Arquivo .env criado a partir de .env.example"
        else
            log_error "Arquivo .env.example nao encontrado."
            exit 1
        fi
    fi

    load_env

    if [ -z "${DOMAIN:-}" ]; then
        read -r -p "Dominio base (ex: exemplo.com): " DOMAIN
        set_env_var "DOMAIN" "${DOMAIN}"
    fi

    if [ -z "${LETSENCRYPT_EMAIL:-}" ]; then
        read -r -p "Email para Let's Encrypt: " LETSENCRYPT_EMAIL
        set_env_var "LETSENCRYPT_EMAIL" "${LETSENCRYPT_EMAIL}"
    fi

    if [ -z "${TRAEFIK_AUTH:-}" ]; then
        local traefik_password traefik_hash
        
        while true; do
            read -r -sp "Senha do Traefik: " traefik_password
            echo ""
            
            if [ -z "${traefik_password}" ]; then
                log_warn "Senha do Traefik nao pode estar vazia. Tente novamente (ou pressione Ctrl+C para cancelar)"
                continue
            fi
            break
        done
        
        if ! command -v htpasswd >/dev/null 2>&1; then
            log_error "htpasswd nao esta instalado. Execute: apt-get install apache2-utils"
            exit 1
        fi
        
        traefik_hash=$(htpasswd -nbB admin "${traefik_password}" | sed 's/\$/\$\$/g')
        set_env_var "TRAEFIK_AUTH" "'${traefik_hash}'"
    fi

    if [ -z "${PORTAINER_ADMIN_PASSWORD:-}" ]; then
        local portainer_password portainer_hash
        
        while true; do
            read -r -sp "Senha do Portainer: " portainer_password
            echo ""
            
            if [ -z "${portainer_password}" ]; then
                log_warn "Senha do Portainer nao pode estar vazia. Tente novamente (ou pressione Ctrl+C para cancelar)"
                continue
            fi
            break
        done
        
        if ! command -v htpasswd >/dev/null 2>&1; then
            log_error "htpasswd nao esta instalado. Execute: apt-get install apache2-utils"
            exit 1
        fi
        
        portainer_hash=$(htpasswd -nbB admin "${portainer_password}" | cut -d ":" -f 2)
        set_env_var "PORTAINER_ADMIN_PASSWORD" "'${portainer_hash}'"
    fi

    load_env
}

stack_name() {
    load_env
    echo "${STACK_NAME:-$STACK_NAME_DEFAULT}"
}

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
cmd_setup() {
    require_linux

    if command -v docker >/dev/null 2>&1; then
        log_info "O Docker ja esta instalado no sistema."
        return 0
    fi

    log_info "Iniciando a instalacao automatizada do Docker..."

    # Remover configuracoes antigas/corrompidas do Docker antes do apt-get update
    log_info "Limpando configuracoes de repositorios antigos do Docker..."
    sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources

    # 1. Atualizar e instalar dependencias basicas
    log_info "Atualizando pacotes e instalando dependencias basicas (ca-certificates, curl, gnupg)..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    # 2. Configurar a chave GPG do Docker
    log_info "Configurando chave GPG oficial do Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # 3. Configurar repositorio do Docker
    log_info "Configurando repositorio do Docker..."
    local suite
    suite=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${suite}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # 4. Atualizar os repositorios do apt e instalar o Docker
    log_info "Atualizando repositorios com o novo source do Docker..."
    sudo apt-get update

    log_info "Instalando Docker Engine, CLI, Containerd e plugins..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 5. Iniciar e habilitar o servico do Docker
    log_info "Habilitando e iniciando servico do Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker

    # 6. Instalar dependencias para geracao de Hash (apache2-utils)
    log_info "Instalando dependencias de Hash (apache2-utils)..."
    sudo apt-get install -y apache2-utils

    # 7. Verificar a instalacao
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker instalado com sucesso!"
        docker --version
    else
        log_error "Erro: Docker nao foi encontrado apos a instalacao."
        exit 1
    fi

    if command -v htpasswd >/dev/null 2>&1; then
        log_success "apache2-utils (htpasswd) instalado com sucesso!"
    else
        log_warn "Aviso: htpasswd nao foi encontrado no PATH."
    fi

    log_success "Setup concluido com sucesso! Agora voce pode rodar './swarm-infra.sh init'"
}

cmd_init() {
    require_linux

    ensure_swarm_active
    ensure_env_configured
    ensure_dirs
    load_env

    local name
    name="$(stack_name)"

    log_info "Verificando rede traefik_public..."
    if ! docker network ls | grep -q "traefik_public"; then
        docker network create --driver overlay --attachable traefik_public
        log_success "Rede criada"
    else
        log_info "Rede traefik_public ja existe"
    fi

    log_info "Fazendo deploy da stack: $name"
    docker stack deploy -c docker-compose.yml --with-registry-auth "$name"

    log_success "Stack inicializada"
}

cmd_start() {
    require_linux

    ensure_swarm_active

    if [ ! -f "$ENV_FILE" ]; then
        log_error "Arquivo .env nao encontrado. Execute: ./swarm-infra.sh init"
        exit 1
    fi

    ensure_dirs
    load_env

    local name
    name="$(stack_name)"

    log_info "Iniciando stack: $name"
    docker stack deploy -c docker-compose.yml --with-registry-auth "$name"
    log_success "Stack iniciada"
}

cmd_stop() {
    require_linux

    local name
    name="$(stack_name)"

    if ! docker stack ls | grep -q "${name}"; then
        log_warn "Stack $name nao encontrada"
        return 0
    fi

    if [ "${1:-}" != "--force" ]; then
        local confirm
        confirm="$(ask_yes_no "Confirma parar a stack $name? (yes/no): " "no")"
        if [ "$confirm" != "yes" ]; then
            log_info "Operacao cancelada"
            return 0
        fi
    fi

    log_info "Parando stack $name..."
    docker stack rm "$name"
    log_success "Stack parada"
}

cmd_restart() {
    require_linux

    local confirm
    confirm="$(ask_yes_no "Confirma reiniciar a stack? (yes/no): " "no")"
    if [ "$confirm" != "yes" ]; then
        log_info "Operacao cancelada"
        return 0
    fi

    cmd_stop --force
    cmd_start
}

cmd_cleanup() {
    require_linux

    local name
    name="$(stack_name)"

    log_warn "⚠️  ATENÇÃO: Este comando vai APAGAR TUDO:"
    log_warn "   - Stack: $name"
    log_warn "   - Volumes: portainer_data, traefik_letsencrypt"
    log_warn "   - Arquivo .env"
    
    local confirm
    confirm="$(ask_yes_no "Deseja continuar? (yes/no): " "no")"
    if [ "$confirm" != "yes" ]; then
        log_info "Operacao cancelada"
        return 0
    fi

    # Parar a stack
    if docker stack ls | grep -q "${name}"; then
        log_info "Removendo stack: $name"
        docker stack rm "$name" || true
        sleep 3  # Aguardar remoção dos serviços
    fi

    # Remover volumes
    log_info "Removendo volumes..."
    docker volume rm "${name}_portainer_data" 2>/dev/null || log_warn "Volume portainer_data não encontrado"
    docker volume rm "${name}_traefik_letsencrypt" 2>/dev/null || log_warn "Volume traefik_letsencrypt não encontrado"

    # Remover arquivo .env
    if [ -f "$ENV_FILE" ]; then
        log_info "Removendo arquivo .env"
        rm -f "$ENV_FILE"
    fi

    log_success "Cleanup completo! Execute 'init' para recomeçar do zero."
}

cmd_help() {
    cat <<EOF
Uso: ./swarm-infra.sh <comando>

Comandos:
  setup       Instala o Docker, Docker Compose e dependencias (apache2-utils) no servidor atual
  init        Inicializa Traefik + Portainer (primeira vez)
  start       Inicia a stack swarm-infra
  stop        Para a stack swarm-infra
  restart     Reinicia a stack swarm-infra
  cleanup     ⚠️  Remove TUDO (stack, volumes, .env) e recomeça do zero
EOF
}

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
case "${1:-}" in
    setup) cmd_setup ;;
    init) cmd_init ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    cleanup) cmd_cleanup ;;
    help|--help|-h|"") cmd_help ;;
    *)
        log_error "Comando desconhecido: $1"
        cmd_help
        exit 1
        ;;
 esac
