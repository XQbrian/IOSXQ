I have read the complete specification. Now I'll produce the comprehensive Phase 1 AI architecture analysis.

---

# XQ Secure Workspaces iOS — Phase 1 AI Architecture Analysis

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces requires a privacy-first, on-device AI governance engine that operates continuously and silently, automating classification, policy enforcement, sensitive data detection, and sharing risk evaluation without user effort. The AI layer is not a feature — it is the primary enforcement mechanism of the entire platform.

Phase 1 scope delivers the Secure File Vault with full AI governance, meaning the AI architecture must be production-complete before the first public release. Every file import, every edit, every share decision passes through the AI governance engine.

The architecture is built on four non-negotiable constraints derived directly from the spec:

- Raw content never leaves the device unless enterprise policy explicitly permits it
- AI providers are interchangeable at runtime, per-tenant, per-policy, per-classification
- CoreML models must be available offline as the permanent fallback
- AI decisions are auditable, overridable, and confidence-threshold controlled

The recommended Phase 1 AI stack is: Apple NaturalLanguage framework and Apple Vision framework for zero-model-weight fast detection, purpose-built CoreML models under 50MB each for PII/PHI/CUI and document classification, ONNX Runtime as the cross-platform model execution layer, and a cloud AI routing gate that requires explicit enterprise policy authorization before any content leaves the device.

---

## 2. AI PROVIDER ABSTRACTION LAYER

### Core Protocol

The spec mandates "no direct API calls" and "interchangeable AI models." Every AI function routes through the `AIProvider` protocol. No ViewModel, Service, or Policy class references a concrete provider.

```swift
// App/Interfaces/AIProvider.swift

import Foundation
import Combine

// Classification result with confidence and label hierarchy
struct ClassificationResult {
    let primaryLabel: SensitivityLabel         // Public, Internal, Confidential, Restricted, Custom
    let secondaryLabels: [SensitivityLabel]    // Multi-label support
    let confidence: Float                       // 0.0 – 1.0
    let detectedEntities: [SensitiveEntity]    // PII, PHI, CUI tokens found
    let reasoning: String                       // Human-readable rationale for UI display
    let modelID: String                         // Which model produced this result (audit)
    let processingLocation: ProcessingLocation // .onDevice | .cloudPermitted
}

// Risk evaluation output — fuzzy, not binary
struct RiskEvaluation {
    let riskScore: Float                        // 0.0 – 1.0 continuous score
    let riskBand: RiskBand                      // .low | .medium | .high | .critical
    let signals: [RiskSignal]                   // Each contributing factor with weight
    let recommendedAction: PolicyAction         // Suggested enforcement action
    let blockingFactors: [String]               // Factors that alone would block the action
    let confidence: Float
    let modelID: String
}

// Onboarding assistant response
struct AssistantResponse {
    let message: String                         // Localized, non-technical language
    let suggestedActions: [OnboardingAction]   // Actionable steps for user
    let detectedConfiguration: RepositoryConfig? // Auto-detected SharePoint/SMB details
    let errorResolution: ErrorResolution?       // Structured fix for auth/config errors
}

// The provider contract — all AI functions defined here
protocol AIProvider {
    var providerID: String { get }
    var supportsOffline: Bool { get }
    var capabilities: Set<AICapability> { get }

    // Document classification — primary governance function
    func classify(
        document: DocumentContent,
        context: ClassificationContext
    ) async throws -> ClassificationResult

    // Sensitive data detection within extracted text
    func detectSensitiveData(
        text: String,
        targetFrameworks: Set<ComplianceFramework>  // .pii, .phi, .cui, .financial, .nist
    ) async throws -> [SensitiveEntity]

    // Risk evaluation for sharing decisions
    func evaluateRisk(
        context: RiskContext
    ) async throws -> RiskEvaluation

    // Policy recommendation — fuzzy logic output
    func recommendPolicy(
        classification: ClassificationResult,
        userContext: UserContext,
        deviceContext: DeviceContext
    ) async throws -> PolicyRecommendation

    // Onboarding assistant — conversational
    func processOnboardingQuery(
        query: String,
        sessionContext: OnboardingSessionContext
    ) async throws -> AssistantResponse

    // Summarization (cloud-permitted use cases only)
    func generateSummary(
        text: String,
        maxLength: Int
    ) async throws -> String
}

enum AICapability {
    case documentClassification
    case sensitiveDataDetection
    case riskEvaluation
    case policyRecommendation
    case onboardingAssistant
    case summarization
    case ocrAnalysis
}

enum ProcessingLocation {
    case onDevice
    case cloudPermitted(providerID: String)
}
```

### Provider Selection and Runtime Switching

The `AIProviderRouter` resolves the correct provider at runtime based on tenant configuration, policy, classification level, and device connectivity. Business logic calls only `AIProviderRouter` — never a concrete provider.

```swift
// App/AI/AIProviderRouter.swift

protocol AIProviderRouter {
    func provider(
        for capability: AICapability,
        classificationContext: ClassificationContext?,
        tenantConfig: TenantAIConfig
    ) -> AIProvider
}

// Selection priority order:
// 1. Tenant-specified provider for this capability + classification level
// 2. Policy-mandated local-only if CUI or higher sensitivity
// 3. Cloud provider if enterprise policy gate passes and connectivity exists
// 4. CoreML fallback always available
```

### Per-Tenant Configuration Model

```swift
struct TenantAIConfig: Codable {
    let tenantID: String

    // Per-capability provider assignment
    let providerMap: [AICapability: AIProviderConfig]

    // Per-classification-level override
    // e.g., force local-only for Restricted and above
    let classificationOverrides: [SensitivityLabel: AIProviderConfig]

    // Global cloud permission gate
    let cloudAIPermitted: Bool
    let cloudAIRequiresApproval: Bool          // Per-share approval vs. policy-wide

    // Confidence thresholds — admin configurable (spec section 8, screen 3.16)
    let minimumClassificationConfidence: Float  // Default 0.70
    let riskEscalationThreshold: Float          // Default 0.75
    let humanReviewThreshold: Float             // Below this → flag for override

    // Model versioning
    let pinnedModelVersions: [String: String]   // capability → model version
    let allowAutoModelUpdate: Bool
}

struct AIProviderConfig: Codable {
    let providerType: AIProviderType            // .coreML, .onnx, .openAI, .anthropic, .bedrock, .azureOpenAI, .enterprise
    let modelIdentifier: String
    let fallbackProviderType: AIProviderType    // Always .coreML
    let timeoutMs: Int                          // Default 200ms on-device, 3000ms cloud
}

enum AIProviderType: String, Codable {
    case coreML
    case onnx
    case openAI
    case anthropic
    case awsBedrock
    case azureOpenAI
    case enterprise                              // Custom enterprise endpoint
}
```

### Concrete Provider Implementations

- `CoreMLAIProvider` — on-device, always available offline, zero network dependency
- `ONNXAIProvider` — on-device, ONNX Runtime, cross-platform model format
- `OpenAIProvider` — cloud, cloud gate required, used for summarization or advanced reasoning
- `AnthropicProvider` — cloud, cloud gate required, structured output for policy recommendation
- `AWSBedrockProvider` — cloud, enterprise SaaS deployments in AWS environments
- `AzureOpenAIProvider` — cloud, Microsoft ecosystem tenants
- `EnterpriseModelProvider` — custom endpoint, air-gapped or self-hosted deployments

All implementations conform to `AIProvider`. The router selects at runtime. No other layer knows which is active.

---

## 3. LOCAL AI STRATEGY

### Architectural Principle

The spec states: "AI models run locally by default. No raw content leaves the device unless explicitly permitted by enterprise policy." This means on-device AI must be complete and production-quality, not a degraded fallback. Cloud AI is the optional extension, not the primary path.

### iOS Native Framework Baseline (Zero Model Weight)

Before invoking any ML model, the classification pipeline uses Apple's built-in frameworks at no model size cost:

**Apple NaturalLanguage Framework (`NaturalLanguage`)**
- `NLTagger` with `.nameType` scheme detects person names, organizations, place names — immediate PII signal
- `NLLanguageRecognizer` identifies document language for multi-language classification routing
- `NLTokenizer` segments text for pattern matching
- Runs synchronously, sub-5ms on any supported device
- No model file required — framework built into iOS

**Apple Vision Framework (`Vision`)**
- `VNRecognizeTextRequest` performs OCR for scanned documents and camera capture (Phase 1 text extraction, OCR camera pipeline in Phase 1 spec section 3.11)
- `VNDetectDocumentSegmentationRequest` for camera-based document boundary detection
- `VNClassifyImageRequest` for image content classification
- Runs on Neural Engine, battery-efficient, no model file required

**Regex Pattern Library (no model required)**
- SSN: `\b\d{3}-\d{2}-\d{4}\b`
- Credit card: Luhn-validated patterns
- EIN, routing numbers, IBAN
- HIPAA identifiers (18 PHI categories as enumerated in HIPAA Safe Harbor)
- NPI numbers, DEA numbers (PHI/healthcare)
- CUI markings: NIST SP 800-171 category headers

This three-layer baseline (NaturalLanguage + Vision + regex) provides meaningful detection with zero model footprint and runs before any CoreML model is invoked.

### CoreML Model Strategy

Three purpose-built CoreML models cover Phase 1 requirements. Each is managed as a separately downloadable asset to minimize initial app size.

**Model 1: SensitiveEntityClassifier.mlmodel**
- Purpose: PII, PHI, CUI, financial record token classification
- Architecture: Fine-tuned Named Entity Recognition (NER) — DistilBERT or MobileBERT variant distilled to CoreML
- Input: Text string, max 512 tokens
- Output: Token-level entity labels with confidence scores
- Target size: under 45MB (quantized INT8)
- Latency target: under 150ms for 2000-word document on A15 Bionic or later
- Training data considerations: synthetic PII/PHI generation to avoid real data in training pipeline; NIST 800-171 category taxonomy for CUI labeling
- CreateML path: Export from Hugging Face → `coremltools` conversion → INT8 quantization → `.mlpackage`

**Model 2: DocumentClassifier.mlmodel**
- Purpose: Assign sensitivity label (Public / Internal / Confidential / Restricted / Custom)
- Architecture: Multi-label text classifier — fine-tuned sentence transformer distilled to CoreML text embedding + shallow classification head
- Input: Document text excerpt (first 1000 tokens + metadata: filename, extension, source repository)
- Output: Probability distribution over sensitivity labels, top label, multi-label candidates above threshold
- Target size: under 30MB (INT8 quantized)
- Latency target: under 100ms for classification decision
- Multi-label support: documents can be simultaneously Confidential (content) and Internal (distribution) — both labels returned with independent confidence scores
- CreateML path: `MLTextClassifier` trained on curated enterprise document corpus with sensitivity labels, or coremltools export from sentence-transformers fine-tuned model

**Model 3: RiskScoringModel.mlmodel**
- Purpose: Sharing risk evaluation — continuous risk score, not binary allow/deny
- Architecture: Gradient boosted tree (GBT) or shallow MLP — tabular features, not text
- Input features: sensitivity score (float), recipient trust tier (enum), external recipient flag, device posture score, location risk zone, time-of-day signal, user sharing history baseline, content-recipient mismatch score
- Output: Risk score 0.0–1.0, confidence, top 3 contributing risk signals
- Target size: under 5MB — tabular model, very compact
- Latency target: under 20ms — synchronous, blocks the Share UI render until complete
- CreateML path: `MLDecisionTreeRegressor` or `MLBoostedTreeRegressor` via `CreateML` framework

### ONNX Runtime Integration

ONNX Runtime for iOS (`onnxruntime-mobile` Swift package) enables:
- Cross-platform model portability: models trained on cloud infrastructure in PyTorch/TensorFlow → exported to ONNX → deployed to iOS without CoreML conversion step
- Enterprise custom models: organizations that maintain their own compliance models (e.g., DOD CUI classifiers) can deliver them in ONNX format without XQ rebuilding them
- Future Android parity: same ONNX model file runs on Android via ONNX Runtime for Android

Integration pattern:
```swift
// App/AI/Providers/ONNXAIProvider.swift

import ORTMobileAPI  // ONNX Runtime Mobile Swift binding

class ONNXAIProvider: AIProvider {
    private let ortSession: ORTSession
    
    init(modelURL: URL, executionProviders: [ORTExecutionProvider] = [.coreML]) {
        // CoreML execution provider routes to Neural Engine when available
        // Falls back to CPU automatically
        let sessionOptions = ORTSessionOptions()
        sessionOptions.appendCoreMLExecutionProvider(with: ORTCoreMLFlags.enableOnSubgraphs)
        self.ortSession = try ORTSession(modelPath: modelURL.path, sessionOptions: sessionOptions)
    }
}
```

ONNX Runtime with the CoreML execution provider routes inference to the Neural Engine automatically — the same hardware acceleration as native CoreML, with the portability of ONNX format.

### Model Size Budget

| Model | Format | Size | Loading Strategy |
|---|---|---|---|
| SensitiveEntityClassifier | CoreML .mlpackage INT8 | 45MB | Download on first launch, cached |
| DocumentClassifier | CoreML .mlpackage INT8 | 30MB | Download on first launch, cached |
| RiskScoringModel | CoreML .mlpackage | 5MB | Bundled in app binary |
| Enterprise Custom | ONNX | Variable, max 80MB | Downloaded per tenant config |

Total bundled AI footprint at launch: 5MB (risk model only). Full classification capability available after ~80MB download on first run, which is acceptable given the security-focused user base. The NaturalLanguage + regex pipeline provides immediate basic protection during the download window.

### Battery Budget

iOS background AI inference must respect battery and thermal constraints. The spec explicitly requires battery-aware processing.

- On-device classification: target under 30mA average draw during document scan
- Triggered only on file events (import, edit-save, share-initiate) — not continuously polling
- `BGProcessingTask` used for background reclassification of the full vault after policy updates — scheduled only when device is charging and idle (BGProcessingTaskRequest.requiresExternalPower = true for bulk operations)
- Thermal state monitoring via `ProcessInfo.thermalState` — degrade to regex-only detection if thermal state is `.serious` or `.critical`
- Neural Engine usage preferred over CPU via CoreML compute unit selection: `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine` (excludes GPU to reduce heat)

---

## 4. CLOUD AI ROUTING

### Enterprise Policy Gate

Cloud AI routing is gated by an explicit enterprise policy check. This is a hard architectural constraint, not a configuration option. The gate runs before any content leaves memory.

```swift
// App/AI/CloudAIGate.swift

protocol CloudAIGate {
    func canRouteToCloud(
        content: DocumentContent,
        tenantConfig: TenantAIConfig,
        classificationResult: ClassificationResult?
    ) -> CloudRoutingDecision
}

struct CloudRoutingDecision {
    let permitted: Bool
    let reason: CloudRoutingReason
    let sanitizedContent: DocumentContent?  // PII-redacted version if partial permitted
    let auditToken: String                  // Logged regardless of decision
}

enum CloudRoutingReason {
    case policyPermitted
    case policyDenied                       // Enterprise policy blocks cloud AI
    case classificationTooSensitive         // Restricted content never leaves device
    case consumerTier                        // Free tier: always local
    case contentSanitized                   // Redacted version permitted
    case offlineContext                     // No connectivity
}
```

Rules enforced by the gate:
1. Free tier (consumer): cloud AI permanently blocked — `policyDenied` always
2. Content classified Restricted: cloud AI blocked regardless of enterprise policy — `classificationTooSensitive`
3. CUI-tagged content: cloud AI blocked unless tenant has explicit CUI cloud authorization
4. PHI content: cloud AI blocked unless tenant has signed BAA and policy flag is set
5. Enterprise SaaS with cloud AI enabled: permitted for Public and Internal classifications

### Privacy Controls Before Transmission

When cloud routing is permitted, the following transformations run before any content leaves the device:

- PII redaction pass: identified PII tokens replaced with type placeholders (`[PERSON]`, `[SSN]`, `[EMAIL]`) using the NaturalLanguage tagger + regex pipeline
- PHI de-identification: 18 HIPAA Safe Harbor identifiers removed or generalized
- Minimum necessary principle: only the content excerpt relevant to the classification task is sent, not the full document
- Content hashing: SHA-256 of original content included in audit log but hash does not leave device
- No document storage: cloud AI calls are stateless — prompt includes content, response is returned, no retention on provider side enforced by prompt instruction and provider contract

### Supported Cloud Providers and Use Cases

| Provider | Primary Use Case | Sensitivity Ceiling |
|---|---|---|
| OpenAI GPT-4o | Advanced document summarization, complex ambiguous classification | Internal only |
| Anthropic Claude | Policy recommendation reasoning, onboarding assistant complex queries | Internal only |
| AWS Bedrock (Claude/Titan) | Enterprise deployments in AWS environments, sovereign region routing | Per-tenant config |
| Azure OpenAI | Microsoft ecosystem tenants, SharePoint-integrated tenants | Per-tenant config |
| Enterprise Custom | Air-gapped cloud, classified environments, DOD deployments | Unrestricted (tenant-managed) |

Cloud AI is specifically suited for: generating human-readable policy rationale (why a file was classified), complex edge-case disambiguation where CoreML confidence is below threshold, and onboarding assistant conversational responses that require general knowledge.

Cloud AI is explicitly not used for: initial PII/PHI detection (always local), risk score calculation (always local), or any processing of Restricted content.

### Fallback Behavior

When cloud AI is unavailable (network failure, provider outage, rate limit):
1. Router automatically falls back to CoreML provider
2. Result is flagged with `isFallback: true` in the audit log
3. Classification confidence may be lower — if below human review threshold, the document is queued for re-analysis when connectivity restores
4. Sharing workflow continues with the on-device risk score — no blocking on cloud availability
5. Onboarding assistant falls back to a deterministic rule-based response system for common SharePoint/SMB configuration queries

---

## 5. AI CLASSIFICATION ENGINE

### Real-Time Scanning Pipeline

The classification pipeline is event-driven, not polling. Every triggering event (file import, edit save, share initiation) dispatches to an async classification pipeline that does not block the main thread.

```
DocumentContent (extracted text + metadata)
    │
    ▼
Stage 1: Fast Pattern Detection (synchronous, <5ms)
    ├── NaturalLanguage NLTagger (person, org, location)
    ├── Regex PII/PHI/financial pattern library
    └── CUI header/footer pattern matching
    │
    ▼
Stage 2: SensitiveEntityClassifier CoreML (async, <150ms)
    ├── Token-level entity labeling
    └── Entity confidence scores
    │
    ▼
Stage 3: DocumentClassifier CoreML (async, <100ms)
    ├── Sensitivity label prediction
    ├── Multi-label classification
    └── Label confidence distribution
    │
    ▼
Stage 4: Confidence Evaluation
    ├── Above threshold → emit ClassificationResult
    ├── Below threshold → route to cloud AI (if policy permits)
    └── Below human review threshold → flag for admin override queue
    │
    ▼
Stage 5: Policy Engine Notification
    └── ClassificationResult → PolicyEngine → enforcement actions
```

Text extraction per document type:
- PDF: `PDFKit` text extraction
- DOCX/XLSX: XML parsing of Office Open XML structure
- TXT/Markdown: direct string
- Images (camera scan): `VNRecognizeTextRequest` via Vision framework

### Confidence Scoring System

Confidence is a first-class output, not an afterthought. Every classification result carries a confidence score used to gate downstream actions.

```swift
struct ConfidenceThresholds {
    // Admin-configurable per tenant (spec section 3.16)
    let autoEnforceAbove: Float        // Default 0.85 — auto-classify and enforce
    let showUserAbove: Float           // Default 0.70 — display label to user
    let routeToCloudBelow: Float       // Default 0.70 — try cloud if permitted
    let humanReviewBelow: Float        // Default 0.50 — queue for admin review
    let ignoreBelow: Float             // Default 0.30 — treat as unclassifiable
}
```

Confidence aggregation uses an ensemble approach when multiple detection stages produce signals:
- Stage 1 pattern match hit: baseline confidence boost of +0.15 per high-specificity pattern (SSN, NPI)
- Stage 2 entity confidence: weighted average of token-level confidences
- Stage 3 document classifier confidence: direct model output
- Final confidence: weighted combination of stages 2 and 3, plus stage 1 boost applied as a floor

### Multi-Label Classification Support

The spec requires multi-label support. A single document can carry multiple sensitivity labels simultaneously. Implementation:

- Document classifier outputs probability for each label independently (sigmoid activation, not softmax)
- Any label with probability above 0.70 is included in the result
- Labels are hierarchically ordered: Restricted > Confidential > Internal > Public
- For policy enforcement, the highest-sensitivity label governs — but all labels are logged and displayed
- Custom tenant-defined labels (spec section 5.2) are mapped into the classification space via tenant-provided label embeddings

### Continuous Reclassification Triggers

Per spec section 4.8 and 4.9, classification is not a one-time event:

| Trigger Event | Reclassification Scope | Priority |
|---|---|---|
| File import | Full document | High — runs before encryption metadata is set |
| Document edit → save | Full document | High — runs before sync to repository |
| Share action initiated | Content sensitivity portion only | Critical — blocks share UI until complete |
| Enterprise policy update | All cached files in vault | Background, batch, charging-required |
| Offline → online reconnect | Modified files only | Background |
| User-initiated manual rescan | Full document | High |

Reclassification results are diffed against prior classification. If the label changes, the policy engine is notified synchronously and enforcement actions re-evaluate before any user action can proceed.

---

## 6. AI GOVERNANCE AND AUDIT

### AI Decision Logging Format

Every AI decision is logged as a structured, immutable audit record. The spec section 3.17 requires full audit visibility for enterprise deployments.

```swift
struct AIDecisionAuditRecord: Codable {
    let recordID: UUID
    let timestamp: Date
    let tenantID: String
    let userID: String                          // Anonymous token for free tier
    let deviceID: String                        // Device fingerprint, not UDID
    
    // Document context (no raw content in log)
    let documentID: String
    let documentHash: String                    // SHA-256 of content at time of classification
    let documentSizeBytes: Int
    
    // AI decision
    let capability: AICapability
    let providerID: String                      // Which provider made the decision
    let modelVersion: String
    let processingLocation: ProcessingLocation
    let durationMs: Int
    
    // Classification result
    let assignedLabels: [SensitivityLabel]
    let confidence: Float
    let detectedEntityTypes: [SensitiveEntityType]  // Types only, not the actual PII values
    let riskScore: Float?
    
    // Outcome
    let enforcedPolicyActions: [PolicyAction]
    let wasOverridden: Bool
    let overrideActorID: String?
    let overrideReason: String?
    
    // Governance
    let wasAboveConfidenceThreshold: Bool
    let wasRoutedToHumanReview: Bool
    let thresholdsApplied: ConfidenceThresholds
}
```

Note: Actual PII/PHI values detected are never written to the audit log — only entity type categories. This ensures the audit system itself does not create a secondary sensitive data exposure.

### Confidence Threshold Configuration

Administrators configure thresholds via the Enterprise Policy Management screen (spec section 3.16). Thresholds are delivered as part of the tenant policy bundle, versioned, and applied to all devices in the tenant:

- Classification auto-enforce threshold: default 85%
- Classification display threshold: default 70%
- Cloud routing trigger: when confidence is below 70% and cloud is permitted
- Human review queue trigger: when confidence is below 50%
- Override threshold: any decision can be overridden by admin regardless of confidence

### Human Override Mechanism

```swift
protocol AIOverrideService {
    // User-initiated override (consumer tier: user can dispute a classification)
    func submitUserOverride(
        documentID: String,
        originalDecision: ClassificationResult,
        proposedLabel: SensitivityLabel,
        reason: String
    ) async throws -> OverrideRequest

    // Admin override (enterprise: admin can reclassify any document)
    func applyAdminOverride(
        documentID: String,
        overrideDecision: ClassificationResult,
        adminID: String,
        auditNote: String
    ) async throws

    // Override feeds back into model improvement pipeline (with consent)
    func submitFeedbackForModelRefinement(
        overrideID: String,
        consentGranted: Bool
    ) async throws
}
```

Override behavior:
- User override is a request, not an immediate change for enterprise — it enters an admin review queue
- Admin override is immediate and logged in the immutable audit trail
- Override records are distinct from the original AI decision record — neither is mutated
- Repeated overrides on similar content patterns trigger a model refinement review flag for the tenant admin

### AI Model Versioning and Rollout

Model updates are delivered via the Dynamic Configuration system (spec section 16):

```swift
struct AIModelManifest: Codable {
    let manifestVersion: Int
    let models: [AIModelDescriptor]
    let rolloutPercentage: Float           // Canary: 0.0–1.0, full rollout = 1.0
    let minimumAppVersion: String
    let forceUpdateByDate: Date?           // Force update deadline
}

struct AIModelDescriptor: Codable {
    let capability: AICapability
    let modelID: String
    let version: String
    let downloadURL: URL
    let sha256Checksum: String             // Integrity verification before loading
    let sizeBytes: Int
    let format: AIModelFormat              // .coreML | .onnx
    let minimumIOSVersion: String
}
```

Model loading safety:
- New model downloaded to temp location
- SHA-256 verified against manifest before moving to active location
- Previous model version retained for 7 days as rollback target
- If new model produces >5% divergence in classification on a held-out validation set, rollout is paused and admin alerted
- Models are never loaded from unverified sources — only XQ-signed manifests accepted

---

## 7. AI DOCUMENT SCANNER (Camera Flow)

This implements spec section 3.11 and 4.7. All processing is on-device — this pipeline has zero network dependency.

### Camera to Classification Pipeline

```
Phase 1: Document Capture
    Camera feed (AVCaptureSession)
        │
        ▼
    VNDetectDocumentSegmentationRequest
        │  — real-time document boundary detection
        │  — overlay shows detected document edges
        ▼
    User confirms capture (or auto-capture when stable)
        │
        ▼
    CGImage of document region

Phase 2: OCR
    VNRecognizeTextRequest
        ├── recognitionLevel: .accurate (when device is stable)
        ├── recognitionLanguages: detected from NLLanguageRecognizer preview
        ├── usesLanguageCorrection: true
        └── Output: [VNRecognizedTextObservation] with bounding boxes + text

Phase 3: Real-Time Sensitivity Overlay (parallel to OCR)
    For each recognized text observation as it arrives:
        ├── Stage 1 regex patterns applied immediately
        ├── Sensitive tokens highlighted in camera overlay UI
        └── Sensitivity detection panel updates in real-time

Phase 4: Full Classification (after capture confirmed)
    Assembled text string → Classification Pipeline (Section 5)
        ├── SensitiveEntityClassifier CoreML
        ├── DocumentClassifier CoreML
        └── ClassificationResult produced

Phase 5: Governance Actions
    ├── Encrypt immediately (XQ encryption applied)
    ├── Suggest secure repository destination (AI-assisted folder suggestion)
    ├── Apply governance labels
    └── Trigger policy enforcement
```

### Real-Time Sensitivity Detection Overlay

The overlay renders during the live camera preview, before the user captures the document:

- `AVCaptureVideoDataOutput` with `CMSampleBuffer` → `VNImageRequestHandler` per frame
- Text recognition runs at reduced accuracy (`.fast`) during live preview for latency
- Detected sensitive regions highlighted with a colored overlay box (red for high-sensitivity entity types, yellow for medium)
- Classification panel at bottom of camera UI updates live: "Possible PII detected", "Financial data pattern found"
- This is purely visual feedback — no data is stored until the user explicitly captures

Privacy guarantee: the live camera processing happens entirely in-memory. No frames are written to disk. The only thing persisted is the user-confirmed final capture, immediately encrypted.

---

## 8. AI ONBOARDING ASSISTANT

### Conversational UI Requirements

The onboarding assistant is a conversational interface presented as a chat panel within the Repository Setup screen (spec section 3.3). Requirements from the spec: detect SharePoint configuration, suggest URLs, resolve authentication errors, recommend sync scope.

```swift
struct OnboardingSessionContext {
    let sessionID: UUID
    let deploymentMode: DeploymentMode          // .consumerLocal | .enterpriseSaaS
    let conversationHistory: [ConversationTurn]
    let detectedEnvironment: DetectedEnvironment? // Auto-detected org/tenant info
    let currentConfigurationState: ConfigurationState
    let failedAttempts: [ConfigurationAttempt]  // Auth failures, connectivity errors
}

struct DetectedEnvironment {
    let organizationDomain: String?            // From email address or MDM profile
    let identityProvider: IDPType?             // Detected from domain (Entra, Okta, etc.)
    let suggestedSharePointURL: URL?           // Constructed from domain pattern
    let suggestedSMBPath: String?
    let mdmManaged: Bool                       // If device is MDM-enrolled
}
```

### SharePoint Configuration Detection

Before the user types anything, the assistant performs automatic environment detection:

1. Read MDM-pushed configuration profiles — if the device is enrolled in Intune/Jamf, the SharePoint tenant URL may be in a managed app config
2. Check iOS Keychain for any existing Microsoft OAuth tokens (user may have Office apps installed)
3. Parse the user's email address (if provided at signup) to construct `[domain].sharepoint.com` as the suggested URL
4. Probe DNS for well-known Microsoft tenant indicators

This detection runs on-device. No network call is made without user initiation.

### Error Resolution Logic

The assistant has a structured error resolution knowledge base for common SharePoint and SMB connection failures:

| Error Condition | AI Diagnosis | Suggested Resolution |
|---|---|---|
| 401 Unauthorized | "Your credentials weren't accepted. This often means MFA is required or your password changed." | Guide through OAuth flow, suggest app-specific password if legacy auth |
| 403 Forbidden | "You were authenticated but don't have access to this SharePoint site." | Prompt for different site URL or contact admin |
| DNS resolution failure | "We couldn't find that server. The address may be incorrect." | Suggest autocomplete variations of common SharePoint URL patterns |
| OAuth token expired | "Your connection has expired." | Silent re-auth via refresh token, or guided re-login |
| Conditional access policy block | "Your organization requires additional verification for this device." | Guide through Intune enrollment or Entra device registration |
| SMB timeout | "The network drive couldn't be reached. You may be outside your organization's network." | Suggest VPN connection, offer offline mode as alternative |

Error resolution uses the on-device rule-based engine for free tier (no cloud dependency). Enterprise tenants with cloud AI enabled can route complex authentication failures to Anthropic/OpenAI for richer natural language diagnosis.

### Provider Routing for Onboarding Assistant

The onboarding assistant is the one capability where cloud AI routing for free-tier users may be acceptable with explicit consent, since the content being processed is configuration data and error messages — not document content. The consent dialog makes this explicit: "To help you connect faster, XQ can send your error message to an AI service. No files or personal documents are involved."

---

## 9. AI SHARING RISK EVALUATOR

### Input Signals

The sharing risk evaluator ingests a structured `RiskContext` and produces a continuous risk score. This directly implements the spec's fuzzy logic requirement (spec section 8).

```swift
struct RiskContext {
    // Content signals
    let documentClassification: ClassificationResult
    let sensitiveEntityCount: Int
    let sensitiveEntityTypes: Set<SensitiveEntityType>
    
    // Recipient signals
    let recipientTrustTier: RecipientTrustTier    // .internal | .knownExternal | .unknownExternal
    let recipientHasXQAccount: Bool               // Spec note: "understand if recipient has XQ account"
    let recipientDomain: String?
    let recipientIsGroupContainer: Bool           // Gmail group as shared workspace
    
    // Context signals
    let sharingMethod: SharingMethod              // .sharePointLink | .secureEmail | .directAttachment
    let deviceTrustScore: Float                   // 0.0–1.0 from device posture evaluation
    let userLocationRiskZone: LocationRiskZone    // .approvedRegion | .restrictedRegion | .unknown
    let timeOfDay: Date
    let userSharingPatternAnomaly: Float          // 0.0–1.0 deviation from user's baseline
    
    // Policy context
    let activeGeofencingPolicy: GeofencingPolicy?
    let recipientGroupPolicy: GroupPolicy?
    let enterpriseExternalSharingPolicy: ExternalSharingPolicy
}
```

### Risk Score Output

```swift
struct RiskEvaluation {
    let riskScore: Float                          // 0.0–1.0 continuous (fuzzy, not binary)
    let riskBand: RiskBand                        // Threshold-derived band for UI display
    let signals: [WeightedRiskSignal]             // Each factor with its contribution
    let recommendedAction: PolicyAction
    let blockingFactors: [String]                 // Any single-factor blockers
    let userMessage: String                       // Non-technical language for UI
    let confidence: Float
}

enum RiskBand {
    case low                    // 0.0–0.35: share proceeds, optional warning
    case medium                 // 0.35–0.65: user prompted to confirm, suggestions offered
    case high                   // 0.65–0.85: strong warning, additional controls enforced
    case critical               // 0.85–1.0: share blocked, admin alert triggered
}

struct WeightedRiskSignal {
    let factor: RiskFactor
    let contributionToScore: Float                // How much this factor added to final score
    let humanReadableExplanation: String
}
```

### Fuzzy Logic Example (from spec section 8.1)

```
IF:  recipientTrustTier == .unknownExternal        → +0.40
AND  classification.primaryLabel == .confidential  → +0.30
AND  deviceTrustScore == 0.60 (medium)             → +0.10
AND  sharingMethod == .directAttachment            → +0.08
AND  userSharingPatternAnomaly == 0.70 (unusual)  → +0.07

TOTAL riskScore = 0.95 → .critical

POLICY OUTPUT:
    recommendedAction = .allowViewOnly
    enforce: .disableDownload, .requireMFAEvery5Min, .applyHeavyWatermark
    userMessage: "This file contains sensitive content. We've applied extra protections for this recipient."
```

### Connection to Policy Engine

```
RiskEvaluation
    │
    ▼
PolicyEngine.evaluate(riskEvaluation:, tenantPolicy:)
    │
    ├── riskBand == .low     → proceed with standard protections
    ├── riskBand == .medium  → present AI risk summary to user, require confirmation
    ├── riskBand == .high    → enforce strong controls, warn user prominently
    └── riskBand == .critical → block share, log audit event, alert admin if enterprise
    │
    ▼
RuntimeEnforcement
    ├── Set SharePoint link permissions (view-only, expiry, download disabled)
    ├── Apply watermark level
    ├── Enable/disable forwarding
    └── Trigger audit log entry with full RiskContext snapshot
```

The risk evaluator runs synchronously when the user taps "Share Securely" — the Share UI displays a loading state ("Evaluating security...") for the under-20ms duration, then renders the risk summary before the user can confirm the share.

---

## 10. PROMPT MANAGEMENT (Cloud AI)

### System Prompt Templates Per Use Case

Cloud AI calls use strict system prompt templates. Templates are version-controlled, delivered via the same manifest system as model updates, and auditable.

**Document Classification Prompt Template**
```
System: You are a document sensitivity classifier for an enterprise security platform.
Your task is to classify the following document excerpt into exactly one of these sensitivity levels:
[Public, Internal, Confidential, Restricted].

Rules:
- Output ONLY valid JSON matching the schema provided.
- Never output explanations outside the JSON structure.
- If you detect PII, PHI, financial records, or CUI, note the category but do not quote the actual sensitive values.
- Base your classification on content sensitivity, not document format.
- If uncertain, classify higher (more sensitive).

Output schema: {"label": string, "confidence": float, "reasoning": string, "detectedCategories": [string]}
```

**Sharing Risk Evaluation Prompt Template**
```
System: You are a sharing risk evaluator for a Zero Trust security platform.
You will receive a structured JSON object describing a file sharing context.
Return ONLY a valid JSON risk evaluation. Do not add commentary.
Do not repeat any content from the input that appears to be personal or sensitive data.

Output schema: {"riskScore": float, "riskBand": string, "signals": [...], "recommendedAction": string, "userMessage": string}
```

**Onboarding Assistant Prompt Template**
```
System: You are an AI setup assistant for XQ Secure Workspaces.
Help users connect to SharePoint or network drives.
Use simple, non-technical language.
Never ask users for passwords. Never suggest disabling security features.
Limit responses to 3 sentences maximum.
```

### Prompt Injection Prevention

- All user-provided content is clearly delimited from system prompts using a separator that is not reproducible in normal text
- Document content sent to cloud AI is pre-processed: any instruction-like patterns (`"ignore previous instructions"`, `"system:"` prefixes) are stripped before inclusion in the prompt
- The classification and risk evaluation prompts do not include raw user-editable text in the system prompt — user content is always in a clearly marked `[DOCUMENT_CONTENT]` section
- Response validation runs before any cloud AI output is acted upon (see below)

### Response Validation

```swift
protocol AIResponseValidator {
    // Validate cloud AI response before acting on it
    func validate(
        response: String,
        expectedSchema: AIResponseSchema,
        capability: AICapability
    ) -> ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let parsedResponse: AIResponse?
    let violations: [ValidationViolation]
    let fallbackToOnDeviceDecision: Bool    // If invalid, use CoreML result instead
}
```

Validation rules:
- Response must parse as valid JSON matching the defined schema
- Confidence values must be in [0.0, 1.0] range
- Label values must be members of the allowed label set (not arbitrary strings)
- Risk scores must be numeric and in range
- If validation fails: log the failure, use the CoreML on-device result, do not surface the raw cloud AI output to the user or policy engine
- Rate limit cloud AI calls: maximum 10 cloud classification requests per minute per device to prevent cost abuse and potential exfiltration-via-classification-queries

---

## 11. PERFORMANCE REQUIREMENTS

### Classification Latency Targets

| Operation | Target Latency | Constraint |
|---|---|---|
| Stage 1 pattern detection (regex + NaturalLanguage) | < 5ms | Synchronous on classification queue |
| Full document classification (CoreML) | < 250ms | Async, does not block UI |
| Risk evaluation (RiskScoringModel CoreML) | < 20ms | Synchronous before Share UI renders |
| Camera OCR live preview sensitivity overlay | < 100ms per frame | Vision framework, dropped frames acceptable |
| Cloud AI classification (when permitted) | < 3000ms | Async with timeout; fallback to CoreML on timeout |
| Reclassification after edit | < 300ms | Triggered on save, before sync |
| Batch reclassification (policy update) | < 5 minutes for 1000 files | Background task, no latency constraint |

### Inference Scheduling

The AI classification pipeline runs on a dedicated serial `DispatchQueue` (or Swift `Actor`) named `ai.classification`. This ensures:

- Main thread is never blocked by AI inference
- File viewer renders immediately with a "Classifying..." indicator; label appears when ready
- Share workflow presents a brief loading state but does not block on the entire share flow — only the risk score calculation (< 20ms) gates the share UI render
- Multiple files imported in batch (e.g., camera roll import) are queued and processed serially to avoid memory pressure from concurrent CoreML inference

```swift
// App/AI/AIClassificationActor.swift

actor AIClassificationActor {
    private let router: AIProviderRouter
    private let auditLogger: AIAuditLogger
    
    // All classification calls serialize through this actor
    // Prevents concurrent CoreML memory contention
    func classify(document: DocumentContent, context: ClassificationContext) async throws -> ClassificationResult {
        // Actor serializes concurrent calls automatically
    }
}
```

### Background AI Processing Strategy

```swift
// Registered in AppDelegate / BGTaskScheduler setup

// Task 1: Batch reclassification after policy update
BGProcessingTaskRequest(identifier: "com.xq.ai.batch-reclassify")
    .requiresNetworkConnectivity = false
    .requiresExternalPower = true           // Only when charging

// Task 2: Model manifest check and download
BGAppRefreshTaskRequest(identifier: "com.xq.ai.model-update")
    // Runs periodically, short time budget
    // Only downloads if manifest version has changed

// Task 3: Audit log sync to enterprise backend
BGProcessingTaskRequest(identifier: "com.xq.ai.audit-sync")
    .requiresNetworkConnectivity = true
```

Foreground inference rules:
- CoreML models are loaded into memory lazily (first use) and kept resident for the app session
- Model warm-up occurs at app launch during the Secure Initialization screen (spec section 3.1): "Initialize local AI models" is one of the background actions on splash
- Memory budget: AI models target < 120MB total resident memory during active classification

---

## 12. RISKS

### Risk 1: CoreML Model Accuracy Below Enterprise Compliance Threshold

**Description**: The SensitiveEntityClassifier and DocumentClassifier CoreML models, being compact mobile-optimized models (MobileBERT-class), may produce false negatives on specialized compliance content — particularly CUI subcategories (NIST 800-171), ITAR-controlled technical data, or domain-specific PHI patterns in specialized medical fields. A false negative on a Restricted document being shared with an external recipient is a compliance failure.

**Mitigation**: Three-layer defense. First, the regex pattern library catches high-specificity patterns (SSN, NPI, IBAN, credit card) with near-zero false negative rate regardless of model performance. Second, the confidence threshold system routes borderline documents to cloud AI (when policy permits) or human review queue. Third, the "classify higher when uncertain" default rule — the model is tuned to prefer false positives (over-classification) over false negatives (under-classification). False positives are recoverable via the override mechanism; false negatives represent real data loss risk. Model accuracy target: > 92% F1 on PII/PHI detection, > 88% F1 on multi-label document classification.

### Risk 2: AI Processing Latency Degrades User Experience on Older Devices

**Description**: iPhone XS and iPad (6th generation) remain within iOS 17 support. These devices have older Neural Engines with significantly lower TOPS ratings than current silicon. A 250ms classification target on A17 Pro may become 800ms+ on A12 Bionic, making the "Share Securely" flow feel sluggish.

**Mitigation**: Device-tier detection at runtime using `ProcessInfo` and device model identifier. Older devices (A14 and below): use smaller model variants (INT4 quantized, ~20MB each), skip Stage 2 entity classification and rely on Stage 1 pattern detection for the fast path. The RiskScoringModel (tabular, 5MB) is unaffected by device tier — always fast. Battery-aware throttling also applies: on Low Power Mode, use pattern-only detection and defer full classification to background. Communicate this transparently in Settings > AI Governance Preferences: "Using optimized mode for your device."

### Risk 3: Tenant AI Configuration Complexity Creates Security Policy Gaps

**Description**: The per-tenant, per-policy, per-classification provider configuration model is powerful but complex. A misconfigured tenant config — for example, accidentally routing Confidential documents to a cloud provider without enabling the PHI protection flag — creates a data exposure pathway that violates the platform's privacy guarantees.

**Mitigation**: Configuration validation at the point of tenant config ingestion, not at runtime. The `TenantAIConfig` parser enforces invariants: cloud AI cannot be enabled for Restricted classification level under any configuration; PHI cloud routing requires a BAA acknowledgment flag set; CUI routing to non-approved providers is blocked by a hardcoded allowlist. These are code-level constraints, not configuration-level policies that can be misconfigured. Configuration changes are logged to the immutable audit trail. A tenant config preview mode shows admins exactly which provider will handle which classification level before activation.

### Risk 4: Model Inversion / Membership Inference via Classification API Probing

**Description**: If an adversary has access to a device and can iteratively query the on-device classification system with carefully crafted inputs, they may be able to infer properties of the training data (membership inference attack) or reverse-engineer classification boundaries to craft documents that evade detection (model evasion attack).

**Mitigation**: Rate limiting on classification API calls within the app (maximum 100 classifications per minute, enforced by the `AIClassificationActor`). Jailbreak detection at app launch blocks access to the classification engine entirely on compromised devices. CoreML models are not accessible as files from outside the app sandbox. For cloud AI, the response validation layer prevents model probing by normalizing outputs — raw logits or probability distributions are not exposed, only the structured classification result. Future: differential privacy noise injection on confidence scores returned to the UI (the audit log retains true confidence, but displayed confidence is perturbed).

### Risk 5: AI Governance Becoming a Compliance Theater Layer

**Description**: If AI governance adds friction without meaningfully preventing data loss — for example, warning dialogs that users click through habitually, or low-confidence classifications that are always overridden — the system devolves into compliance theater. The spec explicitly states "security should be ambient, invisible, and continuous rather than manual and disruptive" and lists "avoiding AI hallucinations" as a success metric.

**Mitigation**: Three design guardrails enforced at the architecture level. First, the ambient AI principle: classification and protection run silently — the user only sees AI when a risk decision genuinely requires their input. "Minimal prompts" is a UX requirement (spec section 9). Second, override analytics: the audit system tracks override rates by classification type, user, and tenant. Override rates above 20% on a specific label trigger an automatic model review flag — high override rates indicate the model is miscalibrated for that tenant's content profile, not that users are wrong. Third, confidence-gated interventions: only decisions above the display confidence threshold are shown to the user. Low-confidence, low-risk classifications are silently logged but do not interrupt the user. The AI should fail gracefully and silently, not loudly.

---

## File Reference

The specification this analysis is based on is at `/Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt`.

The recommended repository structure for the AI subsystem maps to:
- `/App/AI/` — provider implementations, router, classification actor, cloud gate
- `/App/Interfaces/AIProvider.swift` — protocol definition
- `/App/Policies/FuzzyLogicEngine.swift` — risk evaluation and fuzzy policy processor
- `/App/Security/CloudAIGate.swift` — cloud routing permission gate
- `/App/AI/Models/` — CoreML `.mlpackage` files and ONNX model assets
- `/App/AI/Audit/AIDecisionAuditLogger.swift` — immutable audit record writer