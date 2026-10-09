# DoS / Firewall Edge Boundary

## Context

The repository already has health and controller boundary documentation, but it did not yet state
the intended AWS edge split for DoS and firewall controls.

## Observed

- Public HTTP abuse controls are best documented as CloudFront + AWS WAF concerns.
- ALB origin gating needs to be recorded separately from Rails request handling.
- Rails semantic rate limiting should stay business-aware and shared across ECS tasks.

## Why It Matters

Without an explicit boundary, future changes could drift toward task-local firewalling, Nginx-based
defense, or IP-only rate-limit design in Rails.

## Promotion Candidate

Promote this into ADR / docs when implementation work starts on the AWS edge stack so the boundary
stays visible during IaC changes.
