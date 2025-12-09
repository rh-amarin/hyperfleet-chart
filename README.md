# HyperFleet Umbrella Chart

Official Helm chart for deploying the complete HyperFleet platform - API, Adapter, and Sentinel components.

## Overview

This umbrella chart deploys all HyperFleet components with a single command:

- **hyperfleet-api** - Cluster lifecycle management REST API with PostgreSQL
- **hyperfleet-adapter** - Event-driven adapter for cluster provisioning
- **sentinel** - Resource polling and event publishing service
- **rabbitmq** - Message broker for event-driven communication (dev)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Access to component container images (quay.io/openshift-hyperfleet or personal registry)

## Quick Start

### Development Deployment

```bash
# Clone all repos to the same parent directory
git clone git@github.com:openshift-hyperfleet/hyperfleet-chart.git
git clone git@github.com:openshift-hyperfleet/hyperfleet-api.git
git clone git@github.com:openshift-hyperfleet/hyperfleet-adapter.git
git clone git@github.com:openshift-hyperfleet/hyperfleet-sentinel.git

# Update dependencies (pulls from local paths)
cd hyperfleet-chart
helm dependency update

# Deploy to cluster
helm install hyperfleet . \
  --namespace hyperfleet-system \
  --create-namespace
```

### Using Custom Dev Images

```bash
# Copy and customize dev values
cp values-dev.yaml.example values-dev.yaml
# Edit values-dev.yaml with your quay username and image tags

# Deploy with dev values
helm install hyperfleet . \
  -f values-dev.yaml \
  --namespace hyperfleet-system \
  --create-namespace
```

### Using Google Pub/Sub (GKE)

For GKE deployments with Google Pub/Sub instead of RabbitMQ:

```bash
# Copy and customize Pub/Sub values
cp values-pubsub.yaml.example values-pubsub.yaml
# Edit values-pubsub.yaml with your GCP project ID and service accounts

# Deploy with Pub/Sub
helm install hyperfleet . \
  -f values-pubsub.yaml \
  --namespace hyperfleet-system \
  --create-namespace
```

Prerequisites for Pub/Sub:
- GKE cluster with Workload Identity enabled
- GCP service accounts with Pub/Sub IAM roles
- Workload Identity bindings between KSA and GSA

See [values-pubsub.yaml.example](values-pubsub.yaml.example) for detailed configuration.

Or set values directly:

```bash
helm install hyperfleet . \
  --namespace hyperfleet-system \
  --create-namespace \
  --set global.imageRegistry=quay.io/yourusername \
  --set global.imageTag=dev-abc1234
```

## Configuration

### Global Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Override image registry for all components | `""` |
| `global.imageTag` | Override image tag for all components | `""` |
| `global.broker.type` | Broker type: `rabbitmq` or `googlepubsub` | `rabbitmq` |
| `global.broker.googlepubsub.projectId` | GCP project ID for Pub/Sub | `""` |
| `global.broker.googlepubsub.createTopicIfMissing` | Auto-create topics (dev only) | `true` |
| `global.broker.googlepubsub.createSubscriptionIfMissing` | Auto-create subscriptions (dev only) | `true` |

### Component Enable/Disable

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hyperfleet-api.enabled` | Deploy HyperFleet API | `true` |
| `hyperfleet-adapter.enabled` | Deploy HyperFleet Adapter (requires custom AdapterConfig) | `false` |
| `sentinel.enabled` | Deploy HyperFleet Sentinel | `true` |
| `rabbitmq.enabled` | Deploy RabbitMQ broker (dev) | `true` |

**Note**: The adapter is disabled by default because it requires a custom `AdapterConfig` (adapter.yaml) specific to your cloud provider and deployment scenario. See [hyperfleet-adapter config template](../hyperfleet-adapter/configs/adapter-config-template.yaml) for examples.

### Subchart Values

Each component's values can be customized using the subchart name prefix:

```yaml
# API configuration
hyperfleet-api:
  replicaCount: 2
  database:
    postgresql:
      enabled: true

# Adapter configuration
hyperfleet-adapter:
  replicaCount: 1

# Sentinel configuration
sentinel:
  replicaCount: 1
```

See individual subchart documentation for all available values:
- [hyperfleet-api values](../hyperfleet-api/charts/values.yaml)
- [hyperfleet-adapter values](../hyperfleet-adapter/charts/values.yaml)
- [sentinel values](../hyperfleet-sentinel/deployments/helm/sentinel/values.yaml)

## Chart Dependencies

This chart uses local file references for HyperFleet components:

```yaml
dependencies:
  - name: hyperfleet-api
    repository: "file://../hyperfleet-api/charts"
  - name: hyperfleet-adapter
    repository: "file://../hyperfleet-adapter/charts"
  - name: sentinel
    repository: "file://../hyperfleet-sentinel/deployments/helm/sentinel"
```

RabbitMQ is deployed as a simple template (using `rabbitmq:3-management` image) for development.

**Important**: All component repositories must be cloned to the same parent directory.

## Usage Examples

### Deploy with External Database (Production)

```bash
# Create database secret
kubectl create secret generic hyperfleet-db-external \
  --namespace hyperfleet-system \
  --from-literal=db.host=your-cloudsql-ip \
  --from-literal=db.port=5432 \
  --from-literal=db.name=hyperfleet \
  --from-literal=db.user=hyperfleet \
  --from-literal=db.password=your-password

# Deploy with external database
helm install hyperfleet . \
  --namespace hyperfleet-system \
  --set hyperfleet-api.database.postgresql.enabled=false \
  --set hyperfleet-api.database.external.enabled=true \
  --set hyperfleet-api.database.external.secretName=hyperfleet-db-external
```

### Deploy Only Specific Components

```bash
# Deploy only API (no Adapter, Sentinel, or RabbitMQ)
helm install hyperfleet . \
  --namespace hyperfleet-system \
  --set hyperfleet-adapter.enabled=false \
  --set sentinel.enabled=false \
  --set rabbitmq.enabled=false
```

### Production Deployment (External Broker)

For production, disable the built-in RabbitMQ and configure external broker (Google Pub/Sub):

```bash
helm install hyperfleet . \
  --namespace hyperfleet-system \
  --set rabbitmq.enabled=false \
  --set sentinel.broker.type=googlepubsub \
  --set sentinel.broker.googlepubsub.projectId=my-gcp-project \
  --set hyperfleet-adapter.broker.type=googlepubsub \
  --set hyperfleet-adapter.broker.env.BROKER_GOOGLEPUBSUB_PROJECT_ID=my-gcp-project
```

### Upgrade Deployment

```bash
helm upgrade hyperfleet . --namespace hyperfleet-system
```

### Uninstall

```bash
helm uninstall hyperfleet --namespace hyperfleet-system
```

## Troubleshooting

### Check Deployed Resources

```bash
kubectl get all -n hyperfleet-system
```

### View Logs

```bash
# API logs
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=hyperfleet-api

# Adapter logs
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=hyperfleet-adapter

# Sentinel logs
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=sentinel

# RabbitMQ logs
kubectl logs -n hyperfleet-system -l app.kubernetes.io/name=rabbitmq
```

### Access RabbitMQ Management UI

```bash
kubectl port-forward -n hyperfleet-system svc/hyperfleet-rabbitmq 15672:15672
# Open http://localhost:15672 (credentials: hyperfleet / hyperfleet-dev-password)
```

### Dependency Update Fails

Ensure all component repos are cloned to the same parent directory:

```
parent-dir/
├── hyperfleet-chart/     # This repo
├── hyperfleet-api/
├── hyperfleet-adapter/
└── hyperfleet-sentinel/
```

## License

Apache License 2.0
