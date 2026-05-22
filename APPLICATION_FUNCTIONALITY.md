# XQ Secure Workspaces (iOS) — Application Functionality

A functional reference for what the app does, organized by what a user can actually accomplish. Grounded in the current clickable prototype (`prototype/index.html`) and the Phase 1 Swift module structure under `ios/XQSecureWorkspaces/`.

---

## 1. What the App Is

XQ Secure Workspaces is a **secure, AI-governed file workspace for iOS and iPadOS**. It encrypts, classifies, shares, and audits sensitive content **on-device**, so users get enterprise-grade data protection without manual classification, IT involvement, or training.

It serves two distinct audiences from a single app:

- **Consumer / local-first** — privacy-conscious individuals (no account, no SSO, no cloud dependency). Files live in an encrypted on-device vault.
- **Enterprise** — employees on managed devices whose org has connected XQ to **SharePoint** and **Entra ID** (or Okta). Files inherit governance policy automatically.

The product bet: **security is ambient.** The on-device AI continuously classifies content, encrypts at the edge, and enforces policy as background behavior — not as user workflow.

---

## 2. Primary Users and What They Do

| User                 | What they want                                                                                  | How the app delivers                                                            |
| -------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Consumer             | Protect sensitive personal files without setup. Share selectively. Stay offline-safe.           | Local-first onboarding (under 60s), encrypted vault, revocable shares.          |
| Enterprise user      | Open SharePoint files on mobile under the same governance rules as desktop. Don't think about it. | SSO login, automatic SharePoint mount, AI-applied sharing controls.              |
| Enterprise admin     | Define classification schemas, enforce DLP, audit everything, revoke instantly.                 | Policy management screen, full event log, revocation that reaches offline caches. |

---

## 3. Navigation Model

The app uses a **5-tab bottom navigation** as its primary surface:

| Tab      | Screen ID            | Purpose                                                  |
| -------- | -------------------- | -------------------------------------------------------- |
| Home     | `s-home`             | AI briefing, priority actions, workspace insights.       |
| Files    | `s-file-browser`     | Folder/recent/shared/vault views of all protected files. |
| Email    | `s-email-inbox`      | Secure, policy-reviewed mail with phishing/PHI scanning. |
| Sharing  | `s-sharing`          | Outgoing shares, expirations, revocations.               |
| Settings | `s-settings`         | Policy, security, AI model config, theme, display mode.  |

Secondary screens (file viewer, doc editor, compose, semantic search, risk dashboard, lineage, notifications, etc.) are reached from these tabs.

---

## 4. Onboarding

Two parallel paths, surfaced on the **Welcome** screen (`s-welcome`):

### 4.1 Local-First (Consumer)
1. `s-welcome` → "Start for Free"
2. `s-repo-setup` — choose where files live (local vault default; iCloud Drive optional).
3. `s-permissions` — Photos, Files, Notifications, Biometrics. AI guidance explains *why* each permission is needed.
4. Land on `s-home`. No account created. No data leaves the device.

### 4.2 Enterprise (SSO)
1. `s-welcome` → "Connect Enterprise Workspace"
2. `s-enterprise-auth` — Entra / Okta SSO flow.
3. `s-workgroup-select` — pick from organizational workspaces returned by directory.
4. `s-permissions` — same as above plus enterprise data scopes.
5. SharePoint sites auto-mount; user lands on `s-home`.

---

## 5. Home — AI-Driven Operational Surface (`s-home`)

The home screen is **not** a launcher — it's an actionable digest:

- **XQ AI Assistant command bar** — natural-language entry into semantic search and quick actions ("Files at risk", "Pending approvals", "Revoke shares", "Cleanup").
- **AI Daily Briefing** — a 1–3 sentence summary of overnight events: expiring shares, drafts needing policy review, unrecognized-device accesses.
- **Priority Actions** — color-coded cards (Restricted/Confidential/Internal) that link directly to the screen where the action lives.
- **AI Workspace Insights** — counters: vault files, unread secure messages, high-risk shares, vault health status.
- **Quick Access** — fast paths to Files, Email, AI Import, Sharing.
- **Recent Files** — last opened items with classification badge.

---

## 6. File Vault (`s-file-browser`, `s-folder-view`, `s-file-viewer`)

### 6.1 Browser
Four sub-tabs inside Files:
- **Folders** — workspace-organized view (e.g., *Finance & Legal*, *Personal*).
- **Recent** — chronological access list.
- **Shared** — files shared with the user.
- **Vault** — the encrypted local-only container.

Grid view is the default; list view available. AI-generated smart folders ("AI Organize", `s-ai-organize`) propose groupings the user can accept.

### 6.2 File Viewer (`s-file-viewer`)
- **Secure container** — screenshots blocked (`s-screenshot-block` interstitial appears on attempted capture).
- **Security Intelligence Panel (SIP)** — collapsible bar showing:
  - Classification (Restricted / Confidential / Internal / Public — default minimized per current setting).
  - Threat scan results.
  - **Data lineage** (`s-data-lineage`) — full provenance: source, edits, who accessed, where.
- **Share Securely** action → opens the secure share sheet (AES-256-GCM, key in Secure Enclave).

### 6.3 Document Editor (`s-doc-editor`)
- View and Edit modes for Word, Excel, and similar.
- Edits saved back to source (SharePoint or vault) without the plaintext touching uncontrolled local storage.

### 6.4 AI Import (`s-ai-import`)
- User picks a file from Photos/Files; AI classifies and routes it to the right folder/policy before storage.

### 6.5 AI Risk Dashboard (`s-file-risk-dashboard`)
- On-device scan results: credential leaks, PHI, stale permissions, policy drift — with per-issue remediation.

### 6.6 Semantic Search (`s-semantic-search`)
- Natural language: *"show me Q4 budget docs I shared externally"* — runs against on-device embeddings.

---

## 7. Email (`s-email-inbox`, `s-email-thread`, `s-email-compose`, `s-phishing-alert`)

A **secure mail client** layered on top of the user's existing inbox:

- **Inbox** — threaded view with classification badges per message.
- **Thread view** — message history with inline risk context.
- **Phishing alert / Risk Analysis** (`s-phishing-alert`) — AI flags suspicious senders, malicious links, and credential-harvesting patterns. Drill-down view explains the signal.
- **Secure compose** (`s-email-compose`) — pre-send AI scan for:
  - External recipient warnings.
  - Tone/sentiment check.
  - **Commitments** detector (flags promissory language).
  - PHI/PII risk score.
- Attachments sent via secure share, not raw inline.

---

## 8. Sharing (`s-sharing`, `s-received-share`, `s-group-invite`)

The Sharing tab is the **control surface for what's left the device**:

- List of outgoing shares with: recipient, expiration, file, classification, geofence (if any), view-only flag.
- **Renew / Revoke** actions per share.
- **Received Share** view (`s-received-share`) — what others sent to you (decryption requires the XQ app).
- **Group invite** flow (`s-group-invite`) — accept/decline workgroup invitations with policy preview.

Sharing rules are AI-applied based on file classification and recipient — user does not pick controls manually unless overriding.

---

## 9. Notifications (`s-notifications`)

Five sub-tabs:
- **Overview** — combined feed.
- **Activity** — file/share/access events.
- **Security** — policy violations, unrecognized devices, phishing flags.
- **Shared** — incoming share notifications.
- **AI Actions** — pending or completed AI-suggested operations (cleanup, reclassification, expiry rotation).

---

## 10. Settings (`s-settings`, `s-policy`)

- **Display Mode** — Expanded vs **Minimized** (default). Minimized collapses AI/security banners into compact pills; tap to expand inline.
- **Policy Management** (`s-policy`, admin variant) — classification schemas, sharing defaults, geofencing, external recipient rules.
- **Security** — biometric lock, jailbreak detection state, AES-256-GCM / Secure Enclave status, CoreML model version (e.g., *3 loaded · 80 MB*).
- **Theme** — light / dark / system.

---

## 11. AI Assistant (`s-ai-assistant`)

A standalone conversational surface (also embedded in the Home command bar) for:
- Workspace Q&A ("which files have I shared externally this month?").
- Performing actions on request ("revoke all shares to dr.chen@acme.com").
- Explaining security decisions ("why is this file marked Restricted?").

All inference runs **on-device** via CoreML/ONNX models — no content sent to a server for classification.

---

## 12. Security Model (Surfaced to the User)

| Capability                | User-visible signal                                              |
| ------------------------- | --------------------------------------------------------------- |
| AES-256-GCM at rest       | "Vault Secured" tile on Home; SIP on each file.                  |
| Secure Enclave key custody | Mentioned in Help Chat and Settings.                             |
| Screenshot blocking       | `s-screenshot-block` interstitial.                               |
| Jailbreak detection       | Surface in Settings; can fail-closed per enterprise policy.     |
| Offline queue             | Actions taken offline persist and replay on reconnect.           |
| Revocation reaches cache  | Receiving devices invalidate cached ciphertext on revoke.        |
| Zero-knowledge share keys | Key exchange detail noted in Help Chat; server holds only ciphertext. |

---

## 13. Help Chat

A persistent help surface (knowledge-base backed) that answers questions like *"how do I encrypt a file?"*, *"what is a risk score?"*, *"how do I revoke a share?"* using the same vocabulary the UI uses, so users learn the app by using it.

---

## 14. Module-to-Feature Mapping (Swift)

The native iOS code lives under `ios/XQSecureWorkspaces/Modules/`. Top-level module folders correspond roughly to the functional areas above:

| Module folder              | Functionality                                          |
| -------------------------- | ----------------------------------------------------- |
| `UI/Screens/Home`          | Home dashboard, AI briefing, priority cards.          |
| `UI/Screens/FileBrowser`   | File grid/list, folder views, sub-tabs.               |
| `UI/Screens/FileViewer`    | Secure viewer, SIP, secure share sheet.               |
| `UI/Screens/Email`         | Inbox, thread, compose with policy scanning.          |
| `UI/Screens/Sharing`       | Outgoing share management, revocation.                |
| `UI/Screens/AIImport`      | Classify-on-import flow.                              |
| `UI/Screens/AI`            | AI assistant surface.                                 |
| `UI/Screens/Auth`          | SSO and local onboarding entry.                       |
| `UI/Screens/Onboarding`    | Welcome, repo setup, permissions.                     |
| `UI/Screens/Workgroup`     | Workgroup selection and invites.                      |
| `UI/Screens/Notifications` | Activity / security / shared / AI action feeds.       |
| `UI/Screens/Settings`      | Policy, security, AI model, display mode.             |
| `Security`                 | Jailbreak detection, key custody, crypto operations.  |
| `FileIntelligence`         | On-device classification, data lineage, risk scan.    |
| `Repository/Providers`     | Local vault, SharePoint, offline queue.               |
| `Networking/Adapters`      | XQ API v3 adapter and related transport.              |
| `Core/Models`              | Shared domain models.                                 |
| `Core/Protocols`           | Security & API contracts.                             |

---

## 15. What Phase 1 Explicitly Does NOT Cover

(For scope clarity — taken from the Phase 1 product analysis.)

- Multi-user real-time co-editing of documents.
- Cross-platform clients (macOS, Windows, Android) — iOS only in Phase 1.
- Admin web console — admin UX is the policy management screen embedded in the same app.
- Backup/restore of the local vault to a non-XQ destination.
- Generative content (drafting/rewriting) inside Email or Docs beyond risk analysis.

---

*Last updated: 2026-05-22.*
