#!/usr/bin/env bash
# Usage: ./set-weights.sh <stable-weight> <canary-weight>
#   ./set-weights.sh 80 20   baseline canary
#   ./set-weights.sh 50 50   widen the canary
#   ./set-weights.sh 0 100   promote the canary
#   ./set-weights.sh 100 0   roll back
set -euo pipefail
S="${1:?stable weight}"; C="${2:?canary weight}"
if [ $((S + C)) -ne 100 ]; then echo "Weights must add up to 100" >&2; exit 1; fi

cat <<YAML | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: demo-app
  namespace: canary-demo
spec:
  hosts: ["*"]
  gateways: ["demo-gateway"]
  http:
    - route:
        - destination: { host: demo-app, subset: v1 }
          weight: ${S}
        - destination: { host: demo-app, subset: v2 }
          weight: ${C}
YAML
echo "Traffic is now ${S}% v1 (stable) / ${C}% v2 (canary)"
