# HyperFleet Helm Charts

Official Helm charts for deploying the HyperFleet platform.

## Chart Structure

This repository uses a **base + overlay** pattern for multi-cloud support:

```
hyperfleet-chart/
  charts/
    hyperfleet-base/     # Core platform (API, Sentinel, Landing Zone)
    hyperfleet-gcp/      # GCP overlay (validation-gcp, Pub/Sub defaults)
  examples/
    gcp-dev/             # GCP + RabbitMQ for development
    gcp-prod/            # GCP + Pub/Sub for production
```

### hyperfleet-base

Core platform components that work on any cloud:
- **hyperfleet-api** - Cluster lifecycle management REST API
- **sentinel** - Resource polling and event publishing
- **landing-zone** - Adapter that creates cluster namespaces
- **rabbitmq** - In-cluster broker for development

### hyperfleet-gcp

GCP-specific overlay that adds:
- **validation-gcp** - GCP cluster validation adapter
- Google Pub/Sub as default broker
- Workload Identity configuration

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [helm-git plugin](https://github.com/aslafy-z/helm-git)

```bash
helm plugin install https://github.com/aslafy-z/helm-git
```

## Quick Start

### GCP Development (RabbitMQ)

```bash
cd charts/hyperfleet-gcp
helm dependency update
helm install hyperfleet . -f values-dev.yaml \
  -n hyperfleet-system --create-namespace
```

### GCP Production (Pub/Sub)

```bash
cd charts/hyperfleet-gcp
helm dependency update
helm install hyperfleet . \
  -f ../../examples/gcp-prod/values.yaml \
  --set base.global.broker.googlepubsub.projectId=YOUR_PROJECT \
  -n hyperfleet-system --create-namespace
```

## Using Custom Images

Each component has `make image-dev` for building custom images:

```bash
# Build dev images
cd ../hyperfleet-api && QUAY_USER=myuser make image-dev
cd ../hyperfleet-sentinel && QUAY_USER=myuser make image-dev
cd ../adapter-landing-zone && QUAY_USER=myuser make image-dev
cd ../adapter-validation-gcp && QUAY_USER=myuser make image-dev
```

Deploy with custom images:

```bash
# Copy and customize example values
cp examples/gcp-dev/values.yaml my-values.yaml
# Edit with your quay username and image tags

helm install hyperfleet charts/hyperfleet-gcp -f my-values.yaml \
  -n hyperfleet-system --create-namespace
```

## Configuration

### Broker Options

The broker is independent of cloud provider:

| Deployment | Broker | Use Case |
|------------|--------|----------|
| GCP + RabbitMQ | In-cluster RabbitMQ | Development |
| GCP + Pub/Sub | Google Pub/Sub | Production |

Override broker in GCP overlay:

```yaml
# Use RabbitMQ for development
base:
  global:
    broker:
      type: rabbitmq
      rabbitmq:
        enabled: true
  rabbitmq:
    enabled: true
```

### Workload Identity (GCP)

For Pub/Sub access, configure Workload Identity:

```yaml
base:
  sentinel:
    serviceAccount:
      annotations:
        iam.gke.io/gcp-service-account: sentinel@PROJECT.iam.gserviceaccount.com

  landing-zone:
    serviceAccount:
      annotations:
        iam.gke.io/gcp-service-account: landing-zone@PROJECT.iam.gserviceaccount.com

validation-gcp:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: validation-gcp@PROJECT.iam.gserviceaccount.com
```

## Chart Dependencies

Charts pull dependencies from GitHub using helm-git:

```yaml
# hyperfleet-base
dependencies:
  - name: hyperfleet-api
    repository: "git+https://github.com/openshift-hyperfleet/hyperfleet-api@charts?ref=main"
  - name: sentinel
    repository: "git+https://github.com/openshift-hyperfleet/hyperfleet-sentinel@deployments/helm/sentinel?ref=main"
  - name: landing-zone
    repository: "git+https://github.com/openshift-hyperfleet/adapter-landing-zone@charts?ref=main"

# hyperfleet-gcp
dependencies:
  - name: hyperfleet-base
    repository: "file://../hyperfleet-base"
  - name: validation-gcp
    repository: "git+https://github.com/openshift-hyperfleet/adapter-validation-gcp@charts?ref=main"
```

## Examples

See [examples/](examples/) for ready-to-use values files:

- [examples/gcp-dev/values.yaml](examples/gcp-dev/values.yaml) - GCP development with RabbitMQ
- [examples/gcp-prod/values.yaml](examples/gcp-prod/values.yaml) - GCP production with Pub/Sub

## Troubleshooting

### Check Status

```bash
kubectl get pods -n hyperfleet-system
```

### View Logs

```bash
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=hyperfleet-api
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=sentinel
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=landing-zone
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=validation-gcp
```

### RabbitMQ Management UI

```bash
kubectl port-forward -n hyperfleet-system svc/hyperfleet-rabbitmq 15672:15672
# Open http://localhost:15672 (hyperfleet / hyperfleet-dev-password)
```

## Migration from Legacy Chart

The root-level Chart.yaml is deprecated. Migrate to cloud-specific overlays:

```bash
# Old (deprecated)
helm install hyperfleet . -f values.yaml

# New (recommended)
helm install hyperfleet charts/hyperfleet-gcp -f examples/gcp-prod/values.yaml
```

## Future Cloud Support

Additional cloud overlays can be added following the same pattern:
- `hyperfleet-aws` - AWS with SNS/SQS, IRSA
- `hyperfleet-azure` - Azure with Service Bus, Workload Identity

## License

Apache License 2.0
