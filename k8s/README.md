# Kubernetes manifests

| Directory | Resources | Traffic control |
| --- | --- | --- |
| `namespace.yaml` | `aceest` namespace | — |
| `rolling-update/` | Deployment + Service | `maxSurge: 1`, `maxUnavailable: 0` |
| `blue-green/` | blue/green Deployments + Service | Service selector `track` |
| `canary/` | stable/canary Deployments + Service | Replica ratio 3:1 |
| `shadow/` | stable/shadow Deployments, Service, Istio rules | Istio `mirror` |
| `ab-testing/` | stable/canary Deployments, two Services, two Ingresses | NGINX canary header/weight |

Apply a strategy with `kubectl apply -f k8s/<strategy>`, or use
`scripts/deploy.sh <strategy> <image-ref>`, which also patches the image,
waits for rollout, promotes the candidate and runs the smoke test.

Every Deployment uses:

- `imagePullPolicy: IfNotPresent` so Minikube-loaded images work without a registry.
- Readiness and liveness probes on `/api/health`.
- `terminationGracePeriodSeconds: 40` and a `preStop` sleep for graceful drain.
- CPU/memory requests and limits.
- A writable `emptyDir` at `/data` for the demo SQLite database. For production,
  replace it with a shared database/PVC because each pod currently has its own
  demo datastore.

Prerequisites for the advanced strategies:

- A/B: NGINX Ingress controller (`minikube addons enable ingress`).
- Shadow: Istio with sidecar injection enabled on the `aceest` namespace.
