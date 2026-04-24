# Azure Landing Zones Management Repository

This repository manages Azure Landing Zones (ALZ) infrastructure using **Bicep** for Infrastructure as Code, deployed via **GitHub Actions** CI/CD with OIDC federated credentials to Azure.

## Quick Links

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Subscription & Management Group Mapping](#subscription--management-group-mapping)
- [Networking Design](#networking-design)
- [CI/CD Pipelines](#cicd-pipelines)
- [Making Changes](#making-changes)
- [Troubleshooting](#troubleshooting)
- [Cost Estimates](#cost-estimates)

---

## Architecture Overview

| Component | Details |
|-----------|---------|
| **IaC Language** | Bicep (NOT Terraform — Terraform was only used for one-time bootstrap) |
| **CI/CD** | GitHub Actions with OIDC federated credentials |
| **Region** | Single region: `westus2` |
| **Tenant ID** | `4d00acda-e258-43e1-bd90-9370a4d118e1` |
| **Bootstrap Version** | ALZ Accelerator v7.1.1, Bootstrap v7.2.0, Starter v2.0.0 |

### Management Group Hierarchy

```
Tenant Root Group (4d00acda-e258-43e1-bd90-9370a4d118e1)
└── alz (Azure Landing Zones)
    ├── platform
    │   ├── platform-connectivity
    │   ├── platform-identity
    │   ├── platform-management
    │   └── platform-security
    ├── landingzones
    │   ├── landingzones-corp
    │   └── landingzones-online
    ├── sandbox
    └── decommissioned
```

---

## Repository Structure

```
alz-mgmt/
├── .github/
│   ├── copilot-instructions.md    # AI assistant context (this file)
│   └── workflows/
│       ├── ci.yaml                # PR validation workflow
│       └── cd.yaml                # Deployment workflow (push to main)
├── templates/
│   ├── core/
│   │   ├── alzCoreType.bicep      # Shared type definitions
│   │   ├── governance/
│   │   │   ├── lib/alz/           # ALZ policy library (JSON files)
│   │   │   ├── mgmt-groups/       # Management group configurations
│   │   │   │   ├── int-root/      # Root MG (alz)
│   │   │   │   ├── platform/      # Platform MG
│   │   │   │   ├── landingzones/  # Landing Zones MG
│   │   │   │   ├── sandbox/       # Sandbox MG
│   │   │   │   └── decommissioned/# Decommissioned MG
│   │   │   └── tooling/           # Library update scripts
│   │   └── logging/               # Log Analytics workspace
│   └── networking/
│       ├── hubnetworking/         # Hub VNet, Firewall, VPN Gateway, DNS
│       └── virtualwan/            # Virtual WAN (not used)
│   └── workload/
│       └── github-runner/         # Shared self-hosted runner platform in Online LZ
├── parameters.json                # CI/CD environment variables
├── bicepconfig.json               # Bicep linter configuration
└── README.md                      # This file
```

---

## Subscription & Management Group Mapping

| Subscription | Subscription ID | Management Group |
|--------------|-----------------|------------------|
| Spaidoso-MGMT | `e4fdb784-0635-495b-9d34-e57009b5eb57` | platform-management |
| Spaidoso-Connectivity | `82ce8884-3284-4808-b77e-8dd9b0175d4c` | platform-connectivity |
| Spaidoso-Identity | `d9c8ca00-f992-43e8-b77c-d9d12c4a32c0` | platform-identity |
| Spaidoso-LZ1-Corp | `7e8843fa-73d2-4343-814e-513f5e111bd2` | platform-security |
| Spaidoso-LZ-Online | `966a8e3c-bd80-41dd-8910-506aab21e18b` | landingzones-online |

### Subscriptions NOT Managed by This Repo

- `7e1b60b8-...` (Spaid Family Core Infra LZ)
- `67251182-...` (Spaid Family MGMT)

---

## Networking Design

### Hub Virtual Network (`10.0.0.0/22`)

| Subnet | Address Prefix | Purpose |
|--------|---------------|---------|
| AzureFirewallSubnet | `10.0.0.0/26` | Azure Firewall |
| GatewaySubnet | `10.0.0.128/27` | VPN Gateway |
| AzureFirewallManagementSubnet | `10.0.0.192/26` | Firewall management (Basic SKU requirement) |

### Deployed Components

| Resource | SKU / Configuration |
|----------|---------------------|
| **Azure Firewall** | Basic (~$288/mo) |
| **VPN Gateway** | VpnGw1AZ, zone-redundant, active-passive, no BGP (~$153/mo) |
| **Private DNS Zones** | Enabled for privatelink resolution |

### NOT Deployed (Cost Optimization)

- ❌ Azure Bastion (use JIT VM access instead)
- ❌ ExpressRoute Gateway
- ❌ DDoS Protection Plan
- ❌ DNS Private Resolver

### Peering Design

- **Online LZ** (`966a8e3c`) is intentionally **NOT peered** to the hub
- Corp spokes will get UDR `0.0.0.0/0` → Firewall

### Online LZ Workload Network

- Existing workload VNet: `sfgameserver-vnet` in `spaidoso-lz-online-gameserver-rg`
- Address space: `10.0.0.0/16`
- Existing subnet: `default (10.0.0.0/24)`
- New shared runner subnet (planned by this repo): `snet-github-runner (10.0.1.0/24)`
- Shared runner Key Vault uses a private endpoint in `snet-github-runner` and resolves through the existing `privatelink.vaultcore.azure.net` private DNS zone.

---

## CI/CD Pipelines

### Environments

| Environment | Purpose | Approval |
|-------------|---------|----------|
| `alz-mgmt-plan` | CI validation, What-If | None |
| `alz-mgmt-apply` | CD deployment | Manual approval required |

### Workflow Templates

Workflows use shared templates from `Spaidoso/alz-mgmt-templates`:
- `.github/workflows/ci-template.yaml` - Bicep validation + What-If
- `.github/workflows/cd-template.yaml` - What-If + Deploy

> **Note:** The `alz-mgmt-templates` repo also has branch protection on `main`. To modify workflow templates:
> 1. Clone `alz-mgmt-templates` and create a feature branch
> 2. Make changes and push the branch
> 3. Create and merge a PR to `main`
> 4. Re-run the `alz-mgmt` workflow to pick up the changes

### CI Pipeline (`01 Azure Landing Zones Continuous Integration`)

Triggers on: Pull requests to `main`

1. Validate Bicep syntax/lint
2. Run What-If against all management groups

### CD Pipeline (`02 Azure Landing Zones Continuous Delivery`)

Triggers on: Push to `main`

1. **What If Job**: Runs What-If for all deployment steps
2. **Deploy Job**: Applies changes (requires `alz-mgmt-apply` approval)

Deployment order:
1. Governance (int-root → landingzones → platform → sandbox → decommissioned → RBAC)
2. Core Logging
3. Hub Networking
4. Workload Runner Platform (`templates/workload/github-runner`) including the runner VM, runner Key Vault, and Key Vault private endpoint

### CD workflow_dispatch toggles

- Existing governance/core/networking toggles remain unchanged.
- `workload-github-runner` remains available for manual workflow dispatch and defaults to `false` there.
- Pushes to `main` now include the runner platform automatically after approval in `alz-mgmt-apply`.

### Shared Runner Platform

The shared runner deployment now creates:

- Dedicated runner resource group: `rg-alz-github-runner-westus2-001`
- Runner VM with system-assigned managed identity
- Dedicated runner subnet and NSG in the existing Online LZ VNet
- Private-endpoint-enabled Key Vault for runner SSH material

Operational steps after the first approved CD run:

1. Upload the SSH **private** key to the new Key Vault as the `ssh-private` secret (the public key is injected into the VM at deploy time via the `RUNNER_SSH_PUBLIC_KEY` pipeline secret, but storing it in Key Vault too is optional for reference).
2. Perform the just-in-time GitHub runner registration step.
3. Validate the runner can resolve the Key Vault over private link and that future workload deployments can reuse the stored SSH material.

---

## Making Changes

### Workflow

1. Create a feature branch from `main`
2. Make changes to Bicep templates
3. Open a PR to `main`
4. CI runs validation and What-If
5. Review and merge PR
6. CD runs automatically, approve deployment in `alz-mgmt-apply` environment

### Key Conventions

- **Never push directly to `main`** — always use PRs
- **`parLocations`** must be a single-element array `['westus2']` — do NOT add empty elements
- **Security email** in `int-root/main.bicepparam` needs updating from `security@yourcompany.com`

### Protected Resources

⚠️ **Game server VM** in Spaidoso-LZ-Online (`966a8e3c`) has a **resource lock** — do NOT remove

---

## Troubleshooting

### Azure Identity (UAMIs)

| Identity | Principal ID | Permissions |
|----------|--------------|-------------|
| `id-alz-mgmt-westus2-apply-001` | `a8915b05-4eca-49f7-917a-40cac673b1c5` | Owner @ MG `alz` + Owner @ sub `966a8e3c` |
| `id-alz-mgmt-westus2-plan-001` | `3f1188ab-9ef0-447b-af80-24c0e7ea0c50` | Reader @ tenant + `alz_reader` @ MG `alz` + Reader @ sub `966a8e3c` |

Identity RG: `rg-alz-mgmt-identity-westus2-001` in subscription `e4fdb784`

### Rate Limiting

**Error**: `Too Many Requests on TenantandUserLevel. Request limit 150, Throttling window time 00:01:00`

**Cause**: ALZ governance templates contain hundreds of policy definitions. Each What-If makes many ARM API calls, which can exhaust the tenant-level rate limit of 150 requests/minute.

**Solutions**:
1. **Wait 1-2 minutes and re-run** — the throttling window resets
2. **Don't run CI and CD simultaneously** — stagger workflows
3. **Use `skip_what_if` input** — CD workflow supports skipping What-If via workflow_dispatch

### GitHub CLI Authentication

Standard OAuth (`gho_`) tokens work fine for the Spaidoso org (no SAML enforcement). Ensure the token has `repo` and `workflow` scopes.

---

## Cost Estimates

| Resource | Monthly Cost |
|----------|--------------|
| Azure Firewall Basic | ~$288 |
| VPN Gateway VpnGw1AZ | ~$153 |
| Log Analytics | Minimal |
| Shared runner VM + Key Vault + Private Endpoint | Additional cost above current baseline |
| **Total** | **Higher than the current ~$445/month baseline once the runner platform is deployed** |

---

## Planned Future Work

### Immediate

- [ ] Update security contact email from `security@yourcompany.com`
- [ ] Remove direct sub-level RBAC on `966a8e3c` after it's under `alz` MG

### Networking

- [ ] S2S VPN to Ubiquiti home lab (IKEv2, AES-256, SHA-256, DH14, PFS14)
- [ ] UDR for corp spokes → Firewall

### Policy Exclusions

- `Enable-DDoS-VNET` is excluded from Landing Zones and Platform-Connectivity MGs (no DDoS plan deployed)

---

## Bootstrap Artifacts

> **Note**: These are only needed if tearing down bootstrap resources

- **Local output**: `C:\Users\jospaid\alz-accelerator\output` (Terraform state)
- **Config files**: `C:\Users\jospaid\alz-accelerator\config\inputs.yaml` and `platform-landing-zone.yaml`
- **Bootstrap module version**: 7.2.0 (pinned to avoid GitHub API issues with SAML)
