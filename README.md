# HyperFleet Helm Charts

Official Helm charts for deploying the HyperFleet platform.

## Chart Structure

This repository uses a **base + overlay** pattern for multi-cloud support:

```text
hyperfleet-chart/
  charts/
    hyperfleet-base/     # Core platform (API, Sentinel, Landing Zone)
    hyperfleet-gcp/      # GCP overlay (validation-gcp, Pub/Sub defaults)
  examples/
    gcp-rabbitmq/        # GCP + RabbitMQ for development
    gcp-pubsub/          # GCP + Pub/Sub for production (single topic)
    gcp-pubsub-multi-topic/  # GCP + Pub/Sub with clusters + nodepools topics
```

### hyperfleet-base

Core platform components that work on any cloud:
- **hyperfleet-api** - Cluster lifecycle management REST API
- **sentinel** - Resource polling and event publishing (clusters)
- **sentinel-nodepools** - Optional second sentinel for nodepools (multi-topic)
- **adapter-landing-zone** - Adapter that creates cluster namespaces
- **rabbitmq** - Optional in-cluster broker for development

### hyperfleet-gcp

GCP-specific overlay that adds:
- **validation-gcp** - GCP cluster validation adapter (clusters topic)
- **validation-gcp-nodepools** - Optional second validation adapter (nodepools topic)
- Google Pub/Sub as default broker
- Workload Identity configuration

## Architecture

### Single Topic (Default)

All resources flow through one topic:

```text
sentinel (clusters) → clusters-topic → landing-zone-adapter
                                    → validation-gcp-adapter
```

### Multi-Topic (Optional)

Separate topics for clusters and nodepools:

```text
sentinel (clusters)  → clusters-topic  → landing-zone-adapter
                                       → validation-gcp-adapter (clusters)

sentinel (nodepools) → nodepools-topic → validation-gcp-adapter (nodepools)
```

Enable multi-topic by setting:
- `base.sentinel-nodepools.enabled: true`
- `validation-gcp-nodepools.enabled: true`

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
helm install hyperfleet . -f values-rabbitmq.yaml \
  -n hyperfleet-system --create-namespace
```

### GCP Production (Pub/Sub - Single Topic)

```bash
cd charts/hyperfleet-gcp
helm dependency update
helm install hyperfleet . \
  -f ../../examples/gcp-pubsub/values.yaml \
  --set base.global.broker.googlepubsub.projectId=YOUR_PROJECT \
  -n hyperfleet-system --create-namespace
```

### GCP Production (Pub/Sub - Multi-Topic)

For deployments with separate clusters and nodepools topics:

```bash
cd charts/hyperfleet-gcp
helm dependency update
helm install hyperfleet . \
  -f ../../examples/gcp-pubsub-multi-topic/values.yaml \
  -n hyperfleet-system --create-namespace
```

See [examples/gcp-pubsub-multi-topic/values.yaml](examples/gcp-pubsub-multi-topic/values.yaml) for the full configuration template.

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
cp examples/gcp-rabbitmq/values.yaml my-values.yaml
# Edit with your quay username and image tags

helm install hyperfleet charts/hyperfleet-gcp -f my-values.yaml \
  -n hyperfleet-system --create-namespace
```

## Configuration

### Multi-Topic Deployment

To deploy with separate topics for clusters and nodepools:

```yaml
base:
  # Sentinel for clusters (default)
  sentinel:
    enabled: true
    broker:
      type: googlepubsub
      topic: "hyperfleet-clusters"
      googlepubsub:
        projectId: "your-project"

  # Sentinel for nodepools (optional)
  sentinel-nodepools:
    enabled: true  # Enable for multi-topic
    broker:
      type: googlepubsub
      topic: "hyperfleet-nodepools"
      googlepubsub:
        projectId: "your-project"

# Validation adapter for clusters (default)
validation-gcp:
  enabled: true
  broker:
    type: googlepubsub
    googlepubsub:
      topic: "hyperfleet-clusters"
      subscription: "hyperfleet-clusters-validation-gcp"

# Validation adapter for nodepools (optional)
validation-gcp-nodepools:
  enabled: true  # Enable for multi-topic
  broker:
    type: googlepubsub
    googlepubsub:
      topic: "hyperfleet-nodepools"
      subscription: "hyperfleet-nodepools-validation-gcp"
```

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
      type: rabbitmq           # Which broker type components should use
  rabbitmq:
    enabled: true              # Deploy in-cluster RabbitMQ instance
```

**Note:** There are two separate `rabbitmq` configurations:
- `global.broker.type: rabbitmq` - Tells components (sentinel, adapters) to use RabbitMQ
- `rabbitmq.enabled: true` - Deploys an in-cluster RabbitMQ server

For production with external RabbitMQ, set `global.broker.type: rabbitmq` but keep `rabbitmq.enabled: false` and configure the URL in each component's `broker.rabbitmq.url`.

### Workload Identity (GCP)

For Pub/Sub access, configure Workload Identity for each component:

```yaml
base:
  # Sentinel (clusters)
  sentinel:
    serviceAccount:
      annotations:
        iam.gke.io/gcp-service-account: sentinel@PROJECT.iam.gserviceaccount.com

  # Sentinel (nodepools) - uses same GCP SA
  sentinel-nodepools:
    serviceAccount:
      annotations:
        iam.gke.io/gcp-service-account: sentinel@PROJECT.iam.gserviceaccount.com

  adapter-landing-zone:
    serviceAccount:
      annotations:
        iam.gke.io/gcp-service-account: landing-zone@PROJECT.iam.gserviceaccount.com

# Validation adapter (clusters)
validation-gcp:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: validation-gcp@PROJECT.iam.gserviceaccount.com

# Validation adapter (nodepools) - uses same GCP SA
validation-gcp-nodepools:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: validation-gcp@PROJECT.iam.gserviceaccount.com
```

**Important:** When using multi-topic deployment, you need to add Workload Identity bindings for the additional Kubernetes ServiceAccounts:

```bash
# Sentinel nodepools KSA -> Sentinel GSA
gcloud iam service-accounts add-iam-policy-binding \
  sentinel@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[hyperfleet-system/sentinel-nodepools]"

# Validation nodepools KSA -> Validation GSA
gcloud iam service-accounts add-iam-policy-binding \
  validation-gcp@PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT.svc.id.goog[hyperfleet-system/validation-gcp-nodepools-adapter]"
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
  - name: sentinel
    alias: sentinel-nodepools  # Second sentinel for nodepools
    condition: sentinel-nodepools.enabled
  - name: adapter-landing-zone
    repository: "git+https://github.com/openshift-hyperfleet/adapter-landing-zone@charts?ref=main"

# hyperfleet-gcp
dependencies:
  - name: hyperfleet-base
    repository: "file://../hyperfleet-base"
  - name: validation-gcp
    repository: "git+https://github.com/openshift-hyperfleet/adapter-validation-gcp@charts?ref=main"
  - name: validation-gcp
    alias: validation-gcp-nodepools  # Second adapter for nodepools
    condition: validation-gcp-nodepools.enabled
```

## Examples

See [examples/](examples/) for ready-to-use values files:

- [examples/gcp-rabbitmq/values.yaml](examples/gcp-rabbitmq/values.yaml) - GCP with RabbitMQ (development)
- [examples/gcp-pubsub/values.yaml](examples/gcp-pubsub/values.yaml) - GCP with Pub/Sub (production, single topic)
- [examples/gcp-pubsub-multi-topic/values.yaml](examples/gcp-pubsub-multi-topic/values.yaml) - GCP with Pub/Sub (production, multi-topic)

## Troubleshooting

### Check Status

```bash
kubectl get pods -n hyperfleet-system
```

### View Logs

```bash
# Core components
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=hyperfleet-api
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=sentinel
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=adapter-landing-zone
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=validation-gcp

# Multi-topic components (if enabled)
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=sentinel-nodepools
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=validation-gcp-nodepools
```

### RabbitMQ Management UI

```bash
kubectl port-forward -n hyperfleet-system svc/hyperfleet-rabbitmq 15672:15672
# Open http://localhost:15672 (hyperfleet / hyperfleet-dev-password)
```

### Workload Identity Issues

If pods fail with "Permission denied" or "Unable to generate access token":

1. Verify the KSA annotation matches the GSA email
2. Ensure the Workload Identity binding exists:
   ```bash
   gcloud iam service-accounts get-iam-policy GSA@PROJECT.iam.gserviceaccount.com
   ```
3. For multi-topic deployments, ensure bindings exist for both:
   - `sentinel` and `sentinel-nodepools` KSAs
   - `validation-gcp-adapter` and `validation-gcp-nodepools-adapter` KSAs

## Migration from Legacy Chart

The root-level Chart.yaml is deprecated. Migrate to cloud-specific overlays:

```bash
# Old (deprecated)
helm install hyperfleet . -f values.yaml

# New (recommended)
helm install hyperfleet charts/hyperfleet-gcp -f examples/gcp-pubsub/values.yaml
```

## Future Cloud Support

Additional cloud overlays can be added following the same pattern:
- `hyperfleet-aws` - AWS with SNS/SQS, IRSA
- `hyperfleet-azure` - Azure with Service Bus, Workload Identity

## License

Apache License 2.0
