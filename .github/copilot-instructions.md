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

## Deployment State (as of 2026-04-18)

### Completed
1. **Bootstrap (Phase 2)**: 496 resources via Terraform (one-time). GitHub repos, UAMIs, OIDC federated credentials, MG `alz`, branch protection, environments, Actions variables all created.
2. **Phase 3 PR #1**: Merged. Customized networking (Firewall Basic, VpnGw1, no Bastion/ER/DDoS/DNS Resolver, single region) and governance (DDoS policy exclusion, Online LZ sub placement, single-element parLocations).
3. **CI pipeline**: Validated — Bicep build/lint passed, all 18 what-if steps passed.

### Pending / In Progress
4. **CD pipeline (run 24578771115)**: Re-triggered after fixing RBAC. First attempt failed because Online LZ sub (`966a8e3c`) wasn't yet under `alz` MG so the apply UAMI lacked permissions. Fix: granted apply UAMI Owner + plan UAMI Reader directly on that sub.
   - **Action needed**: Approve `alz-mgmt-apply` environment at https://github.com/Spaidoso/alz-mgmt/actions/runs/24578771115
   - If the run ID has changed due to re-run, check `gh run list` for the latest CD run.

### Azure Identity (for troubleshooting)
- **Apply UAMI**: `id-alz-mgmt-westus2-apply-001` — principal `a8915b05-4eca-49f7-917a-40cac673b1c5` — has Owner at MG `alz` + Owner on sub `966a8e3c`
- **Plan UAMI**: `id-alz-mgmt-westus2-plan-001` — principal `3f1188ab-9ef0-447b-af80-24c0e7ea0c50` — has Reader at tenant + custom `alz_reader` at MG `alz` + Reader on sub `966a8e3c`
- **Identity RG**: `rg-alz-mgmt-identity-westus2-001` in sub `e4fdb784`
- **Tenant ID**: `4d00acda-e258-43e1-bd90-9370a4d118e1`

### Bootstrap Artifacts
- **Local bootstrap output**: `C:\Users\jospaid\alz-accelerator\output` (Terraform state — only needed if tearing down bootstrap resources)
- **Config files**: `C:\Users\jospaid\alz-accelerator\config\inputs.yaml` and `platform-landing-zone.yaml`
- **Bootstrap module version**: 7.2.0 (pinned in inputs.yaml to avoid GitHub API download issues with SAML)
- **`gh` CLI**: Must use classic PAT (`ghp_` prefix) via `$env:GH_TOKEN`, NOT OAuth (`gho_`). The Azure org has SAML enforcement that blocks `gho_` tokens.

## Planned Future Work

### Immediate (after CD succeeds)
- Verify game server VM resource lock still intact on sub `966a8e3c`
- Remove direct sub-level RBAC on `966a8e3c` once it's under `alz` MG (optional cleanup)
- Update security contact email from `security@yourcompany.com` in `templates/core/governance/mgmt-groups/int-root/main.bicepparam`

### Networking
- S2S VPN connection to Ubiquiti home lab:
  - IKEv2, AES-256, SHA-256, DH Group 14, PFS Group 14
  - Requires: Local Network Gateway resource + VPN Connection resource (add to hub networking template or create separate template)
- UDR `0.0.0.0/0` → Firewall for peered corp spokes only (NOT Online LZ)
- Online LZ subscription intentionally NOT peered to hub

### Cost Notes
- Estimated monthly: ~$430 (Firewall Basic ~$288 + VpnGw1 ~$138 + Log Analytics minimal)
- No Bastion, ExpressRoute, DDoS, or DNS Private Resolver to reduce costs
