# Auth Guard Testing Checklist

For each endpoint, test:

1. **Happy path** - correct auth context -> succeeds
2. **Wrong auth context** - e.g., JWT on API_KEY-only endpoint -> 401/403
3. **Missing auth** - no token -> 401
4. **Wrong role/permissions** - valid auth, insufficient permissions -> 403

---

## Sandbox Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /sandbox | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /sandbox/paginated | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| POST | /sandbox | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_SANDBOXES | ThrottlerScope: sandbox-create |
| GET | /sandbox/for-runner | JWT, API_KEY | RunnerAuthContextGuard | - | - | Runner auth context |
| GET | /sandbox/:id | JWT, API_KEY | OrGuard([OrgAuth, SshGateway]) | SandboxAccessGuard | - | |
| DELETE | /sandbox/:id | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | DELETE_SANDBOXES | |
| POST | /sandbox/:id/recover | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | WRITE_SANDBOXES | |
| POST | /sandbox/:id/start | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | WRITE_SANDBOXES | |
| POST | /sandbox/:id/stop | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | WRITE_SANDBOXES | |
| POST | /sandbox/:id/resize | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | WRITE_SANDBOXES | Feature flag: SANDBOX_RESIZE |
| PUT | /sandbox/:id/labels | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | WRITE_SANDBOXES | |
| POST | /sandbox/:id/state | JWT, API_KEY | RunnerAuthContextGuard | SandboxAccessGuard | - | Runner-only |
| GET | /sandbox/:id/port-preview-url/:port | JWT, API_KEY | OrGuard([OrgAuth, Proxy, SshGateway]) | SandboxAccessGuard | - | |

## Runner Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /runners | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_RUNNERS | Feature flag |
| GET | /runners/me | JWT, API_KEY | RunnerAuthContextGuard | - | - | |
| GET | /runners/by-sandbox/:sandboxId | JWT, API_KEY | OrGuard([Proxy, SshGateway, Region]) | SandboxAccessGuard | - | |
| GET | /runners/by-snapshot-ref | JWT, API_KEY | OrGuard([Proxy, SshGateway]) | - | - | |
| GET | /runners/:id | JWT, API_KEY | OrganizationAuthContextGuard | RunnerAccessGuard | READ_RUNNERS | |
| GET | /runners/:id/full | JWT, API_KEY | OrGuard([Proxy, SshGateway, Region]) | RunnerAccessGuard | - | |
| GET | /runners | JWT, API_KEY | OrganizationAuthContextGuard | - | READ_RUNNERS | Feature flag |
| PATCH | /runners/:id/scheduling | JWT, API_KEY | OrganizationAuthContextGuard | RunnerAccessGuard | WRITE_RUNNERS | |
| PATCH | /runners/:id/draining | JWT, API_KEY | OrganizationAuthContextGuard | RunnerAccessGuard | WRITE_RUNNERS | Feature flag |
| DELETE | /runners/:id | JWT, API_KEY | OrganizationAuthContextGuard | RunnerAccessGuard | DELETE_RUNNERS | Feature flag |
| POST | /runners/healthcheck | JWT, API_KEY | RunnerAuthContextGuard | - | - | |

## Snapshot Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /snapshots | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_SNAPSHOTS | |
| GET | /snapshots/:id | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotReadAccessGuard | - | |
| DELETE | /snapshots/:id | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotAccessGuard | DELETE_SNAPSHOTS | |
| GET | /snapshots | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /snapshots/:id/build-logs | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotAccessGuard | - | Deprecated |
| GET | /snapshots/:id/build-logs-url | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotAccessGuard | - | |
| POST | /snapshots/:id/activate | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotAccessGuard | WRITE_SNAPSHOTS | |
| POST | /snapshots/:id/deactivate | JWT, API_KEY | OrganizationAuthContextGuard | SnapshotAccessGuard | WRITE_SNAPSHOTS | |

## Volume Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /volumes | JWT, API_KEY | OrganizationAuthContextGuard | - | READ_VOLUMES | |
| POST | /volumes | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_VOLUMES | |
| GET | /volumes/:volumeId | JWT, API_KEY | OrganizationAuthContextGuard | VolumeAccessGuard | READ_VOLUMES | |
| DELETE | /volumes/:volumeId | JWT, API_KEY | OrganizationAuthContextGuard | VolumeAccessGuard | DELETE_VOLUMES | |
| GET | /volumes/by-name/:name | JWT, API_KEY | OrganizationAuthContextGuard | VolumeAccessGuard | READ_VOLUMES | |

## Job Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /jobs | JWT, API_KEY | RunnerAuthContextGuard | - | - | |
| GET | /jobs/poll | JWT, API_KEY | RunnerAuthContextGuard | - | - | Long-poll |
| GET | /jobs/:jobId | JWT, API_KEY | RunnerAuthContextGuard | JobAccessGuard | - | |
| POST | /jobs/:jobId/status | JWT, API_KEY | RunnerAuthContextGuard | JobAccessGuard | - | |

## Preview Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /preview/:sandboxId/public | - | - | AnonymousRateLimitGuard | - | @Public |
| GET | /preview/:sandboxId/validate/:authToken | - | - | AnonymousRateLimitGuard | - | @Public |
| GET | /preview/:sandboxId/access | JWT, API_KEY | - | AuthenticatedRateLimitGuard | - | |
| GET | /preview/:signedToken/:port/sandbox-id | - | - | AnonymousRateLimitGuard | - | @Public |

## Organization Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /organizations/invitations | JWT | - | - | - | |
| GET | /organizations/invitations/count | JWT | - | - | - | |
| POST | /organizations/invitations/:id/accept | JWT | - | - | - | |
| POST | /organizations/invitations/:id/decline | JWT | - | - | - | |
| POST | /organizations | JWT | - | - | - | |
| GET | /organizations | JWT | - | - | - | |
| GET | /organizations/:id | JWT | OrganizationAuthContextGuard | - | - | |
| DELETE | /organizations/:id | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| PATCH | /organizations/:id/default-region | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| GET | /organizations/:id/usage | JWT | OrganizationAuthContextGuard | - | - | |
| PATCH | /organizations/:id/quota | API_KEY | - | - | ADMIN system role | |
| PATCH | /organizations/:id/quota/:regionId | API_KEY | - | - | ADMIN system role | |
| POST | /organizations/:id/leave | JWT | OrganizationAuthContextGuard | - | - | |
| POST | /organizations/:id/suspend | API_KEY | - | - | ADMIN system role | |
| POST | /organizations/:id/unsuspend | API_KEY | - | - | ADMIN system role | |
| GET | /organizations/by-sandbox-id/:sandboxId | API_KEY | ProxyAuthContextGuard | - | - | |
| GET | /organizations/region-quota/by-sandbox-id/:sandboxId | API_KEY | ProxyAuthContextGuard | - | - | |
| GET | /organizations/otel-config/by-sandbox-auth-token/:authToken | API_KEY | OtelCollectorAuthContextGuard | - | - | |
| POST | /organizations/:id/sandbox-default-limited-network-egress | API_KEY | - | - | ADMIN system role | |
| PUT | /organizations/:id/experimental-config | JWT | OrganizationAuthContextGuard | - | OWNER role | Feature flag |

## Organization Invitation Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /organizations/:id/invitations | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| PUT | /organizations/:id/invitations/:invId | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| GET | /organizations/:id/invitations | JWT | OrganizationAuthContextGuard | - | - | |
| POST | /organizations/:id/invitations/:invId/cancel | JWT | OrganizationAuthContextGuard | - | OWNER role | |

## Organization User Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /organizations/:id/users | JWT | OrganizationAuthContextGuard | - | - | |
| POST | /organizations/:id/users/:userId/access | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| DELETE | /organizations/:id/users/:userId | JWT | OrganizationAuthContextGuard | - | OWNER role | |

## Organization Role Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /organizations/:id/roles | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| GET | /organizations/:id/roles | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| PUT | /organizations/:id/roles/:roleId | JWT | OrganizationAuthContextGuard | - | OWNER role | |
| DELETE | /organizations/:id/roles/:roleId | JWT | OrganizationAuthContextGuard | - | OWNER role | |

## Organization Region Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /regions | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| POST | /regions | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_REGIONS | Feature flag |
| GET | /regions/:id | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | - | |
| DELETE | /regions/:id | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | DELETE_REGIONS | Feature flag |
| POST | /regions/:id/regenerate-proxy-api-key | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | WRITE_REGIONS | Feature flag |
| PATCH | /regions/:id | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | WRITE_REGIONS | Feature flag |
| POST | /regions/:id/regenerate-ssh-gateway-api-key | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | WRITE_REGIONS | Feature flag |
| POST | /regions/:id/regenerate-snapshot-manager-credentials | JWT, API_KEY | OrganizationAuthContextGuard | RegionAccessGuard | WRITE_REGIONS | Feature flag |

## Sandbox Telemetry Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /sandbox/:id/telemetry/logs | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | - | Feature flag |
| GET | /sandbox/:id/telemetry/traces | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | - | Feature flag |
| GET | /sandbox/:id/telemetry/traces/:traceId | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | - | Feature flag |
| GET | /sandbox/:id/telemetry/metrics | JWT, API_KEY | OrganizationAuthContextGuard | SandboxAccessGuard | - | Feature flag |

## Docker Registry Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /docker-registry | JWT, API_KEY | OrganizationAuthContextGuard | - | WRITE_REGISTRIES | |
| GET | /docker-registry | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /docker-registry/registry-push-access | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /docker-registry/:id | JWT, API_KEY | OrganizationAuthContextGuard | DockerRegistryAccessGuard | - | |
| PATCH | /docker-registry/:id | JWT, API_KEY | OrganizationAuthContextGuard | DockerRegistryAccessGuard | WRITE_REGISTRIES | |
| DELETE | /docker-registry/:id | JWT, API_KEY | OrganizationAuthContextGuard | DockerRegistryAccessGuard | DELETE_REGISTRIES | |

## Webhook Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /webhooks/organizations/:id/app-portal-access | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /webhooks/organizations/:id/initialization-status | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |

## Object Storage Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /object-storage/push-access | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |

## Audit Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /audit/organizations/:id | JWT, API_KEY | OrganizationAuthContextGuard | - | READ_AUDIT_LOGS | |

## API Key Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| POST | /api-keys | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /api-keys | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| GET | /api-keys/current | API_KEY | OrganizationAuthContextGuard | - | - | API_KEY only |
| GET | /api-keys/:name | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| DELETE | /api-keys/:name | JWT, API_KEY | OrganizationAuthContextGuard | - | - | |
| DELETE | /api-keys/:userId/:name | JWT, API_KEY | OrganizationAuthContextGuard | - | - | OWNER only |

## User Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /users/me | JWT, API_KEY | - | - | - | |
| GET | /users/account-providers | JWT, API_KEY | - | - | - | |
| POST | /users/linked-accounts | JWT, API_KEY | - | - | - | |
| DELETE | /users/linked-accounts/:provider/:providerUserId | JWT, API_KEY | - | - | - | |
| POST | /users/mfa/sms/enroll | JWT, API_KEY | - | - | - | |

## Region Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /shared-regions | - | - | AnonymousRateLimitGuard | - | @Public |

## Health Controller

| Method | Route | Auth Strategy | Auth Context Guard | Access Guard | Permissions | Notes |
|--------|-------|---------------|-------------------|--------------|-------------|-------|
| GET | /health | - | - | AnonymousRateLimitGuard | - | @Public |
| GET | /health/ready | JWT, API_KEY | HealthCheckAuthContextGuard | - | - | |

## Admin Controllers

All admin endpoints require `ADMIN` system role via class-level `@RequiredSystemRole(SystemRole.ADMIN)`.

### Admin Sandbox

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| POST | /admin/sandbox/:sandboxId/recover | JWT, API_KEY | ADMIN | |

### Admin User

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| POST | /admin/users | JWT, API_KEY | ADMIN | |
| GET | /admin/users | JWT, API_KEY | ADMIN | |
| GET | /admin/users/:id | JWT, API_KEY | ADMIN | |
| POST | /admin/users/:id/regenerate-key-pair | JWT, API_KEY | ADMIN | |

### Admin Organization

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| GET | /admin/organizations/by-sandbox-id/:sandboxId | JWT, API_KEY | ADMIN | |
| GET | /admin/organizations/region-quota/by-sandbox-id/:sandboxId | JWT, API_KEY | ADMIN | |

### Admin Runner

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| POST | /admin/runners | JWT, API_KEY | ADMIN | |
| GET | /admin/runners/by-sandbox/:sandboxId | JWT, API_KEY | ADMIN | |
| GET | /admin/runners/by-snapshot-ref | JWT, API_KEY | ADMIN | |
| GET | /admin/runners/:id | JWT, API_KEY | ADMIN | |
| GET | /admin/runners | JWT, API_KEY | ADMIN | |
| PATCH | /admin/runners/:id/scheduling | JWT, API_KEY | ADMIN | |
| DELETE | /admin/runners/:id | JWT, API_KEY | ADMIN | |

### Admin Snapshot

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| GET | /admin/snapshots/can-cleanup-image | JWT, API_KEY | ADMIN | |
| PATCH | /admin/snapshots/:id/general | JWT, API_KEY | ADMIN | |

### Admin Audit

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| GET | /admin/audit | JWT, API_KEY | ADMIN | |

### Admin Docker Registry

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| POST | /admin/docker-registry/:id/set-default | JWT, API_KEY | ADMIN | |

### Admin Webhook

| Method | Route | Auth Strategy | Permissions | Notes |
|--------|-------|---------------|-------------|-------|
| POST | /admin/webhooks/organizations/:id/send | JWT, API_KEY | ADMIN | |
| GET | /admin/webhooks/organizations/:id/messages/:msgId/attempts | JWT, API_KEY | ADMIN | |
| GET | /admin/webhooks/status | JWT, API_KEY | ADMIN | |
| POST | /admin/webhooks/organizations/:id/initialize | JWT, API_KEY | ADMIN | |
