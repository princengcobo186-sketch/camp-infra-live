#!/usr/bin/env bash
# Create the local Kind cluster if it does not exist. Safe to run repeatedly.
#
#   scripts/kind-up.sh          create (no-op if present)
#   scripts/kind-up.sh --down   delete it
set -euo pipefail

name="camp"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${1:-}" = "--down" ]; then
  kind delete cluster --name "${name}"
  exit 0
fi

if kind get clusters 2> /dev/null | grep -qx "${name}"; then
  echo "Kind cluster '${name}' already exists."
else
  kind create cluster --config "${here}/kind/cluster.yaml" --wait 120s
fi

# Fail loudly if kubectl would talk to some other cluster (a real one, by mistake).
kubectl --context "kind-${name}" cluster-info > /dev/null
echo "Ready: kubectl --context kind-${name}"
