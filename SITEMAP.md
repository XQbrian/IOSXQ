# XQ Secure Workspaces — Prototype Sitemap

Navigation map of every screen, sub-tab, overlay, panel, and routing alias in the clickable prototype (`prototype/index.html`). Use this as the canonical reference for "where does X live and how do you get there".

Companion docs: `APPLICATION_FUNCTIONALITY.md`, `AI_COMPOSITION_SPEC.md`, `COLLABORATION_SHARING_SPEC.md`.

---

## Top-level navigation model

```
┌──────────────────────────────────────────────────────────────────────┐
│  Device-mode switcher (floating, bottom-left)                        │
│     Mobile · iPad · Desktop      (xq.deviceMode in localStorage)     │
└──────────────────────────────────────────────────────────────────────┘

┌───────────────────────────── Top of screen ──────────────────────────┐
│  Large title (Files / Messages / Now / Profile)                      │
│  Top-right [BW] avatar  →  Profile (universal entry on every tab)    │
└──────────────────────────────────────────────────────────────────────┘

┌───────────── Bottom tab bar (Mobile) or Sidebar rail (iPad/Desktop) ─┐
│  📁 Files       ✉️ Messages       🔔 Now                              │
└──────────────────────────────────────────────────────────────────────┘
```

- **Mobile mode** (default): 390×844 phone frame, 3-tab bottom nav.
- **iPad mode**: 1024×768 frame, 236px left sidebar rail (Files / Messages / Now + bottom-anchored Profile avatar).
- **Desktop mode**: 1440×900 frame, 264px sidebar rail; folder grid expands to 4 columns.

---

## 1. Onboarding paths

```
s-splash  ── splash() animation
   │
   ▼
s-welcome   "Start for Free"  ─►  onbStart('personal')
            "Connect Enterprise Workspace"  ─►  onbStart('enterprise')
```

### 1.1 Personal / local-first path
```
s-welcome  ─►  s-repo-setup  ─►  s-permissions  ─►  s-notifications (Now)
                                       ▲                    │
                                       └── (back: onbBack() ───── reads xq.onbPath)
```

### 1.2 Enterprise (SSO) path
```
s-welcome  ─►  s-enterprise-auth  ─►  s-workgroup-select  ─►  s-permissions  ─►  s-notifications (Now)
                                              ▲                    ▲
                                              └────────────────────┴── (back: onbBack())
```

> The **Select Workspace** step is skipped entirely for the personal path; only the enterprise path passes through `s-workgroup-select` during onboarding.

---

## 2. Now (`s-notifications`) — Home surface

Bottom-nav tab #3; also the destination of any `go('s-home')` call (legacy alias).

```
s-notifications
   ├── Sub-tab: Overview        (#nt-tab-overview)     — default landing
   ├── Sub-tab: ✦ Ask           (#nt-tab-ask)          — AI assistant
   ├── Sub-tab: Activity        (#nt-tab-activity)
   └── Sub-tab: Security        (#nt-tab-security)
```

**Overview** content includes:
- Trust status pill
- Today event feed (links into Files / Email / Profile→Admin)
- Needs Your Attention cards (links to `s-sharing`, `s-received-share`)
- Suggested AI actions ("See all →" → Activity sub-tab)

**Ask** content (the relocated former AI tab):
- ✦ XQ AI Assistant header + 3 capability cards
- Try Asking prompts
- `#ai-messages` streamed chat area
- Sticky chat input (`#ai-input`)

**From Now → can navigate to:** `s-file-browser`, `s-email-inbox`, `s-sharing`, `s-received-share`, `s-group-invite`, `s-groups`, `s-profile`.

---

## 3. Files (`s-file-browser`)

Bottom-nav tab #1. Contains four content sub-tabs and a fleet of detail screens.

```
s-file-browser
   ├── Header
   │     ├── Title "Files"
   │     ├── [+] button       ─►  Create / Import chooser overlay (create-menu)
   │     ├── [⚠️] risk button ─►  Risk Overview overlay (risk-overlay)
   │     ├── [⋯] more menu
   │     └── [BW] avatar       ─►  s-profile
   │
   ├── Search bar              ─►  Now → Ask sub-tab (canonical AI)
   │
   ├── Sub-tab: Folders        (#fb-tab-folders)   — default
   ├── Sub-tab: Recent         (#fb-tab-recent)
   ├── Sub-tab: Shared         (#fb-tab-shared)
   └── Sub-tab: Vault          (#fb-tab-vault)
```

### 3.1 + Create / Import chooser  (`#create-menu` overlay)

```
Create new:
   📄 Blank Document        ─►  s-doc-editor (Edit mode, "New Document" pill)
   📝 Memo
   📊 Report
   📅 Meeting Agenda
   ☑️ Structured Form

Import existing:
   ☁️ Import file           ─►  s-ai-import
```

### 3.2 File-list destinations

```
File row                                     Destination
─────────                                    ───────────
Editable doc (e.g. .docx)              ─►   s-doc-editor (Edit mode via openInEditor())
View-only file (e.g. .pdf)             ─►   s-file-viewer
Folder card                            ─►   s-folder-view
```

### 3.3 Files-related child screens

| Screen ID                 | Purpose                                                 |
| ------------------------- | ------------------------------------------------------- |
| `s-folder-view`           | Workspace folder detail (file list, breadcrumb, select). |
| `s-folder-empty`          | Empty-state for a brand-new folder.                     |
| `s-ai-organize`           | AI-suggested folder organization.                       |
| `s-ai-import`             | Import + on-device AI classification flow.              |
| `s-file-viewer`           | Dark secure viewer (PDFs, view-only docs).              |
| `s-doc-editor`            | Native editor (text/docx/markdown/reports/forms).       |
| `s-file-risk-dashboard`   | Full risk dashboard for a workspace.                     |
| `s-data-lineage`          | Per-file lineage / provenance graph.                    |
| `s-screenshot-block`      | Interstitial shown on screenshot attempt.               |

### 3.4 File Viewer (`s-file-viewer`) — anatomy

```
s-file-viewer  (dark theme)
   ├── Nav: ← Files | filename |  [✏️ Edit]  [✦ AI]  [↗ Share]
   │                                  │         │       │
   │                                  │         │       └─►  ssheet overlay
   │                                  │         └─►  fv-ai-panel (slide-up)
   │                                  └─►  s-doc-editor (Edit mode)
   ├── Edit-state strip   (badges + owner + workspace + expiry + Why → s-data-lineage)
   ├── Watermark
   ├── File content area
   └── Security & Intelligence Panel (SIP)
         ├── Data Protection
         ├── Risk / Threat Scan
         ├── AI Summary
         └── Lineage / Provenance         ─►  s-data-lineage
```

### 3.5 Doc Editor (`s-doc-editor`) — anatomy

```
s-doc-editor
   ├── Nav: ← Files | [presence row] |  [✦ New Document pill]  ↗ Share  Done
   │                       │
   │                       └── 3 collaborator avatars + active-dot
   ├── Edit-state strip   (Editable / Comments On / 1 External Editor · Lineage →)
   ├── Collab chip bar    (Track Changes · Suggesting · Comments [4] · Versions [12] · Request Approval)
   ├── Classification banner   ─►  Rescan ↻ → s-ai-import
   ├── View / Edit tab control
   ├── Formatting toolbar (edit mode only) + [✦ AI Assist] → doc AI panel
   └── Document page content (contentEditable in Edit mode)
```

---

## 4. Messages (`s-email-inbox`)

Bottom-nav tab #2.

```
s-email-inbox
   ├── Header
   │     ├── Title "Inbox"
   │     ├── [✏️] compose      ─►  s-email-compose
   │     └── [BW] avatar       ─►  s-profile
   │
   ├── Search bar              ─►  Now → Ask sub-tab
   │
   └── Email rows              ─►  s-email-thread
```

### 4.1 Email-related screens

| Screen ID            | Purpose                                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------- |
| `s-email-thread`     | Threaded message view with AI Thread Summary, sender intelligence, compliance controls.    |
| `s-phishing-alert`   | Risk Analysis drill-down for flagged messages.                                              |
| `s-email-compose`    | Compose surface (see below).                                                                 |

### 4.2 Email Compose (`s-email-compose`) — anatomy

```
s-email-compose
   ├── Nav: ← Cancel | "New Secure Message" |  Send
   ├── External-recipient warning banner (compose-ext-warning)
   ├── To / Cc / Bcc rows
   ├── Subject row
   ├── Encryption + From row
   ├── Formatting toolbar  + [✦ AI]  + [📎 Attach]
   │                          │
   │                          └─►  toggles compose-ai-drawer
   ├── ✦ AI Composition drawer  (compose-ai-drawer)  — HIDDEN by default
   │     ├── Help Me Write input
   │     ├── Rewrite chips: Professional / Concise / Executive / Friendly / Technical
   │     ├── Quick actions: Subject / Summarize Thread / Extract Actions / Follow-up / Translate
   │     ├── Streamed output  +  Insert into draft
   │     └── Governance footer (Local-only · Inherits Restricted · Audited)
   ├── Tone analysis bar (compose-tone-bar)
   ├── Commitments banner (compose-commitments)
   ├── AI Risk Score banner (compose-risk-score)
   ├── Body content
   ├── Attachment row
   └── [Send Encrypted Message]  →  compose-send-sheet overlay
```

---

## 5. Profile (`s-profile`) — Command center

Reached from the top-right [BW] avatar on every top-level screen. Legacy alias: `go('s-settings')` → `s-profile`.

```
s-profile
   ├── Identity card  (avatar, name, title, org, badges, last login)
   ├── Security Health card  (MFA · 3 Sessions · Compliant · Encryption)
   ├── Quick Actions  (Change Password · Manage Devices · Configure MFA · Audit Logs)
   ├── Sticky quick-nav chip bar  (General · Security · Notifications · Integrations · Workspace · Devices · Billing · Admin)
   └── Stacked subsections (anchored via #prf-sec-*; deep-link via goProfile())
```

### 5.1 Profile subsections

| Anchor ID                | Subsection      | Highlights                                                                                 |
| ------------------------ | --------------- | ----------------------------------------------------------------------------------------- |
| `#prf-sec-general`       | General         | Account, Theme (Light/Dark/Earth), Display Mode (Expanded/Minimized), About, Support.       |
| `#prf-sec-security`      | Security        | MFA, Biometric Lock, Auto-lock, Change Password, Recovery Codes, Cert Pinning, Enclave.    |
| `#prf-sec-notifications` | Notifications   | In-app banner toggles + channel toggles (Push, Email Digest, SMS).                          |
| `#prf-sec-integrations`  | Integrations    | SharePoint, OneDrive, Entra ID, Outlook 365, Slack, Okta + API keys & access tokens.       |
| `#prf-sec-workspace`     | Workspace       | Tenant info, residency, compliance posture, Workgroups (→ `s-groups`).                     |
| `#prf-sec-devices`       | Devices         | Current device, other active sessions (revocable), sign-out-everywhere.                     |
| `#prf-sec-billing`       | Billing         | Plan, seats, entitlements, payment method.                                                  |
| `#prf-sec-admin`         | Admin           | Policy bundle status, Classification/Share/AI policy gates, Tenant, Detailed Policy Editor → `s-policy`. |

---

## 6. Sharing — overlay flow

The Sharing tab destination is reachable from Now's action cards. The Share-Securely sheet is invoked from the File Viewer, Doc Editor, and Sharing screen.

### 6.1 `s-sharing` screen
Active shares list, expiring shares, revocation actions.

### 6.2 Share Securely sheet (`#ssheet` overlay)

```
ssheet  (4–5 steps, sStep(n))
   ├── ss1  Recipients  (People / Groups tab switch)
   │     │
   │     └── ss-people-tab  |  ss-groups-tab
   ├── ss2  AI Risk Analysis
   ├── ss3  Share Settings
   │     ├── AI Sharing Assistant card  (overexposure, suggested expiry/reshare, Apply…)
   │     ├── Resharing mode selector  (8 modes)
   │     │     None · Internal · Group-Only · Approval · External-Prohibited · Owner · Policy · Temporary
   │     ├── Settings card  (Expiry · Screenshot Detection · Require XQ · Audit Log · Auto-group toggle)
   │     └── Share lineage mini-tree preview
   ├── ss4  Done confirmation
   └── ss5  Admin Approval (escalation)
```

### 6.3 Other share-related screens

| Screen ID            | Purpose                                                  |
| -------------------- | -------------------------------------------------------- |
| `s-received-share`   | Incoming share preview / accept-decrypt flow.            |
| `s-group-invite`     | Workgroup invitation accept/decline.                     |

---

## 7. Workspaces / Groups

| Screen ID              | Purpose                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------- |
| `s-groups`             | Workspaces dashboard — Active Workspace card, Other Workspaces list, Pending Invites.            |
| `s-workgroup-select`   | Active-workspace switcher (also used in enterprise onboarding).                                  |
| `s-group-invite`       | Invitation acceptance flow (also see Sharing).                                                  |

Reachable from: Now → action cards, Profile → Workspace subsection, in-app workspace switch buttons.

---

## 8. AI surfaces (canonical + entry points)

```
                                          Now → Ask sub-tab
                                        (the canonical AI surface)
                                                  ▲
                ┌────────────────────────┬────────┴───────────────────────┐
                │                        │                                │
   go('s-ai-assistant')        go('s-semantic-search')          Files / Email search bars
   (alias → Ask)               (alias → Ask)                    (route through go)
                │
        ✦ AI button on Email Compose → in-place AI drawer (#compose-ai-drawer)
        ✦ AI button on File Viewer  → in-place slide-up panel (#fv-ai-panel)
        ✦ AI Assist on Doc Editor   → in-place doc AI panel (#doc-ai-panel)
        ✦ AI Sharing Assistant       → embedded in ss3 step of Share Securely sheet
```

The dedicated AI tab was retired; its content lives inside the Now tab's Ask sub-tab. The `s-ai-assistant` screen is preserved as an empty stub so unaliased references don't error.

---

## 9. Overlays & bottom-sheets

| ID                      | Trigger                                | Purpose                                              |
| ----------------------- | -------------------------------------- | ---------------------------------------------------- |
| `risk-overlay`          | Files header shield button             | Quick risk overview popup.                            |
| `create-menu`           | Files header `+` button                | Create-or-Import chooser.                            |
| `fv-insights-overlay`   | File Viewer SIP                        | Expanded security/intelligence panel.                |
| `ssheet`                | File Viewer / Doc Editor / Sharing     | Share Securely flow (people, AI risk, settings).     |
| `compose-send-sheet`    | Email Compose Send                     | Pre-send AI classification + Send confirmation.      |
| `agent-auth-sheet`      | Enterprise auth flow                   | Agent/SSO consent prompt.                            |
| `compose-ai-drawer`     | Compose ✦ AI button                    | Inline drawer (not full overlay).                    |
| `fv-ai-panel`           | File Viewer ✦ AI button                | Slide-up AI panel (dark theme).                      |

---

## 10. `go()` aliases — legacy IDs that still work

| If code calls `go(...)` with | The screen actually shown                            |
| ---------------------------- | ---------------------------------------------------- |
| `s-home`                     | `s-notifications` (Now tab is the home).             |
| `s-settings`                 | `s-profile`.                                         |
| `s-policy`                   | `s-profile` (then deep-link to Admin via UI).        |
| `s-ai-assistant`             | `s-notifications` + auto-switch to Ask sub-tab.      |
| `s-semantic-search`          | `s-notifications` + auto-switch to Ask sub-tab.      |

The corresponding `<div class="scr" id="s-…">` blocks remain in the DOM as inert dead code so historical inline references don't error.

---

## 11. Persistent state (`localStorage`)

| Key                  | Values                                                                                                    | Used by                                                          |
| -------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `xq.deviceMode`      | `mobile` \| `ipad` \| `desktop`                                                                            | Device-mode switcher (Mobile / iPad / Desktop frame + sidebar).  |
| `xq.notifMode`       | `expanded` \| `minimized` (default `minimized`)                                                            | In-context security/AI banners — full vs. tap-to-expand pills.   |
| `xq.profileSection`  | `general` \| `security` \| `notifications` \| `integrations` \| `workspace` \| `devices` \| `billing` \| `admin` | Last-viewed Profile subsection (restored on re-entry).         |
| `xq.onbPath`         | `personal` \| `enterprise`                                                                                  | Active onboarding path — controls back-nav and whether `s-workgroup-select` appears. |

---

## 12. All screen IDs (alphabetical, current state)

| ID                          | Status                          |
| --------------------------- | ------------------------------- |
| `s-ai-assistant`            | dead (alias → Now > Ask)        |
| `s-ai-import`               | active                          |
| `s-ai-organize`             | active                          |
| `s-data-lineage`            | active                          |
| `s-doc-editor`              | active (Edit mode default via openInEditor) |
| `s-email-compose`           | active                          |
| `s-email-inbox`             | active                          |
| `s-email-thread`            | active                          |
| `s-enterprise-auth`         | active (enterprise onboarding)  |
| `s-file-browser`            | active (bottom-nav tab)         |
| `s-file-risk-dashboard`     | active                          |
| `s-file-viewer`             | active                          |
| `s-folder-empty`            | active                          |
| `s-folder-view`             | active                          |
| `s-group-invite`            | active                          |
| `s-groups`                  | active                          |
| `s-home`                    | dead (alias → `s-notifications`) |
| `s-notifications`           | active (bottom-nav tab — Now)   |
| `s-permissions`             | active (onboarding)             |
| `s-phishing-alert`          | active                          |
| `s-policy`                  | dead (alias → `s-profile`); reachable from Profile→Admin |
| `s-profile`                 | active (top-right avatar)       |
| `s-received-share`          | active                          |
| `s-repo-setup`              | active (personal onboarding)    |
| `s-screenshot-block`        | active (interstitial)           |
| `s-semantic-search`         | dead (alias → Now > Ask)        |
| `s-settings`                | dead (alias → `s-profile`)      |
| `s-sharing`                 | active                          |
| `s-splash`                  | active (boot)                   |
| `s-welcome`                 | active (boot → onboarding)      |
| `s-workgroup-select`        | active (enterprise onboarding + in-app switcher) |

**Counts:** 26 active screens · 5 aliased-dead screens · 8 overlays/sheets · 4 Profile subsections worth of anchors (8 anchors total) · 4 Now sub-tabs · 4 Files sub-tabs.

---

*Last updated: 2026-05-23.*
