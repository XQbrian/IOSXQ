# Collaboration, Group Sharing & Resharing Governance — Spec

**Status:** Phase 1 draft. UI mocked in `prototype/index.html`; the data model, transport, governance, and Swift contract described here are what the iOS app and backend must implement.

**Companion docs:** `APPLICATION_FUNCTIONALITY.md`, `AI_COMPOSITION_SPEC.md`, `phase1-analysis/03-security-zero-trust.md`.

---

## 1. Goals

- Document editing inside XQ feels native — text, Markdown, Office, PDF annotations, structured enterprise forms, AI-generated reports.
- Collaboration (presence, comments, suggestions, version history) is real-time when connected; offline-safe and resync-clean when not.
- Every share carries explicit **lineage** and **resharing governance**.
- Group creation is automatic where it helps (auto-group on multi-recipient share) but always visible and policy-bound.
- Zero-Trust enforcement is invisible until it's needed, then explicit and explainable.

---

## 2. Editability State Machine

Every file in the workspace has a single **editability state** at any moment. The state is a function of (a) the user's permission, (b) the file's classification, (c) policy, (d) device posture, and (e) workflow status.

### 2.1 States

| State            | Badge token  | UI behavior                                                                                 |
| ---------------- | ------------ | ------------------------------------------------------------------------------------------- |
| Editable         | `ed-edit`     | Edit tools enabled. Autosave on. Track-changes optional.                                    |
| View Only        | `ed-view`     | Editing controls hidden. Comments allowed if `commentsAllowed`.                              |
| Comment Only     | `ed-comment`  | View + comment + suggested edits, no direct mutation.                                       |
| Pending Approval | `ed-pending`  | Edits paused; review snapshot taken. Reviewer notified.                                     |
| Restricted       | `ed-restricted` | Sensitive content (PHI, CUI, etc.). Local-only and extra DLP gating.                       |
| Expired Access   | `ed-expired`  | Access window ended. File still visible if cached but cannot decrypt; reshare reroutes to owner. |
| External Shared  | `ed-external` | File received from outside the tenant. Editing controls follow inbound policy.              |
| Local Only       | `ed-local`    | Never leaves device. Cloud sync, AI cloud routing, server-side previews all blocked.         |
| AI Restricted    | `ed-ai`       | AI inference on this file gated off (cloud AI off, only local LLM allowed).                 |

States are **non-exclusive** — a file can carry multiple (e.g., `Restricted` + `Local Only` + `AI Restricted`). UI shows up to 3 badges at once; overflow goes to a tooltip.

### 2.2 State derivation (server-evaluated, cached client-side)

```
state(file, user, device, ts) :=
    if expired(file.expiresAt, ts)        → Expired Access
    if local_only_label(file.labels)      ⊕ Local Only
    if ai_restricted(file.labels)         ⊕ AI Restricted
    if restricted_class(file.labels)      ⊕ Restricted
    if file.tenantId ≠ user.tenantId      ⊕ External Shared
    if pending_approval(file.workflow)    → Pending Approval
    else
      switch user_permission(file, user, device):
        case write   → Editable
        case suggest → Comment Only
        case comment → Comment Only
        case read    → View Only
```

Operator `⊕` means "add this badge but keep evaluating"; `→` is terminal.

### 2.3 Transitions

| From            | Event                                | To              |
| --------------- | ------------------------------------ | --------------- |
| Editable        | Owner requests approval              | Pending Approval |
| Pending Approval | Reviewer approves                    | Editable         |
| Pending Approval | Reviewer rejects                    | View Only        |
| Editable        | Expiry timer fires                   | Expired Access  |
| Editable        | DLP scan flags PHI mid-edit          | Restricted (concurrently)  |
| Comment Only    | Owner upgrades permission            | Editable        |
| Local Only      | Owner removes Local-Only label       | (label drops; other state derivations apply) |

All transitions write an audit event (§7).

---

## 3. Collaboration Transport

### 3.1 Real-time data model
- **CRDT** for text bodies — **Yjs** as the reference implementation, with a Swift port (`Y.swift`) or WASM bridge.
- **Operation log** for non-text artifacts (comments, suggested edits, structured forms): append-only with vector-clock ordering.
- **Presence** is ephemeral, in-memory, not persisted; broadcast via the same transport with a `kind: "presence"` envelope.

### 3.2 Transport
- **WebSocket over mTLS** for connected sessions.
- **Push notifications** carry "doc-updated" pings; client pulls deltas on next foreground.
- **Tactical / air-gapped:** local operations queue with HMAC-chained sequence numbers; rebroadcast on next sync window.

### 3.3 Offline conflict resolution
- CRDT guarantees text bodies converge — no merge UI for prose.
- For structured documents (forms, spreadsheets) the server **must** evaluate a merge plan; on conflict the user sees a **3-pane diff** (mine | theirs | merged) with field-level accept/reject.
- Suggestions made offline against a doc that has since changed materially are flagged "Stale — re-review" rather than silently applied.

### 3.4 Presence envelope

```json
{
  "kind":     "presence",
  "doc_id":   "f_4af2",
  "user_id":  "u_sarah",
  "state":    "active",
  "cursor":   { "block": 3, "offset": 42 },
  "color":   "#2E7D32"
}
```

Presence TTL: 90 seconds. Idle after 30 s of no input. Away after disconnect.

---

## 4. Group Sharing Model

### 4.1 Group types

| # | Type                       | Lifecycle                              | Membership source           |
| - | -------------------------- | -------------------------------------- | --------------------------- |
| 1 | Personal Share Group       | User-managed, persistent                | User curates                |
| 2 | Workspace Group            | Tenant-managed                          | Tenant admin                |
| 3 | Department Group           | Tenant-managed, label-gated             | IdP attribute / OU sync     |
| 4 | Project Collaboration Group | Project lifecycle (manual close)         | Project owner curates       |
| 5 | Temporary External Group   | Bound to a single file/thread; expires  | Auto-created on share       |
| 6 | Policy-Generated Dynamic Group | Continuously re-evaluated against ABAC rules | Policy engine            |

### 4.2 Auto-group creation rules

When a user shares a file with **2+ recipients**:

1. If a matching personal/project group already exists with those exact members, propose reusing it (no new group).
2. Otherwise the share sheet's "Auto-create share group" toggle is **on by default**.
3. The auto-group:
   - Inherits the file's labels (Restricted → group is Restricted).
   - Inherits the chosen resharing mode (§5).
   - Inherits the file's expiration (when the file expires, so does the group).
   - Is named `"<doc_title> — <date>"` by default; user can rename inline.
   - Is **visible** to the user (banner: "We created a 3-person group named 'MR-28491 Discharge Review' that expires with this share.").
   - Can be promoted to a Personal Share Group (persistent) if the user clicks "Keep this group".

### 4.3 Group security attributes

Every group carries:

```json
{
  "group_id":          "g_01HF9X…",
  "type":              "temporary_external",
  "tenant":            "ahs-prod-9d4e7",
  "members":           [{"id":"u_carol","verified":true},{"id":"u_alice","verified":true},{"id":"u_bob","verified":true}],
  "labels":            ["Restricted", "PHI"],
  "rbac":              ["doc.read", "doc.comment"],
  "abac":              { "dept":"clinical", "device_trust":"managed" },
  "conditional_access": { "geo": ["US"], "device":"managed", "tod_window":null },
  "expires_at":        "2026-05-30T17:00:00Z",
  "external_allowed":  true,
  "geo_restrictions":  ["US-only"],
  "ai_inference":      "local_only",
  "created_by":        "u_brian",
  "created_at":        "2026-05-23T17:14:22Z"
}
```

Each policy attribute is evaluated **at action time**, not at group creation — so device trust drops mid-session immediately revoke access.

---

## 5. Resharing Governance

### 5.1 Permission modes

| # | Mode                          | Meaning                                                                          |
| - | ----------------------------- | -------------------------------------------------------------------------------- |
| 1 | `none`                        | No resharing. Forward/copy/grant all blocked. Reshare button hidden.              |
| 2 | `internal`                    | Reshare inside tenant only. External domains blocked.                            |
| 3 | `group-only`                  | Reshare only to existing share-group members. No new recipients.                  |
| 4 | `approval`                    | Reshare requests route to owner (or designated approver) before access is granted. |
| 5 | `external-prohibit`           | Internal forwarding allowed; external explicitly blocked.                        |
| 6 | `owner`                       | Only the original owner can ever grant access.                                   |
| 7 | `policy`                      | Tenant policy decides per-recipient at request time (admin-controlled).          |
| 8 | `temp`                        | Reshares inherit the original share's expiry; cannot extend.                     |

The chosen mode is stored on **every share-edge** (not just on the file) so granting a third-party access to a file you received doesn't unlock the original owner's intent.

### 5.2 Share lineage data model

Each share creates a directed edge in the lineage graph:

```json
{
  "edge_id":         "edg_01HF9X…",
  "file_id":         "f_4af2",
  "from":            { "kind":"user", "id":"u_brian" },
  "to":              { "kind":"group", "id":"g_01HF9X…" },
  "permissions":     ["doc.read", "doc.comment"],
  "reshare_mode":    "approval",
  "expires_at":      "2026-05-30T17:00:00Z",
  "depth":           1,
  "labels":          ["Restricted", "PHI"],
  "policy_hash":     "sha256:…",
  "audit_ref":       "aud_01HF9X…"
}
```

The lineage graph supports the queries: *who currently has access*, *who shared with whom*, *what was the depth*, *was a node permitted to reshare and did they*.

### 5.3 Depth limits & cycles
- Depth defaults to 1 (owner → one hop). Configurable per-tenant up to 3.
- Cycles are prevented: if `A → B → C` and `C` tries to reshare to `A`, the edge resolves to the existing `A` access; no new edge is written.
- Admins can disable resharing depth >0 entirely.

### 5.4 Reshare attempt flow

```
User taps Share on a file they received
    │
    ▼
Read edge.reshare_mode
    │
    ├── none ──────────────────► UI: "Resharing blocked by owner" (banner)
    ├── internal ──────────────► Allow internal recipients only; external rejected with explanation
    ├── group-only ────────────► Recipient picker scoped to share-group members
    ├── approval ──────────────► Submit reshare request → owner approves/rejects (notification + Now tab card)
    ├── external-prohibit ─────► External domains rejected
    ├── owner ─────────────────► Block immediately; suggest contacting owner
    ├── policy ────────────────► Server evaluates ABAC rules per recipient
    └── temp ──────────────────► Reshare allowed but expires at original.expires_at
```

Every attempt — allowed or blocked — emits an audit event.

---

## 6. Policy Evaluation Order

For every collaboration / share / reshare action the orchestrator evaluates in this order. **First failure stops the chain** and surfaces a user-readable explanation.

1. **RBAC** — does the user have the requested verb on the file?
2. **ABAC** — do user attributes (dept, role, clearance) match required?
3. **Classification labels** — does the action respect the file's label set (Local-Only, AI-Restricted, etc.)?
4. **DLP** — does the payload contain content disallowed for the action?
5. **Sovereignty** — is the target region/tenant allowed?
6. **Device posture** — is the device managed / trusted / patched?
7. **Workspace trust level** — is the workspace at the required trust tier?
8. **External domain trust** — is the recipient domain on the trust list?
9. **Time-based policies** — is the action within an allowed window?
10. **Reshare edge mode** — for resharing actions only, the `reshare_mode` on the originating edge.

Each failure carries `policy_id`, `human_explanation`, and (where available) an `escalation_url` that opens the appropriate request flow.

---

## 7. Audit Schema

Every collaboration, share, and reshare action emits a write-once audit event:

```json
{
  "audit_ref":     "aud_01HF9X…",
  "ts":            "2026-05-23T17:14:22Z",
  "actor":         { "user_id":"u_brian", "tenant":"ahs-prod-9d4e7", "device_id":"dev_iphone15p" },
  "surface":       "share_sheet",
  "intent":        "share.create | share.reshare | doc.edit | doc.comment | doc.approve | group.create | …",
  "target":        { "file_id":"f_4af2", "edge_id":"edg_01HF9X…", "group_id":"g_01HF9X…" },
  "policy_decisions": [
    { "gate":"rbac", "verdict":"allow" },
    { "gate":"reshare_mode", "verdict":"requires_approval" }
  ],
  "result":        "queued_for_approval | allowed | blocked",
  "context": {
    "edit_op_id":  "op_abc",
    "comment_id":  "cm_xyz",
    "from_edge":   "edg_…",
    "approval_id": "apr_…"
  }
}
```

Events are written to a tenant-isolated, append-only store. Admin queries: Profile → Admin → Audit Log Export.

---

## 8. Swift Surface (Illustrative)

### 8.1 Editability state

```swift
enum EditabilityState: String, CaseIterable {
    case editable, viewOnly, commentOnly, pendingApproval
    case restricted, expired, externalShared, localOnly, aiRestricted
}

struct DocumentEditability {
    let primary: EditabilityState
    let modifiers: Set<EditabilityState>
    let owner: User
    let workspace: Workspace
    let expiresAt: Date?
    let reshareMode: ReshareMode
    let explanation: String?
}
```

### 8.2 Collaboration view-model

```swift
@MainActor
final class DocumentCollabViewModel: ObservableObject {
    @Published var editability: DocumentEditability
    @Published var presence: [PresenceMember] = []
    @Published var comments: [Comment] = []
    @Published var pendingSuggestions: [Suggestion] = []
    @Published var version: VersionPointer
    @Published var trackChanges: Bool = false
    @Published var suggestingMode: Bool = false

    private let transport: CollabTransport
    private let policy: PolicyEngine
    private let crdt: Y.Doc

    func apply(_ edit: LocalEdit) async throws {
        try await policy.check(.docEdit, on: editability)
        crdt.apply(edit)
        try await transport.broadcast(edit)
    }
}
```

### 8.3 Resharing

```swift
enum ReshareMode: String { case none, internalOnly, groupOnly, approval, externalProhibit, owner, policy, temp }

struct ShareIntent {
    let fileId: FileID
    let recipients: [Recipient]
    let permissions: Set<Permission>
    let reshareMode: ReshareMode
    let expiresAt: Date?
    let autoCreateGroup: Bool
}

protocol ShareService {
    func share(_ intent: ShareIntent) async throws -> ShareResult
    func attemptReshare(edgeId: ShareEdgeID, to: [Recipient]) async throws -> ShareResult
    func revoke(edgeId: ShareEdgeID) async throws
}
```

`ShareResult` may be `.allowed(edges:)`, `.queuedForApproval(approval:)`, or `.blocked(reason:)`.

---

## 9. Backend API (Illustrative)

| Verb     | Path                                          | Purpose                                              |
| -------- | --------------------------------------------- | ---------------------------------------------------- |
| POST     | `/v3/files/{id}/share`                        | Create share edge(s); may also create auto-group.    |
| POST     | `/v3/files/{id}/share/{edgeId}/reshare`       | Attempt reshare from an existing edge.               |
| GET      | `/v3/files/{id}/lineage`                      | Return the share graph for the file.                 |
| GET      | `/v3/files/{id}/editability`                  | Computed state for the calling user (RTT cacheable). |
| POST     | `/v3/files/{id}/comments`                     | Create a comment.                                    |
| POST     | `/v3/files/{id}/suggestions`                  | Create a suggested edit.                             |
| POST     | `/v3/files/{id}/versions/{vid}:restore`       | Restore a prior version (creates a new version).     |
| POST     | `/v3/files/{id}/approval-requests`            | Move to Pending Approval.                            |
| POST     | `/v3/groups`                                  | Create a group (auto or manual).                     |
| GET      | `/v3/groups/{id}/members`                     | Membership snapshot.                                 |
| GET      | `/v3/audit?file={id}&since=…`                 | Audit feed for a file.                               |
| WSS      | `/v3/collab/{docId}`                          | CRDT + presence transport.                           |

Every endpoint enforces the policy chain from §6 and writes audit events per §7.

---

## 10. Admin Controls (Profile → Admin)

The Admin subsection (already in the prototype) gains a "Collaboration & Sharing" group with these toggles/inputs:

- **Disable external resharing** (`reshare_mode.external_*` forbidden tenant-wide).
- **Restrict auto-group creation** (off / require user opt-in / off entirely).
- **Resharing depth limit** (0 / 1 / 2 / 3).
- **Require approval for** [classifications: Restricted, PHI].
- **Force expiration** for shares of [classifications]. Default 7 days.
- **Group lifecycle policy** — auto-archive groups with no activity for N days.
- **Restrict editing by classification** — e.g., PHI documents are View Only on personal devices.
- **Audit collaboration chains** — direct link to a per-file lineage + audit timeline view.

---

## 11. AI Integration (cross-ref `AI_COMPOSITION_SPEC.md`)

The AI Sharing Assistant in the share sheet uses the same orchestrator. Its responsibilities:

- **Suggest reshare mode** based on classification + recipient mix.
- **Suggest expiration** matching tenant policy maxima.
- **Detect overexposure** (more recipients than the AI thinks the task needs).
- **Suggest tightening** when users grant write but only read is needed.
- **Warn against risky resharing** (e.g., recipient in an external domain that has historically leaked).

Every AI suggestion is advisory — it cannot bypass policy. When the user applies a suggestion, the corresponding action is logged with `intent: "share.ai_suggestion.applied"`.

---

## 12. Mapping to Phase 1 prototype

| Brief deliverable                                | Phase 1 status                                                                          |
| ------------------------------------------------ | --------------------------------------------------------------------------------------- |
| Editability states (9)                           | ✅ All 9 badges defined as CSS tokens; demonstrated on File Viewer + Doc Editor strips.  |
| Edit-state strip with owner / workspace / expiry / reshare info | ✅ Implemented on File Viewer (read-only) and Doc Editor (editable).                |
| Presence indicators                              | ✅ 3-avatar presence row + active dot in Doc Editor nav bar.                             |
| Live cursor tracking                             | 📄 Specified (presence envelope); not visualized in prototype.                          |
| Inline comments + counter chip                   | ✅ Chip with count in collab bar; comment side panel deferred.                           |
| Track Changes                                    | ✅ Toggle chip with state.                                                               |
| Suggested edits mode                             | ✅ "Suggesting" toggle chip.                                                             |
| Approval requests                                | ✅ Chip + canned modal explanation.                                                      |
| Version history + restore                        | ✅ Versions chip + canned modal preview; full UI deferred.                                |
| Secure autosave                                   | ⏳ Indicator placeholder; transport not implemented.                                     |
| Conflict resolution (offline)                    | 📄 Specified (CRDT + 3-pane diff for structured docs).                                  |
| Resharing modes (8)                              | ✅ Selector with all 8 modes in the share sheet.                                         |
| Share lineage                                    | ✅ Mini-tree preview in share sheet; full per-file Share Chain view deferred.            |
| Auto-create share group toggle + notice          | ✅ Toggle row + AI-card explanation.                                                     |
| Group types (6)                                  | 📄 Specified; existing prototype shows Workspace + Project groups in `s-groups`.        |
| Reshare warning + policy explanation             | ⏳ Partial — warnings included in AI assistant + edge-mode descriptions; standalone modal deferred. |
| AI Sharing Assistant                             | ✅ Card with overexposure, suggested expiry, suggested reshare, and apply actions.       |
| Policy evaluation order                          | 📄 Specified (10-step chain).                                                            |
| Audit schema for collaboration / share / reshare | 📄 Specified.                                                                            |
| Admin: disable external resharing, depth limit, etc. | 📄 Specified; existing Profile → Admin already has policy gates we'll extend.        |
| SwiftUI components (`DocumentCollabViewModel`, etc.) | 📄 Specified as illustrative protocols.                                              |
| Backend API endpoints                            | 📄 Specified.                                                                            |

---

## 13. Open Questions

1. **CRDT library choice.** Yjs (mature, JS-first; Swift port less mature) vs. Automerge (Rust core, Swift bindings exist). Lean Yjs unless Swift bridge maturity is a blocker.
2. **PDF annotation transport.** Are PDF annotations first-class structured ops or just embedded comments? Phase 2 decision.
3. **Group lifecycle for auto-groups.** Do they auto-delete when the share expires, or get archived? Default: archive (retains audit trail).
4. **Reshare depth default.** Tenants will want different defaults — proposing per-tenant config in `Profile → Admin`.
5. **Suggested-edits approval routing.** Owner-only? Designated reviewers? Tenant policy? Lean: owner by default, override per-doc.
6. **Real-time presence on tactical/disconnected devices.** Reduce to "last-seen N minutes ago" instead of live? Phase 1 says yes; Phase 2 may allow opportunistic local-mesh presence.

---

*Last updated: 2026-05-23.*
