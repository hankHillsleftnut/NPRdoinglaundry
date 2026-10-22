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
      pid="$(cat "$pidfile")"
      # Only kill it if it is still the npm we started; a reused pid is someone else's.
      if ps -p "$pid" -o command= 2>/dev/null | grep -q "dev:staging"; then
        kill_tree "$pid"
        echo "stopped $name"
      fi
      rm -f "$pidfile"
    fi
  done
}

if [[ "${1:-}" == "stop" ]]; then stop; exit 0; fi

AGENT_DIR="${AGENT_DIR:-$BACKEND_DIR/../../retrospect-agent}"
[[ -d "$AGENT_DIR" ]] || { echo "agent repo not found at $AGENT_DIR (set AGENT_DIR)"; exit 1; }
AGENT_DIR="$(cd "$AGENT_DIR" && pwd)"
BACKEND_ENV="$BACKEND_DIR/.env.staging"
AGENT_ENV="$AGENT_DIR/.env.staging"

# The value of NAME in an env file, as dotenv reads it: an optional leading
# "export ", and one layer of matching quotes removed.
value_of() {
  local v
  v="$(grep -E "^(export[[:space:]]+)?$2=" "$1" | tail -1 | cut -d= -f2-)"
  if [[ "$v" =~ ^\"(.*)\"$ || "$v" =~ ^\'(.*)\'$ ]]; then v="${BASH_REMATCH[1]}"; fi
  printf '%s' "$v"
}

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
[[ "$(value_of "$AGENT_ENV" DOTENV_CONFIG_OVERRIDE)" == "true" ]] \
  || { echo "$AGENT_ENV: DOTENV_CONFIG_OVERRIDE must be true (the file wins over the shell)"; exit 1; }
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
# Background npm itself (not a subshell around it), so the recorded pid is the
# `npm run dev:staging` process that stop checks for and kills.
start_service() {
  local name="$1" dir="$2"
  cd "$dir"
  nohup npm run dev:staging >"$LOG_DIR/$name.log" 2>&1 &
  echo $! >"$LOG_DIR/$name.pid"
  cd - >/dev/null
}
start_service agent "$AGENT_DIR"
start_service backend "$BACKEND_DIR"

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

failed() {
  echo "$1 did not become healthy; see $LOG_DIR/$2.log"
  echo "stop both with: npm run staging:up -- stop"
  exit 1
}
wait_for "agent   GET /health/ready" "http://localhost:3001/health/ready" || failed agent agent
wait_for "backend GET /health      " "http://localhost:3000/health" || failed backend backend
echo "logs: $LOG_DIR (stop with: npm run staging:up -- stop)"
