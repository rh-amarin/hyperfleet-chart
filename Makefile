# Makefile for HyperFleet Helm Charts
#
# This repo uses a base + overlay pattern for multi-cloud support.
# See README.md for full documentation.
#
# Prerequisites:
#   helm plugin install https://github.com/aslafy-z/helm-git
#
# Usage:
#   make help              - Show this help
#   make deps              - Update chart dependencies
#   make lint              - Lint helm charts
#   make template          - Render helm templates
#   make test              - Run all tests

.PHONY: help deps lint template test clean \
        deps-base deps-gcp \
        lint-base lint-gcp \
        template-base template-gcp template-gcp-dev \
        check-helm-git

# Default values
RELEASE_NAME ?= hyperfleet
NAMESPACE ?= hyperfleet-system
CHART_DIR ?= charts/hyperfleet-gcp

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Dependencies

check-helm-git: ## Check if helm-git plugin is installed
	@if ! helm plugin list | grep -q "^helm-git"; then \
		echo "$(RED)ERROR: helm-git plugin not installed$(NC)"; \
		echo ""; \
		echo "Install it with:"; \
		echo "  helm plugin install https://github.com/aslafy-z/helm-git"; \
		echo ""; \
		exit 1; \
	fi
	@echo "$(GREEN)helm-git plugin is installed$(NC)"

deps: deps-base deps-gcp ## Update all chart dependencies

deps-base: check-helm-git ## Update hyperfleet-base dependencies
	@echo "$(GREEN)Updating hyperfleet-base dependencies...$(NC)"
	cd charts/hyperfleet-base && helm dependency update
	@echo "$(GREEN)hyperfleet-base dependencies updated$(NC)"

deps-gcp: deps-base ## Update hyperfleet-gcp dependencies (includes base)
	@echo "$(GREEN)Updating hyperfleet-gcp dependencies...$(NC)"
	cd charts/hyperfleet-gcp && helm dependency update
	@echo "$(GREEN)hyperfleet-gcp dependencies updated$(NC)"

##@ Linting

lint: lint-gcp ## Lint charts (GCP overlay includes base)

lint-gcp: ## Lint hyperfleet-gcp chart (includes base chart validation)
	@echo "$(GREEN)Linting hyperfleet-gcp (dev values)...$(NC)"
	helm lint charts/hyperfleet-gcp -f charts/hyperfleet-gcp/values-dev.yaml
	@echo "$(GREEN)Linting hyperfleet-gcp (prod values)...$(NC)"
	helm lint charts/hyperfleet-gcp -f examples/gcp-prod/values.yaml

##@ Template Rendering

template: template-gcp ## Render templates (default: GCP with Pub/Sub)

template-base: ## Render hyperfleet-base templates
	@echo "$(GREEN)Rendering hyperfleet-base templates...$(NC)"
	helm template $(RELEASE_NAME) charts/hyperfleet-base --namespace $(NAMESPACE)

template-gcp: ## Render hyperfleet-gcp templates (Pub/Sub)
	@echo "$(GREEN)Rendering hyperfleet-gcp templates (Pub/Sub)...$(NC)"
	helm template $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		-f examples/gcp-prod/values.yaml

template-gcp-dev: ## Render hyperfleet-gcp templates (RabbitMQ)
	@echo "$(GREEN)Rendering hyperfleet-gcp templates (RabbitMQ dev)...$(NC)"
	helm template $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		-f charts/hyperfleet-gcp/values-dev.yaml

##@ Testing

test: deps lint test-templates ## Run all tests
	@echo ""
	@echo "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(GREEN)✅ All tests passed!$(NC)"
	@echo "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"

test-templates: ## Validate all template configurations render without errors
	@echo "$(GREEN)Validating template configurations...$(NC)"
	@echo ""
	@echo "📋 Testing hyperfleet-base (RabbitMQ default)..."
	@helm template $(RELEASE_NAME) charts/hyperfleet-base --namespace $(NAMESPACE) > /dev/null
	@echo "$(GREEN)✅ hyperfleet-base OK$(NC)"
	@echo ""
	@echo "📋 Testing hyperfleet-gcp (Pub/Sub)..."
	@helm template $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		-f examples/gcp-prod/values.yaml > /dev/null
	@echo "$(GREEN)✅ hyperfleet-gcp (Pub/Sub) OK$(NC)"
	@echo ""
	@echo "📋 Testing hyperfleet-gcp (RabbitMQ dev)..."
	@helm template $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		-f charts/hyperfleet-gcp/values-dev.yaml > /dev/null
	@echo "$(GREEN)✅ hyperfleet-gcp (RabbitMQ) OK$(NC)"

##@ Deployment

install: deps-gcp ## Install hyperfleet-gcp to cluster
	@echo "$(GREEN)Installing hyperfleet-gcp...$(NC)"
	helm install $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		--create-namespace \
		-f charts/hyperfleet-gcp/values-dev.yaml
	@echo "$(GREEN)✅ HyperFleet installed$(NC)"

install-prod: deps-gcp ## Install hyperfleet-gcp with production values (requires customization)
	@echo "$(YELLOW)Installing hyperfleet-gcp (production)...$(NC)"
	@echo "$(YELLOW)⚠️  Make sure to customize examples/gcp-prod/values.yaml first!$(NC)"
	helm install $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		--create-namespace \
		-f examples/gcp-prod/values.yaml
	@echo "$(GREEN)✅ HyperFleet installed$(NC)"

upgrade: deps-gcp ## Upgrade hyperfleet-gcp
	@echo "$(GREEN)Upgrading hyperfleet-gcp...$(NC)"
	helm upgrade $(RELEASE_NAME) charts/hyperfleet-gcp \
		--namespace $(NAMESPACE) \
		-f charts/hyperfleet-gcp/values-dev.yaml
	@echo "$(GREEN)✅ HyperFleet upgraded$(NC)"

uninstall: ## Uninstall hyperfleet
	@echo "$(YELLOW)Uninstalling hyperfleet...$(NC)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)
	@echo "$(GREEN)✅ HyperFleet uninstalled$(NC)"

status: ## Show helm release status
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)

##@ Cleanup

clean: ## Remove generated files (dependency charts, lock files, packages)
	@echo "$(GREEN)Cleaning generated files...$(NC)"
	rm -rf charts/hyperfleet-base/charts/
	rm -rf charts/hyperfleet-gcp/charts/
	rm -f charts/hyperfleet-base/Chart.lock
	rm -f charts/hyperfleet-gcp/Chart.lock
	rm -f *.tgz
	rm -f charts/*/*.tgz
	@echo "$(GREEN)✅ Clean complete$(NC)"
