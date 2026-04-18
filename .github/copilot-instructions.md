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
4. **RBAC fixes**: Apply UAMI granted Owner + Plan UAMI granted Reader directly on sub `966a8e3c` (wasn't under `alz` MG yet).

### Pending / In Progress
5. **CD pipeline**: Multiple runs have hit ARM API rate limits during What-If phase.
   - **Run 24578771115**: Failed at "Plan: Governance-Platform" step due to `Too Many Requests on TenantandUserLevel`
   - **Run 24607691490**: Currently in progress (as of 2026-04-18 ~10:25 AM)
   - **Root cause**: ALZ governance templates contain hundreds of policy definitions; each What-If makes many ARM API calls, exhausting the 150 requests/minute tenant-level limit
   - **Workaround**: Wait 1-2 minutes between workflow runs; don't run CI and CD simultaneously

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

## Documentation Maintenance Guidelines

**IMPORTANT**: When making changes to this repository, you MUST update the relevant documentation:

### Files to Update

| Change Type | Update These Files |
|-------------|-------------------|
| New/modified subscriptions | `README.md` (Subscription Mapping), this file (Subscription Mapping) |
| Management group changes | `README.md` (MG Hierarchy), this file (MG Hierarchy) |
| Networking changes (VNet, subnets, peering) | `README.md` (Networking Design), this file (Networking Design) |
| New Azure resources | `README.md` (Cost Estimates), this file (Cost Notes) |
| Policy changes/exclusions | `README.md` (Policy Exclusions), this file (Governance Notes) |
| CI/CD workflow changes | `README.md` (CI/CD Pipelines) |
| Identity/RBAC changes | `README.md` (Troubleshooting - Azure Identity), this file (Azure Identity) |
| Completed planned work | Remove from "Planned Future Work" in both files |

### Documentation Checklist

Before completing any PR, verify:
1. [ ] `README.md` reflects the current state after your changes
2. [ ] `.github/copilot-instructions.md` is updated with any new constraints, conventions, or context
3. [ ] Cost estimates are updated if adding/removing paid resources
4. [ ] Subscription/MG mappings are accurate
5. [ ] Any new "protected resources" or constraints are documented

### Style Guidelines

- Keep `README.md` user-facing and concise — focus on "what" and "how"
- Keep `copilot-instructions.md` detailed with context — focus on "why" and constraints
- Use tables for structured data (subscriptions, costs, etc.)
- Use code blocks for CLI commands and file paths
- Mark completed tasks with ✅ and pending with ❌ or [ ]

## Troubleshooting Reference

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Too Many Requests on TenantandUserLevel` | ARM API rate limit (150 req/min) | Wait 1-2 min, re-run. Don't run CI+CD simultaneously |
| `AuthorizationFailed` on What-If | UAMI lacks permissions at scope | Add Reader (plan) or Owner (apply) at appropriate MG/sub |
| Bicep build errors | Outdated ALZ library | Run `tooling/Update-AlzLibraryReferences.ps1` |
| GitHub CLI auth fails with `gho_*` token | SAML enforcement blocks OAuth | Use classic PAT (`ghp_*`) via `$env:GH_TOKEN` |
