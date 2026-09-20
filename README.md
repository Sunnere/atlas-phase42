# ATLAS Phase 4.2 Backend

Self-optimizing thresholds and temporal pattern recognition system deployed on Railway.

## Overview

ATLAS Phase 4.2 implements intelligent threshold optimization and temporal pattern analysis for real-time anomaly detection and decision-making.

## Features

- **Self-Optimizing Thresholds**: Dynamically adjusts detection thresholds based on confusion matrix feedback
- **Temporal Pattern Recognition**: Identifies recurring patterns across time cycles
- **Real-Time Orchestration**: Coordinates multi-agent decision cycles
- **CORS-Enabled API**: Full cross-origin support for dashboard artifacts

## Deployment

Deployed on Railway with automatic GitHub sync. Push to `master` branch triggers new builds.

### Environment

- Node.js 24.x
- Express.js 4.18.2
- Platform: Railway (nixpacks builder)

### Running Locally

```bash
npm install
node 16_railway-backend-phase42.js
```

Server runs on port 3000 (or `PORT` environment variable).

## API Endpoints

- `GET /` — Hello message
- `GET /health` — Health check
- `GET /api/status` — System status
- `POST /api/orchestrate` — Start decision cycle
- `GET /api/cycles` — Cycle history
- `GET /api/patterns` — Pattern history
- `GET /api/thresholds` — Current thresholds
- `POST /api/thresholds/:agentId/record` — Record confusion matrix feedback
- `POST /api/patterns/event` — Log pattern event
- `POST /api/patterns/analyze` — Analyze patterns

## CORS

All API endpoints support CORS for dashboard integration. Headers:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`
- `Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept`

## Phase 4.3

Phase 4.3 analytics dashboard integrates with this backend to fetch live data and visualize ATLAS decision cycles in real time.
