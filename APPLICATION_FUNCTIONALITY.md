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
| Enterprise admin     | Define classification schemas, enforce DLP, audit everything, revoke instantly.                 | Policy management embedded in Profile > Admin, full event log, revocation that reaches offline caches. |

---

## 3. Navigation Model

The app uses a **3-tab bottom navigation** plus a **top-right avatar** for Profile:

| Tab      | Screen ID            | Purpose                                                                          |
| -------- | -------------------- | -------------------------------------------------------------------------------- |
| Files    | `s-file-browser`     | Folder / Recent / Shared / Vault views of all protected files.                   |
| Messages | `s-email-inbox`      | Secure, policy-reviewed mail with phishing/PHI scanning. Includes Sharing.       |
| Now      | `s-notifications`    | Dashboard-style alerts feed + embedded AI assistant + activity + security feeds. |

**Top-right `BW` avatar** on every top-level screen opens **Profile** (`s-profile`) — the single entry point for account, security, notifications, integrations, workspace info, devices, billing, and admin (see §10). Settings as a separate tab no longer exists.

Secondary screens (file viewer, doc editor, compose, risk dashboard, lineage, sharing, etc.) are reached from the three tabs. The old dedicated AI tab and Semantic Search screen have been merged into Now → **Ask** sub-tab; `go('s-ai-assistant')` and `go('s-semantic-search')` automatically route there.

---

## 4. Onboarding

Two parallel paths, surfaced on the **Welcome** screen (`s-welcome`). The path chosen is persisted in `localStorage` (`xq.onbPath`) so back-navigation behaves correctly.

### 4.1 Local-First (Personal / Consumer)
1. `s-welcome` → "Start for Free" → `onbStart('personal')`
2. `s-repo-setup` — choose where files live (local vault default; iCloud Drive optional).
3. `s-permissions` — Photos, Files, Notifications, Biometrics. AI guidance explains *why* each permission is needed.
4. Land on the Now tab. No account created. No data leaves the device.

> The Select Workspace screen is **skipped** entirely for personal onboarding.

### 4.2 Enterprise (SSO)
1. `s-welcome` → "Connect Enterprise Workspace" → `onbStart('enterprise')`
2. `s-enterprise-auth` — Entra / Okta SSO flow.
3. `s-workgroup-select` — pick from organizational workspaces returned by directory.
4. `s-permissions` — same as above plus enterprise data scopes.
5. SharePoint sites auto-mount; user lands on the Now tab.

---

## 5. Now — The Home Surface (`s-notifications`)

"Now" is the default landing screen and serves as the actionable dashboard. It uses **four sub-tabs**:

### 5.1 Overview
- **Trust status pill** — "Workspace protected · scanned just now" with item counts.
- **Today feed** — chronological recent events (encrypted files added, secure email, vault scan, policy bundle updates).
- **Needs Your Attention** — single-row action cards (expiring shares, incoming received shares, externally shared docs to review).
- **Suggested** — AI-proposed actions (apply labels, etc.) with a "See all →" link into Activity.

### 5.2 Ask (✦)
The AI assistant lives here. Sub-tab contains:
- Gradient ✦ icon + "XQ AI Assistant" header.
- "Encrypted workspace intelligence" intro.
- Three capability cards (File Intelligence, Risk Analysis, Email Compliance).
- Four "Try Asking" prompt buttons (Which files contain PHI?, Show files expiring this week, Summarize my security posture, Who can access my Q4 Report?).
- Chat scroll area (`#ai-messages`) with sticky chat input at the bottom — Enter-to-send.

All inference runs **on-device** via CoreML/ONNX models. Search bars in Files and Email also route here.

### 5.3 Activity
File / share / access events feed.

### 5.4 Security
Policy violations, unrecognized devices, phishing flags.

---

## 6. File Vault (`s-file-browser`, `s-folder-view`, `s-file-viewer`)

### 6.1 Browser
Four sub-tabs inside Files: **Folders / Recent / Shared / Vault**. A search bar at the top routes to the AI assistant (Now → Ask) for natural-language find. AI-generated smart folders ("AI Organize", `s-ai-organize`) propose groupings the user can accept.

Defaults to All Sources + Grid view (the legacy smart-view chip row and grid/list/tree toggle were removed for visual calm).

### 6.2 File Viewer (`s-file-viewer`)
- **Secure container** — screenshots blocked (`s-screenshot-block` interstitial appears on attempted capture).
- **Security Intelligence Panel (SIP)** — collapsible bar showing:
  - Classification (Restricted / Confidential / Internal / Public — default minimized per current Display Mode setting).
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

---

## 7. Email (`s-email-inbox`, `s-email-thread`, `s-email-compose`, `s-phishing-alert`)

A **secure mail client** layered on top of the user's existing inbox:

- **Inbox** — threaded view with classification badges per message. Search bar routes to the AI assistant (Now → Ask).
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

The Sharing screen (reachable from Messages and from Now's action cards) is the **control surface for what's left the device**:

- List of outgoing shares with: recipient, expiration, file, classification, geofence (if any), view-only flag.
- **Renew / Revoke** actions per share.
- **Received Share** view (`s-received-share`) — what others sent to you (decryption requires the XQ app).
- **Group invite** flow (`s-group-invite`) — accept/decline workgroup invitations with policy preview.

Sharing rules are AI-applied based on file classification and recipient — the user does not pick controls manually unless overriding.

---

## 9. Workgroups (`s-groups`, `s-workgroup-select`)

A user can belong to multiple workspaces (e.g., *Acme Health — Clinical*, *Acme Legal*, *Acme Finance*, *Personal Vault*). Workgroup management lives under **Profile → Workspace** (§10.5). The in-app workspace switcher screen (`s-workgroup-select`) lets the user change active workspace at any time; during onboarding it's only used by the enterprise path.

---

## 10. Profile (`s-profile`) — Command Center

Reached from the **top-right `BW` avatar** on every top-level screen (Files, Messages, Now, and the AI assistant inside Now).

The screen is laid out as a single vertical column:

1. **Identity card** — avatar, name, title ("Enterprise Admin · Compliance"), org ("Acme Health Systems"), Verified + Ent-Admin badges, last login (device + city).
2. **Security Health card** — four mini-tiles: MFA Enabled · Active Sessions · Policy Compliant · Encryption OK.
3. **Quick Actions** — Change Password · Manage Devices · Configure MFA · Audit Logs (each deep-links to the right subsection).
4. **Sticky quick-nav chip bar** — sticks to the top of the Profile scroll container once the identity block scrolls past. Used for fast jumps between subsections; chips smooth-scroll to anchors.
5. **Stacked subsections** — all subsections render in a single scrollable column, each with a heading. Last-viewed subsection is persisted in `localStorage` (`xq.profileSection`) and restored on re-entry.

The eight Profile subsections:

### 10.1 General
Account name / email / role / language / time zone. Theme picker (Light / Dark / Earth). Display Mode toggle (Expanded vs **Minimized** — minimized is the default; collapses AI/security banners into compact pills users can tap to expand). About (Version, XQ API status, Secure Enclave state, CoreML model count). Help Center / Contact Support / Privacy Policy entries.

### 10.2 Security
Multi-Factor Auth (Authenticator + TouchID). Biometric Lock. Auto-lock timer. Change Password. Recovery Codes. Transport & Storage status: Certificate Pinning, AES-256-GCM at rest, Secure Enclave key custody, Jailbreak Detection.

### 10.3 Notifications
In-app banner toggles for Phishing / PHI / Policy & Compliance / AI Intelligence panels. Channel toggles: Push, Email Digest (Weekly), Critical Alerts via SMS.

### 10.4 Integrations
Connected services: SharePoint, OneDrive, Entra ID (SSO), Outlook 365, Slack, Okta. Each shows connection state with a Connect/Disconnect/Manage action. API Keys & Access Tokens: personal API key (rotatable), audit-log export token, "Create New Token" button.

### 10.5 Workspace
Organization name, tenant ID, plan tier (ENTERPRISE), data residency, compliance posture (HIPAA · SOC 2 Type II). Workgroups list with member counts and policy badges; "Create Workgroup" action.

### 10.6 Devices
This device callout (iPhone 15 Pro, marked CURRENT). Other active sessions with per-session Revoke. "Sign out everywhere else" destructive action.

### 10.7 Billing
Subscription (Plan, Seats, Billing Cycle, Next Renewal). License Entitlements list (On-Device AI, Policy Management, SharePoint Connector, Advanced Audit Export). Payment: card on file, Invoices & Receipts.

### 10.8 Admin
Visible to Enterprise Admin role. Policy bundle signed-status banner. **Classification Rules** toggles (PHI / PII / Financial Data auto-detection). **Share Enforcement** (Block External PHI, Max Share Expiry, Require XQ for Recipients, Screenshot Detection). **AI Policy Gates** (Cloud AI Processing toggle + hardcoded CUI/PHI = Local-Only rule). **Tenant**: user count, Audit Log Export (Download CSV), link to the detailed policy editor (`s-policy`). Publish / Discard policy buttons.

---

## 11. Security Model (Surfaced to the User)

| Capability                | User-visible signal                                                |
| ------------------------- | ------------------------------------------------------------------ |
| AES-256-GCM at rest       | Security Health card in Profile; SIP on each file.                  |
| Secure Enclave key custody | Profile → Security · Profile → General → About.                    |
| Screenshot blocking       | `s-screenshot-block` interstitial.                                  |
| Jailbreak detection       | Profile → Security; can fail-closed per enterprise policy.          |
| Offline queue             | Actions taken offline persist and replay on reconnect.              |
| Revocation reaches cache  | Receiving devices invalidate cached ciphertext on revoke.           |
| Zero-knowledge share keys | Key exchange detail noted in Help Chat; server holds only ciphertext. |

---

## 12. Help Chat

A persistent help surface (knowledge-base backed) that answers questions like *"how do I encrypt a file?"*, *"what is a risk score?"*, *"how do I revoke a share?"* using the same vocabulary the UI uses, so users learn the app by using it.

---

## 13. Module-to-Feature Mapping (Swift)

The native iOS code lives under `ios/XQSecureWorkspaces/Modules/`. Top-level module folders correspond roughly to the functional areas above. (The Swift `Settings` module remains in source but now hosts the Profile UI — the prototype consolidated Settings + Policy into the single Profile surface; the native side will follow as it lands.)

| Module folder              | Functionality                                                  |
| -------------------------- | ------------------------------------------------------------- |
| `UI/Screens/FileBrowser`   | File grid/list, folder views, sub-tabs.                       |
| `UI/Screens/FileViewer`    | Secure viewer, SIP, secure share sheet.                       |
| `UI/Screens/Email`         | Inbox, thread, compose with policy scanning.                  |
| `UI/Screens/Sharing`       | Outgoing share management, revocation.                        |
| `UI/Screens/AIImport`      | Classify-on-import flow.                                      |
| `UI/Screens/AI`            | AI assistant surface (rendered inside the Now > Ask sub-tab). |
| `UI/Screens/Notifications` | Now dashboard: Overview / Ask / Activity / Security feeds.    |
| `UI/Screens/Settings`      | Profile screen (account, security, notifications, integrations, workspace, devices, billing, admin). |
| `UI/Screens/Auth`          | SSO and local onboarding entry.                               |
| `UI/Screens/Onboarding`    | Welcome, repo setup, permissions.                             |
| `UI/Screens/Workgroup`     | Workgroup selection and invites.                              |
| `UI/Screens/Home`          | Legacy home dashboard (now folded into Notifications).        |
| `Security`                 | Jailbreak detection, key custody, crypto operations.          |
| `FileIntelligence`         | On-device classification, data lineage, risk scan.            |
| `Repository/Providers`     | Local vault, SharePoint, offline queue.                       |
| `Networking/Adapters`      | XQ API v3 adapter and related transport.                      |
| `Core/Models`              | Shared domain models.                                         |
| `Core/Protocols`           | Security & API contracts.                                     |

---

## 14. Routing & Persistence Cheat Sheet

The prototype consolidates several legacy entry points via `go()` aliases — every prior link still works:

| Calls `go(...)` with | Actually shows                                  |
| -------------------- | ----------------------------------------------- |
| `s-home`             | `s-notifications` (Now tab is the home).        |
| `s-settings`         | `s-profile`.                                    |
| `s-ai-assistant`     | `s-notifications` + auto-switch to Ask sub-tab. |
| `s-semantic-search`  | `s-notifications` + auto-switch to Ask sub-tab. |

`localStorage` keys used by the prototype:

| Key                  | Values                                                                     | Purpose                                       |
| -------------------- | -------------------------------------------------------------------------- | --------------------------------------------- |
| `xq.notifMode`       | `expanded` \| `minimized` (default `minimized`)                             | Display Mode for in-context banners/pills.   |
| `xq.profileSection`  | `general` \| `security` \| `notifications` \| `integrations` \| `workspace` \| `devices` \| `billing` \| `admin` | Last-viewed Profile subsection.              |
| `xq.onbPath`         | `personal` \| `enterprise`                                                  | Active onboarding path; controls back-nav from Permissions and whether workspace-select is shown. |

---

## 15. What Phase 1 Explicitly Does NOT Cover

(For scope clarity — taken from the Phase 1 product analysis.)

- Multi-user real-time co-editing of documents.
- Cross-platform clients (macOS, Windows, Android) — iOS only in Phase 1.
- Admin web console — admin UX is the Profile → Admin subsection embedded in the same app.
- Backup/restore of the local vault to a non-XQ destination.
- Generative content (drafting/rewriting) inside Email or Docs beyond risk analysis.

---

*Last updated: 2026-05-23.*
