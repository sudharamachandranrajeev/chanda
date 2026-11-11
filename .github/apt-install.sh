#!/usr/bin/env bash
# Installs Ubuntu packages on a CI runner, failing fast instead of hanging.
#
#   bash .github/apt-install.sh clang cmake ...
#
# A mirror that does not answer (or a name that does not resolve) used to
# leave `apt-get update` with stale indexes and `apt-get install` waiting
# until the step's timeout. Now update counts any failed index as an error and
# is tried three times, and each command has its own time limit.
set -euo pipefail

opts=(-o Acquire::Retries=3 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 -o DPkg::Lock::Timeout=60)
sudo=()
[[ $(id -u) == 0 ]] || sudo=(sudo)

for try in 1 2 3; do
  if timeout 240 "${sudo[@]}" apt-get "${opts[@]}" --error-on=any update -qq; then
    break
  fi
  if [[ $try == 3 ]]; then
    echo "::error::apt-get update failed three times (mirror or DNS trouble on the runner)"
    exit 1
  fi
  echo "apt-get update failed; trying again in 20 s"
  sleep 20
done

timeout 600 "${sudo[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "${opts[@]}" install -y -qq "$@" >/dev/null
