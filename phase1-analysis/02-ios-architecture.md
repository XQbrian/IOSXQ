Now I have a thorough understanding of the spec. Let me produce the comprehensive architecture analysis.

---

# XQ Secure Workspaces iOS — Phase 1 Architecture Analysis

---

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces is a Zero Trust, AI-governed secure file platform for iOS and iPadOS. The business objective is frictionless enterprise security: data protection follows the data itself, AI governance is ambient rather than disruptive, and the user never touches a policy control.

The architecture must simultaneously serve three tensions that most platforms choose between:

- Consumer simplicity vs. enterprise configurability
- On-device privacy vs. cloud AI capability
- Native iOS depth vs. Android code reuse

The recommended approach resolves these tensions through a strict layering contract: SwiftUI owns all visual presentation; Kotlin Multiplatform owns all business logic that must survive across iOS and Android; protocol interfaces stand between every layer. No business logic calls any concrete API, provider, or model class directly.

Phase 1 scope — secure file vault, XQ encryption, SharePoint connectivity, offline cache — is achievable in a 4-6 month window if the interface contracts and KMP shared module boundaries are established in the first six weeks. That foundation investment is the highest-leverage decision this document recommends.

---

## 2. RECOMMENDED ARCHITECTURE STACK

### Primary iOS Stack

| Concern | Technology | Rationale |
|---|---|---|
| UI | SwiftUI | Spec mandates it; best native accessibility and animation integration |
| Architecture pattern | MVVM-C (Coordinators) | Navigation logic stays out of ViewModels; testable; KMP-compatible |
| Reactive state | Combine + Swift Observable macro | Bridges KMP StateFlow via coroutine-to-Combine adapter |
| Dependency injection | Manual factory + environment injection | Zero runtime overhead; no magic; mockable at every boundary |
| Navigation | NavigationStack + NavigationSplitView | iPhone/iPad adaptive; spec mandates SplitView for iPad |
| Local persistence | CoreData with encrypted SQLite backing | Well-understood migration story; works offline |
| Encryption | Secure Enclave + CryptoKit | Spec mandates; keys never leave hardware |
| AI runtime (local) | CoreML + ONNX Runtime | Spec mandates both; CoreML for Apple-optimized models |
| Background work | BGTaskScheduler | Sync and AI rescanning outside foreground |
| Networking | URLSession wrapped behind protocol | Never called directly from business logic |

### Kotlin Multiplatform Shared Core

KMP sits between the iOS Swift layer and external services. The division is strict:

**Placed in KMP (shared, cross-platform):**
- Domain models and value types (SecureFile, ClassificationLabel, PolicyDecision, RiskScore, SyncOperation)
- Business logic: policy evaluation, risk scoring, sync orchestration, sharing workflow state machines
- Repository interfaces: RepositoryProvider, XQSecureAPI, AIProvider, ExternalIntegration, PolicyEngine
- Localization engine: JSON loading, key lookup, OTA update logic
- Sync engine: delta computation, conflict resolution, retry queue
- Telemetry and audit event schema
- Design token definitions (colors, spacing, motion timing constants)

**Stays Swift-only (iOS platform APIs required):**
- SwiftUI views and view modifiers
- Coordinators and NavigationStack management
- CoreML model loading and inference dispatch
- Secure Enclave operations (no JVM equivalent)
- BGTaskScheduler registration
- iOS permission request flows
- Screenshot detection and background blur
- QuickLook rendering

### State Management

KMP exposes `StateFlow` from `kotlinx.coroutines`. iOS side bridges via the `KMP-NativeCoroutines` library, which wraps each `StateFlow` in a Swift `AsyncStream`. ViewModels on iOS consume these as `@Published` properties through a thin adapter.

```swift
// Adapter pattern: StateFlow -> Published
final class StateFlowAdapter<T: AnyObject>: ObservableObject {
    @Published var value: T
    private var task: Task<Void, Never>?

    init(stateFlow: CommonStateFlow<T>) {
        self.value = stateFlow.value
        task = Task {
            for await newValue in stateFlow.asAsyncStream() {
                await MainActor.run { self.value = newValue }
            }
        }
    }
}
```

### Dependency Injection Approach

No third-party DI container. All services are resolved through a `ServiceLocator` that is constructed at app startup and threaded through via SwiftUI's `@EnvironmentObject` or explicit initializer injection at coordinator boundaries.

The rationale for avoiding a DI framework: this codebase has hard security requirements. Every dependency resolution must be auditable. Magic reflection-based injection obscures what is instantiated when, which matters during security audits and when debugging policy decisions. Explicit factories are verbose but transparent.

```swift
// App-level composition root
struct AppDependencies {
    let xqAPI: XQSecureAPI
    let repositoryProvider: RepositoryProvider
    let aiProvider: AIProvider
    let policyEngine: PolicyEngine
    let localization: LocalizationService
    let animationEngine: AnimationEngine
    let syncEngine: SyncEngine
}
```

---

## 3. MODULE STRUCTURE

### Full Directory Tree with Responsibilities

```
App/
├── Core/
│   ├── AppCoordinator.swift          -- Root navigation coordinator
│   ├── AppDependencies.swift         -- Composition root
│   ├── AppLifecycleManager.swift     -- Foreground/background transitions, blur enforcement
│   ├── FeatureFlags.swift            -- Remote config + kill switches
│   └── UpdateManager.swift           -- Silent/soft/force update orchestration
│
├── UI/
│   ├── Components/                   -- Shared SwiftUI components (buttons, badges, cards)
│   ├── Screens/
│   │   ├── Splash/
│   │   ├── Onboarding/
│   │   ├── Home/
│   │   ├── FileBrowser/
│   │   ├── FileViewer/
│   │   ├── Editor/
│   │   ├── ShareWorkflow/
│   │   ├── Notifications/
│   │   ├── SharingCenter/
│   │   ├── EnterpriseAdmin/
│   │   └── Settings/
│   ├── DesignSystem/
│   │   ├── Colors.swift              -- Bridges KMP design tokens
│   │   ├── Typography.swift
│   │   ├── Spacing.swift
│   │   └── MotionTokens.swift        -- Duration, spring params from KMP tokens
│   └── Modifiers/
│       ├── SecureViewModifier.swift  -- Screenshot block, watermark overlay
│       ├── AnimatedEntryModifier.swift
│       └── PolicyVisibilityModifier.swift  -- Hides UI based on RBAC
│
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── FileBrowserViewModel.swift
│   ├── FileViewerViewModel.swift
│   ├── ShareWorkflowViewModel.swift
│   ├── OnboardingViewModel.swift
│   └── AdminDashboardViewModel.swift
│   -- ViewModels hold NO business logic. They transform KMP domain state
│   -- into @Published properties and route user intents to Services.
│
├── Services/
│   ├── FileService.swift             -- Orchestrates import, scan, encrypt, classify
│   ├── SharingService.swift          -- Orchestrates share workflow
│   ├── AuthService.swift             -- SSO, token lifecycle, device registration
│   ├── NotificationService.swift     -- Risk alerts, policy events
│   └── OnboardingService.swift       -- First-run setup orchestration
│   -- Services depend ONLY on interfaces from Interfaces/. Never on concrete
│   -- provider implementations.
│
├── Interfaces/
│   ├── RepositoryProvider.swift      -- Protocol: authenticate, list, download, upload
│   ├── XQSecureAPI.swift             -- Protocol: encrypt, decrypt, applyPolicy, revoke
│   ├── AIProvider.swift              -- Protocol: classify, evaluateRisk, summarize
│   ├── ExternalIntegration.swift     -- Protocol: authenticate, sync, query, upload
│   ├── PolicyEngine.swift            -- Protocol: evaluate, subscribe, override
│   ├── LocalizationEngine.swift      -- Protocol: string(forKey:), switchLanguage()
│   ├── SyncEngine.swift              -- Protocol: enqueue, flush, resolveConflict
│   └── AnimationEngine.swift         -- Protocol: entryAnimation(), exitAnimation()
│
├── Providers/
│   ├── SharePointProvider.swift      -- Implements RepositoryProvider
│   ├── SMBProvider.swift
│   ├── LocalVaultProvider.swift
│   ├── GoogleDriveProvider.swift     -- Phase 2
│   └── XQAPIGateway.swift            -- Wraps all XQ network calls; routes to versioned adapter
│
├── AI/
│   ├── CoreMLProvider.swift          -- Implements AIProvider using CoreML
│   ├── ONNXProvider.swift            -- Implements AIProvider using ONNX Runtime
│   ├── OpenAIProvider.swift          -- Implements AIProvider (cloud, policy-gated)
│   ├── AnthropicProvider.swift       -- Implements AIProvider
│   ├── AWSBedrockProvider.swift
│   ├── AzureOpenAIProvider.swift
│   ├── AIOrchestrator.swift          -- Routes to correct provider per tenant/policy/class
│   └── Models/
│       ├── ClassificationModel.mlmodel
│       └── RiskScoringModel.mlmodel
│
├── Security/
│   ├── SecureEnclaveManager.swift    -- Key generation, signing, encryption
│   ├── JailbreakDetector.swift       -- Runtime integrity checks
│   ├── DevicePostureEvaluator.swift  -- Trust score, MDM state, OS version
│   ├── CertificatePinner.swift       -- URLSession delegate
│   ├── ScreenshotGuard.swift         -- UIApplicationUserDidTakeScreenshot + blur
│   ├── ClipboardGuard.swift          -- Paste prevention
│   └── SessionManager.swift          -- Biometric unlock, session timeout
│
├── Policies/
│   ├── FuzzyPolicyEngine.swift       -- Implements PolicyEngine protocol
│   ├── RiskScorer.swift              -- Aggregates inputs into normalized 0-1 score
│   ├── PolicyRuleSet.swift           -- Tenant-configured rules, loaded from KMP
│   ├── PolicyDecision.swift          -- Output value type: restrictions, required actions
│   └── PolicyObserver.swift          -- Subscribes to context changes, re-evaluates
│
├── Localization/
│   ├── LocalizationService.swift     -- Implements LocalizationEngine
│   ├── LanguagePack.swift            -- Parsed JSON language file
│   ├── OTALanguageUpdater.swift      -- Downloads updated packs, applies without restart
│   └── en/messages.json
│   └── fr/messages.json
│   └── de/messages.json
│
├── Animations/
│   ├── AnimationEngine.swift         -- Central animation service
│   ├── EntryAnimation.swift          -- Fade + motion presets
│   ├── ExitAnimation.swift           -- Scale + fade presets
│   ├── SpringInteraction.swift       -- Click response spring configs
│   ├── ReducedMotionAdapter.swift    -- Checks UIAccessibility.isReduceMotionEnabled
│   └── AnimationTokens.swift         -- Duration constants from design system
│
├── Sync/
│   ├── SyncEngineImpl.swift          -- Implements SyncEngine protocol
│   ├── DeltaSyncCalculator.swift     -- Diff local vs remote state
│   ├── SyncQueue.swift               -- Persistent operation queue, survives crashes
│   ├── ConflictResolver.swift        -- Last-write-wins with user prompt fallback
│   ├── OfflineCacheManager.swift     -- Encrypted cache, TTL, remote revocation
│   └── BackgroundSyncTask.swift      -- BGTaskScheduler registration
│
├── Integrations/
│   ├── SharePointIntegration.swift   -- Implements ExternalIntegration for MSFT Graph
│   ├── GmailGroupIntegration.swift   -- Gmail address as workspace container
│   ├── OutlookIntegration.swift      -- Phase 2
│   └── IDPIntegration/
│       ├── EntraIDAdapter.swift
│       ├── OktaAdapter.swift
│       ├── PingAdapter.swift
│       └── GoogleWorkspaceAdapter.swift
│
├── Storage/
│   ├── SecureFileStore.swift         -- Encrypted file storage, never OS filesystem
│   ├── MetadataStore.swift           -- CoreData stack for file metadata, policy bindings
│   ├── KeychainManager.swift         -- Session tokens, OAuth credentials
│   └── EncryptedCache.swift          -- Offline cache layer
│
└── Utilities/
    ├── Logger.swift                  -- Unified logging, policy-governed export
    ├── Telemetry.swift               -- Event tracking, privacy-aware
    ├── NetworkMonitor.swift          -- Connectivity state, sync trigger
    └── ResourceMonitor.swift         -- Battery, thermal, memory — feeds AI throttle
```

### Module Dependency Rules

The dependency graph is a strict DAG. Violations cause compiler errors enforced through Swift package boundaries:

```
UI -> ViewModels -> Services -> Interfaces
                              <- Providers (implement Interfaces)
                              <- AI (implements AIProvider)
                              <- Security (implements security behaviors)
                              <- Policies (implements PolicyEngine)
Providers -> XQ API Gateway -> XQ versioned adapters -> Network
Storage -> Security (for encryption)
Sync -> Storage, Interfaces
Localization -> (no upstream dependencies)
Animations -> DesignSystem (tokens only)
```

No module in the upper layers imports from a sibling's internal implementation. Only interfaces cross layer boundaries.

---

## 4. INTERFACE CONTRACTS

### 4.1 RepositoryProvider

```swift
// Interfaces/RepositoryProvider.swift

public protocol RepositoryProvider: Sendable {
    var providerID: String { get }
    var displayName: String { get }
    var capabilities: RepositoryCapabilities { get }

    func authenticate() async throws -> AuthSession
    func listFiles(at path: RepositoryPath) async throws -> [FileMetadata]
    func downloadFile(id: String) async throws -> SecureFileStream
    func uploadFile(_ file: SecureFile, to path: RepositoryPath) async throws -> FileMetadata
    func deleteFile(id: String) async throws
    func createSharedLink(for fileID: String, policy: SharePolicy) async throws -> SecureLink
    func revokeSharedLink(_ linkID: String) async throws
    func getVersionHistory(fileID: String) async throws -> [FileVersion]
}

public struct RepositoryCapabilities: OptionSet {
    public let rawValue: Int
    public static let versionHistory    = RepositoryCapabilities(rawValue: 1 << 0)
    public static let sharedLinks       = RepositoryCapabilities(rawValue: 1 << 1)
    public static let offlineSync       = RepositoryCapabilities(rawValue: 1 << 2)
    public static let groupPermissions  = RepositoryCapabilities(rawValue: 1 << 3)
    public static let lightEditing      = RepositoryCapabilities(rawValue: 1 << 4)
}
```

### 4.2 XQSecureAPI (Multi-Version)

```swift
// Interfaces/XQSecureAPI.swift

public protocol XQSecureAPI: Sendable {
    var apiVersion: XQAPIVersion { get }
    var supportedCapabilities: Set<XQCapability> { get }

    func encrypt(data: Data, policy: XQPolicy) async throws -> XQEncryptedPayload
    func decrypt(_ payload: XQEncryptedPayload, identity: XQIdentity) async throws -> Data
    func applyPolicy(_ policy: XQPolicy, to payloadID: String) async throws
    func revokeAccess(payloadID: String, recipientID: String?) async throws
    func validateAccess(payloadID: String, identity: XQIdentity) async throws -> AccessDecision
    func createWorkspace(groupEmail: String, members: [XQIdentity]) async throws -> XQWorkspace
    func updateWorkspaceMembership(_ workspaceID: String, members: [XQIdentity]) async throws
    func auditLog(event: XQAuditEvent) async throws
}

public enum XQAPIVersion: String, Comparable {
    case v1, v2, v3
    public static func < (lhs: XQAPIVersion, rhs: XQAPIVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum XQCapability: String {
    case workspaces, groupSharing, dynamicPolicy, geofencing, mfaEscalation
}
```

### 4.3 AIProvider

```swift
// Interfaces/AIProvider.swift

public protocol AIProvider: Sendable {
    var providerID: String { get }
    var executionMode: AIExecutionMode { get }   // .local, .cloud, .hybrid
    var capabilities: Set<AICapability> { get }

    func classify(document: Data, mimeType: String) async throws -> ClassificationResult
    func evaluateRisk(context: RiskContext) async throws -> RiskScore
    func generateSummary(text: String, maxTokens: Int) async throws -> String
    func detectSensitiveData(in text: String) async throws -> [SensitiveDataFinding]
    func evaluateShareRisk(file: FileMetadata, recipient: Recipient) async throws -> ShareRiskAssessment
}

public enum AIExecutionMode { case local, cloud, hybrid }
public enum AICapability: String {
    case classification, riskScoring, summarization, piiDetection
    case phiDetection, cuiDetection, ocrAnalysis
}

public struct RiskContext {
    public let fileMetadata: FileMetadata
    public let userIdentity: UserIdentity
    public let devicePosture: DevicePosture
    public let location: LocationContext?
    public let sessionBehavior: SessionBehavior
    public let proposedAction: UserAction
}
```

### 4.4 PolicyEngine

```swift
// Interfaces/PolicyEngine.swift

public protocol PolicyEngine: Sendable {
    /// Evaluate the current risk context and return a policy decision.
    func evaluate(context: PolicyEvaluationContext) async -> PolicyDecision

    /// Subscribe to continuous policy re-evaluation as context changes.
    func subscribe(to context: PolicyEvaluationContext) -> AsyncStream<PolicyDecision>

    /// Apply an administrator override to a specific resource.
    func applyOverride(_ override: PolicyOverride, authority: AdminAuthority) async throws

    /// Fetch the active rule set for a given tenant.
    func activeRuleSet(for tenantID: String) async throws -> PolicyRuleSet
}

public struct PolicyDecision {
    public let riskScore: Float          // 0.0 (safe) to 1.0 (critical)
    public let classification: DataClassification
    public let allowedActions: Set<UserAction>
    public let restrictions: Set<RuntimeRestriction>
    public let requiredAuthentication: AuthenticationRequirement
    public let watermarkRequired: Bool
    public let auditRequired: Bool
    public let explanation: String       // Human-readable rationale
}

public enum RuntimeRestriction {
    case disableDownload
    case disableSharing
    case disableCopy
    case enforceViewOnly
    case requireMFAEvery(minutes: Int)
    case enableHeavyWatermark
    case disableOfflineAccess
    case geofenceEnforced(regions: [GeofenceRegion])
}
```

### 4.5 ExternalIntegration

```swift
// Interfaces/ExternalIntegration.swift

public protocol ExternalIntegration: Sendable {
    var integrationID: String { get }
    var platform: IntegrationPlatform { get }

    func authenticate(credentials: IntegrationCredentials) async throws -> IntegrationSession
    func sync(scope: SyncScope) async throws -> SyncManifest
    func query(filter: IntegrationQuery) async throws -> [IntegrationRecord]
    func upload(_ file: SecureFile, metadata: IntegrationMetadata) async throws -> IntegrationRecord
    func refreshSession() async throws -> IntegrationSession
    func disconnect() async throws
}

public enum IntegrationPlatform {
    case sharePoint, gmail, googleDrive, oneDrive
    case smb, box, dropbox, awsS3
    case entraID, okta, ping, googleWorkspace
}
```

### 4.6 AnimationEngine

```swift
// Interfaces/AnimationEngine.swift

public protocol AnimationEngine: Sendable {
    var isReducedMotionEnabled: Bool { get }

    func entryAnimation(for element: UIElementType) -> AnyTransition
    func exitAnimation(for element: UIElementType) -> AnyTransition
    func interactionAnimation(for action: InteractionType) -> Animation
    func navigationTransition(style: NavigationStyle) -> AnyTransition
}

public enum UIElementType {
    case screen, card, modal, sheet, badge, notification, fileRow
}

public enum InteractionType {
    case tap, longPress, swipe, drag, toggle
}
```

---

## 5. DATA FLOW DIAGRAM

### Standard Read Path (File Browser)

```
FileBrowserView (SwiftUI)
    |
    | @EnvironmentObject / .task
    v
FileBrowserViewModel (@Observable)
    |
    | calls func loadFiles()
    v
FileService (Application Service)
    |
    | depends on RepositoryProvider (interface only)
    v
[PolicyEngine.evaluate(context)] ---> PolicyDecision
    |                                       |
    | if allowed                            | if restricted
    v                                       v
RepositoryProvider.listFiles()         Return empty + restriction message
    |
    | (SharePointProvider concrete impl)
    v
XQAPIGateway
    |
    | selects versioned adapter via capability negotiation
    v
XQAPIv2Adapter
    |
    | URLSession (pinned)
    v
SharePoint Graph API / XQ API
    |
    v
SecureFileStream -> SecureFileStore (encrypted) -> FileMetadata
    |
    v
FileService returns [SecureFile]
    |
    v
FileBrowserViewModel publishes files to @Published array
    |
    v
FileBrowserView re-renders with animation (AnimationEngine.entryAnimation)
```

### AI Classification Path (Post-Import)

```
File imported
    |
FileService.importFile()
    |
SecureFileStore.encrypt() -- Secure Enclave key
    |
AIOrchestrator.classify() -- routes based on policy + connectivity
    |
    |-- [offline / CUI data] --> CoreMLProvider.classify()
    |-- [online + summarization] --> OpenAIProvider.classify()
    |
ClassificationResult -> PolicyEngine.evaluate()
    |
PolicyDecision -> FileMetadata updated (label, restrictions)
    |
SyncEngine.enqueue(operation: .updateMetadata)
    |
ViewModel publishes update -> View badge animates in
```

---

## 6. XQ API VERSION ADAPTER PATTERN

The core challenge: the spec requires supporting v1/v2/v3 simultaneously. Different enterprise tenants may be pinned to different API versions. The solution is a capability-negotiated adapter factory.

### Capability Negotiation Flow

```
App startup or tenant change
    |
XQAPIGateway.negotiate(tenantID: String)
    |
GET /api/capabilities -> { "version": "v2", "features": ["workspaces", "dynamicPolicy"] }
    |
CapabilityRegistry.register(tenantID, capabilities)
    |
AdapterFactory.create(for: capabilities) -> XQAPIv2Adapter
    |
ServiceLocator.register(XQSecureAPI.self, instance: adapter)
```

### Adapter Implementation Pattern

```swift
// Providers/XQAPIGateway.swift

final class XQAPIGateway {
    private var adapterCache: [String: XQSecureAPI] = [:]

    func adapter(for tenantID: String) async throws -> XQSecureAPI {
        if let cached = adapterCache[tenantID] { return cached }
        let capabilities = try await negotiateCapabilities(tenantID: tenantID)
        let adapter = AdapterFactory.make(capabilities: capabilities)
        adapterCache[tenantID] = adapter
        return adapter
    }

    private func negotiateCapabilities(tenantID: String) async throws -> XQCapabilitySet {
        // Probe endpoint, parse version header, fall back to v1 on failure
        let response = try await URLSession.pinned.data(from: capabilityURL(tenantID))
        return XQCapabilitySet(from: response)
    }
}

// Each adapter wraps version-specific HTTP calls and normalizes them
// to the XQSecureAPI protocol surface.

final class XQAPIv1Adapter: XQSecureAPI {
    let apiVersion: XQAPIVersion = .v1
    var supportedCapabilities: Set<XQCapability> { [.groupSharing] }

    func createWorkspace(groupEmail: String, members: [XQIdentity]) async throws -> XQWorkspace {
        // v1 has no native workspace concept — emulate via group key distribution
        throw XQError.capabilityUnavailable(.workspaces, minimumVersion: .v2)
    }
    // ... other methods map to v1 endpoint shapes
}

final class XQAPIv2Adapter: XQSecureAPI {
    let apiVersion: XQAPIVersion = .v2
    var supportedCapabilities: Set<XQCapability> { [.workspaces, .groupSharing, .dynamicPolicy] }
    // ... full implementation
}

final class XQAPIv3Adapter: XQSecureAPI {
    let apiVersion: XQAPIVersion = .v3
    var supportedCapabilities: Set<XQCapability> { XQCapability.allCases }
    // ... full implementation with geofencing, MFA escalation
}
```

### Feature Flag Mapping

The `FeatureFlags` module sits above the gateway and gates UI features based on the negotiated capability set. If the tenant's adapter does not advertise `.workspaces`, the Gmail workspace invitation flow is hidden at the ViewModel layer — not guarded by a runtime `if` buried inside a view.

---

## 7. FUZZY LOGIC POLICY ENGINE DESIGN

### Why Fuzzy Logic, Not Rules

Binary allow/deny breaks down in mobile security because context is continuous, not discrete. A user sharing a Confidential document from a trusted device on a corporate network is a different risk than the same user on an unknown network, traveling internationally, after business hours. The spec explicitly requires this adaptive model.

Fuzzy logic maps continuous inputs to a normalized risk score, then applies a rule surface to produce graduated output controls.

### Input Sources

| Input | Source | Range |
|---|---|---|
| Content sensitivity | ClassificationResult.confidenceScore | 0.0 – 1.0 |
| User identity trust | IDPAdapter.trustLevel | 0.0 – 1.0 |
| Device posture | DevicePostureEvaluator.score | 0.0 – 1.0 |
| Location context | CoreLocation + geofence policy | In/Out/Unknown |
| Time-of-day | System clock vs policy window | In/Out of window |
| Session behavior | SessionBehavior.anomalyScore | 0.0 – 1.0 |
| Recipient trust | RecipientResolver.trustLevel | Internal/External/Unknown |
| Network posture | NetworkMonitor.trustScore | 0.0 – 1.0 |

### Risk Scoring Architecture

```swift
// Policies/RiskScorer.swift

struct RiskScorer {
    let weights: RiskWeightProfile  // Tenant-configurable weight profile

    func score(context: PolicyEvaluationContext) -> Float {
        let inputs: [WeightedInput] = [
            .init(value: context.contentSensitivity,  weight: weights.contentSensitivity),
            .init(value: context.devicePosture.inverted, weight: weights.devicePosture),
            .init(value: context.identityTrust.inverted, weight: weights.identityTrust),
            .init(value: context.locationRisk,         weight: weights.location),
            .init(value: context.sessionAnomaly,       weight: weights.sessionAnomaly),
            .init(value: context.recipientRisk,        weight: weights.recipient),
            .init(value: context.networkRisk,          weight: weights.network),
            .init(value: context.timeWindowRisk,       weight: weights.timeWindow),
        ]
        // Weighted sum, normalized to [0, 1]
        let rawScore = inputs.reduce(0) { $0 + ($1.value * $1.weight) }
        return min(1.0, max(0.0, rawScore / weights.totalWeight))
    }
}
```

### Fuzzy Rule Surface

The rule surface translates a normalized risk score into a `PolicyDecision`. Ranges are tenant-configurable.

```
Score 0.0 – 0.25: GREEN
  -> AllowedActions: all
  -> Restrictions: none
  -> Watermark: off

Score 0.26 – 0.50: YELLOW
  -> AllowedActions: view, edit, shareInternal
  -> Restrictions: disableExternalDownload
  -> Watermark: subtle

Score 0.51 – 0.75: ORANGE
  -> AllowedActions: view, shareInternal (policy-gated)
  -> Restrictions: disableDownload, requireMFAEvery(30 minutes)
  -> Watermark: visible

Score 0.76 – 0.90: RED
  -> AllowedActions: view only
  -> Restrictions: disableSharing, requireMFAEvery(5 minutes), enableHeavyWatermark
  -> Additional: notify admin

Score 0.91 – 1.0: CRITICAL
  -> AllowedActions: none
  -> Restrictions: disableViewerIfOffline, triggerAlert
  -> Require re-authentication
```

### Connection to XQ Enforcement Layer

The `PolicyDecision` is not advisory — it drives concrete runtime controls:

```swift
// Policies/PolicyObserver.swift

final class PolicyObserver {
    private let engine: PolicyEngine
    private let xqAPI: XQSecureAPI

    func startMonitoring(context: PolicyEvaluationContext) {
        Task {
            for await decision in engine.subscribe(to: context) {
                await applyDecision(decision)
            }
        }
    }

    private func applyDecision(_ decision: PolicyDecision) async {
        // 1. Update XQ payload policy in real-time if classification changed
        if decision.classification != currentClassification {
            try? await xqAPI.applyPolicy(decision.toXQPolicy(), to: currentPayloadID)
        }
        // 2. Push runtime restrictions to the view layer via published state
        await MainActor.run {
            viewerState.restrictions = decision.restrictions
            viewerState.watermarkLevel = decision.watermarkRequired ? .heavy : .none
        }
        // 3. Trigger audit log
        if decision.auditRequired {
            try? await xqAPI.auditLog(event: .policyDecision(decision))
        }
    }
}
```

---

## 8. AI ABSTRACTION LAYER

### Routing Logic

The `AIOrchestrator` is not a simple round-robin. It consults three inputs to select a provider: the data's classification, the current policy (some classifications forbid cloud AI), and device resource state.

```swift
// AI/AIOrchestrator.swift

final class AIOrchestrator: AIProvider {
    private let providers: [AIProvider]
    private let policyEngine: PolicyEngine
    private let resourceMonitor: ResourceMonitor

    var providerID: String { "orchestrator" }
    var executionMode: AIExecutionMode { .hybrid }
    var capabilities: Set<AICapability> { providers.flatMap(\.capabilities).asSet() }

    func classify(document: Data, mimeType: String) async throws -> ClassificationResult {
        let selected = try selectProvider(for: .classification, dataClass: .unknown)
        return try await selected.classify(document: document, mimeType: mimeType)
    }

    private func selectProvider(for capability: AICapability, dataClass: DataClassification) throws -> AIProvider {
        // Rule 1: CUI, Restricted, or above -> local only, never cloud
        if dataClass >= .restricted {
            return try localProvider(capability: capability)
        }
        // Rule 2: Battery < 20% or thermal pressure high -> local only
        if resourceMonitor.batteryLevel < 0.20 || resourceMonitor.thermalState == .critical {
            return try localProvider(capability: capability)
        }
        // Rule 3: No connectivity -> local only
        if !networkMonitor.isConnected {
            return try localProvider(capability: capability)
        }
        // Rule 4: Tenant policy mandates local
        if tenantPolicy.requiresLocalAI {
            return try localProvider(capability: capability)
        }
        // Rule 5: Select best cloud provider for capability
        return try cloudProvider(capability: capability)
    }

    private func localProvider(capability: AICapability) throws -> AIProvider {
        guard let provider = providers.first(where: {
            $0.executionMode == .local && $0.capabilities.contains(capability)
        }) else {
            throw AIError.capabilityUnavailableOffline(capability)
        }
        return provider
    }
}
```

### Model Switching Per Tenant/Policy/Classification

The model selection is configured via the remote feature flag system. A `ModelRoutingTable` (downloaded at tenant provisioning) maps the combination of `(tenantID, classification, capability)` to a provider ID. This means an enterprise can configure: "For PHI detection, always use our self-hosted ONNX model. For summarization of Internal documents, use OpenAI."

### Offline Fallback

All critical capabilities — classification, risk scoring, PII detection — must have a CoreML fallback. The `CoreMLProvider` is always registered as the lowest-priority fallback in the `AIOrchestrator`'s provider list. If every cloud provider fails or is ineligible, CoreML handles the request. The local models are bundled in the app binary for Phase 1 and can be updated OTA in Phase 2 via the remote configuration system.

---

## 9. ANIMATION SYSTEM ARCHITECTURE

### Design Principle

The spec requirement that every UX element must animate creates a temptation to scatter animation code across views. This is the wrong approach — it produces inconsistency, makes accessibility overrides difficult to implement globally, and degrades performance when the same complex transition is re-implemented differently across screens.

The solution is a centralized `AnimationEngine` that all views query. Views never construct `Animation` or `AnyTransition` values directly.

### AnimationEngine Implementation

```swift
// Animations/AnimationEngine.swift

final class AnimationEngine: AnimationEngine {
    private let tokens: AnimationTokens

    var isReducedMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    func entryAnimation(for element: UIElementType) -> AnyTransition {
        guard !isReducedMotionEnabled else {
            return .opacity  // Accessibility: fade only, no motion
        }
        switch element {
        case .screen:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .scale(scale: 0.95))
            )
        case .card:
            return .opacity.combined(with: .offset(y: 16))
        case .modal:
            return .move(edge: .bottom).combined(with: .opacity)
        case .badge:
            return .scale(scale: 0.7).combined(with: .opacity)
        case .notification:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.9))
            )
        case .fileRow:
            return .opacity.combined(with: .offset(x: -8))
        default:
            return .opacity
        }
    }

    func interactionAnimation(for action: InteractionType) -> Animation {
        guard !isReducedMotionEnabled else {
            return .easeOut(duration: tokens.microDuration)
        }
        switch action {
        case .tap:
            return .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
        case .longPress:
            return .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.1)
        case .swipe:
            return .interactiveSpring(response: 0.4, dampingFraction: 0.8)
        case .drag:
            return .interactiveSpring(response: 0.3, dampingFraction: 0.7)
        case .toggle:
            return .spring(response: 0.25, dampingFraction: 0.8)
        }
    }
}
```

### Usage Pattern in Views

```swift
// Correct usage: views query engine, never construct animations directly
struct FileRowView: View {
    @Environment(AnimationEngine.self) var animations

    var body: some View {
        HStack { ... }
            .transition(animations.entryAnimation(for: .fileRow))
            .onTapGesture {
                withAnimation(animations.interactionAnimation(for: .tap)) {
                    isSelected.toggle()
                }
            }
    }
}
```

### Performance Guarantees

60 FPS is maintained through three rules enforced in code review:

1. No synchronous work on the main thread during animations. AI classification, encryption, and network calls happen on background tasks; only the resulting state change hits the main actor.

2. `AnimatedEntryModifier` staggers list row animations by index offset (12ms per row, max 8 rows animated simultaneously). This prevents 50 concurrent animations on the file browser screen.

3. The `ResourceMonitor` can signal `animationComplexityLevel: .reduced` on older devices (A14 and below), which the `AnimationEngine` uses to serve simpler fallback transitions.

---

## 10. LOCALIZATION SYSTEM

### JSON File Structure

The spec mandates `/en/messages.json` path convention. The complete structure:

```
App/Localization/
├── en/messages.json
├── fr/messages.json
├── de/messages.json
├── jp/messages.json
└── ar/messages.json   -- RTL; triggers layout direction flag
```

```json
// en/messages.json
{
  "app.name": "XQ Secure Workspaces",
  "home.title": "Workspace",
  "home.recent_files": "Recent Files",
  "home.suggested": "Suggested",
  "home.offline": "Available Offline",
  "files.import": "Import File",
  "files.share": "Share Securely",
  "files.classification.public": "Public",
  "files.classification.internal": "Internal",
  "files.classification.confidential": "Confidential",
  "files.classification.restricted": "Restricted",
  "risk.warning.external_share": "This file contains sensitive content. Sharing externally will apply additional restrictions.",
  "risk.warning.unclassified": "This document has not been classified. AI will analyze it now.",
  "policy.action.view_only": "View Only Access",
  "policy.action.mfa_required": "Additional verification required",
  "error.offline.ai_unavailable": "AI analysis is unavailable offline. Classification will resume when connected.",
  "onboarding.welcome.headline": "Your secure workspace",
  "onboarding.welcome.subheadline": "Files stay protected automatically."
}
```

### Runtime Language Switching Without Restart

```swift
// Localization/LocalizationService.swift

@Observable
final class LocalizationService: LocalizationEngine {
    private(set) var currentLanguage: String = "en"
    private var pack: LanguagePack = LanguagePack.bundled(language: "en")

    func string(forKey key: String) -> String {
        pack.lookup(key) ?? key  // Key as fallback: visible in UI, aids debugging
    }

    func switchLanguage(to languageCode: String) async throws {
        let newPack = try await loadPack(language: languageCode)
        await MainActor.run {
            self.pack = newPack
            self.currentLanguage = languageCode
            // @Observable propagates change; all String(localized:) calls in views re-evaluate
        }
    }

    private func loadPack(language: String) async throws -> LanguagePack {
        // Check OTA cache first, fall back to bundle
        if let cached = OTALanguageUpdater.cachedPack(language: language) {
            return cached
        }
        return LanguagePack.bundled(language: language)
    }
}
```

### OTA Translation Updates

The `OTALanguageUpdater` checks a remote endpoint on app foreground. If a newer pack version is available for the current language, it downloads it to the encrypted cache and notifies `LocalizationService`. The switch is applied immediately without restart. Packs are signed and verified before application to prevent content injection.

### Adaptive UI for Text Length Variation

German and French strings are typically 30-40% longer than English. Buttons and labels must accommodate this. The design system enforces:

- All buttons use `minimumScaleFactor(0.7)` and `lineLimit(2)`
- No fixed-width containers for text labels
- Icon-only fallbacks for critical action buttons in constrained layouts
- A `LocalizationTestingView` (debug builds only) renders every key in every language simultaneously to catch layout breaks during development

---

## 11. OFFLINE-FIRST SYNC ENGINE

### Delta Sync Strategy

The sync engine maintains a local manifest (stored in CoreData) containing `(fileID, contentHash, policyVersion, lastModified)` for every file in the secure vault. On reconnection, it compares the local manifest against the remote manifest and produces a minimal delta operation set.

```swift
// Sync/DeltaSyncCalculator.swift

struct DeltaSyncCalculator {
    func compute(local: SyncManifest, remote: SyncManifest) -> [SyncOperation] {
        var operations: [SyncOperation] = []

        // Files in remote but not local, or with newer remote version
        for remoteEntry in remote.entries {
            if let localEntry = local.entry(for: remoteEntry.fileID) {
                if remoteEntry.contentHash != localEntry.contentHash {
                    operations.append(.download(remoteEntry))
                } else if remoteEntry.policyVersion > localEntry.policyVersion {
                    operations.append(.updatePolicyMetadata(remoteEntry))
                }
            } else {
                operations.append(.download(remoteEntry))
            }
        }

        // Files modified locally while offline
        for localEntry in local.entries where localEntry.isDirty {
            operations.append(.upload(localEntry))
        }

        // Files deleted remotely
        let remoteIDs = Set(remote.entries.map(\.fileID))
        for localEntry in local.entries where !remoteIDs.contains(localEntry.fileID) {
            if localEntry.isOfflineDesignated {
                operations.append(.markUnavailable(localEntry))  // Don't delete, warn user
            } else {
                operations.append(.deleteLocal(localEntry))
            }
        }

        return operations
    }
}
```

### Conflict Resolution

The strategy is last-write-wins at the content level, with user prompt for significant divergence:

1. If local modification time is within 60 seconds of remote: merge silently (last-write-wins by timestamp)
2. If local and remote have both been modified and timestamps diverge by more than 60 seconds: surface a conflict resolution prompt showing both versions
3. Policy metadata conflicts always defer to the server — local policy overrides are never permitted to persist

### Policy-Aware Sync

Enterprise tenants can disable offline mode via policy. The sync engine checks this before caching:

```swift
// Sync/SyncEngineImpl.swift

func cacheForOffline(fileID: String) async throws {
    let decision = await policyEngine.evaluate(context: .offlineCacheRequest(fileID: fileID))
    guard decision.allowedActions.contains(.offlineAccess) else {
        throw SyncError.offlineDisabledByPolicy(decision.explanation)
    }
    // Proceed with encrypted cache write
}
```

### Encrypted Cache Management

All offline cache files are encrypted under a key derived from the user's Secure Enclave key. The key is never written to disk. Cache entries carry TTL metadata (default: 24h for consumer, configurable for enterprise). The `OfflineCacheManager` runs a purge pass on each app launch to remove expired entries. Remote revocation is handled by invalidating the XQ policy on the payload — even if the cached file bytes remain, the decrypt step will fail the next time access is attempted.

---

## 12. TECHNICAL RISKS

### Risk 1: KMP/Swift Interop Stability

**Probability**: Medium. **Impact**: High.

KMP's Swift interop has improved significantly but remains less mature than pure Swift or pure Kotlin. Generics, async/await bridging, and Swift protocols with associated types each introduce friction.

**Mitigation**: Scope the KMP boundary conservatively in Phase 1. Start with pure data model sharing (no async, no protocols with associated types). Introduce KMP shared business logic in Phase 2 after the team has proven the interop layer. Maintain a Swift-native fallback implementation behind each KMP interface for the first three months.

### Risk 2: CoreML Model Accuracy for On-Device Classification

**Probability**: High. **Impact**: High.

Small on-device models will produce false positives and false negatives. An over-eager classifier that marks common business documents as Restricted will destroy user trust within days of launch.

**Mitigation**: Launch Phase 1 with a conservative model tuned for precision over recall — fewer false positives, more false negatives. Provide a clear override path (one tap in the classification panel). Instrument every classification decision with outcome tracking. Use the cloud AI provider during Phase 1 for users who opt in, collecting labeled data to retrain the local model before Phase 2.

### Risk 3: iOS Secure Enclave Key Lifecycle

**Probability**: Low. **Impact**: Critical.

If a device is wiped, the Secure Enclave key is destroyed. Files encrypted under that key become permanently inaccessible. For enterprise users, this is a data loss event.

**Mitigation**: Implement key escrow as a mandatory enterprise feature. Enterprise deployments require a key recovery mechanism (XQ-managed or customer-managed). Consumer tier: warn users explicitly during onboarding that local-only mode means no recovery path. Store a key backup mechanism behind an enterprise policy flag only.

### Risk 4: Fuzzy Policy Engine Performance Under Continuous Re-Evaluation

**Probability**: Medium. **Impact**: Medium.

The spec requires continuous policy re-evaluation as context changes. If the engine runs on every sensor update (location, network change, session tick), it will drain battery and cause thermal throttling.

**Mitigation**: Debounce context changes. Location updates trigger re-evaluation only when the user crosses a geofence boundary, not on every coordinate update. Session behavior scores are computed on a 30-second rolling window. The `PolicyObserver` uses a `deduplicate()` operator on the context stream to suppress re-evaluation when inputs have not materially changed (less than 0.05 delta on any score component).

### Risk 5: Kotlin Multiplatform Build Complexity Blocking iOS Development Velocity

**Probability**: High. **Impact**: Medium.

KMP adds build toolchain complexity. A broken Gradle build blocks the iOS developer. In early phases, this friction discourages adoption of the shared layer and leads to divergent implementations.

**Mitigation**: In Phase 1, maintain the KMP module as a separately versioned XCFramework with a stable release cadence (weekly). iOS developers consume it as a binary dependency, not a source dependency. The KMP team owns the build; iOS developers are never required to run Gradle locally. This changes in Phase 3 when KMP maturity warrants tighter integration.

---

## 13. IMPLEMENTATION ROADMAP

### Phase 1 Build Order (Recommended Sequence)

The critical path is the interface contract layer. Nothing else can be properly built or tested until protocols are established.

**Weeks 1-2: Foundation**
- Define and review all protocol interfaces (RepositoryProvider, XQSecureAPI, AIProvider, PolicyEngine, ExternalIntegration, AnimationEngine, LocalizationEngine, SyncEngine)
- Establish the `AppDependencies` composition root
- Stand up mock implementations of every interface for use throughout development
- Set up KMP module with shared domain models: SecureFile, ClassificationLabel, PolicyDecision, RiskScore, SyncOperation
- Establish localization JSON structure; write English pack; wire `LocalizationService`

**Weeks 3-4: Security Core**
- `SecureEnclaveManager`: key generation, encryption, decryption
- `JailbreakDetector`: integrity checks on launch
- `DevicePostureEvaluator`: initial scoring
- `SessionManager`: biometric unlock, timeout, background blur
- `SecureFileStore`: encrypted file storage, never exposing to iOS filesystem
- `CertificatePinner`: URLSession delegate setup

**Weeks 5-6: XQ API Integration**
- `XQAPIGateway` + capability negotiation
- `XQAPIv2Adapter` (primary version)
- `XQAPIv1Adapter` as fallback
- End-to-end encrypt/decrypt/applyPolicy against the staging XQ API (https://xq.stoplight.io)
- `KeychainManager`: store XQ session tokens

**Weeks 7-8: Repository Connectivity**
- `SharePointProvider`: Microsoft Graph OAuth flow, list files, download stream
- `LocalVaultProvider`: local import from Files app and camera roll
- `FileService`: orchestrate import → encrypt → store → classify pipeline
- `SMBProvider` skeleton (full implementation can follow)

**Weeks 9-10: AI and Policy**
- `CoreMLProvider`: bundle initial classification model, wire inference
- `RiskScorer`: implement weighted scoring with default weight profile
- `FuzzyPolicyEngine`: implement rule surface, wire to RiskScorer
- `PolicyObserver`: continuous re-evaluation loop with debouncing
- `AIOrchestrator`: routing logic, local fallback enforcement

**Weeks 11-12: Sync Engine**
- `SyncQueue`: persistent operation queue (CoreData-backed, crash-safe)
- `DeltaSyncCalculator`: manifest comparison
- `ConflictResolver`: last-write-wins + user prompt logic
- `OfflineCacheManager`: TTL, remote revocation, encrypted storage
- `BackgroundSyncTask`: BGTaskScheduler registration

**Weeks 13-14: UI Layer**
- `AnimationEngine`: all animation presets, reduced motion support
- Splash / initialization screen
- Onboarding flow (local-first vs. enterprise branch)
- Home screen (recent files, offline files, risk notifications)
- File browser (repository switcher, classification badges, search)
- Secure file viewer (protected renderer, watermark overlay, screenshot guard)

**Weeks 15-16: Integration and Hardening**
- End-to-end test: import file → encrypt → classify → policy apply → share → revoke
- Performance profiling: 60 FPS animation verification, AI inference timing
- Security audit: key lifecycle, certificate pinning, jailbreak detection gaps
- Localization: French and German packs, adaptive layout QA on long strings
- `UpdateManager`: silent/soft/force update detection via remote config
- `FeatureFlags`: kill switch wire-up

**Phase 1 Exit Criteria**
- A file can be imported from SharePoint, encrypted under Secure Enclave, classified by CoreML, assigned a policy decision by the fuzzy engine, viewed in the secure viewer with watermark, and shared via XQ link — with the share revocable
- All UI text sourced from JSON packs; language can be switched at runtime
- Every UI transition uses `AnimationEngine`; reduced motion mode verified
- App passes launch on jailbroken device simulator with appropriate failure response
- Sync engine persists operations through app restart

---

## Key Architectural Decisions Summary

The four decisions with the highest long-term consequence:

1. **All business logic behind interfaces.** The spec mandates this explicitly. Do not compromise on it in Phase 1 to save time. Every shortcut here creates a migration cost when the XQ API releases v3, when a new AI provider is added, or when Android needs the same logic.

2. **KMP boundary at domain models + business logic only in Phase 1.** Resist the temptation to share UI state or navigation logic via KMP in Phase 1. The interop cost exceeds the benefit at small scale. The shared model types (SecureFile, PolicyDecision, etc.) already reduce Android re-implementation risk significantly.

3. **FuzzyPolicyEngine drives runtime controls directly.** The policy engine output is not a suggestion passed back to the ViewModel for optional application — it is enforced by the infrastructure layer before any data is returned to the view. ViewModels cannot override a PolicyDecision of `.viewOnly` by rendering a download button. This is a security architecture property, not a UX convention.

4. **AnimationEngine is centralized and mandatory.** Accessibility compliance requires a single switch point for reduced motion. Performance profiling requires a single location to tune timing. Design consistency requires that no developer invents a custom spring constant. The initial setup investment in `AnimationEngine` pays back within the first sprint of UI development.