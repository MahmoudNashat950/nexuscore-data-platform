# NexusCore — Smart Building Automation Platform

NexusCore is a smart building automation platform designed to monitor
devices, collect real-time telemetry, support automation, and enable
data-driven insights.

## Project Scope

This repository focuses on the Data Engineering and AI components
of the NexusCore graduation project.

The initial proof of concept uses simulated devices to generate
realistic smart-building telemetry.

## Architecture

- Python — Device simulation and data ingestion
- MQTT / Mosquitto — Device messaging
- PostgreSQL + TimescaleDB — Telemetry storage
- FastAPI — Backend APIs
- React + Vite — Monitoring dashboard
- Docker Compose — Local infrastructure

## Current Progress

- [x] Docker and WSL2 environment
- [x] MQTT broker setup
- [x] PostgreSQL + TimescaleDB setup
- [ ] Database schema
- [ ] Device simulator
- [ ] Telemetry ingestion
- [ ] Backend APIs
- [ ] Live dashboard
- [ ] Testing and monitoring

## Getting Started

Create your local environment file:

```bash
cp .env.example .env