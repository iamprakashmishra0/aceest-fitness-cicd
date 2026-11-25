# Progressive Deployment Runbook

All commands assume the repository root as the working directory, a running
Minikube cluster, and an image available to the cluster:

```bash
minikube start --driver=docker
eval $(minikube docker-env)
scripts/build-image.sh 3.2.4 canary green
```

`deploy.sh` applies a strategy, updates every deployment in that strategy to
the supplied image and sets matching version metadata, promotes the candidate,
and waits for readiness. Apply the manifests directly and patch only the
candidate deployment if you want two different versions running side by side.

Use `NAMESPACE=aceest` (the default) or override it per command.

## Rolling update

`k8s/rolling-update/` contains one Deployment (3 replicas) and one Service.
`maxSurge: 1`, `maxUnavailable: 0`, readiness probes and a 10-second `preStop`
hook keep traffic available while pods are replaced one at a time.

```bash
scripts/deploy.sh rolling-update aceest-fitness:3.2.4
scripts/smoke-test.sh
scripts/rollback.sh rolling-update
```

Rollback uses `kubectl rollout undo`, which restores the previous ReplicaSet.

## Blue-green

`k8s/blue-green/` contains blue and green Deployments. The Service selector
initially points to `track: blue`. The new release is deployed to green, tested,
and only then promoted by switching the Service selector.

```bash
scripts/deploy.sh blue-green aceest-fitness:3.2.4 green
curl <service-url>/api/version
scripts/rollback.sh blue-green
```

Promotion and rollback are instantaneous selector changes; both versions stay
running, so reverting is a single `promote.sh blue-green blue` call.

## Canary release

`k8s/canary/` runs 3 stable and 1 canary pod behind a single Service. Replica
counts implement the traffic weight: 1/4 = 25% canary.

```bash
scripts/deploy.sh canary aceest-fitness:3.2.4 green
scripts/promote.sh canary 50
scripts/rollback.sh canary
```

`promote.sh` scales the canary and stable Deployments so the combined replica
count stays at four. Rollback scales the canary to zero and restores all
replicas to the stable deployment.

## Shadow deployment

`k8s/shadow/` deploys a shadow version that receives mirrored requests but no
user responses. Istio's `VirtualService` mirrors 100% of traffic from the
`stable` subset to the `shadow` subset.

```bash
istioctl install --set profile=demo -y
kubectl label namespace aceest istio-injection=enabled
scripts/deploy.sh shadow aceest-fitness:3.2.4 green
scripts/promote.sh shadow 100
scripts/rollback.sh shadow
```

Rollback deletes the mirror `VirtualService`, so shadow traffic stops
immediately while the stable Service is untouched.

## A/B testing

`k8s/ab-testing/` uses two Services and two NGINX Ingress resources. Requests
with header `X-Cohort: beta` always reach the canary; remaining traffic is
split by `canary-weight` (25% by default).

```bash
minikube addons enable ingress
scripts/deploy.sh ab-testing aceest-fitness:3.2.4 green
curl -H 'X-Cohort: beta' http://aceest.local/api/version
scripts/promote.sh ab-testing 50
scripts/rollback.sh ab-testing
```

Add `127.0.0.1 aceest.local` to `/etc/hosts` and use
`minikube tunnel` when using an Ingress on Minikube.

## Verification

`scripts/smoke-test.sh` finds a running pod, calls `/api/health`, and optionally
checks `EXPECTED_VERSION`:

```bash
EXPECTED_VERSION=3.2.4 scripts/smoke-test.sh
```
