# Swift Build — Status & Phase 1 Alignment

What is and isn't in the native iOS implementation as of 2026-05-23, after the Phase 1 IA-alignment work in this session.

> **Honest scope note.** A full native rewrite to visual + behavioral parity with the (substantially evolved) HTML prototype is genuinely months of engineering. This document covers (a) what already existed before this session, (b) the focused Phase 1 alignment delivered now, and (c) a prioritized list of what's still missing.

---

## 1. What already exists in the Swift project

The `ios/` directory holds a **substantial in-progress Swift codebase** built before this session — 80+ Swift files across these domains:

### App shell
- `App/XQSecureWorkspacesApp.swift` — @main entry point.
- `App/RootView.swift` — top-level route switcher.
- `App/AppCoordinator.swift` — @MainActor ObservableObject with auth, routing, repository wiring.
- `App/AppTheme.swift`, `App/Auth/*.swift` — MSAL, App Attest, Keychain, XQ subscription.
- `App/Graph/*.swift` — Microsoft Graph integration.

### Core modules
- `Modules/Core/Models/DomainModels.swift` — domain types (`SecureFile`, `XQSession`, sensitivity levels, etc.).
- `Modules/Core/Protocols/*` — `XQSecureAPI`, `PolicyEngine`, `RepositoryProvider`, `AIProvider`, security protocols.
- `Modules/Networking/*` — `XQAPIGateway`, `XQAPIV3Adapter`, `LocalOnlySecureAPI` (dev/free fallback).
- `Modules/Policy/FuzzyPolicyEngine.swift`.
- `Modules/Security/*` — JailbreakDetectorImpl, SecureFileStore.
- `Modules/Repository/Providers/*` — `LocalVaultProvider`, `OfflineQueueStore`, `SharePointProviderImpl`, Microsoft Graph repository.
- `Modules/Sync/SyncEngine.swift`.
- `Modules/AI/CoreMLProvider.swift`.
- `Modules/FileIntelligence/*` — orchestrator + local provider + lineage tracker.
- `Modules/EmailIntelligence/*` — orchestrator + sender profile store + email models.

### UI components
- `Modules/UI/Components/AppIconSystem.swift` (SF Symbol tokens used by tabs).
- `Modules/UI/Components/FileRowView.swift`, `SensitivityBadge.swift`, `RiskAlertCard.swift`, `SecurityIntelligencePanel.swift`.

### Screens (UI/Screens/*)
Auth, AI, AIImport, Email (Inbox / Compose / Thread / Detail / PhishingAlert), FileBrowser (Browser / Folder / Risk Dashboard / Semantic Search / AI Organize / Sample data repo), FileViewer (Document editor / PDF / QuickLook / Secure share sheet / Data lineage / On-device AI orchestrator / Document content generator), Home, Main, Notifications (NowTabView), Onboarding, Settings, Sharing (Center / Received / Group invite), Splash, Welcome, Workgroup (Select / Workspaces & Groups).

### What was NOT done before this session
- Per-screen visual fidelity to the latest prototype state (Profile, edit-mode banner, AI drawers, resharing modes, edit-state strips, etc.).
- The 3-tab IA — the existing `MainTabView` had **5 tabs**.

---

## 2. Phase 1 alignment delivered this session

Three coordinated changes — all minimum-blast-radius:

### 2.1 `MainTabView.swift` — 5 tabs → 3 tabs
- Removed the AI tab `tabItem` (AI surface relocated into Now → Ask).
- Removed the Settings tab `tabItem` (Settings consolidated into Profile, presented as a sheet).
- Added `.sheet(isPresented: $coordinator.showingProfile) { ProfileView() }` so the top-right avatar can trigger Profile from anywhere.
- `AppCoordinator.AppTab.ai` and `AppCoordinator.AppTab.settings` enum cases **left intact** to avoid cross-file compile breakage in screens that still reference them.

### 2.2 `AppCoordinator.swift` — Profile presentation hooks
Added (additive only):
- `@Published var showingProfile: Bool = false`
- `func presentProfile() { showingProfile = true }`
- `func dismissProfile() { showingProfile = false }`

No existing properties or methods touched.

### 2.3 `NotificationsView.swift` (the `NowTabView` host)
- `NowSubTab` enum: dropped `.shared` and `.aiActions`, added `.ask`. Final order: **Overview · Ask · Activity · Security**.
- Body switch updated accordingly.
- Dead helper vars `sharedStub`, `aiActionsStub` removed.
- New `askTab` private view wraps the existing `AIAssistantView()` so the AI surface is rendered inside Now → Ask (no duplication of AI content).
- Toolbar gains the top-right **[BW] avatar button** → `coordinator.presentProfile()`. Matches the prototype's universal Profile entry pattern. (Pattern needs to be replicated on `FileBrowserView` and `EmailInboxView` — see §5 below.)

### 2.4 `ProfileView.swift` — brand new
`ios/XQSecureWorkspaces/Modules/UI/Screens/Profile/ProfileView.swift` — single-file SwiftUI surface that mirrors the prototype's `#s-profile` screen:
- Identity card (avatar, name, title, org, badges, "Last login" caption).
- Security Health 2×2 mini-grid (MFA, Sessions, Compliant, Encryption).
- Quick Actions row (Change Password, Manage Devices, Configure MFA, Audit Logs).
- Sticky horizontal **quick-nav chip bar** for the 8 subsections.
- **Stacked subsections** with anchor IDs: General · Security · Notifications · Integrations · Workspace · Devices · Billing · Admin.
- Last-viewed section persisted to `UserDefaults` key `xq.profileSection` (mirrors the prototype's localStorage key).
- "Done" toolbar action dismisses the sheet.
- Sign-out button at the bottom routes through `coordinator.signOut()`.

`ProfileSection` enum in the same file with `.allCases` ordering matching the prototype.

> ⚠️ **Xcode project file:** the new `ProfileView.swift` lives on disk but **may not be in the `XQSecureWorkspaces.xcodeproj` build phase yet.** Depending on whether `project.yml` is the source of truth (XcodeGen-style) or `project.pbxproj` is hand-edited, you may need to either re-run XcodeGen or add the file to the target manually. The `project.yml` and `project.pbxproj` files are in the pre-existing `M` (modified) git state — not touched by this session.

---

## 3. What still needs alignment with the prototype

These items are **deferred to follow-up sessions**. Each is non-trivial enough that batching them with the IA work would mean shipping a mountain of half-baked code.

### 3.1 Top-right Profile avatar on remaining tabs
- `FileBrowserView` — needs `ToolbarItem(placement: .navigationBarTrailing)` with avatar + extra header buttons (Create/Import + risk + ellipsis).
- `EmailInboxView` — same avatar pattern next to compose pencil.
- (`NowTabView` has it as of this session.)

### 3.2 Files screen — Create / Import chooser
- New `CreateMenuSheet.swift`: blank doc + 4 templates (Memo / Report / Meeting Agenda / Structured Form) + 1 import row that routes to existing `AIImportView`.
- Replace the `+` button's destination in `FileBrowserView` with the sheet.
- Wire each template creation to a new `createDocument(template:)` method on `AppCoordinator` that opens `DocumentEditorView` in Edit mode and shows the "New Document" indicator.

### 3.3 Doc Editor enhancements (`DocumentEditorView.swift`)
- Presence row (3 collaborator avatars + active-dot).
- Edit-state strip (badges: Editable / Comments On / External Editor).
- Collab chip bar: Track Changes, Suggesting, Comments [N], Versions [N], Request Approval.
- Hook to Phase 1 of the collaboration transport (see `COLLABORATION_SHARING_SPEC.md`).

### 3.4 File Viewer (`FileViewerView.swift`)
- Top-right **Edit** button — only enabled for editable formats; opens `DocumentEditorView` in Edit mode.
- Edit-state strip under the nav bar showing classification badges + owner + workspace + expiration + reshare posture.
- AI panel slide-up (mirror prototype's `#fv-ai-panel`).
- Already has a `SecureShareSheet.swift` — add the resharing-mode selector + AI Sharing Assistant card per `COLLABORATION_SHARING_SPEC.md` §5.

### 3.5 Email Compose
- AI Composition drawer (Help-Me-Write input, 5 rewrite chips, quick actions, streamed output, governance footer) per `AI_COMPOSITION_SPEC.md`.

### 3.6 9-state editability vocabulary
- `EditabilityState` enum + `DocumentEditability` struct (illustrated in `COLLABORATION_SHARING_SPEC.md` §8.1).
- Reusable `EditabilityBadge` SwiftUI component matching the prototype's 9 CSS variants (`ed-edit` / `ed-view` / `ed-comment` / `ed-pending` / `ed-restricted` / `ed-expired` / `ed-external` / `ed-local` / `ed-ai`).
- Plumbing from policy engine → state derivation → UI surfaces.

### 3.7 Resharing & lineage
- `ReshareMode` enum + share-edge data model from `COLLABORATION_SHARING_SPEC.md` §5.
- Lineage visualization for the share sheet.
- API endpoints per spec §9.

### 3.8 AI orchestration plumbing
- `AICompositionService` + provider plugin protocol (`AIProvider`).
- Streaming via `AsyncThrowingStream<ResponseChunk, Error>`.
- Policy gate calls per `AI_COMPOSITION_SPEC.md` §4.
- Already has `Modules/AI/CoreMLProvider.swift` — needs the orchestrator wrapper that routes by classification.

### 3.9 Onboarding path persistence
- The prototype skips `s-workgroup-select` for personal onboarding via `xq.onbPath` in localStorage. Mirror this in Swift `OnboardingView`: persist chosen path in `UserDefaults` and skip the workgroup-select view when `personal`. Existing Swift onboarding goes through workgroup for both paths.

### 3.10 iPad / desktop adaptations
- The prototype has a device-mode switcher (Mobile / iPad / Desktop) — irrelevant for native Swift (the OS decides), but the iPad sidebar pattern is relevant. Replace the `TabView` with a `NavigationSplitView` on iPad with `UIDevice.current.userInterfaceIdiom == .pad` so the 3-tab nav becomes a left rail.

---

## 4. Build & run

### 4.1 Prereqs
- Xcode 16+ (deployment target iOS 17+).
- Swift Package Manager dependencies resolved on first open.
- MSAL configured: set `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `XQ_API_KEY`, `XQ_BASE_URL` in `Info.plist`. For dev work without those keys, the coordinator falls back to a placeholder `MSALAuthProvider` and the in-simulator `devLogin()` button.
- Run on iPhone 15 Pro simulator (the prototype's reference device).

### 4.2 Bring up the project
```bash
# If XcodeGen is the source of truth
cd ios
xcodegen generate
open XQSecureWorkspaces.xcodeproj
```

If `project.yml` doesn't list `Modules/UI/Screens/Profile/` yet, add it and re-run `xcodegen generate`. Otherwise, drag `ProfileView.swift` into the `XQSecureWorkspaces` target in Xcode manually.

### 4.3 Verify Phase 1 alignment
1. Sign in (or `devLogin()` in simulator) → land on Files.
2. Bottom nav: **3 tabs only** (Files, Messages, Now).
3. Tap **Now** → see the new sub-tab bar (Overview, **Ask**, Activity, Security).
4. Tap **Ask** → AI assistant surface appears (the existing `AIAssistantView` content).
5. Tap the top-right **[BW] avatar** on Now → Profile sheet presents.
6. Cycle the Profile chip bar — the chip color follows; the active section anchor scrolls into view.
7. Tap **Done** → sheet dismisses, you return to Now.

### 4.4 Compilation note
- I cannot run `xcodebuild` from this environment.
- The deltas are minimum-surface (1 new file, 3 edited files). Existing references to `AppTab.ai` / `AppTab.settings` are preserved so other screens still compile.
- If there are compile errors after pulling, the most likely cause is that `ProfileView.swift` isn't in the Xcode target's build phase — see §2.4.

---

## 5. Recommended follow-up sequence

In order of biggest UX delta per session:

1. **Avatar entry on Files + Messages** (5 min each — just a `ToolbarItem` block).
2. **Files Create/Import chooser sheet** (1–2 hours — new file + AppCoordinator hook).
3. **DocumentEditorView edit-mode polish** — collab chip bar + edit-state strip.
4. **FileViewerView edit button + edit-state strip + AI slide-up panel**.
5. **EmailComposeView AI drawer** — meaningful UX win, contained scope.
6. **EditabilityBadge component + propagation** — touches many rows but is a single reusable view.
7. **Resharing mode selector in SecureShareSheet** — moderate-sized rewrite of one sheet.
8. **AICompositionService orchestrator** — pure plumbing, no UI changes.
9. **Onboarding personal-path workgroup skip** + persistence.
10. **iPad NavigationSplitView adaptation**.

Each item maps to a section of an existing spec doc:
- `APPLICATION_FUNCTIONALITY.md` (screen-level functionality)
- `AI_COMPOSITION_SPEC.md` (AI orchestration + drawer/panel design)
- `COLLABORATION_SHARING_SPEC.md` (editability, resharing, group sharing)
- `SITEMAP.md` (navigation map)

---

## 6. Mapping the brief's deliverables to current state

| Brief deliverable                          | Status                                                                            |
| ------------------------------------------ | --------------------------------------------------------------------------------- |
| Complete SwiftUI application structure     | ✅ Pre-existed; preserved.                                                         |
| Reusable components                        | ✅ Components/ folder exists; ProfileView introduces patterns reusable elsewhere.  |
| View models                                | ✅ Pre-existed for major screens (FileBrowser, FileViewer, EmailInbox, etc.).       |
| Models                                     | ✅ `Modules/Core/Models/DomainModels.swift` exists.                                |
| Navigation architecture                     | ✅ Updated this session to mirror prototype IA (3-tab + Profile sheet).            |
| Mock services                              | ✅ `SampleDataRepository.swift`, `LocalOnlySecureAPI.swift` for dev.               |
| Sample data                                | ✅ Pre-existed in `SampleDataRepository`.                                          |
| State management                           | ✅ `AppCoordinator` is the single source of truth (MVVM-adjacent).                  |
| Security/governance UI patterns            | ⏳ Partial — `SensitivityBadge`, `SecurityIntelligencePanel` exist; editability/reshare missing. |
| Functional workflows                       | ⏳ Partial — auth, vault, browse, view, share, AI exist; doc-editing collab, resharing modes missing. |
| Build/run instructions                     | ✅ This document, §4.                                                              |
| Clear code organization                    | ✅ Modular feature folders; idiomatic SwiftUI.                                     |

---

---

## 7. Updates after 2026-05-23 alignment

### 7.1 Build is green (verified)
- `xcodegen generate` (XcodeGen 16.3 / Swift 6.0 / iOS 17 target) regenerates `XQSecureWorkspaces.xcodeproj`, picking up `ProfileView.swift` automatically because `project.yml` declares sources by directory path.
- `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` → `** BUILD SUCCEEDED **` (1 unrelated AppIntents metadata warning only).
- App installs and launches cleanly on the simulator (verified via screenshot of the Welcome screen).

### 7.2 Navigation trap audit + fixes
Found and removed every `coordinator.navigate(to: ...)` / `coordinator.route = ...` call that replaced the root view from a non-startup screen — they were the cause of users being stranded with no back path:

1. **SettingsView.swift** — "Policy Management" button was `coordinator.navigate(to: .adminPolicy)`. Now uses `NavigationLink(destination: AdminPolicyView())` so AdminPolicy pushes onto SettingsView's own NavigationStack with a system back button.
2. **FileRiskDashboardView.swift** — "Run AI Remediation" button was `dismiss(); coordinator.navigate(to: .aiImport)`. Now uses `NavigationLink(destination: AIImportView())` — pushes onto the dashboard's NavigationStack instead of dismissing-and-replacing-root.
3. **FolderView.swift** — `coordinator.route = .fileViewer(file)` on file-row tap. Now sets `pendingPushFile = file`, which a new `.navigationDestination(item: $pendingPushFile)` modifier pushes onto the enclosing FileBrowserView NavigationStack.

To prevent re-introduction of these traps, `AppCoordinator.AppRoute` was trimmed from 12 cases to 6:

```swift
enum AppRoute {
    case splash, welcome, xqVerification(...), home, securityFailure(_), onboarding
}
```

Removed: `.fileBrowser`, `.fileViewer(_)`, `.aiImport`, `.emailInbox`, `.settings`, `.adminPolicy`. Any future code that tries `coordinator.navigate(to: .fileViewer(...))` will fail to compile, forcing a proper push or sheet. `RootView`'s switch was shrunk to match.

### 7.3 QuickLook fullScreenCover
`FileViewerView.swift` — QuickLook fullScreenCover lacked an explicit dismiss. Now wrapped in a `NavigationStack` with a "Done" toolbar item that always closes the cover. `.ignoresSafeArea()` narrowed to `.bottom` only so the inherited toolbar stays visible.

### 7.4 NowTabView scrollability
`NotificationsView.swift` — Outer VStack and switch-result content now claim full available height via `.frame(maxWidth: .infinity, maxHeight: .infinity)`. The switch is wrapped in `Group { ... }` so the frame applies uniformly to all four sub-tabs (Overview / Ask / Activity / Security). Without this the switch-result View could size to intrinsic content height, collapsing the inner ScrollView's bounds.

### 7.5 Scrollability audit on other top-level surfaces
- `AIAssistantView` — has `ScrollView` (line 44) and `ScrollViewReader { ScrollView }` (lines 125–126) ✓
- `FileBrowserView` — has `ScrollView` (line 103) ✓
- `EmailInboxView` — uses `emailList` (List-based, scrollable) ✓
- `ProfileView` (new this session) — uses `ScrollView` + `LazyVStack` ✓

The deeper "audit ALL screens" pass requested in the latest brief is **NOT** complete — secondary screens (FolderView, FileRiskDashboardView, AIImportView, SemanticSearchView, EmailComposeView, DocumentEditorView, AdminPolicyView, Settings sections, etc.) need individual inspection. Documented in §8 below.

---

## 8. Latest brief — explicit status mapping

Mapping the latest follow-up brief ("major UX and functionality gaps") to current state:

| Item                                                          | Status                                                                                |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **1. NOW screen scrollable**                                  | ✅ Fix landed (§7.4). Static change verified; runtime tap-verification deferred to user. |
| 1. Audit all screens for scrollability                        | ⏳ Partial — 4 top-level surfaces audited (§7.5); ~15 secondary screens NOT audited.    |
| **2. Profile section**                                        | ✅ `ProfileView.swift` exists with identity card, Security Health, Quick Actions, 8-section chip nav, persistence. Triggered from NowTabView avatar via `.sheet`. |
| 2. Avatar on every top-level screen                           | ⏳ Wired on Now only. Files + Messages still need toolbar avatar (~5 min each).         |
| 2. Account / password / MFA / passkeys / sessions / devices   | ⏳ All represented as **read-only display rows** in ProfileView. Real workflows (MFA enroll, password reset, device revoke) NOT implemented. |
| **2. Gmail integration** (Gmail API + OAuth)                  | ❌ Not implemented. Would need GoogleSignIn SDK, OAuth flow, Gmail API client, IMAP-style sync, Keychain storage. Multi-week effort. |
| **2. Outlook / Microsoft 365 integration**                    | ⏳ MSAL infrastructure exists (`Modules/App/Auth/MSALAuthProvider.swift`, `MicrosoftGraphClient.swift`), so the auth half is partially wired. Mail-specific surfaces (send/receive/sync/unified inbox) NOT implemented. |
| 2. Google Drive / OneDrive / Calendar / Contacts sync          | ❌ Not implemented.                                                                    |
| 2. Multi-account support / account switching                  | ❌ Not implemented.                                                                    |
| 2. Token refresh + Keychain credential storage                | ✅ Infrastructure exists (`KeychainSessionStore.swift`, `XQAuthOrchestrator`) but only wired for XQ session, not Gmail/Outlook accounts. |
| **3. Every button functional**                                | ⏳ Many functional (auth, share sheet, AI triage, file rows, profile chips). Many are still placeholder labels — needs per-button audit. NOT systematically done. |
| 3. Loading / disabled / empty / error states                  | ⏳ Present in some VMs (EmailInboxViewModel has `isLoading`, `isTriaging`); inconsistent across the app. |
| 3. Haptic feedback                                            | ❌ Not added.                                                                          |
| 3. Accessibility labels                                       | ⏳ Some present (e.g., the new Profile avatar button); broadly inconsistent.            |
| **4. Navigation validation / no dead-ends**                    | ✅ Root-replacement traps fixed (§7.2). The architecture is now NavigationStack-only for in-app navigation. |
| 4. UI test coverage / navigation integration tests             | ❌ No test targets created this session.                                               |
| **5. Centralized router / shared state**                      | ✅ `AppCoordinator` is the central state container. Routing now scoped to startup only; per-tab nav uses NavigationStack — which is the recommended SwiftUI pattern post-iOS 16. |
| 5. Service abstraction for Gmail / Outlook / Files / etc.    | ⏳ Files + Governance + AI have provider protocols (`RepositoryProvider`, `XQSecureAPI`, `AIProvider`). Gmail/Outlook layers don't exist. |
| **6. Pull to refresh / loading skeletons / empty states**     | ❌ Not systematically added.                                                            |
| 6. Smooth transitions / persistent nav context                | ✅ Per-tab NavigationStacks preserve push state when switching tabs (SwiftUI default).  |
| 6. iPad split-view layouts                                    | ❌ Still uses iPhone-style TabView on iPad. NavigationSplitView refactor deferred.      |
| 6. Keyboard shortcuts                                         | ❌ Not added.                                                                          |

### Honest scope summary

What's done this session: **navigation traps fixed, dead routes removed, QuickLook hardened, NOW scroll repaired, build verified, scroll audit on top-level surfaces**.

What's NOT done (would dwarf one session): **Gmail/Outlook OAuth and mail integration, per-button audit, haptics, UI tests, iPad NavigationSplitView, every secondary-screen scroll audit, loading/empty/skeleton states across the app**. Each of these is a meaningful multi-day effort; bundling them into one half-baked drop would be worse than calling them out for follow-up.

---

*Last updated: 2026-05-23 (Navigation-trap + NOW scroll fix session).*
