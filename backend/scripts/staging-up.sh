#!/usr/bin/env bash
# Local staging: the agent on :3001 and the backend on :3000, both on this Mac,
# both against the staging Supabase project. See docs/team/staging.md.
#
#   npm run staging:up            check both env files, start both, wait for health
#   npm run staging:up -- stop    stop what this script started
#
# Prints variable names and HTTP status codes only, never a value.
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BACKEND_DIR/logs/staging"

# npm starts a shell that starts tsx that starts node, so the whole tree goes.
kill_tree() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$child"; done
  kill "$1" 2>/dev/null || true
}

stop() {
  for name in backend agent; do
    pidfile="$LOG_DIR/$name.pid"
    if [[ -f "$pidfile" ]]; then
      kill_tree "$(cat "$pidfile")"
      rm -f "$pidfile"
      echo "stopped $name"
    fi
  done
}

if [[ "${1:-}" == "stop" ]]; then stop; exit 0; fi

AGENT_DIR="${AGENT_DIR:-$BACKEND_DIR/../../retrospect-agent}"
[[ -d "$AGENT_DIR" ]] || { echo "agent repo not found at $AGENT_DIR (set AGENT_DIR)"; exit 1; }
AGENT_DIR="$(cd "$AGENT_DIR" && pwd)"
BACKEND_ENV="$BACKEND_DIR/.env.staging"
AGENT_ENV="$AGENT_DIR/.env.staging"

value_of() { grep -E "^$2=" "$1" | tail -1 | cut -d= -f2-; }

check_env() {
  local file="$1"; shift
  [[ -f "$file" ]] || { echo "missing $file (copy .env.staging.example and fill it in)"; exit 1; }
  local missing=()
  for name in "$@"; do [[ -n "$(value_of "$file" "$name")" ]] || missing+=("$name"); done
  if (( ${#missing[@]} )); then echo "$file is missing: ${missing[*]}"; exit 1; fi
  [[ "$(value_of "$file" RETROSPECT_ENV)" == "staging" ]] || { echo "$file: RETROSPECT_ENV must be staging"; exit 1; }
  [[ "$(value_of "$file" DOTENV_CONFIG_PATH)" == ".env.staging" ]] || { echo "$file: DOTENV_CONFIG_PATH must be .env.staging"; exit 1; }
}

check_env "$BACKEND_ENV" SUPABASE_URL SUPABASE_SERVICE_KEY SUPABASE_ANON_KEY ANTHROPIC_API_KEY OPENAI_API_KEY \
  JWT_SECRET AGENT_SERVICE_URL INTERNAL_API_SECRET RETROSPECT_ENV DOTENV_CONFIG_PATH
check_env "$AGENT_ENV" SUPABASE_URL SUPABASE_SERVICE_KEY OPENAI_API_KEY INTERNAL_API_SECRET RETROSPECT_ENV DOTENV_CONFIG_PATH
[[ "$(value_of "$BACKEND_ENV" SUPABASE_URL)" == "$(value_of "$AGENT_ENV" SUPABASE_URL)" ]] \
  || { echo "SUPABASE_URL differs between the two env files"; exit 1; }
[[ "$(value_of "$BACKEND_ENV" INTERNAL_API_SECRET)" == "$(value_of "$AGENT_ENV" INTERNAL_API_SECRET)" ]] \
  || { echo "INTERNAL_API_SECRET differs between the two env files"; exit 1; }
[[ "$(value_of "$BACKEND_ENV" AGENT_SERVICE_URL)" == "http://localhost:3001" ]] \
  || { echo "$BACKEND_ENV: AGENT_SERVICE_URL must be http://localhost:3001"; exit 1; }
echo "env files: complete"

mkdir -p "$LOG_DIR"
stop >/dev/null
for port in 3000 3001; do
  if lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null 2>&1; then echo "port $port is already in use; stop that first"; exit 1; fi
done
(cd "$AGENT_DIR" && nohup npm run dev:staging >"$LOG_DIR/agent.log" 2>&1 & echo $! >"$LOG_DIR/agent.pid")
(cd "$BACKEND_DIR" && nohup npm run dev:staging >"$LOG_DIR/backend.log" 2>&1 & echo $! >"$LOG_DIR/backend.pid")

wait_for() {
  local label="$1" url="$2" code="000"
  for _ in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)"
    [[ "$code" == "200" ]] && break
    sleep 1
  done
  echo "$label $code"
  [[ "$code" == "200" ]]
}

wait_for "agent   GET /health/ready" "http://localhost:3001/health/ready"
wait_for "backend GET /health      " "http://localhost:3000/health"
echo "logs: $LOG_DIR (stop with: npm run staging:up -- stop)"
