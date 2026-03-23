## Motivation

This PR introduces a clear separation of concerns between authentication and authorization, and improves the overall maintainability, consistency, and predictability of the auth layer. The previous implementation had accumulated patterns that made it increasingly hard to extend safely:

- Authentication relied on manually wiring `CombinedAuthGuard` into every controller — workable at a smaller scale, but forgetting it meant the endpoint was silently public.
- Auth context was a broad union type narrowed through unsafe casts, and each new context type required auditing existing guards to make sure none were silently broken. Correctness depended on disciplined usage rather than runtime guardrails.
- Organization authorization was split across a three-layer guard inheritance chain, making it hard to trace what was actually being enforced on a given endpoint.
- System admin access was scattered across resource guards and domain controllers as inline `SystemRole.ADMIN` checks, complicating the logic for the common case and making it difficult to audit what a system admin could actually reach.
- Authentication and authorization failures were handled inconsistently — some guards threw, others returned `false`, and error codes were often swallowed, making it hard to diagnose why a request was rejected.

## Changes

### 1. Authentication is now global

`CombinedAuthGuard` is replaced by `GlobalAuthGuard`, registered as `APP_GUARD`. Every endpoint is authenticated by default.

- Endpoints that need to be public use `@Public()` (health, config, regions).
- `AuthStrategy` decorator controls which authentication methods an endpoint or controller accepts (e.g., JWT only, API key only, or both). Defaults to JWT-only when not specified.

This eliminates the need to wire `CombinedAuthGuard` into every controller and ensures no endpoint is accidentally left unprotected.

---

### 2. System role enforcement is global

`SystemActionGuard` is now registered as a global `APP_GUARD`. It checks whether the endpoint or controller is marked with `@RequiredSystemRole()` and enforces it automatically. Endpoints without the decorator are unaffected. This replaces the previous pattern of manually stacking `SystemActionGuard` in each controller's `@UseGuards()`.

---

### 3. Admin operations separated from domain controllers

Endpoints that required `SystemRole.ADMIN` were previously mixed into domain controllers (`UserController`, `WebhookController`, `SnapshotController`, etc.) with inline role checks. These are now extracted into dedicated admin controllers under `/admin/*`.

The domain controllers no longer contain any admin-only endpoints, and the `SystemRole.ADMIN` bypass is removed from all resource access guards. Admin access is enforced structurally by controller placement, not by inline conditionals.

---

### 4. Organization guards consolidated into one

`OrganizationAccessGuard`, `OrganizationActionGuard`, and `OrganizationResourceActionGuard` are replaced by a single `OrganizationAuthContextGuard` that:

- Resolves the org ID (from params or auth context)
- Loads and caches the organization + membership
- Enforces `@RequiredOrganizationMemberRole` and `@RequiredOrganizationResourcePermissions`
- Enriches `request.user` into a full `OrganizationAuthContext`

---

### 5. Auth context is typed and validated

Each auth context is now a separate interface (`UserAuthContext`, `OrganizationAuthContext`, `RunnerAuthContext`, etc.) with a co-located type guard that narrows safely from `unknown`. A shared `getAuthContext(context, isXxxAuthContext)` utility replaces all raw casts — it either returns the narrowed type or throws 403.

Naming is consistent throughout: interfaces follow `XxxAuthContext`, type guards `isXxxAuthContext()`, and guards `XxxAuthContextGuard`.

---

### 6. Guard layering: auth context + resource access

Controllers now follow a consistent two-layer guard pattern:

1. **Auth context guard** — validates _who_ the caller is and ensures the auth context matches what the endpoint expects (e.g., `OrganizationAuthContextGuard`, `RunnerAuthContextGuard`, `ProxyAuthContextGuard`). When multiple caller types are valid, `OrGuard` composes them.
2. **Resource access guard** — validates the caller has access to the _specific resource_ (e.g., `SandboxAccessGuard`, `SnapshotAccessGuard`)

Previously these responsibilities were mixed — the organization guard hierarchy handled both identity validation and resource-level checks, and some resource guards duplicated caller validation. The separation makes it clear what each guard is responsible for and allows resource access guards to assume a validated, typed auth context.

---

### 7. Region guards simplified

`ProxyAuthContextGuard` now accepts both `proxy` and `region-proxy`, and `SshGatewayAuthContextGuard` accepts both `ssh-gateway` and `region-ssh-gateway` — removing the need for separate region-specific authentication guards.

On the authorization side, `RegionRunnerAccessGuard` and `RegionSandboxAccessGuard` are deleted. Their logic is absorbed into `RunnerAccessGuard` and `SandboxAccessGuard` via a new `RegionAuthContext` base interface (carries `regionId`). For regional contexts, access guards verify that the resource belongs to the caller's region instead of requiring separate guard classes.

---

### 8. Consistent error handling

Guards no longer return `false` or swallow errors. Each layer of the auth stack throws a specific, predictable exception:

- **401 Unauthorized** — invalid or missing credentials (thrown by `GlobalAuthGuard`)
- **403 Invalid authentication context** — the caller's auth context doesn't match what the endpoint expects (thrown by auth context guards and `OrGuard`)
- **403 Access denied** — the caller is authenticated but not authorized for the action (thrown by `OrganizationAuthContextGuard` and `SystemActionGuard`)
- **404 Not found** — the resource doesn't exist or the caller doesn't have access (thrown by resource access guards, to avoid leaking resource existence)

`console.error` replaced with `this.logger.error` throughout.

---

### 9. Type safety in auth strategies

`ApiKeyStrategy` and `JwtStrategy` now return typed auth contexts (`satisfies UserAuthContext`, `satisfies RunnerAuthContext`, etc.) instead of untyped objects. Both strategies check `request.authMetadata.isStrategyAllowed()` before executing — a strategy that isn't allowed for the endpoint returns `null` (skip) instead of failing.

`ApiKeyStrategy.validateToken()` is extracted as a public method so the notification WebSocket gateway can authenticate tokens without going through Passport.

---

### 10. Missing rate limit guards added

Controllers that were missing rate limit guards now have them explicitly applied. `AuthenticatedRateLimitGuard` is added to all authenticated controllers, and `AnonymousRateLimitGuard` to public endpoints, ensuring consistent rate limiting coverage across the API.

---

### 11. Consistent decorator ordering

Controller and method decorators now follow a consistent order across all controllers for better readability and maintainability. This is best-effort, not enforced by tooling:

1. Route decorator (`@Controller`, `@Get`, `@Post`, etc.)
2. Swagger decorators (`@ApiTags`, `@ApiOperation`, `@ApiResponse`, etc.)
3. Auth strategy (`@AuthStrategy`)
4. Role/permission decorators (`@RequiredSystemRole`, `@RequiredOrganizationMemberRole`, `@RequiredOrganizationResourcePermissions`)
5. Guards (`@UseGuards`)
6. Other decorators (`@Audit`, `@SkipThrottle`, etc.)
