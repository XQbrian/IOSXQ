I have everything I need from the spec to produce a comprehensive analysis. Let me now write the full Phase 1 product analysis.

---

# XQ Secure Workspaces (iOS) — Phase 1 Product Analysis

**Product Strategy Agent Deliverable**
**Author**: Alex (Product Manager Agent)
**Date**: 2026-05-16
**Scope**: Phase 1 — Secure File Vault
**Status**: Draft for stakeholder review

---

## 1. EXECUTIVE SUMMARY

- XQ Secure Workspaces Phase 1 is a secure, AI-governed iOS file vault that encrypts and governs files at the edge — on-device — without requiring user training, manual classification, or IT involvement, targeting both privacy-conscious consumers (no-account, local-first) and enterprise teams (SharePoint-connected, policy-enforced, fully auditable).
- The foundational architectural bet is that security becomes ambient and invisible: the on-device AI governance layer continuously classifies, encrypts, and enforces policy as a background behavior, not a user workflow — this is the core product differentiator that must be preserved in every scope and delivery decision.
- Phase 1 scope is well-defined in the spec but carries three critical execution risks that must be resolved before development begins: the performance and accuracy floor for on-device AI models (CoreML/ONNX) on older supported devices, the definition of the XQ API contract across versions, and the ambiguous boundary between the consumer local-first experience and the enterprise SSO path — all three directly affect the onboarding flow and must be locked in the first sprint.

---

## 2. USER PERSONAS

### 2.1 Consumer (Local-First User)

**Profile**: Privacy-conscious individual or small-team knowledge worker. May be a freelancer, journalist, healthcare professional in a solo practice, or an executive who wants personal file protection outside their corporate environment. Does not want to create an account or involve IT. Uses iOS daily as their primary work device.

**Goals**
- Store and access sensitive files (contracts, financials, health records, personal documents) in one secure place on their phone or iPad
- Know their files are protected without having to think about how
- Share files selectively without worrying about losing control of the data after it leaves their hands

**Pain Points**
- Existing options (iCloud Drive, Dropbox, Google Drive) store file content on third-party infrastructure with opaque access policies
- Security products that exist are complex, require configuration, or interrupt workflow
- No obvious signal that a file has been protected — security is invisible until something goes wrong

**Critical Jobs-to-Be-Done**
1. Import a sensitive file from my camera roll or Files app and know it is immediately protected — without being asked to configure anything
2. View a sensitive document in a container that prevents it from being extracted, screenshotted, or forwarded
3. Share a file with a specific person and be able to revoke that access after the fact
4. Use the app completely offline and trust that cached files remain encrypted and contained

**Onboarding Expectation**: Zero friction. Tapping "Continue Local-First" should result in a ready workspace within 60 seconds, with no account required and no credential prompt.

---

### 2.2 Enterprise Standard User

**Profile**: Employee at a mid-market or enterprise organization (regulated industry, financial services, legal, defense contractor, healthcare). Uses a corporate-managed iPhone or iPad. Their organization has deployed XQ and connected it to Microsoft SharePoint and Entra ID. They work with sensitive documents daily and are expected to comply with data governance policies, but are not security experts.

**Goals**
- Access SharePoint files on mobile with the same governance protection they have on desktop
- Collaborate on documents without creating compliance exposure (forwarding attachments by email, downloading locally to uncontrolled devices)
- Do their job without IT friction — they should not be required to classify files manually or make security decisions they are not trained for

**Pain Points**
- Currently uses native SharePoint or Teams mobile apps, which offer no DLP controls at the mobile endpoint
- Receives sensitive files via email attachments that land in unprotected local storage
- Policy violations happen passively — sharing a confidential PDF to a personal email "just this once" — with no guardrail at the point of action
- Training-based compliance programs are ineffective; users comply only when the system enforces

**Critical Jobs-to-Be-Done**
1. Authenticate once via SSO (Entra/Okta) and immediately access my organization's SharePoint without manual configuration
2. Open and lightly edit a Word or Excel file from SharePoint, save changes back to source, and never have the file exist unprotected on my device
3. Share a file with a colleague or external partner with AI-evaluated, policy-appropriate controls applied automatically (view-only, expiration, geofencing) without choosing those controls myself
4. Receive a notification when a policy risk has been detected on something I've shared, and act on it from within the app

**Onboarding Expectation**: SSO login, automatic SharePoint connection with AI-assisted configuration, ready to access files within 3 minutes. No manual SharePoint URL entry required in the common case.

---

### 2.3 Enterprise Administrator

**Profile**: IT Security Administrator, CISO, Compliance Officer, or DLP team member. Responsible for configuring governance policies, monitoring compliance across the organization's use of the platform, and responding to security events. Does not use the file vault for daily productivity — uses the admin panel embedded in the same app (role-based UX variant) or a companion web admin console.

**Goals**
- Define classification labels and AI sensitivity thresholds that match the organization's data classification policy (e.g., aligned to NIST, ABAC groups, or custom schemas)
- Enforce data loss prevention rules that apply automatically at the user level — no reliance on user judgment
- Audit all file access, sharing events, and policy violations across the organization with full attribution
- Override AI classification decisions when the model produces false positives, and feed those corrections back to improve thresholds
- Control offline access, geofencing, view-only enforcement, and revocation capabilities centrally

**Pain Points**
- Most MDM/MAM solutions protect the device container but not the data itself — a revoked device still has the file if it was downloaded
- Audit trails from mobile endpoints are sparse and inconsistent
- Configuring enterprise DLP typically requires expensive, complex tooling and deep integration with each app separately
- Shadow IT on mobile (personal cloud storage, AirDrop, email forwarding) creates uncontrolled egress that current tools cannot see or stop

**Critical Jobs-to-Be-Done**
1. Define a classification schema and configure the AI engine to detect PII, PHI, CUI, and financial records at thresholds the organization sets — without deploying a custom model
2. Set and enforce sharing policies (external sharing restrictions, expiration defaults, geofencing, view-only access) that apply automatically without user opt-in
3. Pull a complete audit log of all file access, share, and policy violation events, filterable by user, file, date range, and event type — and export it for compliance reporting
4. Revoke access to a shared file or revoke a specific user's access entirely, with that revocation taking effect immediately, including on cached offline copies

---

## 3. MVP SCOPE — PHASE 1: SECURE FILE VAULT

The spec is clear that Phase 1 is the Secure File Vault. The scope below is derived from the spec's capability list and screen specifications, with explicit prioritization applied.

### Must-Have Features (Phase 1 GA)

These are features without which the product's core value proposition — frictionless, ambient, on-device encrypted governance — cannot be validated.

1. **Secure app initialization**: Splash screen with jailbreak detection, Secure Enclave initialization, session restore, and offline cache verification
2. **Dual-path onboarding**: Consumer (local-first, no account) and Enterprise (SSO via Entra/Okta) as distinct, unambiguous paths from first launch
3. **iOS permissions setup**: Face ID, notifications, Files access, camera roll — with AI-explained rationale per permission
4. **Local file import**: Import from Apple Files app, camera roll, and device downloads — with immediate on-device AI scan, classification, and encryption on import
5. **Secure File Vault (local)**: Encrypted local storage with classification labels, accessible only within the app sandbox — never exposed to iOS filesystem
6. **SharePoint integration**: Browse, stream, and open SharePoint files directly — files never persist on XQ infrastructure; session tokens stored in iOS Keychain
7. **Secure file viewer**: In-app rendering of PDF, DOCX, XLSX, TXT, and images with screenshot blocking, background blur, copy prevention, and share restriction enforcement
8. **On-device AI classification engine**: CoreML/ONNX-based local inference; classifies documents as Public / Internal / Confidential / Restricted; detects PII, PHI, CUI, financial records — runs locally, offline-capable
9. **AI-driven policy engine (consumer)**: Silent encryption, classification labeling, and warning-before-risky-share for consumer tier — no user configuration required
10. **AI-driven policy engine (enterprise)**: Configurable ABAC/RBAC rules, external sharing restrictions, view-only enforcement, expiration policies, geofencing — applied automatically
11. **Secure share workflow**: Recipient selection, AI risk evaluation before send, policy application, and expiration controls — via SharePoint link or governed attachment
12. **Access revocation**: Revoke shared file access from the Sharing Center screen; revocation must apply to cached offline copies
13. **Offline mode**: User-designated files/folders cached locally with encryption; changes sync back to source on reconnect; conflict resolution prompts when needed; enterprise policy can disable
14. **Light document editing**: In-app editing for DOCX and XLSX; auto-save back to SharePoint/source; AI rescans and reclassifies post-save
15. **Home screen dashboard**: Recent files, AI-suggested files, offline file status, risk notifications, quick actions (import, share)
16. **Notifications and security events screen**: Risk alerts, policy violations, sync conflicts, AI recommendations — with in-app resolution actions
17. **Sharing Center**: Manage active shares, view external recipients, revoke access, extend expiration, view share audit log
18. **Settings**: Account identity, Face ID/session timeout, offline storage management, AI governance preferences (consumer-level), repository connections, notification preferences
19. **Enterprise admin screens**: Policy Management (classification labels, sharing rules, runtime protections, AI threshold configuration) and Audit/Activity log (filterable, exportable)
20. **Biometric lock and session management**: Require Face ID on app return from background; blur app during multitask switch; session timeout configuration

### Nice-to-Have Features (Phase 1, if velocity permits)

These features are referenced in the spec but are not load-bearing for core value validation. They should be deferred to a v1.1 if they create schedule risk.

1. **AI document scanner screen**: Camera-based physical document capture with OCR preview and sensitivity detection — the spec marks OCR explicitly as Phase 3; the camera import wrapper is P1, but full OCR classification is P1.5 at earliest
2. **SMB / network drive connectivity**: Spec lists it as initial support alongside SharePoint, but SharePoint carries the majority of enterprise use cases and should be validated first; SMB can follow in a rapid subsequent release
3. **Multi-select file operations**: Bulk offline designation, bulk classification review — useful but not critical for activation
4. **Sensitivity watermark rendering**: Dynamic watermark overlay on high-sensitivity files in the viewer — the blocking and blur are must-haves; the dynamic visual watermark is a nice-to-have for v1
5. **Conflict resolution UI**: Simple automatic resolution (last-write-wins) is acceptable for v1; a full conflict resolution prompt UI can be a v1.1 improvement
6. **AI-suggested related files in repository browser**: Smart content recommendations during browsing — the classification is must-have; the proactive suggestion UI is a v1.1 enhancement

### Explicitly Out of Scope — Phase 1

These items appear in the spec but belong to later phases or have been explicitly deferred.

1. **Secure Email (Phase 2)**: Inbox, compose, attachment scanning, secure send controls, email-specific AI analysis — the email screens in the spec are Phase 2
2. **Secure Chat (Phase 3)**: All chat functionality
3. **Self-Hosted / Ghosted Deployment (Phase 3)**: Air-gapped and classified environment support
4. **CJIS-class sensitive data detection**: Explicitly marked Phase 3 in the spec
5. **OCR for scanned documents/images**: Explicitly marked Phase 3 in the spec
6. **Google Workspace / Google Drive / OneDrive / Box / Dropbox integration**: Listed as future integrations; not Phase 1
7. **Gmail as group container / group workspace creation via invite**: Referenced in the technical spec but belongs to Phase 2 (Gmail group logic / shared folder model)
8. **AI copilots, multi-model orchestration, workflow automation**: Phase 3/4 per the spec's development phase roadmap
9. **Autonomous governance agents and enterprise analytics dashboard**: Phase 4
10. **Android, macOS, Windows, Web platform support**: Future expansion
11. **Teams collaboration module**: Future screen expansion area per the spec

---

## 4. FUNCTIONAL REQUIREMENTS BY SCREEN/DOMAIN

### Screen 1: Splash / Secure Initialization

**Purpose**: Validate app and device integrity before any content is accessible. This screen must complete before any user data or session is loaded.

**Key Functional Requirements**
- Execute jailbreak/root detection; if detected, display a blocking error screen with no path to app content
- Initialize Apple Secure Enclave and validate cryptographic keys are intact
- Restore encrypted session tokens from iOS Keychain; if session is expired, route to authentication
- Verify offline cache integrity (encrypted file headers; detect tampering)
- Initialize on-device AI models (CoreML/ONNX); graceful fallback if model initialization fails — log error, proceed with reduced classification capability, surface unobtrusive alert
- Verify enterprise policy freshness if enterprise-enrolled; if policies cannot be refreshed and last-known policies are >X hours stale, surface a warning but allow continuation
- Validate app binary integrity (tamper detection)

**User Actions**: None. This screen is fully automated. Target: complete in under 2 seconds on supported hardware.

**Failure States**: Jailbreak detected (hard block), integrity failure (hard block), expired session (redirect to auth), device non-compliance (configurable: hard block or warn).

---

### Screen 2: Welcome / Onboarding Screen

**Purpose**: Establish deployment model and begin guided setup. This is the highest-stakes UX moment — it determines whether the consumer user bounces or the enterprise user connects successfully.

**Key Functional Requirements**
- Present two explicit, unambiguous paths: "Use Locally — No Account Needed" and "Connect Enterprise Workspace"
- Consumer path: proceed directly to Permissions Setup, then to Home with empty vault ready
- Enterprise path: proceed to AI-Assisted Repository Setup (authentication first)
- AI onboarding assistant activated in both paths — guides user through what is happening and why, in plain language
- Intro slides must be skippable after first run; should not be shown on subsequent app launches
- Privacy-first messaging must be accurate: explicitly state that XQ holds no customer data and that files never transit XQ infrastructure

**User Actions**: Select deployment type, optionally view intro slides, tap to begin setup.

---

### Screen 3: AI-Assisted Repository Setup Screen

**Purpose**: Configure SharePoint (or SMB in v1.1) connectivity with maximum AI assistance and minimum manual entry.

**Key Functional Requirements**
- Repository type selector: SharePoint (primary), SMB/Network Drive (v1.1), Local Vault (always available)
- AI setup assistant: presented as a conversational guidance panel, not a configuration form — AI detects SharePoint tenant from email domain if user is authenticated, suggests SharePoint URL, and validates connectivity
- OAuth/SSO login flow: must support Entra ID, Okta, Google Workspace, Ping — via standard PKCE flow; tokens stored in iOS Keychain
- AI resolves authentication errors in plain language ("Your session has expired — tap here to re-authenticate" rather than raw error codes)
- Auto-discover SharePoint sites the user has access to; present as a selectable list rather than requiring manual URL entry
- Connectivity test with clear pass/fail UI before completing setup
- AI recommends sync scope ("sync only files you mark offline" vs "sync all recent files") based on available storage and enterprise policy

**User Actions**: Authenticate via SSO, select or confirm SharePoint connection, confirm sync scope, complete setup.

---

### Screen 4: Permissions Setup Screen

**Purpose**: Request all required iOS system permissions with contextual AI explanations — maximize grant rate by explaining security/privacy value before the system prompt appears.

**Key Functional Requirements**
- Permissions requested: Face ID (biometric authentication), Push Notifications (risk alerts and sync events), Files access (import from Files app), Camera roll access (import photos/scanned documents), Local Network access (SMB, if included)
- Each permission must be preceded by an in-app explanation screen with: what the permission enables, why it is needed for security, what data is accessed and what is not
- Permission grants are non-blocking — app functions with reduced capability if a permission is denied; settings can be revisited from Settings screen
- AI explains enterprise policy impacts where relevant ("Your organization requires Face ID to be enabled to access this workspace")
- Permissions granted must be logged for compliance purposes in enterprise deployments

**User Actions**: Review explanation, grant or deny each permission via system prompt.

---

### Screen 5: Home Screen

**Purpose**: Primary productivity dashboard. Must surface the most relevant content and risk signals without overwhelming the user. Designed around ambient security — risk is surfaced contextually, not as a persistent dashboard.

**Key Functional Requirements**

Recent Files section:
- Last 10 files accessed, sorted by recency, with sensitivity label, file type icon, repository source indicator, and offline availability badge
- Tap to open in Secure File Viewer; long-press for contextual action menu (share, mark offline, view activity)

Suggested Files section (AI-generated):
- AI recommends files based on recent access patterns, related project context, and inferred sharing behavior
- Suggestions are local inference only — no content leaves device to generate recommendations
- User can dismiss individual suggestions; dismissal persists

Offline Files section:
- Files/folders marked for offline availability with sync status indicators (synced, pending sync, sync failed)
- Tap to open; sync status must be accurate and real-time where connectivity permits

Risk Notifications (inline, not a separate modal):
- Surface highest-priority risk event inline (e.g., "Sensitive file shared externally 2 hours ago — Review")
- Maximum 1–2 risk signals in Home view; full list in Notifications screen
- Tapping a risk event navigates to Notifications screen with that event highlighted

Quick Actions:
- Import File, Share Securely, Scan Document (if camera permission granted)
- Actions must be available via Spotlight search and iOS shortcuts for power users

**User Actions**: Open recent or suggested files, manage offline files, review and act on risk notifications, trigger quick actions.

---

### Screen 6: Repository Browser Screen

**Purpose**: Unified file access experience across connected repositories and local vault. File browser is the core navigation surface for enterprise users.

**Key Functional Requirements**
- Repository switcher: toggle between SharePoint sites, local vault, and (v1.1) SMB drives
- Folder hierarchy: standard tree navigation with breadcrumb trail; supports deep folder structures
- File list view (default) and grid view (optional toggle); respects user preference
- Classification badges displayed inline on every file and folder item: sensitivity label (Public/Internal/Confidential/Restricted) as a small color-coded chip
- File indicators per item: sensitivity label, offline availability (cloud vs cached icon), share status (active shares indicator), sync state (syncing spinner, conflict warning)
- Search: full-text search across filenames and metadata within connected repositories; search is performed server-side for SharePoint content, on-device for local vault
- Filter controls: filter by classification, file type, offline status, share status, date modified
- Multi-select: select multiple files for bulk operations (mark offline, bulk share)
- AI features: suggested destination folder when importing, related content recommendations surfaced contextually, smart tag suggestions

**User Actions**: Browse, navigate, search, filter, select files, initiate import, trigger file actions.

---

### Screen 7: Secure File Viewer Screen

**Purpose**: Protected in-app document rendering. This is the most security-critical screen — all DLP controls are active during viewing.

**Supported Formats**: PDF, DOCX, XLSX, TXT, PNG/JPG/HEIC images

**Key Functional Requirements**

Rendering:
- All documents rendered via QuickLook with custom secure renderer layer; no handoff to external apps
- "Open In" workflows disabled entirely
- Documents streamed for viewing; not saved to unprotected local storage during viewing
- Sensitivity label displayed persistently in viewer header with classification color coding

Runtime Protections (mandatory, non-configurable for consumers; enterprise-configurable):
- Screenshot blocking: where iOS APIs permit, block screenshot capture; where not possible (iOS limitation), apply visual watermark that includes user identity and timestamp
- Screen recording detection: detect active screen recording; apply content overlay or terminate view session based on enterprise policy
- Background blur: when app moves to background, immediately replace content with blur screen; require Face ID on return
- Copy/paste prevention: disable system clipboard access within document viewer
- Share sheet restriction: block all share sheet destinations except explicitly approved XQ sharing workflow

AI features during viewing:
- Sensitivity analysis displayed in collapsible side panel: what was detected, why the classification was applied, in plain language
- Risk explanation: if viewing triggers a policy event, explain the policy and its rationale
- Dynamic protection escalation: if AI detects high-risk content patterns during viewing (e.g., user scrolling to a section with previously unscanned PII), escalate watermark visibility or require reauthentication before continuing

Edit button: navigates to Document Editing Screen if file type and policy permit editing; disabled (with explanation) if enterprise policy enforces view-only

**User Actions**: Read document, trigger share action, trigger edit action, view AI classification panel, view activity log.

---

### Screen 8: Document Editing Screen

**Purpose**: Lightweight in-app productivity editing with continuous AI governance. Not a full office suite replacement — scoped to quick edits that must save back to the source repository.

**Key Functional Requirements**

Word (DOCX):
- Text editing with basic formatting (bold, italic, underline, paragraph styles)
- Comment insertion and reply
- No macro support; no embedded object editing

Excel (XLSX):
- Cell editing with formula support (basic formula set)
- Basic cell formatting
- No VBA/macro support; no pivot table editing

Edit session:
- Auto-save to secure local cache every 60 seconds during editing
- Explicit "Save" action pushes changes back to SharePoint/source repository via the RepositoryProvider interface — never directly to network in business logic
- Conflict detection: if source file has been modified since the local copy was opened, surface conflict resolution prompt before save completes
- All runtime DLP protections from the Viewer remain active during editing (copy prevention, screenshot blocking, background blur)

Post-edit AI behavior (critical requirement):
- On every save, AI rescans the full document content on-device
- If classification changes (e.g., user added PII that wasn't present before), update sensitivity label immediately and re-evaluate applicable policies
- If new policy conflicts are introduced by the edit (e.g., the document is now Restricted and the active share link has no expiration), surface a contextual alert and recommend corrective action

**User Actions**: Edit content, save/auto-save, resolve conflicts, respond to AI policy alerts.

---

### Screen 9: Secure Share Workflow Screen

**Purpose**: Governed secure sharing experience. AI evaluates before the user commits — the goal is to prevent the wrong share from happening, not to block sharing as a default.

**Key Functional Requirements**

User flow:
1. User initiates "Share Securely" from Viewer, Editor, or Repository Browser
2. Recipient selector: search contacts, enter email, or select from organizational directory (Entra/Okta sourced for enterprise users); AI suggests recipients based on file context and sharing history
3. Share method selection: SharePoint link (preferred for enterprise), governed attachment (for external users without SharePoint access)
4. AI risk evaluation runs in real-time as recipient is selected: external recipient warning, sensitive content alert, compliance risk detection — displayed as a clear, human-readable risk summary before the user confirms
5. Security settings: expiration date/time, view-only toggle, download prevention toggle — AI pre-populates these based on content sensitivity and policy; user can adjust within policy bounds
6. User confirms share — XQ API applies encryption, generates share link or encrypted attachment, logs the event
7. Share confirmation screen with link or delivery confirmation

Enterprise enforcement:
- Admins can make view-only, expiration, and geofencing non-configurable (locked) for specific classification levels
- External sharing can be blocked entirely for Restricted content via policy
- Group sharing: invite participants to a shared folder workspace; folder inherits policies from highest-sensitivity file within it

AI-assisted decisions:
- Recommend secure link over attachment when recipient is external
- Warn when external domain is outside an enterprise-approved recipient list
- Detect when a recipient has an XQ account (encrypted-to-encrypted delivery) vs. when the recipient will receive a link to access content through XQ's secure delivery

**User Actions**: Select recipients, review AI risk summary, configure share settings (within policy bounds), confirm share, copy/send link.

---

### Screen 10: Local File Import Screen

**Purpose**: Bring external content from iOS sources into the secure workspace with immediate AI-driven protection on entry.

**Key Functional Requirements**

Import sources:
- Apple Files app (system file picker)
- Camera roll (photo/video picker — video files should be reviewed for support scope; images confirmed)
- Device Downloads folder
- Camera capture (for document scanning — camera permission required)

Import flow:
1. User selects source and file
2. AI scans file content immediately on import — on-device, no content leaves device
3. AI suggests destination folder within connected repositories or local vault
4. AI assigns classification prediction with confidence score — displayed as confirmation step, not a blocking prompt
5. File is encrypted immediately and bound to XQ policy metadata before being stored
6. File appears in local vault or selected repository with classification label applied
7. Governance enforcement triggers (policy evaluation, access controls applied based on classification)

Post-import behavior:
- File is never accessible via the iOS Files app or any external app after import (sandbox enforcement)
- If the user imported from camera roll, the original in camera roll is NOT deleted automatically — user must choose to delete from camera roll separately (platform limitation and privacy consideration)

**User Actions**: Select source, browse and select file(s), confirm destination and classification, complete import.

---

### Screen 11: AI Document Scanner Screen

**Purpose**: Capture physical documents via camera and bring them into the secure workspace with immediate content analysis.

**Key Functional Requirements**
- Camera interface with document edge detection and auto-capture
- OCR preview (note: full OCR classification is a v1.1/Phase 3 capability per spec; v1 supports image capture and metadata-based sensitivity detection on the resulting image file)
- Sensitivity detection panel: if OCR is not available in v1, display classification based on image metadata and user-confirmed content type
- Classification preview before confirming import
- On confirmation: encrypt image, suggest secure repository destination, apply governance labels
- Multi-page document capture for physical document workflows

**User Actions**: Point camera at document, capture, review OCR/classification preview, confirm import, select destination.

---

### Screen 12: Secure Email Inbox Screen

**Status: Phase 2 — OUT OF SCOPE for Phase 1 GA**

Included in the spec's screen list but explicitly designated Phase 2. This screen should not be built or exposed in Phase 1. The Email tab in the bottom navigation should either be hidden or display a "Coming Soon" placeholder in Phase 1 builds.

---

### Screen 13: Compose Secure Email Screen

**Status: Phase 2 — OUT OF SCOPE for Phase 1 GA**

Same rationale as Screen 12. No email composition capability in Phase 1.

---

### Screen 14: Notifications and Security Events Screen

**Purpose**: Centralized governance visibility. This is how ambient AI security becomes visible to the user — without interrupting their workflow, but available when they need to act.

**Key Functional Requirements**

Notification categories (all Phase 1 applicable):
- Sharing risks: "Sensitive file shared with external recipient [name] — review access"
- Policy violations: "Policy prevented download of [filename] — view details"
- Sync events: "Sync failed for [filename] — tap to retry" and "Sync conflict detected — resolve"
- Access changes: "Your access to [filename] was modified by [admin]"
- AI recommendations: "3 unclassified files detected — tap to review"

Functional capabilities:
- Review event detail with human-readable explanation and AI reasoning
- Resolve warnings in-line (e.g., revoke a share from within the notification, retry a sync)
- Escalate incidents (for enterprise: notify admin; for consumer: contact support)
- Mark events as reviewed; support for batch-dismiss low-priority notifications
- Deep-link from iOS push notifications directly to relevant in-app screen

**User Actions**: Review notification, act on notification (revoke, retry, escalate), dismiss, navigate to source file/event.

---

### Screen 15: Sharing Center Screen

**Purpose**: Unified management of all active shares and external access. The control plane for data that has already left the vault.

**Key Functional Requirements**
- Shared file list: all files with active shares, with recipient list, share method (link vs. attachment), expiration countdown, and access type (view-only vs. full)
- External recipient list: all external recipients with access to any file, with per-recipient action controls
- Active secure links: link status (active, expired, revoked), copy link, extend expiration
- Expiration timers: visual countdown; notification when a link is about to expire (configurable threshold)
- Revoke access: single tap to revoke a specific share or all access to a file — revocation must propagate to XQ backend and invalidate cached offline copies held by recipients
- Extend expiration: extend a link or access period within policy-permitted bounds
- View audit activity: per-file access log showing who accessed the file, when, and from what location (enterprise only for location data)
- Restrict permissions: downgrade a share from full access to view-only after the fact

**User Actions**: Review active shares, revoke access, extend expiration, view per-file access audit, restrict permissions.

---

### Screen 16: Enterprise Policy Management Screen

**Purpose**: Administrative interface for configuring governance rules. Role-gated — enterprise admin only.

**Key Functional Requirements**

Classification Management:
- Define classification labels (name, color, description) — minimum: support the Public/Internal/Confidential/Restricted schema; support custom labels
- Configure AI sensitivity thresholds per label (what confidence score triggers each classification)
- Override AI decisions: admin can manually reclassify a file and flag that classification as a training signal for model refinement

Sharing Policies:
- Define external sharing rules by classification level (allow / allow with restrictions / block)
- Configure expiration defaults by classification (e.g., Restricted files auto-expire shared links in 24 hours)
- Configure geofencing: restrict file access to specific geographic regions by IP or GPS (GPS requires location permission)
- View-only enforcement: set classification levels at which view-only is mandatory regardless of user selection

Runtime Protection:
- Screenshot enforcement level by classification (watermark / block where possible / require reauthentication)
- Offline mode controls: enable/disable offline caching globally or by classification
- Copy/export controls: enable/disable clipboard access within the viewer by classification level

AI Governance Controls:
- Confidence threshold configuration: minimum AI confidence required before a classification label is applied automatically (below threshold = "Review Required" state)
- Override rules: define which user roles can override AI classifications
- Escalation behavior: configure what happens when a user triggers a policy conflict (warn / block / notify admin)
- AI model selection: per-tenant selection of AI provider (local CoreML, OpenAI, Anthropic, Azure OpenAI, etc.) — governed by AIProvider interface abstraction

**User Actions**: Create/edit/delete classification labels, configure sharing and runtime policies, adjust AI thresholds, review and override AI decisions.

---

### Screen 17: Audit and Activity Screen

**Purpose**: Enterprise audit visibility and compliance reporting. Admin-only with full activity tracing.

**Key Functional Requirements**

Event types tracked:
- File access (user, file, timestamp, repository, device ID)
- Sharing events (file, recipient, share method, policy applied, expiration)
- Policy violations (user, file, attempted action, policy that blocked it, outcome)
- Classification changes (from → to, trigger: AI or manual override, admin actor if manual)
- Device trust events (device registered, posture change detected, device revoked)

Features:
- Search logs by user, file name, event type, date range, device
- Filter by event category, severity, policy area
- Export audit reports in CSV or JSON format (PDF export is a v1.1 enhancement)
- User activity tracing: view complete activity timeline for a specific user
- Real-time log updates for active sessions (enterprise admin can see live events)

**User Actions**: Search and filter logs, export reports, trace specific user activity, drill into event details.

---

### Screen 18: Settings Screen

**Purpose**: Personal and security configuration for both consumer and enterprise users.

**Key Functional Requirements**

Account section:
- Display identity (email/name if authenticated; "Local User" for consumer no-account mode)
- SSO status (connected / disconnected / expired) with reauthenticate action
- Device registration status (enterprise: show device trust score and enrollment date)

Security section:
- Face ID toggle (mandatory for enterprise if policy requires)
- Session timeout configuration (1 minute / 5 minutes / 15 minutes / on close)
- App lock behavior (immediately on background vs. after timeout)

Offline Storage section:
- Current cache size and available storage
- List of folders/files marked for offline availability with remove controls
- "Clear offline cache" action (with confirmation warning)
- Enterprise policy display: shows if offline mode is restricted by admin

AI Governance section (consumer-facing preferences):
- Privacy settings: confirm that all AI processing is on-device and no content is shared
- Consumer can configure notification verbosity for AI recommendations (all / risk-only / off)
- "Review AI decisions" — consumer can see recent AI classifications and dispute/correct them

Repository Connections section:
- List connected repositories with status (connected / auth expired / error)
- Add new repository (triggers AI-Assisted Repository Setup flow)
- Remove repository (with warning about offline cache impact)
- Reauthenticate specific connection

Notifications section:
- Alert preferences: risk alerts, policy events, sync events, AI recommendations — each individually togglable
- Risk notification level: all / high-only / critical-only

**User Actions**: Configure all personal and security settings, manage repository connections, adjust notification preferences, clear cache, view AI governance preferences.

---

## 5. USER FLOW DEFINITIONS

### Flow 1: Consumer Onboarding

**Trigger**: First app launch, consumer path selected

**Steps**:
1. Splash screen (automated — 2 seconds max)
2. Welcome screen → user taps "Use Locally — No Account Needed"
3. Permissions Setup screen → AI explains Face ID, notifications, Files access; user grants desired permissions
4. Home screen loads with empty vault; AI onboarding assistant displays contextual prompt: "Tap Import to add your first file — it will be protected automatically"
5. User imports first file → Local File Import screen → AI scans, classifies, encrypts → file appears in vault with classification label
6. Onboarding complete; onboarding assistant dismissed; ambient governance active

**Success Criterion**: Consumer reaches a functional, file-containing vault within 90 seconds of first launch with zero account creation steps.

**Failure Cases**:
- User denies Face ID: vault functions with passcode fallback; Face ID can be enabled later in Settings
- No files to import yet: Home screen is empty but functional; no blocking prompt

---

### Flow 2: Enterprise Onboarding

**Trigger**: First app launch, enterprise path selected

**Steps**:
1. Splash screen (automated — 2 seconds max)
2. Welcome screen → user taps "Connect Enterprise Workspace"
3. AI-Assisted Repository Setup screen → user enters work email; AI detects Entra tenant from domain; AI-initiated OAuth flow opens; user authenticates via SSO (Entra, Okta, or configured IDP)
4. SharePoint sites auto-discovered; AI presents list; user selects primary workspace
5. AI recommends sync scope; user confirms
6. Permissions Setup screen → AI explains each permission with enterprise policy context (e.g., "Your organization requires Face ID")
7. Home screen loads with SharePoint content surfaced in Recent Files; AI onboarding assistant explains classification badges and how protection works
8. Onboarding complete; enterprise policy engine active

**Success Criterion**: Enterprise user has an authenticated, SharePoint-connected vault with visible files and active AI governance within 3 minutes of first launch.

**Failure Cases**:
- SSO authentication fails: AI displays plain-language error with specific remediation step; "Contact IT" fallback with pre-filled IT email if enterprise MDM provides IT contact
- SharePoint URL not detectable from email domain: AI prompts user to enter SharePoint URL manually with format guidance
- Enterprise policy requires additional device registration: guide user through MDM enrollment flow before granting access

---

### Flow 3: Import File

**Trigger**: User taps "Import File" from Home quick actions or Repository Browser

**Steps**:
1. Local File Import screen → source selector presented (Files app, Camera Roll, Downloads, Camera)
2. User selects source and file(s)
3. AI begins on-device scan immediately (progress indicator shows "Analyzing content...")
4. AI presents classification prediction and destination folder suggestion; user confirms or adjusts
5. File encrypted immediately using Secure Enclave key; bound to XQ policy metadata
6. File appears in vault/selected repository with classification label applied
7. If classification is Confidential or Restricted: AI notifies user of applicable policies (e.g., "This file will be view-only when shared externally")

**Success Criterion**: File is encrypted, classified, and accessible within the vault in under 10 seconds for a typical document (<50MB).

**Failure Cases**:
- AI classification confidence below threshold: file is imported and encrypted; label shows "Review Required" with option for user to confirm or adjust
- File format not supported for content scanning: file is encrypted and stored; classification falls back to metadata-based heuristics; label shown as "Unclassified — Review"
- Storage insufficient: alert with current cache usage and option to clear; import blocked until storage is available

---

### Flow 4: View File

**Trigger**: User taps a file in Home (Recent Files, Suggested Files), Repository Browser, or Offline Files

**Steps**:
1. Secure File Viewer opens with file streamed/decrypted in-memory (never written to unprotected storage)
2. All runtime DLP protections activate: screenshot blocking, background blur, copy prevention, share restriction
3. Sensitivity label displayed in viewer header with classification color
4. AI classification panel available (collapsible): shows detected sensitive data types, confidence score, policy rationale
5. User reads/reviews document
6. If high-risk content is detected mid-session (e.g., scrolling to PII-dense section): AI dynamically escalates protection (watermark visibility increases, or reauthentication prompt if enterprise policy requires)
7. When user backgrounds app: content blurred immediately
8. When user returns to app: Face ID required before content is visible again

**Success Criterion**: File opens in under 3 seconds for typical documents; all DLP protections active from first render frame.

**Failure Cases**:
- File format not supported for rendering: display unsupported format message with file metadata and classification label visible
- File is corrupted or decryption fails: display error; log event to audit trail; offer to retry or report
- Face ID fails on return: offer 3 attempts then require full session re-authentication

---

### Flow 5: Share File

**Trigger**: User taps "Share Securely" in the Secure File Viewer, Document Editing Screen, or Repository Browser context menu

**Steps**:
1. Secure Share Workflow screen opens
2. Recipient selector: user searches for recipient by name or email; organizational directory (Entra/Okta) is searched for enterprise users
3. As recipient is entered/selected, AI evaluates in real-time:
   - Is the recipient external to the organization? → surface warning
   - Does the file classification allow sharing with this recipient type? → if blocked, display policy block with explanation; do not allow bypass
   - What are the recommended share settings for this content sensitivity + recipient combination?
4. AI presents risk summary: plain-language description of what was detected and what protections will be applied
5. Share settings displayed (pre-populated by AI, user can adjust within policy bounds): expiration, view-only, download prevention
6. User confirms share
7. XQ API called via XQSecureAPI interface: encrypt, generate share link or encrypted attachment, register recipient access
8. Audit event logged with: file, recipient, share method, policy applied, timestamp, device ID
9. Share confirmation screen; link copied or email/notification sent

**Success Criterion**: A governed share is created with all AI-evaluated protections applied in under 5 seconds from user confirmation.

**Failure Cases**:
- Policy blocks share entirely (Restricted file, external recipient): display clear blocking message with policy rationale; no bypass option for standard users; admin can override from Policy Management
- Recipient lookup fails (no directory available for consumer user): allow email entry with AI warning about unverified recipient status
- Network unavailable at share time: queue the share action and notify user; execute when connectivity restored (for SharePoint link shares)

---

### Flow 6: Handle Policy Violation

**Trigger**: AI detects a policy conflict — either proactively (during file scan) or at action time (during share, edit, or access attempt)

**Steps**:
1. AI detects violation (examples: user attempts to share a Restricted file externally; user tries to screenshot; file imported with PII is about to be sent via unapproved channel)
2. Policy violation surface mechanism depends on severity:
   - **Warning** (soft): contextual inline banner with explanation and recommended alternative action; user can proceed or accept recommendation
   - **Block** (hard): action is prevented; modal dialog explains what policy was violated and why; offers alternative compliant path if one exists; no bypass available for standard users
   - **Escalate** (enterprise): action blocked, admin is notified automatically, user sees "Your administrator has been notified" message
3. Notification logged to Notifications and Security Events screen
4. Enterprise audit event created with: user, file, attempted action, policy triggered, outcome, timestamp
5. If violation was a false positive (user believes classification is wrong): user can tap "Dispute this classification" → flags for admin review; does not unblock the action

**Success Criterion**: Policy violation is surfaced within 1 second of the triggering action; user receives a clear, non-technical explanation of what happened and what their options are.

**Failure Cases**:
- AI false positive on content classification (high likelihood in early releases): admin override path is available; user dispute mechanism prevents user frustration from becoming churn
- Policy engine unavailable (e.g., enterprise policy server unreachable): fallback to last-known policy state; if policies are stale beyond threshold, default to most restrictive applicable policy (fail-secure)

---

## 6. FEATURE BACKLOG — PRIORITIZED

### P0 — Must Ship Before Any GA (Phase 1 Blocking)

These features are foundational. Shipping without them means the product's core promise cannot be delivered.

| ID | Feature | Rationale |
|----|---------|-----------|
| P0-01 | Splash/Secure Initialization with jailbreak detection and Secure Enclave init | App security baseline |
| P0-02 | Consumer onboarding (local-first, no account, Face ID setup) | Consumer activation path |
| P0-03 | Enterprise onboarding (SSO via Entra/Okta, SharePoint auto-discovery) | Enterprise activation path |
| P0-04 | Local file import with immediate on-device AI scan and encryption | Core value delivery |
| P0-05 | On-device AI classification engine (CoreML/ONNX) — PII, PHI, CUI, financial records | Governance foundation |
| P0-06 | Secure File Viewer with screenshot blocking, background blur, copy prevention, share restriction | DLP enforcement |
| P0-07 | Local encrypted vault (Secure Enclave, sandboxed from iOS filesystem) | Data containment |
| P0-08 | SharePoint integration (browse, stream, open files via RepositoryProvider interface) | Enterprise use case |
| P0-09 | Secure Share Workflow with AI risk evaluation before send | Governed sharing |
| P0-10 | Access revocation (shared link and offline copy invalidation) | Zero Trust access control |
| P0-11 | XQSecureAPI interface layer with version adapter support | API abstraction (spec requirement) |
| P0-12 | Home screen with Recent Files, Risk Notifications, Quick Actions | Primary UX surface |
| P0-13 | Biometric lock on background/return (Face ID + session blur) | Runtime security |
| P0-14 | Consumer policy automation (silent encryption, warn-before-risky-share) | Consumer governance |
| P0-15 | Enterprise policy engine (ABAC/RBAC, external sharing rules, expiration, view-only enforcement) | Enterprise governance |

### P1 — Must Ship for Phase 1 Feature Completeness

These features are required for a complete Phase 1 product but could be delivered in a rapid follow-on if P0 is stable and time-critical.

| ID | Feature | Rationale |
|----|---------|-----------|
| P1-01 | Offline mode (explicit user-designated caching, encrypted, auto-sync on reconnect) | Key differentiator for mobile |
| P1-02 | Light document editing — DOCX and XLSX (in-app, save to source, post-edit AI rescan) | Enterprise productivity |
| P1-03 | Repository Browser (folder hierarchy, classification badges, search, filter, multi-select) | Core file navigation |
| P1-04 | Sharing Center (manage active shares, revoke, extend expiration, view audit) | Share management |
| P1-05 | Notifications and Security Events screen | Ambient security visibility |
| P1-06 | Enterprise Policy Management screen (classification labels, sharing rules, AI threshold config) | Admin governance |
| P1-07 | Audit and Activity screen (searchable, filterable, exportable logs) | Compliance requirement |
| P1-08 | Settings screen (full — account, security, offline, AI prefs, repositories, notifications) | User control |
| P1-09 | Permissions Setup screen with AI-explained rationale | Onboarding quality |
| P1-10 | AI Document Scanner screen (camera capture, classification preview) | Local-first use case |
| P1-11 | Post-edit AI reclassification and policy re-evaluation | AI governance completeness |
| P1-12 | AI-Assisted Repository Setup with connection diagnostics and error remediation | Enterprise onboarding quality |
| P1-13 | Conflict resolution for offline sync | Data integrity |
| P1-14 | Dynamic watermarking on sensitive content (user identity + timestamp embedded) | High-sensitivity DLP |

### P2 — Post-Phase 1 / Phase 1.1 Enhancements

These features improve the product but should not delay Phase 1 GA.

| ID | Feature | Rationale |
|----|---------|-----------|
| P2-01 | SMB / Network Drive connectivity | Secondary enterprise use case |
| P2-02 | Full OCR in AI Document Scanner | Phase 3 per spec |
| P2-03 | AI suggested related files in Repository Browser (proactive recommendations) | Engagement enhancement |
| P2-04 | Multi-select bulk operations (bulk offline, bulk share) | Power user efficiency |
| P2-05 | Audit log PDF export | Compliance convenience |
| P2-06 | Spotlight search and iOS Shortcuts integration | iOS ecosystem |
| P2-07 | Gmail as group container / shared workspace via invite | Phase 2 dependency |
| P2-08 | OneDrive, Box, Dropbox, Google Drive connectivity | Expanded enterprise coverage |
| P2-09 | Real-time live admin event monitoring | Advanced admin capability |
| P2-10 | Tenant-specific language packs and OTA translation updates | Localization completeness |
| P2-11 | Adaptive resource control (AI throttling, GPU caps for older devices) | Performance optimization |
| P2-12 | AI model per-tenant switching (local vs. cloud provider per policy) | Enterprise customization |

---

## 7. DEPENDENCIES

### 7.1 XQ API (xq.stoplight.io / XQ-Message-Inc SDK)

**What it provides**: Core encryption (encrypt, decrypt), policy application (applyPolicy), access validation (validateAccess), and access revocation (revokeAccess).

**Interface requirement**: The spec is explicit — all XQ API calls must go through the XQSecureAPI protocol interface, with version adapters (XQAPIv1Adapter, XQAPIv2Adapter, XQAPIv3Adapter). Business logic must never reference a specific API version directly.

**Critical questions that must be resolved before dev starts**:
- What XQ API version is current and stable? What is the backward compatibility guarantee?
- Does the XQ API support offline policy evaluation, or does it require connectivity for every policy enforcement action? If it requires connectivity, the offline mode design is critically affected.
- What is the XQ API's rate limiting model? This affects sharing and real-time policy evaluation at scale.
- Does the SDK support the Gmail-as-group-identity model specified in the technical spec?
- What is the XQ API's data residency model — specifically, what metadata (if any) transits XQ infrastructure during encryption key management? This is essential for enterprise data sovereignty claims.

**Owner**: XQ engineering team. **Deadline to resolve**: Before architecture spike, Week 1.

---

### 7.2 Microsoft SharePoint / Entra ID

**What it provides**: File repository access (browse, stream, upload via SharePoint REST API or Microsoft Graph), enterprise identity and SSO (Entra ID OAuth/OIDC), group membership and ABAC attributes.

**Integration pattern**: Must be implemented via the RepositoryProvider and ExternalIntegration protocol interfaces. The SharePointProvider implementation calls Microsoft Graph; business logic never calls Graph directly.

**Dependencies**:
- Microsoft Graph API access: requires app registration in Azure, API permissions (Sites.Read.All, Files.ReadWrite.All minimum), and customer tenant admin consent for enterprise deployments
- Entra ID OIDC: PKCE flow for mobile; token storage in iOS Keychain; token refresh handled by API Gateway layer
- SharePoint conditional access compatibility: app must declare compliance with Intune MAM policies where required by enterprise tenant; this affects app signing and entitlements

**Critical questions**:
- Will XQ manage a single Azure app registration or will each enterprise customer need to register their own? This is a significant onboarding complexity difference.
- What SharePoint API throttling limits apply and how does the sync engine handle backoff?
- How does the SharePoint integration handle tenant-level external sharing policies that may conflict with XQ's own sharing model?

**Owner**: Engineering lead + enterprise partnerships. **Deadline to resolve**: Before SharePoint integration sprint.

---

### 7.3 Apple Secure Enclave and Face ID

**What it provides**: Hardware-backed cryptographic key storage (key generation, key storage, encryption/decryption operations bound to Secure Enclave); biometric authentication (Face ID) for session unlock and sensitive operation authorization.

**Integration pattern**: Accessed via CryptoKit and LocalAuthentication frameworks. Secure Enclave stores the per-device master key; XQ policy metadata is bound to this key. Files are encrypted using keys that never leave the Secure Enclave.

**Constraints and considerations**:
- Secure Enclave keys are device-bound. If the user moves to a new device, re-encryption or key migration is required — this flow must be designed explicitly in Phase 1 for local-first users (enterprise users: keys can be held customer-side via XQ's key management service)
- Face ID is not available on all supported devices; TouchID and passcode fallback must be implemented
- iOS limits on biometric authentication attempt frequency affect how often view-session reauthentication can be required for high-sensitivity documents — this must be factored into the enterprise policy for "require reauthentication on high-risk content"
- Background blur requires UIApplicationWillResignActiveNotification handling — must be implemented before any content is composited to the screen buffer

**Owner**: iOS Security lead. **Deadline to resolve**: Architecture spike, Week 1.

---

### 7.4 CoreML / ONNX Runtime

**What it provides**: On-device AI inference for document classification, sensitive data detection (PII, PHI, CUI, financial records), risk scoring, and policy recommendation.

**Critical unresolved questions (these are P0 risks)**:
- What is the model for the on-device classification capability? Is XQ building a custom CoreML model, licensing a pre-trained model, or using an ONNX model converted from an existing framework (Hugging Face, etc.)? This determines Phase 1 feasibility on the core AI governance promise.
- What is the minimum device hardware required to run these models with acceptable latency (<2 seconds per document scan for a typical <10MB document)? A/12 Bionic or newer? This directly affects the supported device floor.
- What is the model update mechanism — how are improved classification models pushed to the app? This is a Phase 1 consideration because the initial model will certainly produce false positives that need to be corrected via update.
- For enterprise deployments requiring cloud AI (OpenAI, Azure OpenAI, Anthropic): how is the AIProvider switch configured? Via the admin Policy Management screen or MDM profile? The AIProvider interface abstraction in the spec supports this, but the configuration surface must be defined.
- Battery and memory impact: what is the expected battery draw for background AI scanning during active file sessions? This needs measurement on target hardware before GA.

**Owner**: AI/ML lead + iOS architecture lead. **Deadline to resolve**: AI model strategy must be decided in Week 1; prototype classification accuracy must be validated before the Document Viewing sprint begins.

---

### 7.5 Identity Providers — Entra, Okta, Google Workspace, Ping, AWS IAM Identity Center

**What it provides**: SSO authentication, user identity, group membership, and ABAC attributes for enterprise policy enforcement.

**Integration pattern**: All IDPs accessed via the IDP/Auth Adapter interface. The IDP Adapter normalizes identity claims across providers into a standard identity model used by the policy engine.

**Considerations**:
- PKCE-based OAuth2/OIDC flows for all providers; no client secrets stored in the app binary
- Token refresh must be handled transparently; expired sessions should not result in data loss (unsaved edits must be preserved through reauthentication)
- For enterprise policy enforcement that uses IDP group attributes (ABAC): the policy engine must receive normalized group claims; different IDPs expose groups differently (Entra uses security groups in the JWT; Okta uses groups claim; Google Workspace uses a separate Directory API call) — the IDP Adapter must normalize these
- Phase 1 priority: Entra ID is the highest-priority IDP (Microsoft SharePoint dependency); Okta is second; Google Workspace, Ping, and AWS IAM are P1/P2

**Owner**: Security engineering + enterprise integrations lead. **Deadline to resolve**: IDP Adapter interface spec must be written before authentication sprint.

---

## 8. SUCCESS CRITERIA — PHASE 1

Success criteria are organized by persona and time horizon. These are the metrics that determine whether Phase 1 has succeeded, not whether it was shipped.

### Activation (30 days post-launch)

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Consumer onboarding completion rate (first file imported) | 70% of users who open the app | Analytics event: file_imported_first |
| Enterprise onboarding completion rate (SharePoint connected) | 80% of enterprise trial activations | Analytics event: repository_connected_first |
| Time to first protected file (consumer) | Median <90 seconds | Analytics event timing: app_open → file_encrypted |
| Time to first SharePoint file viewed (enterprise) | Median <3 minutes | Analytics event timing: app_open → file_viewed |

### AI Governance Quality (60 days post-launch)

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| On-device AI classification accuracy (Confidential and above) | 85% precision, 80% recall vs. human-labeled test set | Pre-launch validation on labeled dataset |
| False positive rate (correct files blocked or flagged incorrectly) | <5% of classification events | User dispute rate + admin override rate |
| Policy violation prevention rate (risky shares blocked before send) | 90% of policy-violating shares caught before transmission | Analytics: share_blocked / share_attempted where policy applies |
| AI classification latency (document scan to label applied) | <3 seconds on A14 Bionic or newer; <5 seconds on A12 Bionic | Performance test on target devices |

### Security and DLP (60 days post-launch)

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| DLP control activation rate (screenshot block/watermark triggered) | 100% on sessions with Confidential/Restricted files | QA automated testing across device matrix |
| Unauthorized file egress incidents (file accessed outside app) | Zero confirmed incidents | Security audit + app analytics |
| Session blur on background | 100% — no content visible in iOS app switcher | QA test across device matrix |
| Biometric lock on return | 100% of return-from-background events | QA automated testing |

### Retention and Engagement (90 days post-launch)

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| 30-day retention (consumer) | 40% (file-centric utility products benchmark) | Analytics cohort analysis |
| 30-day retention (enterprise) | 65% (enterprise SaaS benchmark; stickier due to policy enforcement) | Analytics cohort analysis |
| Files classified per active user per week | ≥5 (indicates AI governance is running on real content) | Analytics: ai_classification_events / active_users |
| Enterprise admin policy configuration completion | 70% of enterprise trials create at least 1 custom policy | Analytics event: policy_created |
| NPS (90-day survey, enterprise users) | ≥35 | In-app survey |

### Launch Quality

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| App crash rate | <0.5% of sessions | Crashlytics / instrument telemetry |
| SharePoint sync error rate | <2% of sync operations | Telemetry: sync_failed / sync_attempted |
| API error rate (XQ API calls) | <1% | API Gateway telemetry |
| App Store rating at 30 days | ≥4.3 stars | App Store Connect |

---

## 9. RISKS

### Risk 1: On-Device AI Model Availability and Accuracy

**Description**: The entire AI governance layer — the product's primary differentiator — depends on an on-device CoreML/ONNX model that can reliably detect PII, PHI, CUI, and financial records in document content with acceptable accuracy and latency on supported iOS hardware. There is no indication in the spec that this model exists, has been validated, or has a defined development path. This is the highest risk in Phase 1.

**Likelihood**: High — this is not a solved problem off the shelf for the required classification taxonomy.
**Impact**: Critical — without functional AI classification, the product reverts to a basic encrypted file storage app with no governance differentiation.
**Mitigation**:
- Week 1 AI model strategy spike: define whether XQ builds, buys, or adapts a model; evaluate CoreML-compatible pre-trained models for document classification (e.g., MobileNet-based fine-tuned models, ONNX-converted Hugging Face classifiers)
- Establish a minimum viable accuracy floor (85% precision on PII/PHI detection) as a go/no-go gate before the AI layer is enabled for production users
- Design the AIProvider abstraction so that if local model accuracy is insufficient, a cloud AI fallback (Azure OpenAI, Anthropic via API) can be configured for enterprise tenants without architectural rework
- For v1 launch, consider a staged release: enable AI governance for enterprise customers first (who can validate and override) before consumer GA

---

### Risk 2: iOS DLP API Limitations (Screenshot Blocking, Screen Recording)

**Description**: The spec states screenshot blocking and screen recording prevention as mandatory DLP controls. iOS does not provide a native API to programmatically block screenshots (this was removed in iOS 11 and is not available in any current iOS API). What is available: detecting screenshot capture after the fact (UIApplicationUserDidTakeScreenshotNotification) and applying dynamic watermarks. Screen recording can be detected via UIScreen.isCaptured but cannot be blocked. If the product is marketed with "screenshot blocking" and this capability is impossible on iOS, there is a significant trust and compliance risk.

**Likelihood**: Certain — this is a known iOS platform constraint.
**Impact**: High — enterprise DLP requirements often explicitly require screenshot prevention; marketing this as a capability without the technical backing creates compliance liability.
**Mitigation**:
- Reframe the spec language immediately: "screenshot mitigation" (not "blocking") — the product detects screenshots and applies persistent dynamic watermarks containing user identity and timestamp; this creates accountability without iOS-impossible blocking
- Implement screen recording detection and, on detection, immediately overlay a full-screen blur/block — this is iOS API-supported
- Document this limitation explicitly in enterprise security documentation and DLP compliance materials before sales engages compliance-focused buyers (healthcare, government)
- Ensure the UX communicates to users that content is "watermarked for accountability" rather than "screenshot-blocked"

---

### Risk 3: XQ API Version Compatibility and Offline Policy Enforcement

**Description**: The spec mandates multiple XQ API version adapters (v1, v2, v3) and interface-driven architecture. The XQ API documentation at xq.stoplight.io was not reviewable in this analysis. If the current XQ API does not support offline policy evaluation (i.e., requires network connectivity to validate access or apply policies), then the offline-first value proposition is materially compromised — a user with cached files but no connectivity cannot be governed.

**Likelihood**: Medium — this is a common limitation in cloud-backed encryption key management systems.
**Impact**: High — offline mode is listed as a key differentiator; if policy enforcement fails offline, the secure container fails its core promise.
**Mitigation**:
- Architecture spike in Week 1: catalog current XQ API capabilities against the spec's requirements; specifically validate: does the API support offline policy bundles? Can keys be cached locally for offline decryption within policy bounds?
- Design the XQSecureAPI interface to support an "offline policy cache" model: when online, pull the latest policy bundle and cache it encrypted locally; when offline, evaluate against cached policies; on reconnect, re-validate and update
- Define a maximum policy staleness threshold (e.g., 72 hours) after which offline access to Restricted files is blocked as a fail-secure behavior

---

### Risk 4: SharePoint / Entra Conditional Access Conflicts

**Description**: Many enterprise Entra ID tenants have Conditional Access policies that require apps to be Microsoft-compliant (Intune-enrolled, MAM-registered, or using the Microsoft Authentication Library). If XQ Secure Workspaces does not meet these requirements, the OAuth flow may fail at the token issuance step for SharePoint access, blocking the enterprise onboarding path entirely for Intune-managed customers.

**Likelihood**: High — conditional access requirements are standard in regulated enterprise tenants (healthcare, finance, government).
**Impact**: High — this would block enterprise adoption in the highest-value customer segments.
**Mitigation**:
- Evaluate Microsoft's Mobile Application Management (MAM) SDK integration requirements early; determine whether Intune App SDK integration is required for Phase 1 enterprise targets
- Register the app with Microsoft's partner program to enable Intune-compatible conditional access support
- Build the authentication flow using MSAL (Microsoft Authentication Library) to ensure maximum compatibility with Entra conditional access policies
- During enterprise beta: recruit 3–5 Intune-managed tenants specifically to validate the authentication flow end-to-end before GA

---

### Risk 5: Consumer Activation Without AI Governance Differentiation

**Description**: The consumer onboarding requires no account and delivers immediate file protection. However, if the AI classification layer is not functional or accurate at launch, the consumer user receives an encrypted file storage app — a crowded market (iCloud with Advanced Data Protection, Tresorit, Boxcryptor equivalents). The AI governance layer is what differentiates; without it, consumer acquisition and retention will underperform.

**Likelihood**: Medium — depends on the outcome of Risk 1.
**Impact**: Medium — consumer tier is the bottom-up growth engine; early underperformance damages word-of-mouth and App Store ratings.
**Mitigation**:
- Do not launch the consumer tier until AI classification achieves the 85% precision baseline on the target document categories — consider enterprise-only soft launch first
- In the consumer experience, make the AI classification visible and legible — the first time a file is classified, show the user exactly what was detected ("We found Social Security numbers in this file — it's been marked Confidential and protected"). This earns trust from the AI layer rather than hiding it
- Identify 3–5 specific consumer use cases where the AI governance is unambiguously valuable (medical records, tax documents, legal contracts) and optimize the onboarding narrative for those use cases specifically

---

## 10. RECOMMENDATIONS FOR OTHER AGENTS

### What the UX Agent Must Prioritize

1. **The onboarding split is the highest-risk UX moment.** The Welcome screen ("Continue Local-First" vs "Connect Enterprise Workspace") must be immediately understandable without explanation. User research is needed on label copy — "Local-First" is developer language, not user language. Test alternatives: "Personal Vault" vs "Work Workspace" or "Just for Me" vs "Connect My Organization."

2. **AI risk signals must not feel alarming.** The spec is clear that AI governance should be ambient and invisible. When risk surfaces — a classification badge, a warning before sharing — it must be calm, specific, and human-readable. "This document contains personal information. We'll make sure it's shared securely." not "POLICY VIOLATION DETECTED: PII CLASSIFICATION THRESHOLD EXCEEDED." Study Flighty's real-time UX and Gentler Streak's emotionally intelligent notification design as specified in the design guidance section.

3. **The Secure File Viewer is the product's moment of truth.** The combination of sensitivity label in the header, visible watermark on sensitive content, and the collapsible AI classification panel must feel like protection, not surveillance. The classification panel should be progressive disclosure — collapsed by default, available on demand. Never force the user to dismiss it to read their document.

4. **Sensitivity labels must be universal and consistent.** Every file in every screen (Repository Browser, Home Recent Files, Sharing Center, Offline Files) must display the same classification chip in the same position with the same color coding. This builds trust in the system. Any inconsistency in label display will erode confidence in the AI governance.

5. **The share flow's AI risk summary is a critical conversion moment.** This is where the user decides to trust the system or not. The risk summary must explain the risk in one sentence, explain what protection is being applied in one sentence, and offer a clear confirm action. It must never be a wall of security jargon. Consider designing the risk summary card as a named pattern that gets reused exactly the same way across all contexts where AI risk is surfaced.

6. **Animation system (spec requirement)**: The spec requires an animation for every UX element entry, exit, and tap interaction at 60 FPS minimum. This is a non-trivial engineering commitment — the UX agent should establish a motion design language early and the animation system should be built as a shared module, not added per-screen. Prioritize reduced-motion accessibility support alongside the full animation system.

7. **iPad layout is a first-class requirement.** The spec explicitly supports iPad and iPhone. The Repository Browser and File Viewer screens in particular need a true iPad layout (SplitView — folder tree on the left, file list and viewer on the right), not a scaled-up phone layout. This should be designed from the start, not retrofitted.

---

### What the Architecture Agent Must Know

1. **Interface-driven architecture is a hard requirement, not a preference.** The spec explicitly states: no direct API calls in business logic. Every external system — XQ API, SharePoint, IDPs, AI models — must be accessed through a Swift protocol interface with injected implementations. This is non-negotiable and must be enforced at the code review level from the first commit.

2. **The XQSecureAPI interface needs multi-version adapter support built from the start.** The spec anticipates API versioning. The architecture must support runtime version negotiation — the app must be able to determine which XQ API version is available and route to the correct adapter. Do not build v1 assuming v2 will be a refactor; build the adapter pattern now.

3. **The AI governance layer requires its own abstraction.** The AIProvider protocol interface must support: local CoreML model, ONNX runtime model, and remote cloud AI providers (OpenAI, Anthropic, Azure OpenAI, AWS Bedrock). The architecture must support per-tenant, per-policy, per-classification-level model switching at runtime — configured without app rebuild. Specifically: CUI content must be evaluated by the local model even if cloud AI is enabled for other content types.

4. **Offline-first is a data architecture constraint, not just a UX feature.** The sync engine must support: delta sync (not full re-download), optimistic local writes with server reconciliation, policy-aware sync (do not sync files whose policy prohibits offline storage), and a secure encrypted sync queue that persists across app restarts. This is a complex data layer — allocate a full sprint to its design and prototype before any file editing features are built on top of it.

5. **Kotlin Multiplatform (KMP) is the recommended architecture for cross-platform expansion.** The spec explicitly recommends SwiftUI + Jetpack Compose + KMP as the "safest long-term architecture." For Phase 1 (iOS only), build the business logic layer, policy engine, AI abstraction, security model, and sync engine as KMP modules from the start. SwiftUI is the iOS UI layer. This avoids a full rewrite when Android is prioritized.

6. **The secure file system model has a critical constraint.** Files must never be exposed to the iOS filesystem outside the app sandbox. This means: no use of UIDocumentPickerViewController for export, no handoff to QuickLook's system sharing, no "Open In" to other apps. The secure viewer must use custom renderers for any format that requires an "Open In" workflow in iOS — this is a significant constraint on the file viewer implementation that must be resolved before the viewer sprint.

7. **Localization is a first-class architectural requirement.** All UI strings must be externalized to /localization/[lang].json files from day one. No hardcoded strings. The architecture must support runtime language switching without app restart and OTA translation updates. This is easier to build from the start than to retrofit.

8. **Resource control must be designed proactively.** On-device AI inference on older supported devices (A12 Bionic era) will have meaningful battery and thermal impact. The architecture must include an adaptive resource control layer that throttles AI processing based on device thermal state, battery level, and foreground/background state. BGTaskScheduler is specified for background tasks — use it for non-urgent AI scanning rather than blocking the foreground thread.

---

### What the Security Agent Must Address

1. **The iOS screenshot limitation is a compliance documentation problem first.** The security agent must produce a clear, accurate data sheet for enterprise buyers describing what screenshot protection the app provides and does not provide on iOS. Claiming "screenshot blocking" when iOS only permits screenshot detection and post-hoc watermarking creates legal liability. The correct claim: "screenshot accountability via persistent user-identity watermarking and immediate detection notification." This must be documented before any enterprise sales conversations.

2. **Secure Enclave key lifecycle for device migration is undesigned.** When a consumer user gets a new iPhone and restores from iCloud backup, their Secure Enclave keys do not migrate (they are hardware-bound). The security agent must define: what happens to locally encrypted files when a user moves to a new device? Options: re-encryption via XQ's key management on first login; loss of local-only files (must warn user prominently); or a secure key escrow mechanism for consumer users who opt in. This must be resolved before Phase 1 GA — it is a data loss scenario.

3. **Jailbreak/root detection must be layered, not binary.** A single jailbreak detection check can be bypassed by sophisticated users. The security agent should implement and validate a multi-layer approach: filesystem artifact checks (Cydia paths, etc.), sandbox escape tests, code signature validation, and runtime hook detection. The result should be a device trust score used by the policy engine, not a simple pass/fail that blocks all access — some enterprise policies may want to allow degraded access on jailbroken devices rather than locking out users entirely.

4. **Certificate pinning must be implemented and the revocation path must be designed.** All XQ API traffic must use certificate pinning (already called out in the spec's security architecture). The security agent must also design the emergency certificate rotation procedure: if XQ's certificate is compromised, how does the app receive an updated pin without requiring a full App Store update? Dynamic pin updating via remote configuration with multiple pin backup must be designed before launch.

5. **The offline policy cache is a security boundary.** When enterprise policies are cached locally to enable offline governance, that cache is a target. The security agent must define: how is the policy cache encrypted? Is it bound to the same Secure Enclave key as the files? What is the maximum TTL before cached policies are considered stale? How does the app behave if the policy cache is tampered with? The fail-secure answer: if tamper is detected, block all access to Restricted and Confidential files until policies can be refreshed.

6. **Audit log integrity must be verifiable.** Enterprise compliance requirements (especially in regulated industries) require that audit logs cannot be tampered with by the app, the user, or even XQ. The security agent should design the audit log with cryptographic integrity: each log entry should be signed, and the log should support a chain-of-custody verification mechanism. This is a Phase 1 requirement for enterprise compliance claims — do not defer.

7. **Data residency verification must be technically demonstrable.** The spec claims "XQ holds no customer data at any point." The security agent must produce a technical data flow diagram showing exactly what data (file content, metadata, keys, policy events) transits XQ infrastructure at every step, what stays on-device, and what is stored at the customer's SharePoint. This diagram must be reviewed by legal before enterprise sales begins — a single counterexample that undermines the data residency claim will damage enterprise trust.

---

**Document complete.**
**File**: /Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt (source specification)