# Copilot Instructions for ALZ Management Repo

## Project Overview

This is an **Azure Landing Zones (ALZ)** management repository using **Bicep** for Infrastructure as Code, deployed via **GitHub Actions** CI/CD. It was bootstrapped using the ALZ Accelerator PowerShell module (v7.1.1, bootstrap v7.2.0, starter v2.0.0).

## Architecture

- **IaC**: Bicep (NOT Terraform — Terraform was only used for the one-time bootstrap)
- **CI/CD**: GitHub Actions with OIDC federated credentials to Azure
- **Environments**: `alz-mgmt-plan` (CI) and `alz-mgmt-apply` (CD, requires manual approval)
- **Template Repo**: `Spaidoso/alz-mgmt-templates` contains shared workflow templates
- **Region**: Single region — `westus2` only
- **MG Hierarchy**: `alz` (root) → platform (connectivity, identity, management, security) + landingzones (corp, online) + sandbox + decommissioned

## Subscription Mapping

| Subscription | ID | Management Group |
|---|---|---|
| Spaidoso-MGMT | `e4fdb784-0635-495b-9d34-e57009b5eb57` | platform-management |
| Spaidoso-Connectivity | `82ce8884-3284-4808-b77e-8dd9b0175d4c` | platform-connectivity |
| Spaidoso-Identity | `d9c8ca00-f992-43e8-b77c-d9d12c4a32c0` | platform-identity |
| Spaidoso-LZ1-Corp | `7e8843fa-73d2-4343-814e-513f5e111bd2` | platform-security |
| Spaidoso-LZ-Online | `966a8e3c-bd80-41dd-8910-506aab21e18b` | landingzones-online |

## Networking Design

- **Hub VNet**: `10.0.0.0/22` in westus2
- **Azure Firewall Basic** (cost-optimized, ~$288/mo)
- **VPN Gateway VpnGw1** non-AZ, active-passive (NOT active-active BGP)
- **No Bastion** — use JIT VM access instead
- **No ExpressRoute**, **No DDoS Protection Plan**, **No DNS Private Resolver**
- **Private DNS Zones**: Enabled for privatelink resolution
- The `main.bicep` type definition was modified to allow non-AZ VPN SKUs (`VpnGw1`, `VpnGw2`, `VpnGw3`)

## Governance Notes

- `Enable-DDoS-VNET` policy is **excluded** from Landing Zones and Platform-Connectivity MGs (no DDoS plan deployed)
- `parLocations` is a single-element array `['westus2']` everywhere — do NOT add an empty second element
- Security contact email in int-root governance needs updating from placeholder `security@yourcompany.com`

## Key Conventions

- All changes go through **PRs to main** — never push directly
- CI validates Bicep syntax/lint + runs `what-if` against all MGs
- CD runs on merge to main with a manual approval gate before deploy
- File structure: `templates/core/governance/` (MGs, policies, RBAC), `templates/core/logging/` (Log Analytics), `templates/networking/hubnetworking/` (hub VNet, firewall, VPN, DNS)
- `parameters.json` at repo root maps subscription IDs and location variables used by CI/CD workflows

## Protected Resources

- **Game server VM** in Spaidoso-LZ-Online subscription has a **resource lock** — do NOT remove or modify it
- The Online LZ subscription is intentionally **NOT peered** to the hub network
- Subscriptions `7e1b60b8` (Spaid Family Core Infra LZ) and `67251182` (Spaid Family MGMT) are **not managed** by this repo

## Planned Future Work

- S2S VPN connection to Ubiquiti home lab (IKEv2, AES-256, SHA-256, DH14, PFS14)
- UDR `0.0.0.0/0` → Firewall for peered corp spokes only (NOT Online LZ)
- Update security contact email
