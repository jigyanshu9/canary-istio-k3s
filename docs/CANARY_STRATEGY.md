# Canary deployment strategy

## What a canary deployment is

A new version (the canary) receives a small share of real traffic while the stable version keeps serving the rest. If the canary behaves well, its share grows until it takes over. If it misbehaves, traffic goes back to stable and only a small share of users were affected.

## How it is built here

| Piece | Role |
|---|---|
| `app-stable` Helm release | Version `v1`, 2 replicas |
| `app-canary` Helm release | Version `v2`, 2 replicas |
| One Kubernetes Service `demo-app` | Selects both versions |
| Istio `DestinationRule` | Defines subsets `v1` and `v2` by the `version` label |
| Istio `VirtualService` | Sets the traffic weights |
| `scripts/set-weights.sh` | Changes the weights |
| `scripts/load-test.sh` | Counts responses per version and status code |

The weights are set by Istio, not by replica counts. That is the point of using a service mesh: the canary can take exactly 20% of traffic with only two pods, and the share does not change if a pod restarts.

## Rollout stages

| Stage | Stable | Canary | Purpose |
|---|---|---|---|
| 1. Baseline | 80% | 20% | Real traffic, small blast radius |
| 2. Widen | 50% | 50% | More confidence under higher load |
| 3. Promote | 0% | 100% | Canary becomes the live version |

Move to the next stage only when the canary meets the criteria below. Pause a few seconds after every weight change before measuring, because Istio takes a moment to push the new rule to the gateway.

## Promotion criteria (move forward)

- No `5xx` responses from the canary over a test run of at least 100 requests at the current stage.
- Response times in line with stable (no unexplained slowdown).
- Canary pods `Running` with all containers ready and no restarts.

## Rollback triggers (go back)

- Any sustained `5xx` from the canary (more than a handful of errors in a test run).
- Clearly higher latency than stable.
- Canary pods crash-looping or failing readiness checks.

## Rollback procedure

1. **Protect users first.** Send all traffic to stable: `./scripts/set-weights.sh 100 0`.
2. Confirm with `./scripts/load-test.sh http://localhost/ 100`. Expect `100 v1 200`.
3. Then fix or revert the canary at leisure: `helm rollback app-canary <revision> -n canary-demo`.

Shifting traffic before touching the deployment means users are safe within seconds, and nothing has to be redeployed under pressure.

## Results from this project

| Stage | Result (100 requests) |
|---|---|
| Baseline 80/20, healthy canary | 78 `v1 200`, 22 `v2 200` |
| Bad canary at 80/20 (50% errors, 300 ms delay) | 79 `v1 200`, 9 `v2 200`, 12 `v2 500` |
| After moving all traffic to stable | 100 `v1 200` |
| Healthy canary back at 80/20 | 79 `v1 200`, 21 `v2 200` |
| 50/50 | 56 `v1 200`, 44 `v2 200` |
| Promote to 100% canary | First run: 4 `v1 200`, 96 `v2 200`. Re-run: 100 `v2 200` |

What these show:

- **The split follows the weights.** Each request is routed independently, so a sample of 100 lands near the target, not exactly on it (22 against 20, 44 against 50).
- **A bad canary is visible immediately and contained.** All 12 errors came from the canary's 21 requests. Stable served all 79 of its requests without error, and the failures reached only about one request in eight overall.
- **Rollback is fast.** One command returned every request to stable, with no failures in the next run.
- **Weight changes are not instant.** In the promotion test, the first 4 requests still went to stable. A second run a few seconds later showed 100% on the canary. Measure after a short pause.

## Limitations of this setup

- **Both versions run the same image.** The canary's "bad" behaviour is simulated with environment variables (`ERROR_RATE`, `DELAY_MS`), not a real code change.
- **Routing is per request, not per user.** The same visitor can see v1 on one request and v2 on the next. Production canaries often pin a user to one version with a header or cookie rule.
- **Decisions are made by hand.** Here a person reads the load test output. Tools such as Argo Rollouts or Flagger can read Prometheus metrics and promote or roll back automatically.
- **Small samples.** 100 requests is enough to see a 50% error rate, but not enough to catch a 1% problem. Real rollouts need more traffic or a longer observation window.
- **Single node, one instance.** There is no high availability, and the public IP changes whenever the instance is stopped and started.
