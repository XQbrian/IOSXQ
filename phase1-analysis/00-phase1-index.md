# XQ Secure Workspaces iOS — Phase 1 Analysis Index

**Date**: 2026-05-16  
**Status**: All 8 agents complete  
**Source Spec**: `/Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt`

---

## Agent Deliverables

| File | Agent | Status | Key Output |
|------|-------|--------|------------|
| [01-product-strategy.md](01-product-strategy.md) | Product Strategy | ✅ Complete | Personas, MVP scope, 18-screen requirements, user flows, risks, success metrics |
| [02-ios-architecture.md](02-ios-architecture.md) | iOS Architecture | ✅ Complete | Module structure, Swift protocols, KMP strategy, 16-week roadmap |
| [03-security-zero-trust.md](03-security-zero-trust.md) | Security & Zero Trust | ✅ Complete | Threat model, STRIDE analysis, key hierarchy, NIST alignment, top 5 risks |
| [04-backend-api.md](04-backend-api.md) | Backend/API | ✅ Complete | XQSecureAPI interface, multi-version adapters, SharePoint/SMB/IDP integration, offline queue |
| [05-ai-integration.md](05-ai-integration.md) | AI Integration | ✅ Complete | AIProvider protocol, CoreML models, cloud AI gate, classification pipeline |
| [06-devops-delivery.md](06-devops-delivery.md) | DevOps & Delivery | ✅ Complete | CI/CD pipeline, build targets, feature flags, force update system |
| [07-qa-testing.md](07-qa-testing.md) | QA & Testing | ✅ Complete | Unit/integration/E2E strategy, DLP validation, AI accuracy benchmarks, device matrix |
| [08-ux-ui-design.md](08-ux-ui-design.md) | UX/UI Design | ✅ Complete | Design tokens, 18-screen specs, animation system, component library |


---

## Cross-Agent Consensus — Critical Decisions

### Architecture Foundation
- **MVVM-C + SwiftUI**: ViewModels hold no business logic; Coordinators own navigation
- **Interface-Driven**: ALL external calls (XQ API, SharePoint, AI, IDP) behind Swift protocols — no direct API calls in business logic
- **Kotlin Multiplatform**: Business logic, policy engine, AI abstraction in KMP from day one
- **Dependency Injection**: Resolver/Factory pattern; all test doubles injected at protocol boundaries

### Security Non-Negotiables
- **Secure Enclave root key**: All cryptography anchored to hardware; keys never leave Secure Enclave
- **AES-256-GCM**: Every file encrypted before any disk write; plaintext never touches filesystem
- **Multi-layer jailbreak detection**: 5 signal groups (filesystem, dylib, process integrity, behavioral, App Attest)
- **Certificate pinning**: SPKI hash pinning on all XQ and SharePoint endpoints with remote pin update
- **NSFileProtectionComplete**: All offline cache files — inaccessible when device locked

### AI Governance Rules
- **Local-first always**: CoreML is the default and permanent fallback
- **Cloud AI requires dual gate**: (1) enterprise opt-in in policy AND (2) content classification permits cloud
- **CUI/PHI = local only**: No cloud AI for CUI or PHI regardless of enterprise setting
- **3 CoreML models**: SensitiveEntityClassifier (45MB), DocumentClassifier (30MB), RiskScoringModel (5MB)

### Phase 1 Screen Priority
- **P0 (blocking)**: Splash, Welcome, Permissions, Home, File Browser, File Viewer, Local Import, Secure Share
- **P1 (complete Phase 1)**: Document Editor, AI Scanner, Notifications, Sharing Center, Settings, Policy Mgmt, Audit Log
- **Out of scope**: Secure Email (Phase 2), Secure Chat (Phase 3)

### XQ API Multi-Version Strategy
- Capability negotiation at session start → pin adapter for session lifetime
- v1Adapter, v2Adapter, v3Adapter all conform to `XQSecureAPI` protocol
- Version negotiation cached in actor; invalidated on session expiry or offline→online transition
- Operations that cannot be fulfilled at negotiated version throw `apiVersionMismatch` — never silently degrade

### Top Risks (All Agents Agree)
1. **On-device AI model accuracy** on A12/A15 devices — must hit 95% PII recall, 97% PHI recall on minimum-spec hardware before GA
2. **iOS screenshot limitation** — screenshot "blocking" is impossible; only detection + watermarking available; enterprise security docs must be accurate
3. **Consumer-to-Enterprise key transition** — no cryptographic protocol defined for transitioning Secure Enclave-only consumer files to XQ KMS enterprise control
4. **Dynamic policy downgrade attack** — compromised XQ policy infrastructure could deliver permissive policy to all tenants; policy bundle signature verification + HSM-held signing keys required
5. **XQ API offline capability gap** — if XQ API requires connectivity for every policy evaluation, offline-first model is undermined

---

## Phase 1 Build Order (16 weeks, from iOS Architecture Agent)

| Weeks | Work |
|-------|------|
| 1–2 | Interface protocols + mocks + KMP domain models + localization JSON |
| 3–4 | Security core (SecureEnclave, JailbreakDetector, SessionManager, SecureFileStore, CertificatePinner) |
| 5–6 | XQ API (Gateway + v1/v2 adapters + encrypt/decrypt + Keychain) |
| 7–8 | Repository (SharePointProvider, LocalVaultProvider, FileService pipeline) |
| 9–10 | AI + Policy (CoreMLProvider, RiskScorer, FuzzyPolicyEngine, AIOrchestrator) |
| 11–12 | Sync engine (SyncQueue, DeltaSync, ConflictResolver, OfflineCache) |
| 13–14 | UI layer (AnimationEngine + all 18 screens) |
| 15–16 | Integration hardening (E2E tests, perf profiling, security audit, L10n QA) |

---

## Next: Phase 2 — Prototype Refinement

Design iteration continues in the HTML prototype (`prototype/index.html`).
