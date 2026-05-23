# AI Composition Assistance — Architecture & Governance Spec

**Status:** Phase 1 draft. The UI is mocked in the clickable prototype (`prototype/index.html`); the orchestration, governance, and provider layers described here are the contract the Swift app and backend must implement.

**Companion docs:** `APPLICATION_FUNCTIONALITY.md` (screen-level functionality), `phase1-analysis/05-ai-integration.md` (broader AI-integration overview).

---

## 1. Goals

- Embedded, contextual AI assistance inside **Secure Email** and **Files** — never a standalone chatbot.
- **Zero-Trust by default.** Every prompt, retrieval, output, and policy decision is auditable.
- Lightweight, ambient UX: inline drawers, chips, streamed responses, no modal interruptions.
- Pluggable model backends (cloud + sovereign + on-device) with policy-driven routing.
- Works in tactical edge / air-gapped deployments.

---

## 2. Surfaces (Phase 1)

### 2.1 Email Compose — AI Drawer
Triggered by the **✦ AI** button in the formatting toolbar. Drawer contains:
- **Help Me Write** — natural-language prompt input; produces a draft.
- **Rewrite Selection** — 5 chips: Professional · Concise · Executive · Friendly · Technical.
- **Quick Actions** — Subject Ideas · Summarize Thread · Extract Actions · Meeting Follow-up · Translate.
- **Streamed output** with **Insert into draft** action.
- **Governance footer** — local-only badge, label inheritance, audit indicator.

### 2.2 Email Thread — In-context AI
Existing AI Thread Summary card remains. New (future) entries: suggested replies row above the reply composer; phishing/risk inline as today.

### 2.3 File Viewer — Document Assistant Panel
Triggered by the **✦ AI** button in the viewer nav bar. Slides up from bottom; max 62% of viewport:
- **Ask About This Document** input (contextual Q&A against the open file).
- **Actions** — Executive Summary · Extract Tasks · Auto-tag · Suggest Classification · Risk Analysis · Redact PHI.
- **Streamed output** with governance footer (local-only, lineage recorded, label inheritance).

### 2.4 Files List — AI surfaces
The Files header search bar already routes to the Now → Ask sub-tab (canonical AI surface). A future floating **✦ Ask AI** FAB is reserved (CSS defined; insertion deferred to keep Phase 1 focused).

---

## 3. Orchestration Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          iOS Client (XQ App)                         │
│                                                                      │
│  Email Compose AI Drawer    File Viewer AI Panel    AI Tab (Now/Ask) │
│         │                          │                       │         │
│         └──────────────┬───────────┴───────────────────────┘         │
│                        │                                             │
│             AICompositionService (Swift)                             │
│               · request envelope assembly                            │
│               · streaming receive                                    │
│               · client-side policy guards                            │
│               · result label inheritance                             │
└────────────────────────┬─────────────────────────────────────────────┘
                         │  Signed request envelope (mTLS + JWT)
                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     XQ Orchestration Layer                           │
│                                                                      │
│   Prompt Enrichment ─► Policy Gate ─► RAG (authorized sources only)  │
│                                │                                     │
│                                ▼                                     │
│                        Model Router (sovereignty-aware)              │
│                                │                                     │
│           ┌────────────┬───────┴────────┬──────────────┐             │
│           ▼            ▼                ▼              ▼             │
│      OpenAI       Azure OpenAI    Anthropic      Sovereign /         │
│      (managed)    (tenanted)      (managed)      Local LLM           │
│                                                                      │
│                       Result Filter ◄────────── streamed tokens      │
│                                │                                     │
│                                ▼                                     │
│                Label Inheritance + Audit Log Write                   │
└──────────────────────────────────────────────────────────────────────┘
```

**Rule:** the client **never** talks to a model provider directly. Every request goes through the XQ orchestrator. Provider keys live only on the orchestrator.

### 3.1 Request Envelope (illustrative)

```json
{
  "request_id":  "req_01HF9X…",
  "user":        { "id": "u_brian", "tenant": "ahs-prod-9d4e7" },
  "actor":       { "role": "enterprise_admin", "workspace": "acme-clinical" },
  "surface":     "email_compose",
  "intent":      "rewrite.professional",
  "context": {
    "subject":    "Patient discharge summary — URGENT",
    "body_id":    "compose_draft_abc",
    "recipients": ["carol.thomas@hospital.org"],
    "attachments": [{ "fid": "f_4af2", "class": "Restricted-PHI" }]
  },
  "policy_hint": { "classification": "Restricted-PHI", "external_recipient": true },
  "stream":      true
}
```

### 3.2 Response Envelope (per streamed chunk)

```json
{
  "request_id":   "req_01HF9X…",
  "kind":         "token",
  "delta":        "...",
  "inherit_labels": ["Restricted", "PHI"],
  "audit_ref":    "aud_01HF9X…"
}
```

`kind` values: `token` | `done` | `error` | `policy_blocked` | `needs_approval`. A terminal `policy_blocked` carries `reason_code`, `human_explanation`, and `escalation_url`.

---

## 4. Governance Model

### 4.1 Pre-inference policy gates
The orchestrator runs these checks **before any model is called**:

| Gate              | Behavior                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| RBAC / ABAC       | User must have view permission on every source document referenced in the prompt.                  |
| Workspace scope   | Only workspaces the user is a member of can supply context.                                        |
| Label gating      | Documents labeled `Local-Only` or `CUI/PHI` cannot leave the device — request is routed to local LLM. |
| Retention rules   | Sources past retention cannot be used as RAG context.                                              |
| Sovereignty       | Tenant-pinned sovereign provider chosen when policy requires.                                      |
| DLP               | Outbound prompt scanned for sensitive content per tenant DLP rules.                                |

Failed gate → request stops; user sees a banner explaining what was blocked and (when applicable) an `Request escalation →` link.

### 4.2 Post-inference filters
Before streaming reaches the user:

- **Content filter** — strip any model output that violates DLP (e.g., a hallucinated SSN).
- **Label inheritance** — every output inherits the maximum-sensitivity label of any source used. If `Restricted-PHI` was in the prompt, the output is `Restricted-PHI`.
- **Watermark / provenance tag** — output carries `audit_ref` for downstream tracing.

### 4.3 Audit log (write-once)
Every interaction emits:

```json
{
  "audit_ref":    "aud_01HF9X…",
  "request_id":   "req_01HF9X…",
  "ts":           "2026-05-23T17:14:22Z",
  "user_id":      "u_brian",
  "tenant":       "ahs-prod-9d4e7",
  "surface":      "email_compose",
  "intent":       "rewrite.professional",
  "model_id":     "azure-openai/gpt-4o-mini",
  "provider":     "azure_openai",
  "region":       "us-west",
  "sources":      [{ "fid": "f_4af2", "tokens_used": 312 }],
  "policy_decisions": [{ "gate": "label", "verdict": "downgrade_to_local" }],
  "tokens_in":    784,
  "tokens_out":   211,
  "ms_total":     1432,
  "output_labels": ["Restricted", "PHI"]
}
```

Logs are written to a tenant-isolated, append-only store. Admins query via Profile → Admin → Audit Log Export.

---

## 5. Model Provider Architecture

### 5.1 Routing matrix

| Classification of inputs | Preferred provider                       | Fallback              |
| ------------------------ | ---------------------------------------- | --------------------- |
| Public, Internal         | Cloud (Azure OpenAI / OpenAI / Anthropic) | Local LLM             |
| Confidential             | Tenanted Azure OpenAI in tenant region   | Local LLM             |
| Restricted               | Local LLM (CoreML / ONNX on-device)      | None (no cloud fallback) |
| CUI / PHI                | Local LLM, **always**                    | None                  |
| Sovereign tenant         | Tenant-specified sovereign endpoint      | None                  |
| Air-gapped deployment    | Local LLM, **always**                    | None                  |

The router is configured per-tenant by the admin in Profile → Admin → AI Policy Gates. The Cloud AI Processing toggle there is the master gate; CUI/PHI = Local-Only Always is **hardcoded** and cannot be overridden.

### 5.2 Provider plugin contract (Swift, illustrative)

```swift
protocol AIProvider {
    var id: String { get }
    var supportsStreaming: Bool { get }
    var residencyRegion: ResidencyRegion { get }

    func send(envelope: RequestEnvelope) async throws -> AsyncThrowingStream<ResponseChunk, Error>
    func capabilities() -> ProviderCapabilities
}
```

Provider implementations: `OpenAIProvider`, `AzureOpenAIProvider`, `AnthropicProvider`, `LocalCoreMLProvider`, `LocalLlamaProvider`, `SovereignHTTPProvider`. The orchestrator instantiates whichever matches the routing decision; the client only sees `AsyncThrowingStream<ResponseChunk, Error>`.

### 5.3 SwiftUI client surface (illustrative)

```swift
@MainActor
final class AICompositionViewModel: ObservableObject {
    @Published var output: AttributedString = ""
    @Published var isStreaming = false
    @Published var policyBanner: PolicyBlock? = nil
    @Published var outputLabels: [SensitivityLabel] = []

    private let service: AICompositionService

    func run(intent: AIIntent, context: AIContext) async {
        isStreaming = true; defer { isStreaming = false }
        do {
            for try await chunk in try await service.send(intent: intent, context: context) {
                switch chunk.kind {
                case .token: output.append(AttributedString(chunk.delta ?? ""))
                case .done:  outputLabels = chunk.inheritLabels
                case .policyBlocked: policyBanner = chunk.policyBlock
                default: break
                }
            }
        } catch { /* surface to UI */ }
    }
}
```

UI views: `EmailComposeAIDrawer`, `FileViewerAIPanel`, `AskTabView`. All bind to the same view-model contract — the surface differs, the protocol does not.

---

## 6. RAG (Retrieval-Augmented Generation)

- **Index scope:** every retrieval is scoped to the documents the calling user has read access to **at request time** (not at index time). Permissions changes propagate immediately.
- **Tenant isolation:** indices are partitioned per tenant; cross-tenant retrieval is impossible.
- **Embedding model:** runs locally on-device for `Local-Only` documents; runs in the tenant's region otherwise.
- **Source attribution:** every chunk used appears in the response envelope and the audit log; the UI shows `Source: <filename>, p.<N>` after the answer.
- **Index lifecycle:** retention rules and document deletions cascade to the vector store within 60 seconds (SLA).

---

## 7. Edge / Air-Gapped Deployment

- **Local LLM bundle:** XQ ships a quantized model bundle (CoreML / GGUF) sized for iPad Pro (~3B params Phase 1; 7B for M-series). Profile → General → About shows `CoreML Models · 3 loaded · 80 MB`.
- **No remote calls:** in air-gapped mode the orchestrator runs on-device entirely. No telemetry leaves the device until a sync window.
- **Sync windows:** when a connection becomes available, audit logs and (allowed) telemetry sync to the tenant's log sink in batches. Synced events are flagged `replay=true` so they don't double-count metrics.
- **Mode indicator:** the AI drawer's `Local-only` badge is shown when running locally.

---

## 8. UX Patterns

### 8.1 Provenance & confidence cues
- Every AI surface shows a `● On-device` or `● Tenant region` badge based on the actual provider used.
- For Q&A outputs, low-confidence answers are tagged `Low confidence — verify` and surface the underlying source row.

### 8.2 Streaming
- Tokens render as they arrive. The text element gets the `.ai-stream` class (animated caret); the class is removed on stream end.
- Hard cap: 30 seconds per request. After that, the orchestrator returns `kind: "error"` and the UI shows "Inference timed out — try a shorter prompt."

### 8.3 Policy banners
- Blocked requests show a single-line warning in the drawer with the specific reason from the policy decision. Example: "Cloud AI is disabled for Restricted content. This request was rerouted to on-device inference."

### 8.4 Human approval workflows
- For actions tagged `high_risk` (e.g., draft a message to all external partners), the orchestrator returns `kind: "needs_approval"` and the UI shows an "Approve & send →" CTA that routes to the admin queue.

---

## 9. Telemetry

The prototype includes none — but the production telemetry must be:

- **Per-tenant isolated.**
- **Differential-privacy enabled** for cross-tenant aggregates that admins opt into.
- **Schema-stable:** every event carries `event_version`, `tenant_id`, `redacted: true|false`.
- **Sampling-controlled:** model usage events 1.0, audit events 1.0, UX engagement events 0.05 by default.

---

## 10. Mapping to the Phase 1 prototype

| Brief deliverable                          | Phase 1 status                                                                                  |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Inline compose assistance                  | ✅ Compose AI drawer with rewrites, quick actions, streaming.                                    |
| Help Me Write                              | ✅ Drawer input + draft generation.                                                              |
| Rewrite actions (5 styles)                 | ✅ Implemented (Professional / Concise / Executive / Friendly / Technical).                      |
| Summarize threads / extract actions / followup / translate | ✅ Quick-action chips with canned outputs.                                       |
| Ghost-text predictive drafting              | ❌ Deferred — needs real model.                                                                  |
| Suggested replies                          | ❌ Deferred — UI surface reserved in Email Thread.                                               |
| Sensitive content detection / DLP send warning | ✅ Existing pre-send classification overlay covers this.                                    |
| AI-generated subject lines                 | ✅ Subject Ideas chip.                                                                           |
| Tone analysis                              | ✅ Existing `#compose-tone-bar`.                                                                 |
| Files: AI doc creation / Q&A / summary / auto-tag / classify / risk / redact | ✅ File viewer AI panel.                            |
| Multi-document synthesis                   | ❌ Deferred — Files browser surface.                                                              |
| Contextual recommendations                  | ⏳ Partial — surfaced in Now → Ask + per-document panel.                                         |
| Pluggable provider architecture            | 📄 Specified above; implementation in Swift orchestrator.                                       |
| Tenant-isolated inference, sovereign routing | 📄 Specified above.                                                                            |
| Streaming                                  | ✅ UI shows token-by-token render (canned mock).                                                 |
| RAG against authorized data                | 📄 Specified above.                                                                              |
| Full audit logging                         | 📄 Specified above (schema).                                                                     |
| Local-only inference for sensitive content | 📄 Specified above (routing matrix).                                                             |
| Admin governance UI                        | ⏳ Partial — Profile → Admin has policy gates, audit log export, AI policy gates; no full UI yet. |
| Offline / air-gapped support               | 📄 Specified above.                                                                              |

---

## 11. Open Questions for Architecture Review

1. **Local LLM bundle size cap.** What's the max footprint we'll ship by default vs. download-on-demand? Affects cold-start UX.
2. **Sovereign provider onboarding.** How does a tenant register their own endpoint? Self-serve form or admin-mediated?
3. **Streaming over weak networks (tactical).** Do we degrade to non-streaming or chunked-and-buffered?
4. **Multi-document synthesis permissions.** When a user references two documents and only has access to one, do we (a) fail closed, (b) silently drop the unauthorized one, or (c) tell the user "1 source omitted (no access)"? Phase 1 spec says (c).
5. **Approval workflows.** Inline (within the drawer) or routed to a separate Approvals queue? Both? Phase 1 spec leans inline with optional admin queue.

---

*Last updated: 2026-05-23.*
