Now I have a thorough understanding of the full specification. Let me produce the comprehensive Phase 1 test strategy.

---

# XQ Secure Workspaces iOS — Phase 1 QA Test Strategy

---

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces is a Zero Trust, AI-governed secure file vault for iOS and iPadOS. Phase 1 ships 11 screens covering the full lifecycle from first launch through file classification, secure viewing, sharing, and local import. The security posture of this application is exceptionally high: encryption is mandatory, every file must be classified by on-device AI, DLP controls are non-negotiable, and no data may leave the secure container through unauthorized paths.

This test strategy establishes a defense-in-depth validation model across six quality dimensions: functional correctness, security/DLP enforcement, AI classification accuracy, offline resilience, performance at 60 FPS with sub-200ms AI latency, and cross-device fidelity on iPhone and iPad. Given that this is a regulated enterprise security product, test failures in the security and DLP categories are treated as release blockers with no tolerance for false negatives. AI false positive rates are tracked against quantified acceptance thresholds rather than treated as subjective feedback.

Testing is organized into three tiers: automated unit tests driving toward 80%+ coverage of core modules, integration tests validating XQ API, SharePoint, and IDP contracts, and XCUITest end-to-end flows for the 11 Phase 1 screens. A dedicated security test pass and an AI accuracy benchmark run complete the picture. The estimated automated test suite execution time target is under 12 minutes for the full CI run.

---

## 2. TEST STRATEGY OVERVIEW

### Testing Philosophy

Security enforcement testing takes precedence over functional testing. If a DLP control is absent or bypassable, that is a Severity 1 defect regardless of UX quality. Functional testing operates under an assumption of adversarial usage: every input field receives boundary, injection, and malformed data variants. Offline-first means every test scenario has an offline variant by default unless connectivity is architecturally required.

The spec mandates that all services are abstracted behind Swift protocols (no direct API calls in business logic). This protocol-driven architecture is a significant testability advantage and the mock strategy is built entirely on it: every integration point has a test double injected at the `RepositoryProvider`, `AIProvider`, `XQSecureAPI`, and `ExternalIntegration` protocol boundaries.

### Test Pyramid

```
                  [E2E / XCUITest]
                 11 critical flows
                ~150 test scenarios
               ─────────────────────
              [Integration Tests]
           XQ API, SharePoint, IDP, Sync
              ~200 test scenarios
           ────────────────────────────
          [Unit Tests]
       Business logic, AI engine, crypto,
       policy engine, sync engine, DLP rules
          ~800+ test cases
       ─────────────────────────────────────
```

Ratio target: 70% unit / 20% integration / 10% E2E.

### Coverage Targets by Layer

| Layer | Module | Target Coverage |
|---|---|---|
| Unit | Policy engine (fuzzy logic processor) | 90% |
| Unit | AI classification engine | 90% |
| Unit | XQ encryption/decryption | 95% |
| Unit | DLP rule evaluation | 90% |
| Unit | Sync engine (conflict resolution) | 85% |
| Unit | Identity/token management | 90% |
| Unit | Repository service (all providers) | 80% |
| Unit | Localization string resolution | 80% |
| Integration | XQ API adapter (all versions) | 85% |
| Integration | SharePoint provider | 80% |
| Integration | IDP/OAuth flows | 85% |
| Integration | Offline sync round-trip | 80% |
| E2E | Phase 1 critical paths | 100% of defined flows |

---

## 3. UNIT TESTING PLAN

### Framework Recommendation: Swift Testing over XCTest

For Phase 1, adopt Swift Testing (introduced in Xcode 16 / Swift 6) as the primary unit test framework, supplementing with XCTest only where legacy tooling requires it.

Rationale for Swift Testing:
- `@Test` and `@Suite` macros enable parameterized test variants, which is essential for testing classification accuracy across a labeled dataset of 500+ documents with a single `@Test(.arguments(testDataset))` declaration.
- Structured concurrency (`async/await`) integration aligns naturally with the async AI inference and sync engine design.
- Better failure diagnostics: `#expect` produces structured diffs rather than XCTest's opaque assertion failures.
- Tag system (`@Test(.tags(.security), .tags(.dlp))`) allows CI to run security-tagged tests in a dedicated gate before merge.

XCTest is retained for XCUITest (UI testing, which has no Swift Testing equivalent yet) and for modules with existing XCTest coverage.

### What to Unit Test

**Policy Engine (Fuzzy Logic Processor)**

The fuzzy logic engine is the most complex and highest-risk business logic module. Every policy input combination that could produce an incorrect enforcement outcome is a test case.

Test categories:
- Single-input policy evaluation: verify that `externalUser=true` alone produces view-only enforcement
- Compound policy evaluation: verify the spec example (external user + high sensitivity + medium device trust) produces view-only + disabled download + MFA every 5 minutes + heavy watermark
- Risk score boundary tests: verify enforcement tier changes at documented score thresholds
- Policy override: verify admin override correctly supersedes AI classification
- Dynamic re-evaluation: verify that content reclassification mid-session triggers policy recalculation
- Geofencing: verify location-aware policies evaluate correctly when coordinates are at boundary, inside, and outside defined regions
- Session anomaly signals: verify that elevated session anomaly scores produce expected escalation

```swift
// Example parameterized policy test using Swift Testing
@Suite("Fuzzy Logic Policy Engine")
struct PolicyEngineTests {
    @Test("Compound policy evaluation", arguments: PolicyTestDataset.compoundScenarios)
    func compoundPolicyEvaluation(scenario: PolicyScenario) async throws {
        let engine = PolicyEngine(provider: MockPolicyProvider())
        let result = await engine.evaluate(context: scenario.input)
        #expect(result.enforcedControls.sorted() == scenario.expectedControls.sorted())
        #expect(result.riskScore >= scenario.minRiskScore)
        #expect(result.riskScore <= scenario.maxRiskScore)
    }
}
```

**AI Classification Engine**

Unit tests validate the classification interface contract, not model weights (model accuracy is covered under Section 7). Test the `AIProvider` protocol implementation using injected mock models.

Test categories:
- Classification label assignment for each supported type (Public, Internal, Confidential, Restricted)
- Multi-label support: a file can carry both PII and Financial classification simultaneously
- Confidence score range validation: all scores are 0.0–1.0, no NaN or out-of-range values
- Model switching: verify runtime swap from local CoreML model to cloud provider produces structurally identical output format
- Offline fallback: when cloud model is unavailable, verify local CoreML model activates transparently
- Rescan after edit: verify that edited document triggers reclassification with new content, not cached result
- Empty/corrupted document: verify graceful failure, not crash, when AI processes a zero-byte or malformed file

**XQ Encryption and Decryption**

The spec mandates encryption on every imported file immediately. These tests must be deterministic and not rely on actual XQ infrastructure.

Test categories:
- Encrypt-then-decrypt round-trip: verify that decrypted output is byte-identical to original input for PDF, DOCX, XLSX, TXT, and image files
- Key binding: verify that encrypted file cannot be decrypted without the original key
- Policy metadata binding: verify that XQ policy metadata is preserved after encrypt/decrypt cycle
- Secure Enclave key storage: verify that key material is stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection class
- Session token restoration: verify that an encrypted session is correctly restored after simulated app restart using `MockSecureEnclave`
- Version adapter: verify that `XQAPIv1Adapter`, `XQAPIv2Adapter`, and `XQAPIv3Adapter` all implement the `XQSecureAPI` protocol contract identically at the interface level

**DLP Rule Evaluation**

DLP rules are evaluated in the runtime protection layer. Unit tests validate the rule engine independently of the UI.

Test categories:
- Screenshot detection state machine: verify the state transitions from `unprotected` to `screenshotBlocked` when a file above the sensitivity threshold is loaded
- Copy/paste prevention: verify that `UIPasteboard` writes are intercepted and blocked for Confidential/Restricted content
- Share sheet filtering: verify that only approved destinations appear in the share sheet for each classification level
- Background blur activation: verify that the blur view is applied within one frame of `applicationWillResignActive` notification
- Watermark presence: verify watermark layer is inserted into the document canvas for Confidential and above
- Revocation of offline cache: verify that a remotely revoked file is deleted from the local encrypted cache within the next sync cycle

**Sync Engine**

Test categories:
- Delta sync: verify that only changed byte ranges are transmitted, not full file content
- Conflict resolution: verify that when local and remote versions both have edits, the conflict resolution prompt fires exactly once
- Retry queue: verify that failed sync operations are re-attempted with exponential backoff up to the configured retry limit
- Policy-aware sync: verify that a file whose policy disables offline access is removed from the local cache on next sync when connectivity returns
- Background sync: verify `BGTaskScheduler` registration and that sync tasks execute within their time budget

**Mock Strategy**

Every protocol in the interface layer has a corresponding test double. The mock registry pattern ensures consistency:

```
MockRepositoryProvider        → implements RepositoryProvider
MockAIProvider                → implements AIProvider
MockXQSecureAPI               → implements XQSecureAPI
MockIDPAdapter                → implements ExternalIntegration (IDP variant)
MockSharePointProvider        → implements RepositoryProvider
MockSecureEnclave             → test double for CryptoKit/Secure Enclave operations
MockPolicyProvider            → implements PolicyProvider
MockSyncEngine                → implements SyncEngine
MockLocalizationEngine        → implements LocalizationProvider
```

All mocks are injectable via the dependency injection container (Resolver/Factory as specified). No `@testable import` tricks that bypass the interface boundary. Business logic tests must only interact with protocol types.

---

## 4. INTEGRATION TESTING PLAN

Integration tests run against real external services in a dedicated test environment. A separate integration test target is configured in Xcode to prevent these tests from blocking the fast unit test suite in CI. Integration tests are tagged `@Test(.tags(.integration))` and run in a nightly pipeline and pre-release pipeline, not on every commit.

### XQ API Integration Tests

Reference: https://xq.stoplight.io

Test environment: XQ staging environment with dedicated test tenant.

Test scenarios:
- `encrypt()`: send a known plaintext payload, verify ciphertext is returned, verify the ciphertext is not equal to plaintext
- `decrypt()`: take the ciphertext from the above test, decrypt it, verify byte-identical output to original plaintext
- `applyPolicy()`: apply a classification policy to a test file, verify the policy metadata is returned in the response and matches the request
- `revokeAccess()`: revoke access to a shared file, verify that subsequent `validateAccess()` returns an access-denied response
- `validateAccess()`: test with valid token, expired token, and invalid token; verify correct responses for each
- Version adapter negotiation: verify that the `XQAPIv1Adapter`, `XQAPIv2Adapter`, and `XQAPIv3Adapter` all successfully complete the same operation against the staging API (capability negotiation)
- Token refresh: force token expiration in the test environment; verify the gateway layer transparently refreshes and retries the request without user intervention
- Certificate pinning: send a request with a deliberately mismatched certificate; verify the connection is rejected and an error is logged to the audit system
- Retry orchestration: simulate a 503 from the XQ API gateway; verify the retry queue fires exactly 3 times with exponential backoff before surfacing an error to the ViewModel

### SharePoint Integration Tests

Test environment: Dedicated Microsoft 365 developer tenant with pre-populated test files and folder structure.

Test scenarios:
- OAuth authentication: complete the OAuth flow with a valid enterprise account, verify token is stored in iOS Keychain
- `listFiles(path:)`: list a known folder, verify the file list matches the pre-populated test structure
- `downloadFile(id:)`: download a known file, verify byte count and MD5 hash match the reference
- `uploadFile(file:)`: upload a test file, verify it appears in the SharePoint folder via a subsequent `listFiles` call
- Permission boundary: attempt to access a folder that the test user does not have permission to; verify 403 is handled gracefully and user is shown a localized error, not a raw API error
- Large file streaming: stream a 50MB PDF through the secure workspace; verify it loads without memory warning
- Session expiry: let the SharePoint OAuth token expire (use a short-lived test token), verify the app silently refreshes without disrupting the user's navigation state

### IDP Authentication Tests

Supported IDPs per spec: Microsoft Entra ID, Okta, Google Workspace, Ping, AWS IAM Identity Center.

Phase 1 priority: Entra ID (required for SharePoint integration) and Okta (most common enterprise IDP).

Test scenarios for each IDP:
- Happy path SSO: complete SSO flow end-to-end, verify correct identity claims are present in the session
- MFA challenge: trigger MFA step-up, verify the app correctly handles the MFA redirect and stores the resulting token
- Conditional access policy: configure a conditional access policy in the test IDP that requires compliant device; verify the app surfaces the correct error when run from a non-compliant simulator
- Token revocation: revoke the session from the IDP console, verify the app detects the 401 on next API call and redirects to re-authentication
- Passive identity integration: verify that enterprise identity attributes (group membership, department) are passed through to the policy engine correctly

### Offline/Online Sync Tests

These are integration tests because they require the real sync engine against a real repository endpoint.

Test scenarios:
- Mark file offline: mark a file offline while connected, kill the network interface, open the file, verify it loads from encrypted local cache
- Edit offline, sync on restore: edit a locally cached text file while offline, restore network connectivity, verify changes are pushed to SharePoint within the next sync cycle
- Conflict creation: simultaneously edit the same file both locally (offline) and in SharePoint (simulated by direct API call), restore connectivity, verify the conflict resolution prompt appears exactly once and both versions are preserved for user selection
- Revocation while offline: revoke a file via the XQ API while the device is offline, restore connectivity, verify the file is removed from the local cache within the next sync cycle and the user cannot open it
- Policy update while offline: push a new policy from the enterprise admin console while device is offline, restore connectivity, verify the updated policy is applied to affected files without requiring user action

---

## 5. UI TESTING PLAN (XCUITest)

XCUITest is the required framework for iOS E2E UI testing. All UI tests use the Page Object Model to isolate test logic from view hierarchy details. Each Phase 1 screen has a corresponding Page Object class.

### Page Object Model Design

```
XCUITests/
├── PageObjects/
│   ├── SplashPage.swift
│   ├── OnboardingPage.swift
│   ├── RepositorySetupPage.swift
│   ├── PermissionsPage.swift
│   ├── HomePage.swift
│   ├── FileBrowserPage.swift
│   ├── FileViewerPage.swift
│   ├── ShareWorkflowPage.swift
│   ├── LocalImportPage.swift
│   ├── AIScannerPage.swift
│   └── SettingsPage.swift
├── Flows/
│   ├── ConsumerOnboardingFlow.swift
│   ├── EnterpriseOnboardingFlow.swift
│   ├── FileImportClassificationFlow.swift
│   ├── SecureSharingFlow.swift
│   └── PolicyViolationFlow.swift
└── Helpers/
    ├── MockServerLaunchArguments.swift
    ├── NetworkConditionHelper.swift
    └── BiometricMockHelper.swift
```

Each Page Object exposes typed accessors to UI elements using accessibility identifiers, never raw XPath or UI description strings. Example structure:

```swift
struct FileViewerPage {
    let app: XCUIApplication

    var sensitivityLabel: XCUIElement { app.staticTexts["fileViewer.sensitivityLabel"] }
    var shareButton: XCUIElement { app.buttons["fileViewer.shareButton"] }
    var editButton: XCUIElement { app.buttons["fileViewer.editButton"] }
    var watermarkOverlay: XCUIElement { app.otherElements["fileViewer.watermarkOverlay"] }
    var policyIndicator: XCUIElement { app.staticTexts["fileViewer.policyIndicator"] }

    func tapShare() -> ShareWorkflowPage {
        shareButton.tap()
        return ShareWorkflowPage(app: app)
    }
}
```

This design means that when view hierarchy changes, only the Page Object needs updating, not dozens of test methods.

### Accessibility Identifiers

Every interactive and informational element in the Phase 1 screens must have a deterministic `accessibilityIdentifier` set. This is a testability requirement surfaced to the development team from the QA spec. Identifier naming convention: `screenName.elementType.semanticName` (e.g., `fileViewer.button.share`, `onboarding.label.privacyMessage`).

### Critical Flows to Automate

**Flow 1: Consumer Onboarding**

Steps:
1. Launch app cold (no prior session)
2. Wait for Splash screen to complete security initialization (assert XQ logo animation completes)
3. Assert Welcome screen displays "Continue Local-First" and "Connect Enterprise Workspace" options
4. Tap "Continue Local-First"
5. Assert Permissions screen appears with Face ID, Notifications, Files access requests
6. Grant each permission via mock (use `XCUIApplication.launchArguments` to pre-grant permissions in CI since system permission dialogs cannot be automated reliably)
7. Assert Home screen appears with empty state (no recent files)
8. Assert all UI elements on Home screen are present: recent files section, suggested files section, offline files section, risk notifications section, quick actions
9. Assert animation completes without stutter (validated via frame rate assertion — see Section 8)

Pass criteria: Flow completes in under 30 seconds. All screens display localized text (no raw key names). No crash or ANR.

**Flow 2: Enterprise Onboarding**

Steps:
1. Launch app cold
2. Splash — assert security initialization completes
3. Welcome — tap "Connect Enterprise Workspace"
4. Repository Setup screen — assert AI assistant chat panel is visible
5. Select SharePoint as repository type
6. Enter test SharePoint URL and credentials via mock IDP
7. Assert connection diagnostic runs and shows success state
8. Proceed to Permissions setup
9. Grant permissions
10. Assert Home screen shows SharePoint repository in connected state

Pass criteria: SSO flow completes without user entering credentials manually (mocked IDP). Repository shows at least the test folder structure from the pre-populated SharePoint test tenant.

**Flow 3: File Import and Classification**

Steps:
1. Starting from Home screen
2. Tap "Import file" quick action
3. Local Import screen appears — tap "Apple Files" source
4. Select a pre-prepared test PDF containing PII (SSN, name, address)
5. Assert import progress indicator appears
6. Assert AI scanning progress indicator appears (on-device classification)
7. Assert sensitivity label "Confidential" is applied to the imported file
8. Assert file appears in File Browser with correct classification badge
9. Assert encryption icon is present on the file (indicating encrypted local storage)
10. Open the file in File Viewer
11. Assert sensitivity label is displayed in the viewer
12. Assert watermark overlay is present on the document canvas
13. Assert share button reflects policy restrictions for a Confidential file

Variants:
- Import a file with no PII: assert classification is "Internal" or "Public", no watermark
- Import a file with PHI (medical terms, patient ID patterns): assert "Restricted" classification
- Import a zero-byte file: assert graceful error, not crash

**Flow 4: Secure Sharing Workflow**

Steps:
1. Open a Confidential file in File Viewer
2. Tap Share button
3. Assert Share Workflow screen appears with recipient selector
4. Enter an external (non-organization) email address
5. Assert AI risk summary panel shows "External recipient warning"
6. Assert share method options automatically suggest "Secure Link" over "Direct Attachment"
7. Assert expiration controls are present
8. Confirm share
9. Assert share is logged in the audit trail (navigating to Sharing Center after)
10. Navigate to Sharing Center
11. Assert the shared file appears with active link and expiration timer
12. Tap Revoke
13. Assert the share link status changes to "Revoked"

Variants:
- Share with an internal recipient: assert no external recipient warning
- Share a Restricted file with an external recipient: assert the share is blocked, not just warned

**Flow 5: Policy Violation Handling**

Steps:
1. Configure the mock policy engine to classify a file as Restricted and set external sharing as blocked
2. Open the Restricted file in File Viewer
3. Attempt to tap the share button
4. Assert a policy violation warning is displayed, not a share sheet
5. Assert the warning includes human-readable policy rationale (not a technical error code)
6. Assert no share sheet is presented to the iOS system
7. Attempt to trigger a screenshot (via `XCUIDevice.shared.press(.home)` then screenshot API — limited by iOS, but validate blur is applied)
8. Background the app
9. Assert the background blur view is applied (check for blur element in the hierarchy)
10. Return to foreground
11. Assert biometric authentication prompt appears (Face ID mock)
12. Authenticate
13. Assert file is accessible again

---

## 6. SECURITY TESTING PLAN

Security testing is executed as a dedicated test pass, separate from functional test automation. It involves both automated assertions in the unit/integration tiers and manual exploratory testing with specialized tooling. All security test failures are Severity 1 defects.

### DLP Validation

**Screenshot Blocking**

iOS 17 provides `UITextField.isSecureTextEntry` and the newer `UIView.makeSecure()` equivalent for secure screen rendering (preventing screenshots and screen recording at the system level). However, iOS does not provide a guaranteed screenshot-blocking API for all content. The spec acknowledges this with "where iOS APIs permit."

Test approach:
- Unit test: verify that the `SecureContentView` wrapper applies the secure layer (`UIScreen.main.addSubview(secureView)` pattern) whenever a Confidential or above file is displayed
- Unit test: verify that `NotificationCenter` observer for `UIScreen.capturedDidChangeNotification` is registered when a secure file is open
- Unit test: verify that when `UIScreen.isCaptured` becomes `true`, the document canvas is replaced with a "Screen recording detected" overlay
- Manual test: on a physical device (not simulator), attempt screenshot while Confidential file is open. Verify the screenshot captures the secure overlay, not document content.
- Manual test: attempt AirPlay mirroring while a Restricted file is open. Verify mirrored display shows blur/overlay.

**Background Blur**

- Unit test: verify `applicationWillResignActive` observer triggers the blur overlay with a window-level blur view
- Unit test: verify the blur view has `windowLevel = .alert + 1` to appear above all other content
- E2E test (XCUITest): background the app during file viewing. Assert `fileViewer.blurOverlay` element exists in the view hierarchy when app is in background state.
- Manual test: use iOS app switcher to verify the app preview in the multitask switcher shows blur, not document content.

**Copy Prevention**

- Unit test: mock `UIPasteboard.general` and verify that programmatic paste of document content is intercepted and cleared
- Unit test: verify that `UIMenuController` long-press actions (Select All, Copy) are disabled on the secure document canvas
- Manual test: long-press on text in a Confidential document viewer. Verify no text selection handles appear.

**Share Sheet Filtering**

- Unit test: verify that the `UIActivityViewController` is initialized with an `excludedActivityTypes` list that excludes all third-party app destinations for Confidential and above
- Unit test: verify that only "Share via XQ Secure Share" and "Copy Secure Link" appear in the filtered share sheet for the test classification
- E2E test: trigger share for a Confidential file. Verify the system share sheet is not presented. Verify the XQ share workflow is presented instead.

### Jailbreak Detection Testing

The spec requires jailbreak detection during Splash initialization.

Tests:
- Unit test: verify the `JailbreakDetector` returns `true` for jailbreak indicators on a clean simulator (since simulators do not have jailbreak indicators, use a mock detector that injects known indicators)
- Unit test: verify presence of `/Applications/Cydia.app` returns `jailbreakDetected = true`
- Unit test: verify ability to write outside the sandbox (simulated) returns `jailbreakDetected = true`
- Unit test: verify that a detected jailbreak causes the Splash initialization to halt and display a non-dismissible error screen
- Unit test: verify that the jailbreak detection result is logged to the audit system
- Manual test on physical jailbroken device (if available in the test lab): verify app refuses to launch. This is the gold standard test.
- Simulator test: inject the mock jailbreak detector via launch arguments; verify the UI flows correctly into the failure state.

### Encryption Validation

- Integration test: import a file, then inspect the application's Documents directory using the XCUITest `attachment` API. Verify that the stored file is not readable as plaintext (the raw bytes should not contain the original content in clear form).
- Integration test: kill the app process, restart, verify the encrypted file is correctly decrypted and displayable.
- Integration test: inspect the iOS Keychain for the encryption key using `SecItemCopyMatching`. Verify the key is present and has `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` attribute.
- Integration test: verify that deleting the app removes the Keychain items (by reinstalling and confirming the prior session's files are inaccessible).

### Certificate Pinning Verification

- Integration test: configure a proxy (Charles Proxy or mitmproxy) in the test environment with a self-signed certificate. Attempt to make an API call through the proxy. Verify the connection is refused with a `NSURLErrorServerCertificateUntrusted` error.
- Unit test: verify the `CertificatePinningValidator` rejects connections where the presented leaf certificate does not match the pinned public key hash.
- Unit test: verify that certificate pinning failure is logged to the security audit channel.
- Test both XQ API and SharePoint API endpoints for pinning enforcement.

### Token Storage Security

- Unit test: verify that OAuth tokens are stored using `kSecClassGenericPassword` in the iOS Keychain, not `UserDefaults` or any other unprotected store.
- Unit test: verify that tokens are stored with `kSecAttrAccessGroup` set to the app's designated access group (preventing access by other apps).
- Unit test: verify that the token is not logged anywhere in the application's unified logging output (scan log output for known token format patterns).
- Integration test: after authentication, use `SecItemCopyMatching` to confirm the token is in the Keychain and not in any database, plist, or cache file.

### Data Leakage Testing

- Verify via file system inspection (using XCUITest attachments) that no decrypted file content is written to `/tmp`, `NSTemporaryDirectory()`, or the Photos library.
- Verify that QuickLook preview generation does not write decrypted content to the system's shared preview cache.
- Verify that no file content appears in the iOS Clipboard after viewing (test by checking `UIPasteboard.general.string` after viewing a document).
- Verify that crash reporter logs (if integrated) do not contain sensitive file content.

---

## 7. AI TESTING PLAN

AI testing for this app has two distinct concerns: (1) the correctness of the AI interface contract, covered by unit/integration tests with mocked providers; and (2) the accuracy of the actual classification models, which requires a labeled test dataset evaluated against quantified thresholds. Section 3 covers interface contract testing. This section covers accuracy validation.

### Classification Accuracy Benchmarks

A labeled test dataset of 500 documents must be prepared before Phase 1 launch. Dataset composition:

| Category | Count | Examples |
|---|---|---|
| Public documents | 75 | Marketing materials, public press releases, open source docs |
| Internal documents | 100 | Internal memos, project plans without sensitive data |
| Confidential — PII | 100 | Documents containing SSN, full name + address, driver's license numbers |
| Confidential — PHI | 75 | Documents with patient names, diagnoses, medication records, insurance IDs |
| Confidential — Financial | 75 | Bank statements, credit card numbers, financial reports |
| Restricted — CUI | 50 | NIST-categorized controlled unclassified information patterns |
| Edge cases | 25 | Redacted documents, mixed-classification documents, non-English PII |

Each document in the dataset has a ground-truth label. The benchmark runner feeds each document through the `AIProvider.classify(document:)` interface and compares the result against the ground truth.

### Acceptance Thresholds

These thresholds are derived from the spec's risk management section which identifies "AI false positives" as a primary risk requiring "user override + model refinement."

| Metric | Threshold | Justification |
|---|---|---|
| Overall classification accuracy | >= 90% | Product success metric from spec |
| PII detection recall (true positive rate) | >= 95% | False negatives allow data to leak unprotected |
| PHI detection recall | >= 97% | Higher threshold due to HIPAA compliance exposure |
| Financial data detection recall | >= 95% | False negatives expose financial PII |
| False positive rate (Public misclassified as Confidential) | <= 5% | Spec identifies workflow disruption as a key risk |
| CUI detection recall | >= 90% | Federal compliance requirement |
| Multi-label accuracy | >= 85% | Documents with multiple sensitive categories |

A false negative (sensitive document classified as non-sensitive) is weighted more heavily than a false positive. A false negative rate above threshold on PHI or PII is a release blocker.

### PII/PHI Detection Test Dataset

The test dataset must include coverage for:
- US Social Security Numbers in multiple formats (XXX-XX-XXXX, XXXXXXXXX)
- Driver's license numbers (format varies by state — test 5 representative states)
- Credit card numbers (Visa, Mastercard, Amex patterns)
- IBAN and routing/account number patterns
- Patient names combined with diagnosis codes (ICD-10)
- Medication names combined with patient identifiers
- Full name + date of birth + address combinations
- Phone numbers and email addresses in isolation (edge case: these alone may not trigger high classification)
- Non-English PII: German Personalausweis numbers, UK National Insurance numbers

### Performance Tests (Classification Latency)

On-device AI inference must not degrade user experience. Targets:

| Document Type | Maximum Classification Latency | Measurement Method |
|---|---|---|
| Text file (< 10KB) | 500ms | `measure {}` block in Swift Testing |
| PDF (< 1MB) | 2 seconds | `measure {}` block |
| DOCX (< 5MB) | 3 seconds | `measure {}` block |
| XLSX (< 2MB) | 3 seconds | `measure {}` block |
| Image (< 8MB) | 4 seconds (Phase 3 OCR excluded) | `measure {}` block |

These latency tests run on the minimum supported device in the matrix (see Section 12). Passing on a new A18 chip but failing on an A15 chip is a defect.

AI model memory footprint must not exceed 150MB resident memory during active classification.

---

## 8. PERFORMANCE TESTING

### UI Frame Rate Validation (60 FPS Minimum)

The spec is explicit: every UI element must animate (entry, exit, click), and 60 FPS is the minimum. On ProMotion displays (120Hz iPad Pro and iPhone 15 Pro), 120 FPS is the target.

Frame rate measurement approach:

Use Xcode's MetricKit and `XCTMetric` within UI test runs:

```swift
@Test("File browser entry animation maintains 60fps")
func fileBrowserEntryAnimationFrameRate() throws {
    let metrics: [XCTMetric] = [XCTOSSignpostMetric.scrollDecelerationMetric]
    let measureOptions = XCTMeasureOptions()
    measureOptions.invocationOptions = [.manuallyStart]

    measure(metrics: metrics, options: measureOptions) {
        startMeasuring()
        // Navigate to File Browser (triggers entry animation)
        let app = XCUIApplication()
        app.tabBars.buttons["Files"].tap()
        app.tables.firstMatch.waitForExistence(timeout: 2)
        stopMeasuring()
    }
}
```

Manual frame rate validation tool: Instruments > Core Animation. Run the following scenarios and record the 1st percentile FPS (worst frame) alongside average FPS:

| Animation | Minimum Average FPS | Maximum Frame Drop (single frame) |
|---|---|---|
| Home screen entry (app launch) | 58 | 35ms |
| Tab bar navigation transition | 58 | 35ms |
| File Browser list scroll | 58 | 35ms |
| File Viewer open animation | 58 | 35ms |
| Share Workflow presentation | 58 | 35ms |
| Settings screen entry | 58 | 35ms |
| Risk alert appearance | 58 | 35ms |

A sustained drop below 50 FPS for more than 500ms is a defect. A single frame drop below 30ms is a warning.

### AI Inference Latency Targets

See Section 7. Additionally measure impact on concurrent UI rendering: while AI classification runs in the background on an imported file, the UI must remain at or above 55 FPS (5 FPS tolerance for background processing).

### Offline Cache Performance

- Time to open an offline-cached file: under 300ms from tap to first-byte rendered
- Time to list all offline files in File Browser: under 200ms for up to 100 cached files
- Memory overhead of the offline cache index: under 10MB resident memory for 1000 file metadata entries

### Memory Usage Limits

| Scenario | Maximum Resident Memory |
|---|---|
| App idle (Home screen, no files open) | 80MB |
| File Browser (100 file list) | 120MB |
| File Viewer (10MB PDF) | 200MB |
| AI classification active (background) | 350MB total (model + document buffer) |
| Offline sync in progress | 250MB |

Memory limit violations are measured using Xcode Memory Graph and MetricKit `MXMemoryMetric`. Exceeding peak limits on older devices in the matrix must be investigated for model size optimization.

### Battery Impact Assessment

AI classification is the highest battery risk. The spec explicitly requires "battery-aware processing" and "lightweight on-device models."

Test methodology: use MetricKit `MXCPUMetric` to capture CPU time during classification. A classification of a 1MB document must not consume more than 0.5% of total battery capacity on an iPhone 15 (A16 Bionic) as measured over a 30-minute active use session.

Test scenarios for battery profiling:
- 30-minute file browsing session with no AI activity
- 30-minute session importing 10 files with full AI classification on each
- 30-minute session with the app in the background (offline sync active)

The delta between baseline (no AI) and active classification sessions must be under 8% total battery impact for a 30-minute session.

---

## 9. OFFLINE TESTING

Offline testing validates the spec requirement that "core functions operate without connectivity." All offline tests use the Network Link Conditioner or `XCTestCase` with `URLProtocol` mock to intercept and block network traffic.

### Critical Flows in Offline Mode

| Flow | Expected Behavior | Pass Criteria |
|---|---|---|
| App launch (no connectivity, prior session exists) | App loads from encrypted session, Splash completes, Home screen loads with cached file list | Home screen visible within 4 seconds, no network error shown |
| Open offline-cached file | File opens from encrypted local cache | File renders within 300ms |
| Edit offline-cached text file | Edits saved to local encrypted cache, edit indicators shown | Edit saves without error, sync pending indicator visible |
| AI classification of imported file | Local CoreML model used, no cloud model call | Classification completes within latency targets in Section 7 |
| Browse File Browser (cached content) | Cached file list displayed with offline badge | File list renders, online-only files shown as unavailable |
| Attempt to open non-cached file | Clear offline unavailability indicator shown | "Not available offline" message in localized string, no spinner indefinitely |
| Attempt to share a file | Share workflow validates locally; network-dependent actions are queued | UI clearly indicates which share actions require connectivity |

### Sync Behavior When Connectivity Restores

Test procedure: perform actions offline, then restore network using Network Link Conditioner programmatically via `DeviceConditioner` helper in the test target.

| Scenario | Expected Behavior |
|---|---|
| Offline edits, no remote changes | Edits push to SharePoint automatically, sync indicator clears |
| Offline edits + remote changes to different sections of same file | Both changes merged, no conflict prompt |
| Offline edits + remote changes to same section of same file | Conflict resolution prompt displayed with both versions |
| New file added to SharePoint while device was offline | File appears in File Browser with correct metadata after sync |
| Policy update pushed while offline | New policy applied to all affected files during first sync |
| Offline cache expired file (time-limited per spec) | Expired file removed from cache, replaced with online-only indicator |

### Conflict Resolution Scenarios

| Conflict Type | Resolution Strategy | Test Verification |
|---|---|---|
| Text file: same line edited both locally and remotely | User shown diff, prompted to choose local, remote, or merge | Prompt fires once, both versions preserved for selection |
| File renamed locally and content edited remotely | Conflict prompt showing both states | User sees descriptive conflict summary in localized language |
| File deleted remotely while edited locally | User prompted: discard local edits or restore file | Clear actionable prompt, no data loss without explicit user consent |
| Folder structure changed remotely while browsing locally | Graceful refresh after connectivity restore | No crash, stale local paths resolve to updated remote paths |

---

## 10. ACCESSIBILITY TESTING

Accessibility is a first-class requirement given the spec's explicit call-out of VoiceOver, Dynamic Type, Reduced Motion, and RTL support.

### VoiceOver Coverage

Every interactive element on all 11 Phase 1 screens must have:
- A meaningful `accessibilityLabel` (not the raw accessibility identifier)
- A correct `accessibilityTraits` (button, link, image, etc.)
- `accessibilityHint` for non-obvious actions (e.g., the policy indicator needs a hint explaining what tapping it does)

Automated validation: use `XCUITest` with VoiceOver enabled via `app.launch()` with accessibility enabled, and verify that `element.isAccessibilityElement == true` and `element.accessibilityLabel.isEmpty == false` for every interactive control.

Manual validation: enable VoiceOver on a physical device and navigate the five critical flows in Section 5 using only VoiceOver gestures. Document any element where VoiceOver announces "button" without a label, or where focus order is illogical.

### Dynamic Type Support

All text in the app must use system-scaled fonts and lay out correctly from the smallest accessibility text size (xSmall) through the largest (AX5).

Test procedure: change the system font size in Settings > Accessibility > Display & Text Size > Larger Text for each size from xSmall to AX5, and screenshot each Phase 1 screen. Check for:
- Text truncation without ellipsis
- Overlapping elements
- Buttons too small to interact with at large sizes
- Sensitivity labels clipped

Automated: use snapshot testing (SnapshotTesting library or Xcode's built-in UI test screenshots) to capture all Phase 1 screens at xSmall, Default, Large, and AX5 text sizes. Visual regression comparison alerts when layout breaks.

### Reduced Motion Support

The spec requires Reduced Motion accessibility support while also mandating that every element animates. These must coexist: when Reduced Motion is enabled in iOS Accessibility settings, animations must either be removed or replaced with cross-fades (as required by Apple HIG).

Test procedure:
- Enable Reduce Motion in iOS Settings
- Navigate all five critical flows
- Verify that no element performs a bounce, spring, or scale animation (these cause vestibular discomfort)
- Verify that transitions use opacity changes (cross-fades) instead of slides
- Verify that the `@Environment(\.accessibilityReduceMotion)` modifier is respected in SwiftUI views

### High Contrast Support

- Enable Increase Contrast in iOS Accessibility settings
- Navigate all five critical flows
- Verify that sensitivity label colors meet WCAG AA contrast ratio (4.5:1 for text, 3:1 for UI components)
- Verify that watermark overlays are legible in high contrast mode
- Verify that risk notification colors (typically red/yellow) are distinguishable in high contrast and for colorblind users (use Simulator's Color Blind simulations)

---

## 11. LOCALIZATION TESTING

The spec requires that all UI text is externalized in JSON localization files and that runtime language switching is supported without an app restart.

### Language Switching Behavior

- Navigate to Settings > (simulated language preference) and switch language at runtime
- Verify all visible text on the current screen updates immediately without dismissing or reloading the screen
- Verify that no raw localization key (e.g., `home.title`) is ever displayed in the UI
- Verify that switching language does not reset any app state (current file, navigation position, offline cache status)

Test automation: create a test that iterates through all supported language codes (at minimum: en, fr, de, ja, ar, he), switches language programmatically, and asserts that the Home screen title text is not equal to the localization key.

### Text Truncation in Different Languages

German, Finnish, and Russian text is significantly longer than English equivalents. Test all buttons and labels with German locale enabled.

Specific risk areas based on Phase 1 screens:
- Onboarding "Continue Local-First" button: German equivalent is typically 40-60% longer
- File Viewer "Share Securely" button
- Policy violation error messages
- AI classification label badges (must fit within the badge chip)
- Settings category headers

Test procedure: switch device to German locale, navigate all Phase 1 screens, photograph or snapshot every button and label. Flag any element where text is clipped (truncated with `...`) without the full text being accessible via VoiceOver.

### RTL Layout Testing (Arabic, Hebrew)

Arabic and Hebrew require full RTL layout mirroring. SwiftUI handles most RTL mirroring automatically when using `leading`/`trailing` instead of `left`/`right` layout constraints.

Test procedure:
1. Set device locale to Arabic (ar)
2. Navigate all Phase 1 screens
3. Verify that the primary content is right-aligned
4. Verify that the bottom tab bar icons are mirrored (Files tab is rightmost in RTL)
5. Verify that back buttons point right (RTL direction)
6. Verify that sensitivity label badges appear on the correct side of file list items
7. Verify that the AI scanner camera interface is correctly mirrored
8. Verify that text input fields accept Arabic input and display correctly (right-to-left text direction)
9. Verify that localization strings in `/localization/ar.json` are complete and not falling back to English (check for any English text on Arabic screens)

---

## 12. DEVICE MATRIX

### Minimum Test Devices (Physical Devices Required for Security Tests)

| Device | Chip | iOS Version | Priority | Rationale |
|---|---|---|---|---|
| iPhone 15 | A16 Bionic | iOS 18.x | P1 — Primary dev target | Current gen, most common enterprise deployment |
| iPhone 13 | A15 Bionic | iOS 17.x | P1 — Minimum performance target | Lowest spec in supported range |
| iPhone SE (3rd gen) | A15 Bionic | iOS 17.x | P2 | Small screen layout validation |
| iPad Pro 13" (M2) | M2 | iOS 17.x / iPadOS 17.x | P1 — iPad primary | Split view, Stage Manager, large canvas |
| iPad Air (5th gen) | M1 | iPadOS 17.x | P2 | Mid-range iPad performance |
| iPad mini (6th gen) | A15 Bionic | iPadOS 17.x | P2 | Compact iPad layout variant |

Physical devices are required for:
- Biometric authentication (Face ID / Touch ID cannot be fully mocked on simulator)
- Secure Enclave operations (simulator uses software emulation, not hardware)
- Screenshot blocking validation (simulator always allows screenshots)
- Background blur validation in app switcher
- Jailbreak detection (jailbroken physical device required for negative test)
- Certificate pinning under real network conditions
- Battery impact measurement (MetricKit requires physical device)

Simulator is sufficient for:
- Functional flows
- Localization tests
- Accessibility tests (with VoiceOver enabled)
- Unit and integration tests
- Offline/network simulation tests

### iPad vs iPhone Differences

| Behavior | iPhone | iPad |
|---|---|---|
| Navigation model | NavigationStack (push/pop) | SplitView (sidebar + detail) |
| File Browser layout | Full screen list | Master-detail with sidebar |
| Share Workflow | Full-screen modal | Popover or half-sheet |
| Keyboard support | Virtual only | External keyboard + shortcuts |
| Stage Manager | Not applicable | Multi-window, app overlapping |
| Drag and drop | Limited | Full drag-and-drop between apps (must be blocked per DLP) |

iPad-specific test cases:
- Verify DLP controls are enforced when another app is visible in Stage Manager (the secure viewer must not expose content when split)
- Verify drag-and-drop from XQ Secure Workspaces to the Files app or another app is blocked for Confidential and above
- Verify Split View layout renders correctly without text overlap or broken constraints
- Verify the external keyboard shortcut table (if implemented) includes accessibility keyboard navigation

### OS Version Matrix

| iOS Version | Devices | Test Depth |
|---|---|---|
| iOS 17.x | iPhone 13, iPad Air, iPad mini | Full test matrix |
| iOS 18.x | iPhone 15, iPad Pro | Full test matrix |
| iOS 18 Beta | Xcode simulators | Smoke tests only — regression detection |

The spec states "latest two major releases minimum." Both iOS 17 and iOS 18 are fully supported and must pass the complete test suite. Any iOS 18-specific API used (e.g., new SwiftUI modifiers) must have an iOS 17-compatible fallback tested explicitly.

---

## 13. ACCEPTANCE CRITERIA BY FEATURE (PHASE 1 SCREENS)

### Screen 3.1: Splash / Secure Initialization

Definition of Done:
- XQ logo animation completes within 2.5 seconds on minimum-spec device
- All background checks (jailbreak, integrity, enclave, token, cache) complete before navigation proceeds
- Jailbreak detection causes a non-dismissible error screen with a localized message explaining the issue
- Expired session causes redirect to onboarding (not a crash)
- Screen is not accessible via accessibility navigation skip (security screen must complete before any user input)

### Screen 3.2: Welcome / Onboarding

Definition of Done:
- Both "Continue Local-First" and "Connect Enterprise Workspace" paths are fully navigable
- Privacy-first messaging is displayed and localized in all supported languages
- Intro slides animate at 60 FPS
- The onboarding flow is completable without creating an account (consumer path)
- AI onboarding assistant is triggered on the enterprise path

### Screen 3.3: AI-Assisted Repository Setup

Definition of Done:
- SharePoint connection succeeds with a valid Entra ID/OAuth token
- SMB configuration is accepted and validated
- AI assistant chat panel surfaces contextual suggestions (auto-detected URL format, credential hint)
- Connection diagnostics correctly distinguish between authentication failure, connectivity failure, and permission failure
- Invalid credentials show a localized error, not a raw API error code
- The setup is re-enterable without data loss (user can go back and retry without losing entered configuration)

### Screen 3.4: Permissions Setup

Definition of Done:
- All five required permissions (Face ID, Notifications, Files, Camera roll, Network) are requested in the correct order
- Declining a permission shows a localized explanation of the impact on functionality
- Declining Face ID does not block access (app falls back to PIN or session timeout)
- AI explanation of each permission's purpose is displayed before the system permission dialog

### Screen 3.5: Home Screen

Definition of Done:
- Recent Files section populates within 500ms of app foreground with up to 10 most recent files
- Suggested Files section surfaces AI-generated suggestions based on usage history
- Offline Files section shows all marked-offline files with sync status indicators
- Risk Notifications section displays any pending policy violations or AI alerts
- Quick Actions (Import, Compose, Share, Scan) all navigate to the correct screens
- All sections render with correct animations at 60 FPS
- Empty state is shown when no content exists (not a blank screen)

### Screen 3.6: Repository Browser (File Browser)

Definition of Done:
- All connected repositories are accessible from the repository switcher
- Folder hierarchy navigation works for at least 10 levels deep
- Classification badges are displayed on all files that have been classified
- Search returns results within 300ms for a 1000-file repository (offline cache search)
- Multi-select works for up to 50 files simultaneously
- Sensitivity labels, offline badges, share status, and sync state indicators are all correct and current
- Drag-to-mark-offline gesture works on iPad; long-press context menu works on iPhone

### Screen 3.7: Secure File Viewer

Definition of Done:
- PDF, DOCX, XLSX, TXT, and image files all render correctly
- Sensitivity label is visible throughout the viewing session
- Watermark is present for Confidential and above classifications
- Screenshot blocking is active (verified on physical device)
- Background blur activates within 1 frame of `applicationWillResignActive`
- Copy/paste is disabled for Confidential and above
- Share button respects policy restrictions
- Screen recording detection shows overlay when screen is being recorded (physical device)
- Pinch-to-zoom works on PDF and images without frame rate degradation

### Screen 3.8: Document Editing (adjacent to Viewer for Phase 1)

Definition of Done:
- Text files and DOCX open in edit mode
- Changes are auto-saved to the local encrypted cache
- "Saving..." indicator appears during sync
- After save, AI rescan completes and classification is updated if content changed
- Edits to a DOCX file do not corrupt the file format
- The editor itself does not allow text to be copied to the system clipboard for Confidential documents

### Screen 3.9: Secure Share Workflow

Definition of Done:
- Recipient selector works for email address and internal group selection
- AI risk summary is displayed before share confirmation for all files above "Internal"
- External recipient warning triggers for non-organization email domains
- Expiration control defaults to the enterprise policy setting
- Share is blocked (not warned) for Restricted files when enterprise policy prohibits external sharing
- Audit log entry is created for every share action
- Share revocation from the Sharing Center takes effect within 30 seconds (next policy evaluation cycle)

### Screen 3.10: Local File Import

Definition of Done:
- Files can be imported from Apple Files, Camera roll, and Downloads
- Import progress indicator accurately reflects the import + encryption + classification pipeline
- AI-suggested destination folder appears within 1 second of import completion
- Classification prediction is displayed before the user confirms the destination
- Imported files are encrypted immediately (verify via storage inspection)
- Policy protections are applied within the classification pipeline

### Screen 3.11: AI Document Scanner

Definition of Done:
- Camera opens successfully and shows real-time viewfinder
- OCR preview is visible during capture
- Sensitivity detection panel updates in real time as document text is recognized
- PII, PHI, Financial, and CUI patterns are flagged in the classification preview
- Scanned document is encrypted immediately on import
- Governance labels are applied before the file appears in the File Browser
- Camera permission denial is handled gracefully with a localized explanation

### Screen 3.18: Settings

Definition of Done:
- Account section shows current identity, SSO status, and device registration state
- Face ID toggle enables/disables biometric authentication for subsequent app launches
- Session timeout slider defaults to the enterprise policy value when enrolled
- Offline Storage section shows current cache size and allows folder selection for offline sync
- AI Governance section exposes consumer-level preferences (scanning frequency, notification verbosity)
- Repository Connections section lists all connected repositories with reauthentication actions
- All settings changes persist across app restarts

---

## 14. RISK ASSESSMENT

### Risk 1: On-Device AI Model Accuracy Below Threshold on Minimum-Spec Devices

Likelihood: High. Severity: High.

The AI classification models must run on devices as old as an A15 Bionic (iPhone 13 / iPhone SE 3rd gen). Quantized CoreML models may have meaningfully lower accuracy than their full-precision cloud equivalents. The accuracy thresholds in Section 7 (95% PII recall, 97% PHI recall) were defined against an ideal model. The same thresholds must hold on minimum-spec hardware.

Mitigation: The AI accuracy benchmark (Section 7) must be run on the minimum-spec device (iPhone SE 3rd gen) in addition to current-gen hardware. If accuracy on the minimum device falls below threshold, either the quantization must be improved or the classification task must be routed to a cloud model (with appropriate privacy disclosure) for that device class. This is a go/no-go decision before Phase 1 release.

### Risk 2: iOS DLP API Limitations Expose Content Through System-Level Mechanisms

Likelihood: Medium. Severity: Critical.

iOS does not provide a reliable API to prevent screenshots in all scenarios. Screen recording via AirPlay, iOS Mirroring (Continuity Camera), and the new iOS screen sharing features may bypass the app-level `UIScreen.isCaptured` detection. The spec acknowledges this with "where iOS APIs permit" for screenshot blocking, and falls back to watermarking.

Mitigation: The watermarking system is the defense-in-depth fallback and must be tested rigorously to ensure it is always present and legible on Confidential+ content. Test each bypass vector individually (AirPlay, Continuity Camera, USB screen recording via QuickTime) on physical devices. Ensure the watermark contains user identity (email + timestamp) so that leaked screenshots are attributable. Document the residual risk in the release notes for enterprise customers who need a formal risk acceptance sign-off.

### Risk 3: Sync Engine Data Loss During Conflict Resolution

Likelihood: Medium. Severity: High.

The offline-first sync model creates conflict scenarios that are complex to handle correctly. The spec requires that conflict resolution "prompts user only when necessary" and that "no data loss" occurs. A bug in the delta sync or conflict resolution algorithm could silently discard either local or remote edits.

Mitigation: The sync engine unit tests (Section 3) must achieve 85%+ branch coverage. Every conflict resolution code path must be explicitly tested (see Section 9). Additionally, implement a non-destructive conflict resolution model: before resolving any conflict, both versions must be preserved in the local encrypted cache with timestamps. The user selection discards one version; neither version is deleted before the user makes an explicit choice. Add a sync audit log that records every conflict and its resolution, accessible in the enterprise Audit & Activity screen.

### Risk 4: Jailbreak Detection Bypass

Likelihood: Low (for typical enterprise users). Severity: Critical.

Sophisticated threat actors can bypass common jailbreak detection heuristics by hooking the filesystem check methods or patching the binary. If jailbreak detection is bypassed, the entire DLP control set is potentially undermined: the attacker has full filesystem access, can read the decrypted in-memory content, and may be able to extract keys from the Secure Enclave emulation layer.

Mitigation: Use multiple independent jailbreak detection signals (filesystem checks, library injection detection, dyld inspection, and runtime integrity checks) so that bypassing one check does not compromise all checks. Consider integrating a commercial anti-tamper SDK (Guardsquare's iXGuard or similar) for Phase 1 enterprise deployments where jailbreak resistance is a hard requirement. Test the detection suite against known jailbreak tools (Checkra1n, Dopamine) in the test lab. Accept that a determined sophisticated attacker with a novel jailbreak tool may succeed; document this in the threat model.

### Risk 5: XQ API Version Compatibility Breaking at Runtime

Likelihood: Medium. Severity: High.

The spec requires support for multiple XQ API versions simultaneously via `XQAPIv1Adapter`, `XQAPIv2Adapter`, and `XQAPIv3Adapter`. An enterprise tenant may be pinned to an older API version. If the version negotiation logic has a defect, the app could silently use the wrong adapter and produce incorrect encryption, incorrect policy enforcement, or authentication failures.

Mitigation: The version adapter integration tests (Section 4) must verify that each adapter correctly implements the `XQSecureAPI` protocol contract. Add a contract compatibility test that calls every method on each adapter against the staging API and validates the response schema. Implement a startup-time capability negotiation that logs the selected adapter version to the unified logging framework so that support teams can diagnose version mismatch issues in the field. Do not allow a version negotiation failure to silently fall back to an untested adapter; surface a clear error to the user and block access until the version conflict is resolved by the enterprise administrator.

---

**Testing Lead Sign-off Gate**

The following conditions must be met before Phase 1 can be declared release-ready:

1. All unit tests pass with 80%+ coverage across core modules
2. All integration tests pass against staging environment (zero failures)
3. All five E2E flows pass on all P1 devices (iPhone 13 iOS 17, iPhone 15 iOS 18, iPad Pro iPadOS 17)
4. Security test pass complete with zero Severity 1 defects open
5. AI classification accuracy benchmark meets all thresholds on minimum-spec device (iPhone SE 3rd gen)
6. 60 FPS animation target met for all Phase 1 screens on minimum-spec device
7. DLP validation complete on physical device (not simulator only)
8. RTL layout validation complete for Arabic locale on at least one physical device
9. All acceptance criteria for all 11 Phase 1 screens marked as passed

---

**Relevant paths:**
- Spec source: `/Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt`
- Recommended test target structure root: `/Users/brianwane/agentic-lab/apps/IOSXQ/` (no test files exist yet — this strategy defines what to build)