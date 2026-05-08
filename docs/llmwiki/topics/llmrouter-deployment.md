# LLMRouter Deployment

## Overview

OpenClaw Router (LLMRouter) is deployed in the shared Kind cluster under namespace `ai`. It provides an OpenAI-compatible API with intelligent LLM routing (random, round-robin, cost-optimized, load-balanced).

**Repo**: `https://github.com/microscaler/LLMRouter` (cloned to `microscaler/LLMRouter/`)
**Namespace**: `ai`
**Image**: `llmrouter:latest` (loaded via `kind load docker-image`)

## Architecture

```
Client → /v1/chat/completions → llmrouter.ai.svc.cluster.local:8000 → [LLM endpoints]
              ↓
         /v1/models (list available models)
         /health (liveness/readiness)
```

## Key Components

### ConfigMap

Mounted at `/etc/llmrouter/config.yaml`. Contains:
- `router.strategy`: routing strategy (`random`, `round-robin`, `cost`, `load`)
- `llms`: LLM endpoint definitions with `name`, `provider`, `endpoint`, `api_key`, `description`
- `media.enabled`: multimodal support toggle

### Deployment

- 1 replica (can scale up)
- Port: 8000
- Resource limits: 2Gi memory, 1 CPU
- Health check: `curl -f http://localhost:8000/health`

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/v1/models` | List models |
| POST | `/v1/chat/completions` | Chat completions (OpenAI-compatible) |

## Configuration

See `LLMRouter/openclaw_router/config.py` for the full config schema.

## TODO

- Add real LLM endpoints to ConfigMap
- Add Kubernetes Service and/or Ingress for external access
- Add HPA (Horizontal Pod Autoscaler)
- Add monitoring dashboards for routing metrics
