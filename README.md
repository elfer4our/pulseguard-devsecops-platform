# PulseGuard: Cloud-Native DevSecOps & SRE Platform
![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub_Actions_%7C_Jenkins-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Production_Hardened-326ce5)
![Security](https://img.shields.io/badge/Security-Trivy_%7C_Gitleaks_%7C_NonRoot-success)
![Observability](https://img.shields.io/badge/Observability-Prometheus_Golden_Signals-orange)
## 1. Executive Summary
**PulseGuard** is an end-to-end production blueprint demonstrating modern **DevSecOps, Container Orchestration, Infrastr
---
## 2. System Architecture & DevSecOps Flow
```text
[Developer Push]
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ CI/CD & DevSecOps Pipeline (Jenkins Groovy / GitHub Actions) │
│ 1. Secret Scan (Gitleaks) & SAST │
│ 2. Unit Tests (Pytest) & Dependency Audit (pip-audit) │
│ 3. Multi-Stage Docker Build (Tagged with immutable Git SHA) │
│ 4. Container Vulnerability Gate (Trivy CRITICAL/HIGH block) │
└─────────────────────────────────────────────────────────────────┘
 │
 ▼
┌─────────────────────────────────────────────────────────────────┐
│ Kubernetes Production Namespace (pulseguard-prod) │
│ │
│ [Service: ClusterIP] ──► [PulseGuard API Pods (x3 Replicas)] │
│ │ ▲ (Read-Only Root FS, │
│ NetworkPolicy (TCP 6379) │ │ UID 10001, HPA, PDB) │
│ ▼ │ │
│ [Redis Cache Pod] │
│ │
│ [Prometheus Scraper] ──► Scrapes /metrics (P99 & Error Rate) │
└─────────────────────────────────────────────────────────────────┘
