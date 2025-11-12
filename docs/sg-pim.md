# Azure RBAC and PIM Group Design

## Purpose
Standardize privileged access to Azure resources using **Microsoft Entra ID (PIM)** and **Azure RBAC**, aligned with **Microsoft Cloud Adoption Framework (CAF)** and **Enterprise-Scale Landing Zone** principles.

---

## Overview

Access is divided into two logical layers:

| Layer | Group Type | Purpose | Example |
|-------|-------------|----------|----------|
| **Eligibility (PIM)** | `entra-priv` | Defines who *can* become privileged (managed in PIM). | `sg-infra-entra-priv` |
| **Assignment (RBAC)** | `role` | Holds Azure permissions at the scope level (static in RBAC). | `sg-infra-contributor` |

When a user activates in PIM, they are temporarily added to the corresponding RBAC group, gaining access for a limited time.

---

## Group Structure Examples

### Infra Team
| Group | Type | Scope | Role | Access Duration |
|--------|------|--------|------|----------------|
| `sg-infra-entra-priv` | Entra (PIM) | Tenant | N/A | Eligible |
| `sg-infra-contributor` | RBAC | MG: Platform | Contributor | Time-bound (via PIM) |
| `sg-infra-reader` | RBAC | MG: Platform | Reader | Permanent |
| *(optional)* `sg-infra-uaa` | RBAC | MG: Platform | User Access Administrator | Time-bound (via PIM) |

### Network Team
| Group | Type | Scope | Role | Access Duration |
|--------|------|--------|------|----------------|
| `sg-network-entra-priv` | Entra (PIM) | Tenant | N/A | Eligible |
| `sg-network-contributor` | RBAC | MG: Network | Contributor | Time-bound (via PIM) |
| `sg-network-reader` | RBAC | MG: Network | Reader | Permanent |

### Device Admin Team
| Group | Type | Scope | Role | Access Duration |
|--------|------|--------|------|----------------|
| `sg-device-entra-priv` | Entra (PIM) | Tenant | N/A | Eligible |
| `sg-device-contributor` | RBAC | MG: Endpoint | Contributor | Time-bound (via PIM) |
| `sg-device-reader` | RBAC | MG: Endpoint | Reader | Permanent |
| *(optional)* `sg-device-uaa` | RBAC | MG: Endpoint | User Access Administrator | Time-bound (via PIM) |

### Security Admin Team
| Group | Type | Scope | Role | Access Duration |
|--------|------|--------|------|----------------|
| `sg-security-entra-priv` | Entra (PIM) | Tenant | N/A | Eligible |
| `sg-security-contributor` | RBAC | MG: Security | Contributor | Time-bound (via PIM) |
| `sg-security-reader` | RBAC | MG: Security | Reader | Permanent |
| *(optional)* `sg-security-uaa` | RBAC | MG: Security | User Access Administrator | Time-bound (via PIM) |

### Break-Glass Accounts
| Account | Role | Scope | Duration |
|----------|------|--------|-----------|
| `breakglass-01` | Owner | Tenant Root | Permanent |
| `breakglass-02` | Owner | Platform MG | Permanent |

> These are **not** group members and should remain offline, monitored, and tightly controlled.

---

## Scope Application

| Scope Type | When to Use | Example |
|-------------|--------------|----------|
| **Management Group** | Broad or shared access (Infra, Network, Device, Security). | Assign `sg-infra-contributor` at Platform MG. |
| **Subscription** | Workload or app team boundaries. | Assign `sg-app1-contributor` at App1 subscription. |
| **Resource Group** | Rare isolation within a subscription. | Assign `sg-dbops-contributor` for database RG only. |

---

## Access Flow

1. User is permanently a member of `sg-<team>-entra-priv`.  
2. User activates in **PIM** (just-in-time).  
3. PIM grants temporary membership in `sg-<team>-contributor` (or `uaa`).  
4. The RBAC group already holds the role at the appropriate scope.  
5. After expiry, the user is removed automatically.

---

## PIM Configuration Recommendations

| Setting | Value |
|----------|--------|
| Activation Duration | 2–4 hours |
| MFA Requirement | Enabled |
| Justification | Required |
| Ticket ID | Optional but recommended |
| Notification | Enabled for all activations and changes |

---

## Key Principles

1. **No standing access** – Only Reader roles are permanent.  
2. **PIM controls elevation** – Contributor/UAA via Entra Priv groups only.  
3. **Assign roles to groups, not users.**  
4. **Infra team** temporarily owns RBAC management; future **Help Desk** will assume UAA duties.  
5. **Break-glass accounts** are separate and permanently assigned Owner.

---

## Naming Convention

- sg--
- sg-[team]-entra-priv

Examples:
- `sg-infra-contributor`
- `sg-network-reader`
- `sg-device-contributor`
- `sg-security-entra-priv`

---

## Summary

| Access Type | Example Group | PIM Required | Duration | Scope |
|--------------|---------------|---------------|-----------|--------|
| Contributor | `sg-infra-contributor` | Yes | 2–4 hrs | MG/Sub |
| Reader | `sg-infra-reader` | No | Permanent | MG/Sub |
| User Access Admin | `sg-infra-uaa` | Yes | 1–2 hrs | MG/Sub |
| Break-glass (Owner) | `breakglass-01` | N/A | Permanent | Tenant Root |
| Privilege Eligibility | `sg-infra-entra-priv` | Yes (activation control) | N/A | Tenant |

---

## Benefits

- **Auditable** – Clear PIM logs for elevation events.  
- **Least privilege** – No permanent write access.  
- **Scalable** – Add new teams easily using the same pattern.  
- **CAF-aligned** – Matches Microsoft’s recommended enterprise-scale governance model.