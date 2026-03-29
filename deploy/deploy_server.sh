#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PARENT="$(cd "$PROJECT_DIR/.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$SCRIPT_DIR/.deploy.env}"
if [[ -f "$DEPLOY_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$DEPLOY_ENV_FILE"
  set +a
fi

SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-root}"
SERVER_PORT="${SERVER_PORT:-22}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"

REMOTE_DIR="${REMOTE_DIR:-/srv/toolStore}"
REMOTE_RELEASE_PATH="${REMOTE_RELEASE_PATH:-/root/toolstore-release.tgz}"
REMOTE_SCRIPT_PATH="${REMOTE_SCRIPT_PATH:-/root/toolstore-deploy-remote.sh}"
REMOTE_UPLOADED_ENV_PATH="${REMOTE_UPLOADED_ENV_PATH:-/root/toolstore.env.server}"

LOCAL_ENV_FILE="${LOCAL_ENV_FILE:-deploy/.env.server}"
UPLOAD_ENV_FILE="${UPLOAD_ENV_FILE:-0}"
PRESERVE_REMOTE_ENV="${PRESERVE_REMOTE_ENV:-1}"
STOP_NGINX_ON_PORT_80="${STOP_NGINX_ON_PORT_80:-1}"

HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"
WAIT_FOR_HEALTH_SECONDS="${WAIT_FOR_HEALTH_SECONDS:-90}"
SKIP_HEALTHCHECK=0

usage() {
  cat <<'EOF'
Usage:
  ./deploy/deploy_server.sh [options]

Options:
  --host <host>           Override SERVER_HOST
  --user <user>           Override SERVER_USER
  --port <port>           Override SERVER_PORT
  --password <password>   Override SERVER_PASSWORD
  --remote-dir <dir>      Override REMOTE_DIR
  --sync-env              Upload local deploy/.env.server before deploy
  --skip-healthcheck      Skip the final /health validation
  -h, --help              Show this help

Defaults are read from deploy/.deploy.env when present.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      SERVER_HOST="$2"
      shift 2
      ;;
    --user)
      SERVER_USER="$2"
      shift 2
      ;;
    --port)
      SERVER_PORT="$2"
      shift 2
      ;;
    --password)
      SERVER_PASSWORD="$2"
      shift 2
      ;;
    --remote-dir)
      REMOTE_DIR="$2"
      shift 2
      ;;
    --sync-env)
      UPLOAD_ENV_FILE=1
      shift
      ;;
    --skip-healthcheck)
      SKIP_HEALTHCHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SERVER_HOST" ]]; then
  echo "SERVER_HOST is required. Set it in deploy/.deploy.env or pass --host." >&2
  exit 1
fi

if [[ -z "$HEALTHCHECK_URL" ]]; then
  HEALTHCHECK_URL="http://$SERVER_HOST/health"
fi

if [[ "$UPLOAD_ENV_FILE" == "1" && ! -f "$PROJECT_DIR/$LOCAL_ENV_FILE" && ! -f "$LOCAL_ENV_FILE" ]]; then
  echo "Local env file not found: $LOCAL_ENV_FILE" >&2
  exit 1
fi

SSH_TARGET="${SERVER_USER}@${SERVER_HOST}"
TMP_EXPECT=""
TMP_REMOTE_SCRIPT=""
PACKAGE_PATH="$(mktemp /tmp/toolstore-release.XXXXXX.tgz)"

cleanup() {
  rm -f "$PACKAGE_PATH"
  if [[ -n "$TMP_EXPECT" ]]; then
    rm -f "$TMP_EXPECT"
  fi
  if [[ -n "$TMP_REMOTE_SCRIPT" ]]; then
    rm -f "$TMP_REMOTE_SCRIPT"
  fi
}
trap cleanup EXIT

if [[ -n "$SERVER_PASSWORD" ]]; then
  if ! command -v expect >/dev/null 2>&1; then
    echo "expect is required when SERVER_PASSWORD is set." >&2
    exit 1
  fi
  TMP_EXPECT="$(mktemp /tmp/toolstore-ssh.XXXXXX.expect)"
  cat > "$TMP_EXPECT" <<'EOF'
#!/usr/bin/expect -f
set timeout -1
set password [lindex $argv 0]
set cmd [lrange $argv 1 end]
spawn {*}$cmd
expect {
  "*yes/no*" { send "yes\r"; exp_continue }
  "*assword:*" { send "$password\r"; exp_continue }
  eof
}
catch wait result
set exit_status [lindex $result 3]
exit $exit_status
EOF
  chmod 700 "$TMP_EXPECT"
fi

run_ssh() {
  if [[ -n "$SERVER_PASSWORD" ]]; then
    "$TMP_EXPECT" "$SERVER_PASSWORD" ssh -p "$SERVER_PORT" -o StrictHostKeyChecking=no "$SSH_TARGET" "$1"
  else
    ssh -p "$SERVER_PORT" -o StrictHostKeyChecking=no "$SSH_TARGET" "$1"
  fi
}

run_scp() {
  local source_path="$1"
  local target_path="$2"
  if [[ -n "$SERVER_PASSWORD" ]]; then
    "$TMP_EXPECT" "$SERVER_PASSWORD" scp -P "$SERVER_PORT" -o StrictHostKeyChecking=no "$source_path" "$SSH_TARGET:$target_path"
  else
    scp -P "$SERVER_PORT" -o StrictHostKeyChecking=no "$source_path" "$SSH_TARGET:$target_path"
  fi
}

echo "Packaging $PROJECT_NAME ..."
tar \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='.pytest_cache' \
  --exclude='data' \
  --exclude='test.db' \
  --exclude='tool_store.db' \
  --exclude='__pycache__' \
  --exclude='mobile_app/.dart_tool' \
  --exclude='mobile_app/build' \
  --exclude='mobile_app/.flutter-plugins' \
  --exclude='mobile_app/.flutter-plugins-dependencies' \
  -czf "$PACKAGE_PATH" \
  -C "$PROJECT_PARENT" \
  "$PROJECT_NAME"

echo "Uploading release package ..."
run_scp "$PACKAGE_PATH" "$REMOTE_RELEASE_PATH"

if [[ "$UPLOAD_ENV_FILE" == "1" ]]; then
  LOCAL_ENV_ABS="$LOCAL_ENV_FILE"
  if [[ ! -f "$LOCAL_ENV_ABS" ]]; then
    LOCAL_ENV_ABS="$PROJECT_DIR/$LOCAL_ENV_FILE"
  fi
  echo "Uploading environment file ..."
  run_scp "$LOCAL_ENV_ABS" "$REMOTE_UPLOADED_ENV_PATH"
fi

TMP_REMOTE_SCRIPT="$(mktemp /tmp/toolstore-remote.XXXXXX.sh)"
cat > "$TMP_REMOTE_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

remote_dir="$REMOTE_DIR"
remote_release="$REMOTE_RELEASE_PATH"
remote_uploaded_env="$REMOTE_UPLOADED_ENV_PATH"
preserve_remote_env="$PRESERVE_REMOTE_ENV"
upload_env_file="$UPLOAD_ENV_FILE"
stop_nginx_on_port_80="$STOP_NGINX_ON_PORT_80"

stamp=\$(date +%Y%m%d%H%M%S)
remote_parent="\$(dirname "\$remote_dir")"
backup_env="/root/toolstore.env.server.backup"

if [[ -d "\$remote_dir" && -f "\$remote_dir/deploy/.env.server" && "\$preserve_remote_env" == "1" ]]; then
  cp "\$remote_dir/deploy/.env.server" "\$backup_env"
fi

if [[ -d "\$remote_dir" ]]; then
  mv "\$remote_dir" "\$remote_dir.bak.\$stamp"
fi

mkdir -p "\$remote_parent"
tar -xzf "\$remote_release" -C "\$remote_parent"

if [[ "\$upload_env_file" == "1" && -f "\$remote_uploaded_env" ]]; then
  cp "\$remote_uploaded_env" "\$remote_dir/deploy/.env.server"
elif [[ -f "\$backup_env" ]]; then
  cp "\$backup_env" "\$remote_dir/deploy/.env.server"
fi

if [[ ! -f "\$remote_dir/deploy/.env.server" ]]; then
  echo "Missing \$remote_dir/deploy/.env.server after extraction." >&2
  exit 1
fi

if [[ "\$stop_nginx_on_port_80" == "1" ]]; then
  port_80_state="\$(ss -ltnp 2>/dev/null | awk '/:80 / {print \$0}')"
  if grep -q "nginx" <<<"\$port_80_state"; then
    nginx -s stop >/dev/null 2>&1 || pkill nginx || true
    sleep 2
  elif [[ -n "\$port_80_state" ]] && ! grep -q "docker-proxy" <<<"\$port_80_state"; then
    echo "Port 80 is occupied by a non-nginx process:" >&2
    echo "\$port_80_state" >&2
    exit 1
  fi
fi

cd "\$remote_dir/deploy"
docker compose --env-file .env.server -f docker-compose.server.yml up -d --build
docker compose --env-file .env.server -f docker-compose.server.yml ps
EOF
chmod 700 "$TMP_REMOTE_SCRIPT"

echo "Uploading remote deployment script ..."
run_scp "$TMP_REMOTE_SCRIPT" "$REMOTE_SCRIPT_PATH"

echo "Executing remote deployment ..."
run_ssh "bash $REMOTE_SCRIPT_PATH"

if [[ "$SKIP_HEALTHCHECK" == "1" ]]; then
  echo "Deployment finished. Healthcheck skipped."
  exit 0
fi

echo "Waiting for healthcheck: $HEALTHCHECK_URL"
deadline=$((SECONDS + WAIT_FOR_HEALTH_SECONDS))
while (( SECONDS < deadline )); do
  if response="$(curl --silent --show-error --max-time 10 "$HEALTHCHECK_URL" 2>/dev/null)"; then
    echo "Healthcheck passed: $response"
    exit 0
  fi
  sleep 2
done

echo "Local healthcheck failed. Checking from server ..." >&2
run_ssh "curl --silent --show-error --max-time 10 http://127.0.0.1/health || docker logs --tail 80 toolstore-app"
exit 1
