The spec is comprehensive. I now have everything needed to produce a detailed, grounded Phase 1 delivery pipeline design.

---

# XQ Secure Workspaces iOS — Phase 1 Delivery Pipeline Design

---

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces is a Zero Trust, AI-governed mobile platform built on SwiftUI (iOS native UI) with Kotlin Multiplatform (KMP) carrying shared business logic across future Android and desktop targets. Phase 1 delivers Auth, File Browser, Secure Viewer, XQ Encryption, SharePoint integration, and Offline Cache — the foundational security container that all subsequent phases depend on.

The delivery pipeline must enforce several non-negotiable constraints that flow directly from the spec:

- Files and session tokens must never leave the app container unencrypted. The CI/CD system must verify this through static analysis and cannot relax code signing or entitlements.
- The interface-driven architecture (no direct API calls in business logic) means the pipeline can validate protocol conformance as a build gate — a mock-based test suite is tractable without live services.
- The spec mandates interchangeable AI models and version-gated remote configuration. The pipeline must therefore support OTA config delivery independently of binary releases.
- Force update, soft update, and kill switch capabilities are first-class requirements (spec section 16), not post-launch additions. Their infrastructure must be live before the first TestFlight build.
- KMP shared modules are compiled as XCFrameworks consumed by the Xcode project. The build pipeline must treat KMP compilation as a first-class stage, not an afterthought.

The recommended toolchain is GitHub Actions as the CI/CD orchestrator, Fastlane for iOS-specific automation (code signing, TestFlight upload, release notes), and Xcode Cloud as an optional parallel track for App Store Connect integration. Firebase Remote Config is the recommended feature flag and dynamic config backend.

---

## 2. CI/CD PIPELINE DESIGN

### Tool Selection

**Primary Orchestrator: GitHub Actions**

Rationale: GitHub Actions is the strongest choice because the spec mandates interface-driven architecture verified through automated tests, and GitHub Actions provides the most flexible matrix build capability needed to compile KMP for multiple targets. It also integrates cleanly with code scanning (CodeQL), dependency auditing, and secret management via GitHub Secrets without requiring a separate secret store for the CI layer.

**iOS Automation Layer: Fastlane**

Fastlane handles everything iOS-specific: certificate and provisioning profile management via match, TestFlight uploads via pilot, App Store submissions via deliver, and screenshot automation via snapshot. This keeps platform-specific concerns out of the workflow YAML and in version-controlled Fastfile lanes.

**Supplementary: Xcode Cloud**

Xcode Cloud is used for one specific purpose: App Store Connect integration and notarization. It handles the final submission workflow because it runs on Apple-managed infrastructure with native access to App Store Connect APIs. All other stages run in GitHub Actions.

### Pipeline Stages

```
Feature Branch Push
        |
        v
[Stage 1: Lint + Static Analysis]
  - SwiftLint (enforcing interface-driven rules)
  - Detekt for KMP Kotlin code
  - CodeQL security scanning
  - Dependency vulnerability audit (swift-package audit)
  Duration target: < 3 minutes
        |
        v
[Stage 2: KMP Build]
  - Compile shared KMP module
  - Run KMP unit tests (pure Kotlin, no iOS dependency)
  - Generate XCFramework for iOS consumption
  - Publish XCFramework artifact for downstream stages
  Duration target: < 8 minutes
        |
        v
[Stage 3: Unit Tests]
  - XCTest suite against mock providers (never real XQ API)
  - Test XQSecureAPI protocol adapter implementations
  - Test policy engine logic (fuzzy logic unit tests critical)
  - Test offline cache encryption/decryption
  - Coverage gate: minimum 80% for Core/ and Security/ modules
  Duration target: < 6 minutes
        |
        v
[Stage 4: Security Scan]
  - MobSF static scan (detects hardcoded secrets, insecure APIs)
  - SAST via CodeQL Swift queries
  - Entitlements validation (ensure no prohibited entitlements present)
  - Check that no test credentials appear in any source file
  Duration target: < 5 minutes
        |
        v
[Stage 5: Build — Debug/Staging]
  - Fastlane: gym build with Staging scheme
  - Inject environment config from GitHub Secrets
  - No real API keys in the binary — all resolved at runtime via RemoteConfigProvider
  Duration target: < 10 minutes
        |
        v
[Stage 6: UI Test Suite]
  - XCUITest against Simulator (iPhone 16 Pro, iPad Pro M4)
  - Screenshot blocking behavior verification
  - Background blur activation test
  - Secure container escape attempt tests
  - Share sheet restriction verification
  Duration target: < 15 minutes on parallel simulators
        |
        v
[Stage 7: Integration Tests] (develop branch and above only)
  - Tests against staging XQ API environment
  - SharePoint OAuth flow with test tenant
  - Offline cache encryption persistence test
  - Version check / force update response parsing
  Duration target: < 10 minutes
        |
        v
[Stage 8: Performance Benchmarks]
  - XCTest Metrics: app launch time < 2 seconds
  - File decrypt and render time benchmarks
  - Memory footprint during AI model initialization
  - Results archived; regression > 20% blocks merge
  Duration target: < 8 minutes
        |
        v
[Stage 9: Sign + Package]
  - Fastlane match fetches certificates from private certs repo
  - Signing with Distribution certificate for TestFlight
  - IPA generation with embedded Staging config
        |
        v
[Stage 10: Distribute to TestFlight] (develop branch only)
  - Fastlane pilot uploads IPA
  - Automatic changelog from git commit messages
  - Notifies Slack channel #ios-builds
        |
        v
[Stage 11: App Store Submission] (main branch, tagged release only)
  - Xcode Cloud triggered via App Store Connect API
  - Fastlane deliver uploads metadata
  - Manual review trigger in App Store Connect
```

### Branch Strategy

```
main
  - Protected. Requires 2 approvals + all CI stages green.
  - Tagged commits trigger App Store submission workflow.
  - Force update minimum version configuration lives here.

develop
  - Integration branch. Single approval required.
  - All pushes trigger full pipeline including TestFlight upload.
  - Feature flags default to OFF on builds from this branch.

feature/<ticket-id>-<short-description>
  - Individual developer branches.
  - Push triggers stages 1–5 only (no TestFlight, no integration tests).
  - Must branch from develop.

hotfix/<ticket-id>-<description>
  - Branches from main.
  - Triggers full pipeline including TestFlight upload to hotfix group.
  - Merges to both main and develop.

release/v<major>.<minor>.<patch>
  - Cut from develop when ready for release candidate.
  - Final integration test and performance benchmark run.
  - Merges to main after App Store approval received.
```

### PR Gates (must pass before merge)

The following gates are enforced by branch protection rules and cannot be bypassed:

1. All CI pipeline stages green (no manual override permitted for Security Scan failures)
2. SwiftLint zero violations (warnings are acceptable; errors block merge)
3. Code coverage for Core/ and Security/ modules meets 80% floor
4. No new secrets detected by git-secrets pre-receive hook
5. KMP XCFramework builds successfully (ensures shared module is not broken)
6. At least one reviewer who is not the PR author
7. Linear commit history enforced (squash merges only to develop and main)
8. PR description includes TestFlight test instructions for UI-impacting changes

---

## 3. BUILD CONFIGURATION

### Xcode Project Structure

The Xcode workspace contains two projects: the iOS app project and the KMP-generated XCFramework project. They are linked via a local Swift Package.

```
XQSecureWorkspaces.xcworkspace
├── XQSecureWorkspaces.xcodeproj
│   ├── Targets
│   │   ├── XQSecureWorkspaces (main app)
│   │   ├── XQSecureWorkspacesTests (unit tests)
│   │   └── XQSecureWorkspacesUITests (UI tests)
│   └── Configurations
│       ├── Debug.xcconfig
│       ├── Staging.xcconfig
│       └── Production.xcconfig
└── Packages
    └── XQShared (KMP XCFramework wrapped in Swift Package)
```

The xcconfig files inject environment-specific values at build time without touching source code. No #if DEBUG blocks containing API endpoints or key material are permitted.

### Build Targets

**Debug**
- Bundle ID: `com.xqmsg.secureworkspaces.debug`
- Used for local development only
- Points to XQ API sandbox environment
- Verbose logging enabled including AI model inference timing
- Jailbreak detection disabled (allows simulator use)
- Remote config polling disabled; local config JSON file used instead

**Staging**
- Bundle ID: `com.xqmsg.secureworkspaces.staging`
- Distributed via TestFlight to internal and external testers
- Points to XQ API staging environment
- Certificate pinning active against staging certificate
- Remote config active, pointing to staging Firebase project
- Force update check active against staging version manifest
- Performance monitoring enabled

**Production**
- Bundle ID: `com.xqmsg.secureworkspaces`
- Distributed via App Store
- Certificate pinning active against production certificate
- All debug logging stripped
- Remote config active against production Firebase project
- Jailbreak detection fully active
- Secure Enclave operations fully enabled

### Code Signing Strategy

Fastlane match is the only acceptable code signing mechanism. It stores certificates and provisioning profiles encrypted in a private Git repository. No developer certificate or provisioning profile is stored on any developer's machine or in any CI runner.

```
# Matchfile
git_url("git@github.com:xqmsg/ios-certs-private.git")
storage_mode("git")
type("appstore")
app_identifier([
  "com.xqmsg.secureworkspaces",
  "com.xqmsg.secureworkspaces.staging",
  "com.xqmsg.secureworkspaces.debug"
])
```

The MATCH_PASSWORD secret is stored in GitHub Secrets and injected into CI runners. Developers run `fastlane match development` locally, which fetches and installs their development certificate from the private certs repo.

### Bundle ID Configuration Per Environment

| Environment | Bundle ID | Push Notification Topic | Keychain Access Group |
|-------------|-----------|------------------------|-----------------------|
| Debug | com.xqmsg.secureworkspaces.debug | debug.xqmsg.secureworkspaces | com.xqmsg.debug |
| Staging | com.xqmsg.secureworkspaces.staging | staging.xqmsg.secureworkspaces | com.xqmsg.staging |
| Production | com.xqmsg.secureworkspaces | xqmsg.secureworkspaces | com.xqmsg |

Keychain access group separation is critical because the spec requires session tokens stored in iOS Keychain. Separate groups prevent staging credentials from ever being accessible by the production app binary.

---

## 4. ENVIRONMENT STRATEGY

### Dev Environment

- XQ API: XQ sandbox (api-sandbox.xq.io, or equivalent staging URL from xq.stoplight.io docs)
- SharePoint: Developer-owned Microsoft 365 E3 trial tenant
- AI models: CoreML models checked into the repository under `AI/Models/debug/` (small quantized versions acceptable)
- Remote config: Local JSON file at `Config/debug-remote-config.json`
- Firebase: None — eliminates Firebase dependency for local development
- Network traffic inspection: Certificate pinning disabled, allowing Charles Proxy for debugging
- Secure Enclave: Simulator fallback to software AES (documented limitation)

### Staging Environment (TestFlight)

- XQ API: XQ staging environment with production-equivalent security posture
- SharePoint: Dedicated XQ test tenant (not developer personal tenants)
- AI models: Production-identical CoreML models
- Remote config: Firebase Remote Config, staging project `xq-secure-workspaces-staging`
- Firebase: Crashlytics enabled, Analytics enabled with `analyticsCollectionEnabled = false` by default (opt-in)
- Certificate pinning: Active against staging certificate
- TestFlight groups: Internal (XQ team), External Beta (selected enterprise pilot customers)
- Force update manifest: Hosted at `https://config-staging.xqmsg.co/ios/version.json`

### Production Environment (App Store)

- XQ API: Production endpoints with full certificate pinning
- Remote config: Firebase Remote Config, production project `xq-secure-workspaces-prod`
- Firebase: Crashlytics enabled, Analytics with privacy-safe event names only (no PII in event parameters — this is non-negotiable given the spec's privacy-first mandate)
- Force update manifest: `https://config.xqmsg.co/ios/version.json`
- App Store Connect: Phased release enabled (7-day rollout for all non-hotfix releases)

### Environment-Specific Config Injection

Config is injected through three layers, with zero secrets in source code:

**Layer 1: xcconfig at build time** — non-secret environment values (API base URLs, feature flag project IDs, version manifest URLs).

**Layer 2: GitHub Secrets injected into CI runners** — signing secrets (MATCH_PASSWORD, App Store Connect API key), Firebase GoogleService-Info.plist per environment.

**Layer 3: Firebase Remote Config at runtime** — all dynamic behavior (feature flags, AI model selection, minimum version, kill switches). The app treats Remote Config as the source of truth for runtime behavior after launch.

The `GoogleService-Info.plist` for each environment is stored as a base64-encoded GitHub Secret and decoded into the correct location during the CI build step, never committed to the repository.

---

## 5. SECRETS MANAGEMENT

### Where Secrets Live

| Secret Type | Storage Location | Access Method |
|-------------|-----------------|---------------|
| Code signing certificates | Private Git repo (Fastlane match encrypted) | CI injects MATCH_PASSWORD |
| App Store Connect API key | GitHub Secrets (org-level) | Fastlane reads via ENV |
| Firebase GoogleService-Info.plist | GitHub Secrets (base64 encoded, per environment) | CI decodes to temp file |
| XQ API keys (staging/prod) | GitHub Secrets | Injected into xcconfig at build time |
| SharePoint test tenant credentials | GitHub Secrets | Integration test ENV only |
| MATCH_PASSWORD | GitHub Secrets (org-level) | Fastlane match |

**Absolute prohibitions:**
- No secret of any kind in any `.swift`, `.plist`, `.xcconfig`, or `.json` file that is committed to any repository (including private repos)
- No API keys in `Info.plist`
- No hardcoded URLs that contain authentication parameters

### CI/CD Secret Injection Pattern

```yaml
# In GitHub Actions workflow
- name: Decode GoogleService-Info
  env:
    FIREBASE_PLIST_B64: ${{ secrets.FIREBASE_PLIST_STAGING_B64 }}
  run: |
    echo "$FIREBASE_PLIST_B64" | base64 --decode \
      > XQSecureWorkspaces/Resources/GoogleService-Info.plist
    
- name: Set XQ API configuration
  env:
    XQ_API_BASE_URL: ${{ secrets.XQ_API_STAGING_BASE_URL }}
  run: |
    echo "XQ_API_BASE_URL = $XQ_API_BASE_URL" \
      >> Configurations/Staging.xcconfig
```

### XQ API Keys Management

The XQ SDK (github.com/XQ-Message-Inc) uses API keys for tenant identification. These are injected as build-time xcconfig values from GitHub Secrets. At runtime, the `XQSecureAPI` protocol adapter reads the key from the app's compiled configuration, not from any user-facing config file. Keys are rotated by updating the GitHub Secret and triggering a new build — no source code change required.

---

## 6. TESTING AUTOMATION

### Unit Test Requirements

The interface-driven architecture (spec section 5) makes the unit test boundary clear: test every Swift protocol implementation with mock counterparts. No live network calls in unit tests.

Required test coverage targets:
- `Core/` module: 85% line coverage
- `Security/` module: 90% line coverage (highest bar given encryption and DLP requirements)
- `Policies/` module: 85% line coverage (fuzzy logic engine must have table-driven tests for all rule combinations)
- `AI/` module: 75% line coverage (AI provider adapter switching must be fully tested)
- `Services/` module: 80% line coverage
- `UI/` and `ViewModels/`: 60% (business logic in ViewModels tested; pure layout not required)

Critical unit test scenarios mandated by spec:
1. `XQSecureAPIAdapter` v1/v2/v3 version negotiation logic
2. Policy engine: external user + high sensitivity + medium device trust → view-only enforcement
3. Offline cache: encrypt on write, decrypt on read, verify inaccessible to other apps via entitlement check
4. AI provider switching: confirm `classify()` routes to correct provider based on RemoteConfig flag
5. Force update: version below minimum → returns `.forceUpdate`, version above → returns `.current`
6. Kill switch: killed feature returns disabled state before any initialization occurs

### UI Test Automation (XCUITest)

XCUITest runs against the Debug build on Simulator. Scenarios are organized around the secure container model:

**Security boundary tests (highest priority):**
- Attempt to trigger iOS share sheet from secure viewer — verify blocked
- Verify background blur activates when app enters background
- Verify copy action is unavailable in document viewer
- Verify "Open In" workflow is disabled for all viewed documents

**Happy path flows:**
- First launch → local-first selection → workspace ready
- Connect SharePoint repository → browse files → open PDF in secure viewer
- Mark file for offline → disable network → verify file accessible and decrypted correctly
- Import file from Files app → verify classification label appears → verify encryption applied

**Accessibility:**
- VoiceOver traversal of file browser without exposing sensitive file metadata as accessibility labels

### Integration Test Strategy

Integration tests run only on `develop` and `release/*` branches against the staging environment. They require real (test-tenant) credentials injected from GitHub Secrets.

Scenarios:
- Full OAuth flow against Microsoft staging tenant for SharePoint
- Upload file through SharePoint provider → verify it appears in file browser → open in viewer
- XQ encrypt file → revoke access → attempt open → verify decryption fails with correct error
- Remote config fetch → parse minimum version → verify version check logic receives correct value

Integration tests are gated behind a `run-integration-tests: true` label on PRs, preventing accidental execution on every feature branch push.

### Security Test Automation

Automated security checks in CI:

1. **MobSF static analysis** — runs on every build, blocks on High severity findings. Checks for: insecure random number generation, hardcoded secrets, HTTP (not HTTPS) URLs, insecure local storage, debug flags in production builds.

2. **Entitlements validation** — custom script verifies production entitlements contain no prohibited capabilities (e.g., `com.apple.developer.networking.wifi-info` is not needed and must not be present).

3. **Binary string scan** — grep the compiled IPA for known secret patterns (AWS key prefixes, `-----BEGIN`, API key formats). Fails build if any match found.

4. **Swift package audit** — `swift package audit` equivalent; checks known CVE database for all SPM dependencies. Blocks on Critical/High findings.

### Performance Benchmarks in CI

XCTest Metrics capture these benchmarks on every `develop` push:

| Metric | Target | Regression Threshold |
|--------|--------|---------------------|
| App cold launch (to home screen) | < 2.0 seconds | 20% regression blocks merge |
| File decrypt + render (1MB PDF) | < 1.5 seconds | 20% regression |
| AI model initialization | < 3.0 seconds | 30% regression |
| Memory footprint at idle | < 150 MB | Absolute ceiling |
| Memory during file viewing (10MB doc) | < 300 MB | Absolute ceiling |

Results are stored as GitHub Actions artifacts and trended in a simple dashboard. The spec's requirement for lightweight on-device AI models and 60 FPS animations makes these benchmarks non-optional.

---

## 7. RELEASE WORKFLOW

### TestFlight Distribution Workflow

```
develop branch push
    |
    v
Full CI pipeline passes
    |
    v
Fastlane lane: staging_testflight
  - fastlane match appstore (fetch signing)
  - gym (build with Staging scheme)
  - Inject build number = CI run number
  - pilot upload (TestFlight)
  - Automatic changelog: last 10 git commit messages, formatted
  - Notify Slack #ios-builds: "New TestFlight build: v{version} ({build})"
    |
    v
TestFlight groups receive build:
  - "XQ Internal" (immediate, no review wait)
  - "Enterprise Beta" (24-hour review period typical)
```

Build numbers follow the format `{major}.{minor}.{patch}.{CI_RUN_NUMBER}`. This ensures TestFlight builds are always sortable and traceable to a specific CI run.

### App Store Submission Process

```
Release decision made
    |
    v
Create release/v{X}.{Y}.{Z} branch from develop
    |
    v
Full pipeline runs on release branch
    |
    v
QA signs off on TestFlight build
    |
    v
Fastlane lane: production_submit
  - fastlane match appstore
  - gym (build with Production scheme)
  - deliver (upload to App Store Connect)
  - Phased release: 7-day rollout configured
  - App Store Connect API: submit for review
    |
    v
Apple review (typically 24-48 hours for new apps, faster for updates)
    |
    v
Approved: tag main branch v{X}.{Y}.{Z}
  - GitHub Release created automatically
  - Release notes generated from changelog
  - Force update manifest updated if required
```

### Release Notes Automation

Release notes are generated by a GitHub Actions step that:
1. Pulls all commit messages since the previous release tag
2. Filters to commits prefixed with `feat:`, `fix:`, `security:`, `perf:`
3. Groups by category
4. Produces a human-readable changelog in English (primary) that becomes the App Store "What's New" copy
5. For TestFlight, includes the full technical changelog for tester context

This feeds directly into `fastlane deliver`'s `release_notes` parameter.

### Crash Monitoring

**Primary: Firebase Crashlytics**

Crashlytics is integrated at app launch in the `AppDelegate`/`App` struct. Privacy constraint from spec: Crashlytics is configured with `crashlytics.setCrashlyticsCollectionEnabled(false)` by default in the Debug scheme. In Staging and Production, it is enabled. No user-identifying information is attached to crash reports — the spec explicitly states XQ holds no customer data.

**Secondary: Sentry (optional, for enterprise deployments)**

Enterprise customers who operate self-hosted XQ deployments may require on-premise crash reporting. A `CrashReporterProvider` protocol abstracts the crash reporter, allowing Crashlytics or Sentry or a null implementation to be injected — consistent with the spec's interface-driven mandate.

---

## 8. FORCE UPDATE IMPLEMENTATION

### Architecture

Force update is driven entirely by remote configuration, not by App Store version checking. This is necessary because the spec requires kill switches and version gating as first-class delivery mechanisms, and App Store version checking is unreliable (propagation delays, caching).

The version manifest is a JSON file hosted on XQ infrastructure:

```json
{
  "ios": {
    "minimum_version": "1.0.0",
    "current_version": "1.2.0",
    "force_update_below": "1.0.0",
    "soft_update_below": "1.1.0",
    "update_url": "https://apps.apple.com/app/xq-secure-workspaces/id{APP_ID}",
    "force_update_message": {
      "en": "A critical security update is required. Please update XQ Secure Workspaces to continue.",
      "fr": "..."
    },
    "soft_update_message": {
      "en": "A new version of XQ Secure Workspaces is available with important security improvements."
    }
  }
}
```

This manifest is fetched on every app launch before the home screen is displayed. It is also fetched by Firebase Remote Config, which provides the fallback if the manifest endpoint is unreachable.

### Version Check on App Launch

The version check occurs during the Splash / Secure Initialization phase (spec section 3.1), which already performs device trust checks, integrity validation, and session restoration. The version check is added to this sequence:

```
App Launch
    |
    v
Secure Enclave initialization
    |
    v
Device integrity checks (jailbreak detection, etc.)
    |
    v
VERSION CHECK (fetch manifest, compare to CFBundleShortVersionString)
    |
    ├── force update required → show ForceUpdateView (no home screen access)
    |
    ├── soft update recommended → show SoftUpdateBanner, proceed to home
    |
    └── current → proceed to home
```

The version manifest fetch has a 3-second timeout. If it times out and there is no cached manifest, the app proceeds normally. If a cached manifest shows force update required, the force update UI is shown regardless of connectivity (preventing downgrade attacks). The cached manifest is stored in iOS Keychain (not UserDefaults) so it cannot be cleared by the user without removing the app.

### Minimum Version Enforcement

The `minimum_version` field in the manifest defines the floor. Any installed binary with `CFBundleShortVersionString` below this value is blocked. The comparison uses semantic versioning (major.minor.patch). A `VersionComparator` utility in the `Core/` module handles this; it is unit tested exhaustively including edge cases (pre-release suffixes, missing patch components).

### Force Update UI Flow

The force update screen is a modal presented over the splash screen that cannot be dismissed. It contains:
- XQ branding
- The localized `force_update_message` from the manifest (spec requires all UI text externalized via localization system)
- A single "Update Now" button that opens the App Store URL
- No "Later" or dismiss option

The screen is implemented as a SwiftUI view that is not part of the navigation stack — it is presented as a full-screen overlay in the scene, ensuring no background interaction is possible.

### Soft Update Prompting

Soft update uses a non-blocking banner at the top of the home screen. It:
- Appears once per app session
- Can be dismissed with a swipe
- Reappears on the next session if the user has not updated
- After 3 sessions without updating, escalates to a modal (still dismissible)
- After 10 sessions, escalates to full-screen (still dismissible but more prominent)

The escalation thresholds are controlled by Remote Config, not hardcoded.

---

## 9. FEATURE FLAG SYSTEM

### Feature Flag Service Architecture

The `FeatureFlagProvider` protocol is the single access point for all feature flags in the app. Business logic and ViewModels never reference Firebase, UserDefaults, or any concrete config system directly.

```swift
protocol FeatureFlagProvider {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func value<T>(for flag: ConfigKey<T>) -> T
    func refresh() async throws
}

enum FeatureFlag: String {
    // Phase 1 flags
    case sharePointIntegration = "f_sharepoint_v1"
    case offlineCache = "f_offline_cache_v1"
    case secureViewer = "f_secure_viewer_v1"
    case xqEncryption = "f_xq_encryption_v1"
    
    // AI model selection (see section below)
    case aiModelTier = "ai_model_tier"
    
    // Kill switches
    case killSwitchSharePoint = "kill_sharepoint"
    case killSwitchOfflineSync = "kill_offline_sync"
    case killSwitchAI = "kill_ai_engine"
}
```

### Remote Config (Firebase Remote Config)

Firebase Remote Config is the production implementation of `FeatureFlagProvider`. Configuration:

- **Fetch interval**: 1 hour in production, 30 seconds in staging (for testing config changes)
- **Minimum fetch interval**: Respected; do not override in production
- **Default values**: A bundled `remote_config_defaults.json` file provides safe defaults for all flags. This ensures the app functions correctly if Remote Config is unreachable, with all Phase 1 features enabled by default and all kill switches set to `false` (not killed)
- **Real-time config updates**: Firebase Real-Time Config listener is registered for kill switch keys only, so kill switches take effect without requiring an app restart

The bundled defaults file is versioned and reviewed as part of every release. It is not a secret (it ships in the app bundle) but it defines the safe-state behavior of the app.

### Kill Switch Implementation

Kill switches are the highest-priority Remote Config values. Implementation:

1. Kill switch keys are fetched first, before any other config, during the splash initialization sequence
2. A killed feature is treated identically to a feature that has not been unlocked — the UI simply does not render that feature's entry points
3. Kill switches are evaluated at the `FeatureFlagProvider` level, so no conditional logic is spread through the codebase
4. Real-time listener updates kill switch state within seconds of server-side change, without requiring app restart

The kill switch check at the `FeatureFlagProvider` level means that even if a ViewModel has already been initialized, subsequent calls to `isEnabled(.killSwitchSharePoint)` return `false` after the kill switch is activated. ViewModels that bind to a `@Published` flag property will automatically update the UI.

### AI Model Rollout Control

The spec explicitly requires "AI model rollout via remote config" and "interchangeable AI models." The `AIModelTier` enum is controlled by Remote Config:

```
Remote Config key: ai_model_tier
Values:
  "local_minimal"    → Smallest CoreML model, lowest resource usage
  "local_standard"   → Production CoreML model (default)
  "cloud_anthropic"  → Routes to Anthropic API (enterprise, data-residency permitting)
  "cloud_openai"     → Routes to OpenAI API (enterprise)
  "cloud_bedrock"    → Routes to AWS Bedrock
```

Model switching happens per-tenant and per-data-classification. A CUI document routes to `local_minimal` regardless of the `ai_model_tier` flag — this overriding rule is implemented in the `AIGovernanceEngine`, not in the Remote Config logic. The spec is explicit: "Local model for CUI."

The AI model binary (CoreML `.mlpackage`) is delivered via on-demand resources (Apple ODR), not bundled in the initial IPA. This keeps the initial download size below 50MB. New model versions are published as new ODR tags and rolled out via Remote Config changing the ODR tag reference — allowing model updates without a binary release.

### Policy Update Delivery

Enterprise policy updates follow the same remote config mechanism but with a separate priority delivery channel:

- Enterprise policies are fetched from XQ's policy endpoint, not Firebase
- Policy updates trigger a local re-evaluation of all active file classifications
- The spec section 8.4 ("Policies adapt dynamically") requires this re-evaluation to be automatic, not user-initiated
- Policy updates received while offline are queued in the secure local cache and applied when the device reconnects

---

## 10. OBSERVABILITY

### Crash Reporting

Firebase Crashlytics is the primary crash reporter. Configuration constraints driven by the spec's privacy-first mandate:

- No user identifiers attached to crash reports (no `setCrashlyticsCollectionEnabled` with user ID)
- No custom keys that could expose file names, SharePoint paths, or classification labels
- Custom keys permitted: `app_version`, `build_number`, `deployment_model` (consumer vs enterprise), `ios_version`, `device_model`
- `crashlytics.log()` calls strip any string that matches PII patterns before logging
- Enterprise customers with data residency requirements can disable Crashlytics entirely via Remote Config kill switch, reverting to the null `CrashReporterProvider` implementation

### Performance Monitoring

Firebase Performance Monitoring traces for:
- App cold start time (automatic)
- File decrypt duration (custom trace: `file_decrypt`, attribute: `file_size_kb` in bucketed ranges, not exact size)
- AI model inference time (custom trace: `ai_classify`, attribute: `model_tier`)
- SharePoint API response time (custom trace: `sharepoint_list_files`)
- XQ API response time (custom trace: `xq_encrypt`, `xq_decrypt`)

All trace attribute values are bucketed (e.g., file sizes in ranges: `<100KB`, `100KB-1MB`, `1MB-10MB`, `>10MB`) to prevent inference of specific file content from telemetry.

### Analytics (Privacy-Safe)

Firebase Analytics with the following strict controls:

- `analyticsCollectionEnabled = false` is the default
- Users opt in explicitly in Settings — not on first launch
- Events use generic names: `file_viewed`, `share_initiated`, `offline_file_added`, `repository_connected`
- No file names, paths, content types, or classification labels in event parameters
- User pseudo-ID (Firebase's anonymous identifier) is reset on app reinstall
- Enterprise deployments default analytics to off and require admin-level opt-in

### Error Tracking

Application-level errors (not crashes) are tracked through a `ErrorTracker` protocol with a Sentry implementation as an option alongside the Firebase implementation. Error events include:
- XQ API authentication failures (without request/response bodies)
- SharePoint OAuth failures (without token values)
- Offline sync conflicts (without file content)
- Policy enforcement blocks (event type only, no content context)

All errors pass through a `ErrorSanitizer` before being sent to any external system. The sanitizer strips anything matching email addresses, file paths, authentication tokens, or classification labels.

---

## 11. KMP BUILD INTEGRATION

### How KMP Shared Modules Integrate with Xcode

The KMP shared module lives in a sibling directory to the iOS Xcode project:

```
xq-secure-workspaces/
├── ios/                          (Xcode project)
│   ├── XQSecureWorkspaces.xcodeproj
│   └── XQSecureWorkspaces/
├── shared/                       (KMP module)
│   ├── build.gradle.kts
│   ├── src/
│   │   ├── commonMain/
│   │   ├── iosMain/
│   │   └── androidMain/
│   └── build/
│       └── XCFrameworks/
│           └── release/
│               └── XQShared.xcframework
└── android/                      (future)
```

The KMP module exports an XCFramework using Kotlin's `XCFramework` DSL in `build.gradle.kts`. The iOS Xcode project references this XCFramework via a local Swift Package (`Package.swift` in the `shared/` directory that wraps the XCFramework as a binary target).

This approach avoids checking the XCFramework binary into Git. Instead, the CI pipeline builds the XCFramework as an artifact and the iOS build step fetches it before building.

### Build Automation for KMP

The KMP build is Stage 2 in the CI pipeline. It runs on a Linux runner (faster than macOS for Kotlin compilation), produces the XCFramework, and uploads it as a GitHub Actions artifact. The iOS build stage runs on a macOS runner, downloads the artifact, and places it in the expected path before running Xcode build.

```yaml
build-kmp:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4
      with:
        distribution: 'temurin'
        java-version: '17'
    - name: Build KMP XCFramework
      working-directory: shared
      run: ./gradlew assembleXCFramework
    - name: Upload XCFramework
      uses: actions/upload-artifact@v4
      with:
        name: XQShared-xcframework
        path: shared/build/XCFrameworks/release/XQShared.xcframework

build-ios:
  needs: build-kmp
  runs-on: macos-14
  steps:
    - uses: actions/checkout@v4
    - name: Download XCFramework
      uses: actions/download-artifact@v4
      with:
        name: XQShared-xcframework
        path: shared/build/XCFrameworks/release/
    - name: Build iOS app
      run: fastlane staging_build
```

### Dependency Management

**iOS (Swift Package Manager):** All iOS dependencies managed via SPM. No CocoaPods. CocoaPods is excluded because it requires a lock file that is difficult to audit and because the spec's long-term cross-platform vision is better served by SPM's deterministic resolution. Key Phase 1 dependencies:
- Firebase iOS SDK (Crashlytics, Remote Config, Analytics) — via SPM
- MSAL (Microsoft Authentication Library for SharePoint OAuth) — via SPM
- XQ SDK (if available via SPM; otherwise vendored as XCFramework)

**KMP (Gradle):** Standard Kotlin Gradle dependency management. `gradle.lockfile` checked into version control. KMP dependencies that need iOS platform access use `iosMain` source sets with platform-specific implementations hidden behind `expect/actual` declarations.

**Shared design tokens:** Maintained as a KMP module (`shared/designTokens/`) that emits Swift constants for iOS consumption. Token updates trigger a token-sync CI step that commits updated Swift files — this ensures the design system stays synchronized without manual copy-paste.

---

## 12. DELIVERY RISKS

### Risk 1: Apple App Review Rejection Due to Security Entitlements

**Probability: Medium. Impact: High.**

The spec requires screenshot blocking, share sheet filtering, Open-In prevention, and clipboard restrictions. Apple's review team sometimes rejects apps that override system behaviors without clear user justification. The secure viewer's restriction of system-level interactions could trigger a rejection under App Store Review Guideline 4.2 (minimum functionality) if the reviewer cannot understand the enterprise security purpose.

**Mitigation:** Prepare a detailed App Review Information note in App Store Connect explaining the enterprise Zero Trust use case before the first production submission. Include a test account that demonstrates SharePoint connectivity. Engage Apple's developer relations team for an expedited enterprise app review if the initial submission is rejected. Build the TestFlight pipeline first and use extended external beta testing to surface review concerns early.

### Risk 2: KMP XCFramework Build Instability Blocking iOS Builds

**Probability: Medium. Impact: High.**

KMP's XCFramework export has historically had instability in Kotlin/Native toolchain updates. A Kotlin version bump that breaks XCFramework generation would block all iOS builds until resolved.

**Mitigation:** Pin the Kotlin and KMP plugin versions in `build.gradle.kts` and do not update without a dedicated upgrade branch that runs the full pipeline. Cache the last-known-good XCFramework artifact in GitHub Actions cache and fall back to it if the KMP build fails — this allows the iOS team to continue building while the KMP issue is resolved. Assign KMP build ownership to a specific engineer, not shared responsibility.

### Risk 3: Firebase Remote Config Propagation Delay Causing Inconsistent Kill Switch State

**Probability: Low. Impact: Critical.**

If a kill switch must be activated urgently (security incident), Firebase Remote Config has a propagation delay of up to 1 hour under the standard fetch interval. During this window, some app instances will continue operating the affected feature.

**Mitigation:** Register Firebase Real-Time Config listeners for all kill switch keys specifically (not all config keys — real-time updates have cost implications at scale). Test the real-time path on every release cycle. Document the maximum propagation time in incident response runbooks. For true emergency scenarios, the force update mechanism (updating the version manifest minimum version) can be used to push all users to update or be blocked, which is a more nuclear option but guarantees enforcement.

### Risk 4: XQ API Version Negotiation Complexity Delaying Phase 1 Build

**Probability: Medium. Impact: Medium.**

The spec requires support for XQ API v1/v2/v3 adapters with dynamic capability negotiation. Implementing all three adapters before any Phase 1 feature can be tested adds significant risk to the Phase 1 schedule.

**Mitigation:** Implement only the adapter version that the current XQ API supports (check xq.stoplight.io for the current spec). Build the adapter negotiation framework — the protocol, the factory, the capability flags — but stub v2 and v3 adapters with `fatalError("Not yet implemented")`. The interface-driven architecture means the rest of the app cannot tell the difference. Add the real implementations in sprints, not as a prerequisite to Phase 1 feature delivery.

### Risk 5: Secure Enclave Limitations on Simulator Breaking CI UI Tests

**Probability: High. Impact: Medium.**

iOS Simulator does not have a Secure Enclave. Any UI test that exercises the encryption path will either fail or require a software fallback path. The spec's requirement for Secure Enclave-backed key storage means this is a design-level gap, not a simple test issue.

**Mitigation:** Design the `EncryptionProvider` protocol with a `SecureEnclaveProvider` (production, using CryptoKit's SecureEnclave APIs) and a `SoftwareAESProvider` (Debug and test only, using CryptoKit's symmetric encryption). The `SoftwareAESProvider` uses the same interface and produces identical ciphertext format but without hardware backing. Gate the software provider strictly behind a `#if DEBUG || TESTING` compilation condition and a build-time flag so it cannot be activated in Staging or Production builds. UI tests run against the software provider. Unit tests for the real `SecureEnclaveProvider` must run on a physical device — add a physical device runner (a dedicated iPhone or iPad in the XQ office) to the CI environment for the security test stage.

---

**Pipeline Design Completed**

Key artifacts referenced in this design:

- `/Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt` — source specification (sections 16, 5, 7, 22 were the most directly load-bearing for pipeline decisions)
- The Fastfile, `.github/workflows/`, `Matchfile`, and `remote_config_defaults.json` files should be created in the iOS project repository. No templates have been written to disk — this design is the blueprint for the engineering team to implement from.

The most important implementation sequence is: (1) establish Fastlane match and code signing before writing a single line of app code, (2) stand up the Remote Config project and version manifest endpoint before the first TestFlight build, and (3) build the `FeatureFlagProvider` and `XQSecureAPI` protocol abstractions before implementing any concrete feature — everything else depends on those interfaces being stable.