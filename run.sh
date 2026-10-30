#!/usr/bin/env bash
# Usage: ./run.sh          -> read-only suite (safe on prod)
#        ./run.sh write    -> write suite (inserts GPS + log rows)
#        ./run.sh all      -> both
# Error output detail comes from error_format in location.env (long|short); ERROR_FORMAT=short ./run.sh overrides it.
# cacert / insecure in location.env become --cacert / --insecure (for https with a local certificate).
# Extra args are passed to hurl, e.g. ./run.sh read --variable base_url=http://localhost/rm-location/webapp/index.php
set -euo pipefail
cd "$(dirname "$0")"

suite="${1:-read}"
[ $# -gt 0 ] && shift

case "$suite" in
  read)  files=(location-api.hurl) ;;
  write) files=(location-api-write.hurl) ;;
  all)   files=(location-api.hurl location-api-write.hurl) ;;
  *)     echo "unknown suite: $suite (read|write|all)" >&2; exit 2 ;;
esac

if [ ! -f location.env ]; then
  echo "location.env not found: cp location.env.example location.env, then fill in api_key and the IDs" >&2
  exit 2
fi

env_setting() { sed -n "s/^$1=\(.*\)$/\1/p" location.env | tail -n1; }

env_error_format=$(env_setting error_format)
error_format="${ERROR_FORMAT:-${env_error_format:-long}}"

# TLS for https base_url with a locally generated certificate
tls_args=()
cacert=$(env_setting cacert)
[ -n "$cacert" ] && tls_args+=(--cacert "$cacert")
[ "$(env_setting insecure)" = true ] && tls_args+=(--insecure)

now=$(date +%s)
hurl --test \
  --error-format "$error_format" \
  --variables-file location.env \
  --variable now_epoch="$now" \
  --variable since_epoch="$((now - 30 * 60))" \
  --variable today="$(TZ=Asia/Kolkata date +%F)" \
  ${tls_args[@]+"${tls_args[@]}"} \
  "$@" "${files[@]}"
