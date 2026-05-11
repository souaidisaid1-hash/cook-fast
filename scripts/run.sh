#!/usr/bin/env bash
# Run or build CookFast with API keys injected via --dart-define.
# Usage:
#   ./scripts/run.sh                        → flutter run (debug, picks device)
#   ./scripts/run.sh -d RZGYB0SK64X         → specific device
#   ./scripts/run.sh --release              → release mode
#   ./scripts/run.sh build apk --release    → build APK
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.example and fill in your keys." >&2
  exit 1
fi

# Load .env into current shell (skip blank lines and comments)
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  export "$key"="${value}"
done < "$ENV_FILE"

DEFINES=(
  "--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY:-}"
  "--dart-define=SUPABASE_URL=${SUPABASE_URL:-}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}"
  "--dart-define=SENTRY_DSN=${SENTRY_DSN:-}"
)

cd "$ROOT"
flutter run "${DEFINES[@]}" "$@"
