The spec is comprehensive. Let me now produce the full Phase 1 security architecture analysis.

---

# XQ Secure Workspaces (iOS) — Phase 1 Security Architecture Analysis

**Date**: 2026-05-16 | **Version**: 1.0 | **Classification**: Confidential — Engineering Internal
**Prepared by**: Security Engineer Agent | **Scope**: Phase 1 — Secure File Vault

---

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces is a Zero Trust Data platform targeting one of the highest-risk categories in enterprise mobility: sovereign, encrypted file access on personal devices at the edge. The ambition is correct and the market need is real. The security architecture must be flawless from day one because the product's entire value proposition *is* the security — a single material breach or bypass of the container model destroys the product's credibility.

Phase 1 (Secure File Vault) establishes the attack surface that all subsequent phases inherit. Every architectural decision made here — key hierarchy, session management, the container boundary, offline cache design, AI model access controls — propagates forward into email and chat in Phases 2 and 3. Getting it wrong now is compounding debt.

**Three existential risks identified in the spec that must be resolved in Phase 1:**

1. The spec positions XQ as holding no customer data, yet the offline cache must persist decrypted-enough content for usability. The boundary between "encrypted at rest" and "accessible to the app" is the primary attack surface on a compromised device.

2. The AI provider abstraction (OpenAI, Anthropic, AWS Bedrock listed as supported providers) directly contradicts the "no raw content leaves the device" requirement for CUI/PHI content. This is not a design tension — it is a compliance violation if cloud AI providers receive document content without explicit enterprise policy gate.

3. The free tier's "no account required" model means there is no server-side binding for key revocation. A user who transitions from consumer to enterprise must have their locally-held keys either re-wrapped under enterprise KMS control or the files become orphaned from the enterprise policy engine. The spec does not address this transition cryptographically.

**Overall security posture**: The architecture as specified is sound at the principle level. The implementation risks are in the gaps between principles. This document identifies those gaps and prescribes controls.

---

## 2. THREAT MODEL

### 2.1 Asset Inventory — What We Protect

| Asset | Classification | Value to Attacker |
|-------|---------------|-------------------|
| File content (documents, spreadsheets, images) | PII, PHI, CUI, Financial | Primary target — direct data exfiltration |
| XQ encryption keys (per-file DEKs) | Critical | Enables bulk decryption of all protected files |
| Secure Enclave root key | Critical | Master key compromise, equivalent to device seizure |
| Session tokens (IDP access/refresh tokens) | High | Lateral movement to SharePoint, email, network drives |
| SharePoint/repository credentials | High | Access to source-of-truth, beyond app container |
| Classification metadata | Medium | Reveals what sensitive data exists, aids targeted attack |
| Audit logs | High | Tampering enables insider threat concealment |
| AI model inference results (locally) | Medium | Reveals document sensitivity without seeing content |
| Enterprise policy bundles | Medium | Policy bypass if attacker understands enforcement logic |
| User behavioral patterns | Medium | Social engineering, timing attacks on sync |

### 2.2 Threat Actors

**External Adversaries**
- Nation-state actors targeting CUI/classified content in Phase 3 deployments (government vertical)
- Financial threat actors targeting PHI/financial records — common in healthcare and finance targets
- Ransomware operators targeting SharePoint credential theft for lateral enterprise access
- Certificate theft adversaries attempting to bypass certificate pinning via rogue CAs

**Insider Threats**
- Employees attempting to exfiltrate sensitive documents before termination (the spec's "view-only mode" and "revocation" features directly address this)
- Administrators with policy override capability — admin-level abuse is the most damaging insider scenario
- Users circumventing the container via physical means (camera pointed at screen, photographing watermarked content)

**Device-Level Threats**
- Jailbroken device — the most critical attack vector for this product; breaks the app container model at the OS level
- Malware with kernel access (post-jailbreak) — can read Keychain, intercept decrypted file buffers in memory
- Physical device seizure with MDM enrollment bypass
- Screen recording via iOS mirroring / AirPlay when not properly detected
- iCloud backup extraction of app data container (mitigated by iOS data protection class, but must be explicitly set)

**Supply Chain Threats**
- Compromised third-party SDK (AI provider SDKs, document rendering libraries)
- XQ API compromise — if the XQ key management service is compromised, all per-file DEKs that are XQ-held become accessible
- Malicious policy updates delivered via the dynamic configuration channel

### 2.3 Attack Vectors Specific to This App

**AV-1: Offline Cache Extraction**
An attacker with physical device access (or backup) attempts to extract the offline cache directory from the iOS app sandbox. If files are stored using iOS Data Protection `NSFileProtectionComplete`, they are inaccessible when the device is locked. If stored with `NSFileProtectionCompleteUntilFirstUserAuthentication` (which is the default after first unlock), they are accessible to any process running on the device — including malware — for the entire uptime of the device after first unlock.

**AV-2: Jailbreak + Memory Scraping**
On a jailbroken device, an attacker can use tools like Fridump or Objection to scrape the process heap and extract decrypted file content from memory buffers during rendering. The Secure Enclave keys themselves cannot be extracted, but the derived session keys used to decrypt content for rendering are in memory.

**AV-3: AI Model Data Exfiltration**
If the `AIProvider` interface is configured to use a cloud provider (OpenAI, Anthropic, AWS Bedrock) and document content is passed to `classify(document: Data)` or `generateSummary(text: String)`, that content has left the device. The spec states "No raw content leaves device unless enterprise policy permits" but the technical architecture lists cloud AI providers as supported without a mandatory policy gate enforcing this distinction.

**AV-4: Share Sheet Escape**
iOS share sheets are intercepted at the UIKit/SwiftUI level, but a sophisticated user can potentially invoke the share sheet via Shortcuts automations or use accessibility APIs to bypass custom share sheet filtering. The spec says "block unapproved share sheet destinations" but iOS does not provide a fully reliable API to prevent all share sheet usage — this must be understood as a best-effort defense.

**AV-5: QR Code / Screenshot Workaround**
Watermarking mitigates but does not prevent camera-based capture. A user can photograph the screen with a second device. The watermark must include sufficient identifying information (user ID, timestamp, device ID) to enable attribution after-the-fact. Prevention via camera is impossible on iOS.

**AV-6: Certificate Pinning Bypass**
On a jailbroken device, tools like SSL Kill Switch 3 can disable certificate pinning by hooking `SecTrustEvaluate`. Without jailbreak detection preceding all network operations, certificate pinning provides no protection.

**AV-7: OAuth Token Theft via IPC**
If OAuth redirect URIs use custom URL schemes (e.g., `xq://oauth/callback`) rather than universal links with associated domains, a malicious app on the same device can register the same URL scheme and intercept the authorization code. This is a known attack against mobile OAuth implementations — PKCE is required but not sufficient if the redirect URI is not bound to the app via associated domains.

**AV-8: Dynamic Policy Tampering**
Enterprise policies are delivered over the network and applied at runtime. If an attacker can perform a man-in-the-middle on the policy channel (or compromise the policy delivery infrastructure), they can downgrade enforcement — for example, removing view-only mode or disabling audit logging for a specific user.

**AV-9: Backup and Restore Attack**
By default, iOS includes app data in iCloud or local iTunes/Finder backups unless the app explicitly opts out. If the offline cache, Keychain items, or CoreData store is included in backup with insufficient protection, an attacker who controls a user's iCloud account can extract file content.

**AV-10: Consumer-to-Enterprise Transition Key Orphaning**
A user who creates files in free/consumer mode holds the only copy of the Secure Enclave key (which is non-exportable). When they transition to enterprise, if the enterprise KMS cannot re-wrap those keys, the enterprise cannot enforce policy or revocation on pre-existing files. Conversely, if the transition requires re-encryption with enterprise keys, the transition window leaves files temporarily in a state where enterprise governance is not yet applied.

### 2.4 STRIDE Analysis for Key Components

#### Secure File Viewer (highest risk surface in Phase 1)

| Threat | Attack Scenario | Risk | Mitigation |
|--------|----------------|------|------------|
| Spoofing | Attacker clones app with removed DLP controls, connects to same XQ backend | High | App attestation via DeviceCheck/App Attest; certificate pinning bound to bundle ID |
| Tampering | Debugger attached to intercept file decryption buffer before display | High | Jailbreak detection; anti-debugging via PT_DENY_ATTACH; encrypted rendering pipeline |
| Repudiation | User denies viewing a sensitive document | Medium | Audit log records file open event with user identity, timestamp, device ID, XQ token |
| Info Disclosure | Screenshot taken during rendering, or file content leaked via drag-and-drop | High | Screenshot notification API; UITextField.isSecureTextEntry pattern for custom views; background blur |
| DoS | Malicious file crafted to consume excessive memory during parsing (parser bomb) | Medium | File size limits; rendering timeouts; sandboxed rendering process |
| Elevation of Privilege | User modifies file sensitivity label locally to downgrade policy enforcement | High | Classification labels must be server-validated; local AI classification is advisory only unless offline and enterprise policy permits |

#### Authentication / Session Management

| Threat | Attack Scenario | Risk | Mitigation |
|--------|----------------|------|------------|
| Spoofing | OAuth authorization code intercepted via malicious app with same URL scheme | Critical | Universal Links for OAuth redirect; PKCE mandatory; state parameter validation |
| Tampering | JWT role/group claims modified client-side to escalate privilege | Critical | All authorization decisions must be made server-side; client-side claims are display-only |
| Repudiation | Admin denies making policy change | Medium | Admin actions require separate audit trail with admin identity binding |
| Info Disclosure | Session token logged in crash report or telemetry | High | Tokens must never appear in logs, telemetry, or error messages; use token references |
| DoS | Account lockout via credential stuffing on SSO endpoint | Medium | Leverage IDP's built-in lockout; do not implement custom authentication bypass |
| Elevation of Privilege | Expired session token reused after account deprovisioning | Critical | Token revocation must propagate to the XQ policy layer; dynamic access revocation |

#### AI Governance Engine

| Threat | Attack Scenario | Risk | Mitigation |
|--------|----------------|------|------------|
| Spoofing | Attacker substitutes a permissive local AI model via filesystem manipulation | High | Model integrity verification (hash check) at load time; model stored in app bundle, not user-writable storage |
| Tampering | Adversarial inputs crafted to fool classification (e.g., steganographically hidden PII that evades detection) | Medium | AI classification is one layer; pattern-matching regex runs in parallel as ground truth for known PII patterns |
| Repudiation | AI misclassifies and user claims they didn't know content was sensitive | Low | AI confidence score and classification rationale logged with the decision |
| Info Disclosure | Document content sent to cloud AI provider without user/enterprise consent | Critical | Hard policy gate: content classification must default to local model only; cloud AI requires explicit enterprise opt-in with audit trail |
| DoS | Large file triggers AI processing loop, draining battery/memory | Medium | AI processing must be bounded by file size, time budget, and battery state |
| Elevation of Privilege | User overrides AI classification to downgrade sensitivity, bypassing policies | High | User overrides must be logged; enterprise can disable user overrides for Restricted/CUI content |

#### XQ API Abstraction Layer

| Threat | Attack Scenario | Risk | Mitigation |
|--------|----------------|------|------------|
| Spoofing | Attacker sets up rogue XQ API endpoint via certificate pinning bypass (requires jailbreak) | High | Certificate pinning + jailbreak detection as compound control |
| Tampering | API response tampering to return permissive policy or wrong decryption key | Critical | Response signing; policy bundle integrity check; HMAC or JWS on policy payloads |
| Repudiation | XQ infrastructure denies serving a particular policy version | Medium | Local immutable log of policy versions received and applied |
| Info Disclosure | XQ API access logs reveal what files users are accessing | Medium | XQ's stated model of "files never transit XQ infrastructure" must extend to access pattern metadata where possible; consider blind tokens |
| DoS | XQ API unavailable; app must fail securely | High | Offline mode with cached policy; fail-closed on access decisions when policy cannot be validated |

---

## 3. ZERO TRUST ARCHITECTURE

### 3.1 Zero Trust Applied to Mobile Context

Traditional Zero Trust assumes a network perimeter. Mobile Zero Trust eliminates the network assumption entirely and evaluates trust at the device and data layer simultaneously. For XQ Secure Workspaces, Zero Trust has three distinct expression points:

**Data-Centric Zero Trust (XQ's Core Model)**: Encryption keys are bound to access policy, not network location. A file can be accessed only if the requestor can prove current authorization to the XQ key service. This means access decisions happen at read time, not at write time.

**Device Zero Trust**: The device itself is a trust signal. iOS device attestation (Apple's DeviceCheck and App Attest APIs) provides cryptographic proof that the app is genuine and the device is uncompromised. This signal must be evaluated at session establishment and periodically during long sessions.

**Session Zero Trust**: Sessions are not persistent by default. Each significant action re-evaluates whether the current combination of identity, device posture, location, content sensitivity, and time still merits the requested access level.

### 3.2 Continuous Trust Evaluation Points

The spec's fuzzy policy engine correctly identifies the inputs. The implementation must evaluate these at specific lifecycle hooks:

| Evaluation Point | Triggers | Trust Signals Evaluated |
|-----------------|----------|------------------------|
| App launch | Cold start | Jailbreak status, app integrity, certificate validity |
| Authentication | SSO completion | IDP token validity, device enrollment, MFA completion |
| File open | Every file access | Session age, device posture, content classification, location |
| Share initiation | Share action invoked | Recipient trust level, content sensitivity, policy compliance, location |
| Background/foreground | App state change | Session timeout, biometric re-auth requirement |
| Network change | WiFi to cellular, VPN drop | Re-evaluate network trust; consider if offline policy applies |
| Policy update received | Push or poll | Re-evaluate all cached access grants against new policy |
| Edit save | Document modified | Rescan classification; re-evaluate if sensitivity changed warrants restriction |
| Periodic heartbeat | Every N minutes | Token refresh, device posture re-check, session anomaly detection |

### 3.3 Re-Authentication Triggers

The spec mentions "require biometric unlock on return" which is the right behavior. The complete trigger set is:

- App returns from background after configurable timeout (default: 5 minutes for enterprise; configurable by admin)
- High-risk content accessed (Restricted or CUI classification) — always require fresh biometric
- Session token age exceeds maximum (even if app has been in foreground continuously — prevent sleeping sessions)
- Device posture score drops below threshold (e.g., new configuration profile installed mid-session, or VPN disconnected on a policy that requires VPN)
- Location changes to outside geofenced area mid-session
- Failed biometric attempt (after grace period, require full re-authentication via IDP)
- Admin-triggered forced re-authentication (for incident response scenarios)
- MFA step-up for download-equivalent actions in view-only mode (e.g., offline marking of Restricted content)

### 3.4 Identity → Device → Session → Data Trust Chain

This chain must be validated left-to-right. A failure at any layer collapses the chain entirely — no exceptions.

```
Identity Trust
  └── IDP-issued token (Entra/Okta/Google/Ping) is valid, unexpired, not revoked
  └── MFA was completed within policy-defined window
  └── User group memberships retrieved and bound to session
        │
        ▼
Device Trust
  └── App Attest assertion verified (Apple cryptographic device integrity)
  └── Jailbreak detection passed (multi-signal, not single check)
  └── Device registered in enterprise MDM (if enterprise deployment)
  └── OS version meets minimum requirement (spec: iOS 17+)
  └── Device posture score computed (MDM compliance, screen lock, encryption status)
        │
        ▼
Session Trust
  └── Session token scoped to device + user combination (prevent token transfer)
  └── Certificate pinning validated for all network connections
  └── Session age within maximum lifetime
  └── Behavioral baseline not violated (anomaly detection optional, Phase 2+)
        │
        ▼
Data Trust
  └── XQ key service confirms current access grant for this user + device + file
  └── Content classification loaded and policy applied
  └── Geofence check (if applicable to this content or group policy)
  └── Expiration check (share expiry, offline cache TTL)
  └── Runtime DLP controls applied (screenshot blocking, watermark rendered)
```

A revoked identity (user deprovisioned in Entra) must propagate failure up through the chain within the policy-defined window. For high-sensitivity content, this window should be less than 5 minutes.

---

## 4. AUTHENTICATION & IDENTITY

### 4.1 SSO Flow — All Supported IDPs

All IDP integrations must follow the same secure pattern regardless of provider. The `IDPAuthAdapter` interface must enforce this:

**Required OAuth/OIDC implementation requirements for all providers:**

- PKCE (RFC 7636) is mandatory — no client secret on mobile
- Authorization Code Flow only — no implicit flow, no client_credentials on device
- Redirect URI must use HTTPS universal links (`https://app.xqmsg.co/oauth/callback`) with associated domain verification, never custom URL schemes like `xq://`
- `state` parameter: cryptographically random, verified on return, bound to a short-lived nonce stored in memory only
- `nonce` parameter in OIDC flows: required for ID token binding
- Token storage: access tokens in memory only; refresh tokens in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + Secure Enclave-backed access control object
- Token lifetime: honor IDP-provided expiry; do not extend. Refresh tokens must be rotated on each use
- ID token claims must be re-validated on every use: `iss`, `aud`, `exp`, `iat`, `nonce` — not just at issuance

**Entra ID (Microsoft)**: Use MSAL for iOS. MSAL handles broker-based SSO and MDM integration correctly. Do not use a generic OAuth library for Entra — MSAL handles Windows Hello, Conditional Access, and PRT (Primary Refresh Token) correctly on iOS. Token cache must use MSAL's secure cache, not a custom implementation.

**Okta**: Use Okta's `okta-oidc-ios` SDK or the Okta Mobile SDK. Okta's device authorization grant for step-up is supported. Device trust signals can be passed to Okta's policy engine via the Okta Device SDK integration.

**Google Workspace**: Use `AppAuth-iOS` (the IETF-recommended library). Google supports Custom Tabs on Android but on iOS the ASWebAuthenticationSession approach is correct — it uses the system browser, which shares cookies with Safari and enables SSO.

**Ping Identity**: PingFederate and PingOne both support standard OIDC. Use `AppAuth-iOS`. Verify Ping's token introspection endpoint is pinned for certificate pinning.

**AWS IAM Identity Center**: Supports OIDC. Uses the standard authorization code + PKCE flow. Token exchange for AWS credentials (STS AssumeRoleWithWebIdentity) must happen server-side if AWS resources are accessed — never call STS from the mobile client directly.

### 4.2 MFA Integration Points

MFA is evaluated at the IDP level (preferred) and enforced by the app at specific step-up points. Do not implement custom MFA — leverage the IDP's MFA.

- **IDP-level MFA**: Required at initial authentication. All supported IDPs support MFA enforcement via Conditional Access policies (Entra), Okta Verify, Google Authenticator/TOTP, Ping MFA. The app must not cache the result of MFA as a bypass — the IDP token's AMR (Authentication Methods References) claim must contain the expected MFA method.
- **Step-up MFA**: For accessing Restricted or CUI classified content, or when device posture drops, the app must initiate a step-up authentication flow via the IDP's step-up endpoint or re-trigger the OIDC flow with `prompt=login` and `acr_values` specifying MFA.
- **Local biometric as MFA second factor**: Face ID / Touch ID can satisfy the "something you are" factor locally but only as an unlocking mechanism for a previously established IDP session. A cached Keychain token + biometric is not equivalent to IDP-validated MFA for high-sensitivity operations.
- **Offline MFA**: When offline, the app cannot perform IDP-based MFA. The policy for offline access must explicitly state that biometric authentication is sufficient for offline mode access at a configurable sensitivity threshold (e.g., Confidential and below offline, Restricted requires connectivity for MFA).

### 4.3 Device Registration Flow

Device registration binds a specific device to a user account and establishes the device trust baseline.

```
Registration Flow:
1. User completes IDP authentication (SSO + MFA)
2. App generates device keypair in Secure Enclave:
   SecKeyCreateRandomKey with kSecAttrTokenIDSecureEnclave
3. App obtains Apple App Attest assertion:
   DCAppAttestService.generateKey() → attest(key:clientDataHash:)
4. App sends to XQ registration endpoint:
   - IDP access token (proves identity)
   - App Attest assertion (proves device integrity)
   - Device public key (Secure Enclave-generated, non-exportable)
   - Device metadata (iOS version, device model, MDM enrollment status)
5. XQ backend verifies App Attest with Apple's servers
6. XQ backend registers device + user binding + device public key
7. XQ backend returns device certificate (signed with XQ CA)
8. Device certificate stored in Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
9. Subsequent API calls present device certificate in mutual TLS or as a signed assertion
```

Device registration must be revocable by enterprise admin. Revocation must cascade to session invalidation within the policy-defined window.

### 4.4 Session Management and Token Lifecycle

**Token Storage Hierarchy (most to least sensitive):**

| Token Type | Storage Location | Access Control | Notes |
|-----------|-----------------|---------------|-------|
| Secure Enclave private key | Secure Enclave hardware | Biometric + device lock | Non-exportable by hardware design |
| Refresh token | Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + LAContext biometric protection | Rotate on every use |
| Access token | In-memory only | Process isolation | Never write to disk or logs |
| Device certificate | Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | Device-bound |
| Session state | Encrypted CoreData | Derived from Secure Enclave key | Cleared on logout |

**Token lifecycle rules:**
- Access tokens: use until expiry, never extend, never cache beyond in-memory session
- Refresh tokens: stored in Keychain with biometric access control; rotated on every refresh operation; invalidated on logout, device removal from account, admin revocation
- Session timeout: configurable by enterprise admin; default 30 minutes of inactivity; maximum 8 hours total session length before forced re-authentication
- Logout: must delete access token from memory, delete refresh token from Keychain, clear CoreData session state, invalidate the token at the IDP's revocation endpoint, notify XQ API to revoke device session

### 4.5 Conditional Access Evaluation

Conditional Access policies from Entra/Okta are evaluated at the IDP level during token issuance. The app must handle Conditional Access challenge responses correctly:

- If IDP returns a Conditional Access challenge (e.g., "device not compliant"), the app must surface a clear, actionable error — not a generic auth failure
- For Entra: the MSAL `MSALErrorServerDeclinedScopes` and `MSALErrorInteractionRequired` must be handled with appropriate re-authentication prompts
- For Okta: handle `MFA_ENROLL` and `LOCKED_OUT` policy states from the Okta authentication API
- Device compliance signals: if MDM is enrolled (Intune, Jamf), the app should request the compliance token from the MDM broker and include it in the token request so the IDP can evaluate it against Conditional Access policy
- The app must not attempt to evaluate Conditional Access policy itself — this is the IDP's responsibility. The app's role is to correctly surface challenge responses and complete the IDP-directed remediation flow.

---

## 5. ENCRYPTION ARCHITECTURE

### 5.1 Key Hierarchy

The key hierarchy must be explicitly designed before any file encryption code is written. The following hierarchy supports both the consumer (no-account) and enterprise deployment models:

```
Secure Enclave Device Root Key (non-exportable, hardware-bound)
  │   Generated at app install; never leaves the Secure Enclave
  │   Used only for Wrap/Unwrap operations; never for direct encryption
  │
  ├── User Key Encryption Key (KEK) — Consumer Tier
  │     Derived via Secure Enclave signing operation
  │     Exists in memory only during active session
  │     Protects per-file Data Encryption Keys (DEKs)
  │
  ├── Enterprise KEK — Enterprise Tier
  │     Enterprise master key held by XQ KMS (customer-controlled)
  │     Device KEK wraps a copy of enterprise KEK during provisioning
  │     Enterprise KEK wraps per-file DEKs → enables enterprise revocation
  │     Key rotation supported without file re-encryption (re-wrap only)
  │
  └── Per-File Data Encryption Keys (DEKs)
        Generated fresh for every file using CryptoKit's SymmetricKey(size: .bits256)
        Algorithm: AES-256-GCM
        DEK stored as XQ-encrypted metadata bound to file
        DEK never stored unencrypted on disk
        Wrapped under Consumer KEK (consumer) OR Enterprise KEK (enterprise)
        For shared files: DEK additionally wrapped under XQ key service
          → enables dynamic revocation and recipient access control
```

**Why AES-256-GCM**: Provides authenticated encryption — tampering with ciphertext is detectable. The authentication tag ensures file integrity in addition to confidentiality. CryptoKit's `AES.GCM.seal()` implements this correctly. Never use AES-CBC or AES-ECB.

**Nonce management**: AES-GCM nonces (IVs) must be unique per encryption operation. Use CryptoKit's automatic nonce generation (`AES.GCM.Nonce()`) which uses `SecRandomCopyBytes`. Never reuse a nonce with the same key — GCM nonce reuse is catastrophic and reveals both plaintexts and the authentication key.

**Key derivation for consumer tier**: If a password-based variant is needed (for recovery), use HKDF (CryptoKit `HKDF`) or Argon2id (via a vetted library) — never PBKDF2 with fewer than 600,000 iterations (NIST 2024 guidance), and never MD5 or SHA-1 based KDF.

### 5.2 XQ Encryption Integration

XQ's encryption model (based on the XQ API documentation) provides a distributed key management service where keys are split and managed by XQ, with access governed by XQ policies. The integration with local Secure Enclave must be layered:

```
File Encryption at Import:
1. Generate fresh DEK: SymmetricKey(size: .bits256)
2. Encrypt file content: AES.GCM.seal(content, using: DEK)
3. Create XQ key token: XQSecureAPI.encrypt() with DEK + policy metadata
   → XQ stores key material (their split key model)
   → Returns XQ token (an opaque reference, not the key itself)
4. Store encrypted file + XQ token in secure sandbox
5. Wrap DEK under local KEK for offline access (if offline permitted by policy)
6. Store wrapped DEK in encrypted CoreData alongside XQ token

File Decryption at Open:
1. Retrieve XQ token from CoreData
2. Call XQSecureAPI.validateAccess() — checks current policy at XQ key service
   (This is where dynamic revocation is enforced — if access is revoked at XQ,
   this call fails even if the local wrapped DEK exists)
3. If online and authorized: XQSecureAPI.decrypt() returns DEK
4. If offline and policy permits: unwrap local KEK using Secure Enclave,
   unwrap local wrapped DEK, proceed
5. Decrypt file content in memory: AES.GCM.open(sealedBox, using: DEK)
6. Pass plaintext to rendering pipeline (never write to disk in plaintext)
7. Zero DEK from memory on file close (explicit memory zeroing)
```

**Critical gap in spec**: The spec states "Files never transit XQ infrastructure." The XQ API documentation must confirm that the `encrypt()` call only transmits the DEK (or a key fragment) to XQ — not the file content. If file content is passed to any XQ API endpoint, this contradicts the spec's core data residency claim. This must be verified against the XQ API specification at `https://xq.stoplight.io/` before implementation.

### 5.3 Offline File Encryption

Offline files represent the highest risk for data-at-rest attacks. Requirements:

- All offline files must be stored with iOS Data Protection class `NSFileProtectionComplete` — this means they are cryptographically inaccessible when the device is locked. This is enforced by passing the `.completeFileProtection` attribute when writing files.
- Do not rely on iOS Data Protection alone — it is one layer. The XQ-level AES-256-GCM encryption must be applied first, then stored with `.completeFileProtection`. The result is two independent encryption layers.
- The offline cache directory must be excluded from iCloud backup: set `isExcludedFromBackupKey = true` on the URL.
- Offline cache TTL must be enforced: when the TTL expires, the cached DEK is deleted and the file becomes inaccessible (the file bytes remain but are undecryptable). This implements "auto-expiring" without requiring connectivity.
- Cache location: use `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` — this directory is not accessible to other apps. Do NOT use the documents directory which may be exposed via Files.app if the app declares UIFileSharingEnabled.

### 5.4 Transit Encryption — TLS and Certificate Pinning

All network communication must use TLS 1.2 minimum; TLS 1.3 preferred. iOS 17's App Transport Security (ATS) enforces TLS 1.2 minimum by default.

**Certificate Pinning Implementation:**

Certificate pinning on iOS is implemented via `URLSessionDelegate` with `urlSession(_:didReceive:completionHandler:)`. The correct approach for this app:

- Pin to intermediate CA certificate(s), not leaf certificates (leaf certificates rotate more frequently). Alternatively, pin to the public key of the leaf certificate (SPKI pinning).
- For XQ API endpoints: pin XQ's known intermediate or root CA SPKI hash
- For IDP endpoints (Entra, Okta, Google, Ping): do NOT pin IDP endpoints if they use large certificate pools (e.g., Google and Okta use CDN-based certificate issuance with rotating leaf certs). Instead, pin to the well-known intermediate CAs and implement strict hostname validation.
- Backup pins: always ship at least two pins (current + next). A single pin without a backup creates a single point of failure that can brick the app if the pinned certificate expires.
- Pin update mechanism: pins must be remotely updatable via the dynamic configuration system, but the update mechanism itself must be authenticated (signed configuration update) and must use a pre-pinned connection to retrieve the new pins.

**URLSession configuration for all XQ API calls:**
- `allowsCellularAccess = true` (required for mobile)
- `waitsForConnectivity = false` (fail fast — do not queue indefinitely when policy cannot be verified)
- `timeoutIntervalForRequest = 30` seconds (prevent indefinite waits)
- Custom `URLSessionDelegate` implementing certificate pinning for all sessions

---

## 6. SECURE CONTAINER IMPLEMENTATION

### 6.1 Data Entry Controls

Files may only enter the secure container through these explicitly guarded pathways:

**Pathway 1 — SharePoint / Repository Stream:**
- Files stream directly into the secure rendering pipeline
- Never written to iOS filesystem in plaintext at any point
- Streamed bytes encrypted with DEK before any disk write
- Memory buffer holding plaintext zeroed after encryption

**Pathway 2 — Local File Import:**
- User selects file via `UIDocumentPickerViewController` (the system picker — use this, not a custom file browser, to avoid needing broad filesystem permissions)
- File is read into memory, immediately scanned by on-device AI
- Encrypted with new DEK before written to secure container
- Original file in the Files app or camera roll is NOT deleted by default (this is important — the user retains the original; the app's job is to protect the copy it holds)

**Pathway 3 — Document Scanner (Camera):**
- Camera frames must not be written to the camera roll or photo library
- Use `AVFoundation` with a custom capture session, not `UIImagePickerController` (which may write to photo library)
- Scanned document content is processed in memory, never persisted as a raw image

**Pathway 4 — Email Attachments (Phase 2):**
- Attachments must be decrypted in memory for viewing; never written to a temp directory in plaintext
- If a temp file is necessary for rendering (e.g., for QuickLook), it must be written with `.completeFileProtection`, rendered, then securely deleted

### 6.2 Data Egress Controls

Files may only leave the container through these governed exits:

**Exit 1 — Approved Secure Share Workflow:**
- User must invoke the explicit "Share Securely" flow
- AI risk evaluation must complete before share options are presented
- Enterprise policy must validate the recipient
- Audit event created before transmission

**Exit 2 — Policy-Approved Email Delivery (Phase 2):**
- Content must remain under XQ encryption for external delivery
- Recipient must have XQ account for XQ-to-XQ encrypted sharing
- External recipients receive a link that requires authentication, not a raw attachment

**Exit 3 — Repository Synchronization:**
- Modified files sync back to SharePoint / source
- Sync must re-encrypt with the same DEK before transmission
- Sync must not bypass the XQ policy check (no "background sync as a way to exfiltrate")

**What is explicitly blocked:**
- `UIActivityViewController` (share sheet) — the app must not invoke the standard iOS share sheet with protected file content. If implemented, it must filter activities to only XQ-approved extensions.
- Drag and drop: `UIDragInteraction` must be disabled on protected content views. On iPad, drag-and-drop between apps is a serious data leakage risk.
- Copy to pasteboard: `UIPasteboard.general` writes must be blocked for protected content. Note that iOS 14+ notifies users when apps read from the pasteboard, creating a privacy signal if the app accidentally reads instead of writes.
- "Open In" / "Open With": `application(_:open:options:)` and `UIDocumentInteractionController` must not be used to open protected files in third-party apps
- AirDrop: AirDrop receiving protected files into another app is blocked because the container controls egress, not ingress. AirDrop sending of files from within the app must be blocked via share sheet filtering.

### 6.3 DLP Enforcement Mechanisms

**Screenshot Mitigation:**
iOS does not allow blocking screenshots completely (this is a deliberate Apple design decision for privacy). The available controls are:

1. `UITextField` with `isSecureTextEntry = true` draws with a system-level obscuring layer that prevents screenshots. This pattern can be applied to custom content via overlaying a secure text field, but it produces visual artifacts. Not recommended for document rendering.
2. Subscribe to `UIApplication.userDidTakeScreenshotNotification` — this fires AFTER the screenshot is taken. The screenshot cannot be prevented, but the app can log the event and alert the user/admin.
3. Subscribe to `UIScreen.capturedDidChangeNotification` — this fires when screen recording starts or stops. When `UIScreen.main.isCaptured` is true, the app should blur or black-out the content immediately.
4. Dynamic watermarking: render user identity (email, user ID), timestamp, and device ID as a semi-transparent overlay on all protected content. This enables attribution but does not prevent capture.

**The honest security statement for the spec**: Screenshot prevention is not technically possible on iOS for third-party apps. The app can detect screenshots after the fact and detect screen recording before/during. The spec's language "Screenshot blocking where iOS APIs permit" is the accurate framing — implement detection, detection-triggered protective response (blur/black the view on recording detection), watermarking for attribution, and audit logging.

**Background Blur:**
```swift
// Implement in AppDelegate or using UIApplication lifecycle
func applicationWillResignActive(_ application: UIApplication) {
    // Add blur overlay BEFORE the app snapshot is taken for the app switcher
    // This must happen synchronously in this method, before returning
    securityOverlay.isHidden = false
    blurEffectView.alpha = 1.0
}

func applicationDidBecomeActive(_ application: UIApplication) {
    // Require biometric re-auth before removing blur
    authenticateWithBiometrics { success in
        if success {
            self.securityOverlay.isHidden = true
        }
    }
}
```
The key timing constraint: the blur must be applied in `applicationWillResignActive`, not `applicationDidEnterBackground`. The app switcher snapshot is taken during `willResignActive`. If blur is applied in `didEnterBackground`, the unblurred content appears in the app switcher.

**Copy/Paste Restriction:**
Override `copy:`, `cut:`, `paste:` in the custom document renderer's UIResponder. Return `false` from `canPerformAction(_:withSender:)` for copy/cut actions on protected content. For text views, set `isSelectable = false` or `allowsEditingTextAttributes = false`. Note that a determined user can still dictate or type content from memory — copy prevention reduces casual leakage but is not absolute.

**Share Sheet Filtering:**
When a share sheet is necessary (for the governed sharing flow), use `UIActivityViewController` with an explicit `excludedActivityTypes` list. This list must include at minimum:
- `.airDrop` (unless explicitly enabled by policy for a specific share)
- `.copyToPasteboard`
- `.print` (unless policy permits printing)
- `.saveToCameraRoll`
- `.addToReadingList`
- All third-party action extensions that are not XQ-approved

iOS 17+ provides `allowedActivityTypes` as an alternative that whitelists rather than blacklists — use `allowedActivityTypes` (whitelist) instead of `excludedActivityTypes` (blacklist). Whitelist is a stronger security posture.

### 6.4 iOS API-Specific Limitations — What Cannot Be Blocked

This section provides the honest security posture for the product:

| Claimed Control | Reality | Recommended Approach |
|----------------|---------|---------------------|
| Screenshot blocking | Impossible on iOS for third-party apps | Detection + watermark + audit log |
| Screen recording prevention | Cannot prevent, only detect via `UIScreen.isCaptured` | Detect and blur/black content immediately |
| Copy prevention from custom renderers | Effective for custom views; not for OS-rendered content via QuickLook | Use custom renderers, not QuickLook, for sensitive content |
| Drag and drop blocking | `UIDragInteraction` can be disabled on specific views | Disable drag interactions on all protected content views |
| Prevent all share sheet usage | Share sheet can be triggered by Shortcuts automations | No complete solution; whitelist-based filtering is best effort |
| Block camera-based capture | Impossible | Watermarking for attribution |
| Block iCloud Photo Library in the background | Cannot intercept system photo capture | N/A — this is device-level, outside app scope |
| Prevent AirPlay mirroring | Cannot prevent system AirPlay; can detect via `UIScreen.screens.count > 1` | Detect external display and blank/blur the mirrored output |

---

## 7. AI SECURITY

### 7.1 Risk of Sending Data to Cloud AI

This is the most critical AI security issue in the spec. The `AIProvider` interface supports cloud providers (OpenAI, Anthropic, AWS Bedrock, Azure OpenAI). If document content is passed to `classify(document: Data)` or `generateSummary(text: String)` on a cloud AI adapter, the following applies:

- **GDPR Article 28**: Document content transmitted to an AI provider makes that provider a data processor. A Data Processing Agreement (DPA) with each provider is legally required before any EU personal data is processed.
- **HIPAA**: PHI transmitted to cloud AI without a signed BAA with the provider is a HIPAA violation. OpenAI, Anthropic, and AWS all offer BAAs in their enterprise tiers, but this must be contractually verified before enabling cloud AI for PHI content.
- **CUI**: Controlled Unclassified Information cannot be sent to commercial cloud AI services without explicit government authorization. The spec targets this data category. A local-only model is not optional for CUI — it is legally mandatory.
- **XQ's "no data leaves device" claim**: Sending document content to any cloud AI endpoint directly contradicts this claim. The product's core value proposition is violated.

### 7.2 Local-First AI Requirement

The default must be local. The `AIProvider` interface must implement a policy gate that is evaluated before every inference call:

```swift
protocol AIProvider {
    var requiresNetworkAccess: Bool { get }
    var permittedContentClassifications: Set<ContentClassification> { get }
    
    func classify(document: Data) async throws -> ClassificationResult
}

// Policy gate — must be called before any AIProvider method
class AIProviderPolicyGate {
    func selectProvider(
        for content: ClassifiedContent,
        tenantPolicy: TenantAIPolicy
    ) -> AIProvider {
        // Rule 1: CUI content → local only, always, no override
        if content.classification == .cui {
            return localCoreMLProvider
        }
        // Rule 2: PHI content → local only unless BAA confirmed in tenant policy
        if content.classification == .phi && !tenantPolicy.cloudAIBAAConfirmed {
            return localCoreMLProvider
        }
        // Rule 3: Cloud AI disabled for tenant
        if !tenantPolicy.cloudAIEnabled {
            return localCoreMLProvider
        }
        // Rule 4: Offline → local only
        if !networkMonitor.isConnected {
            return localCoreMLProvider
        }
        // Rule 5: Explicit enterprise opt-in for cloud AI
        return tenantPolicy.preferredCloudProvider ?? localCoreMLProvider
    }
}
```

The local model must be functional for all Phase 1 classification requirements (PII, PHI, CUI detection, sensitivity scoring) without cloud dependency.

### 7.3 Enterprise Policy for Cloud AI

Enterprise admins must explicitly configure cloud AI permission. The policy bundle must include:

- `cloudAIEnabled: Bool` — global on/off for cloud AI in this tenant
- `cloudAIPermittedClassifications: [ContentClassification]` — which sensitivity levels may use cloud AI (e.g., only Public and Internal)
- `cloudAIProvider: CloudAIProviderType` — which provider (OpenAI, Anthropic, etc.)
- `cloudAIBAAConfirmed: Bool` — admin attestation that a BAA is in place (required for PHI)
- `cloudAIDataResidencyRegion: String` — enforce region-specific AI endpoints if required (EU data residency)

These policy settings must be received from the enterprise admin via the authenticated XQ policy channel and must be enforced at the `AIProviderPolicyGate` level before any content is transmitted.

### 7.4 AI Interaction Audit Logging

Every AI inference call that processes document content must be logged:

- Timestamp
- User identity
- File identifier (not file content)
- AI provider used (local vs. cloud; if cloud, which provider)
- Classification result and confidence score
- Whether the result was overridden by user or admin
- Policy applied based on classification result

For cloud AI calls, additionally log:
- Network endpoint contacted
- Data volume transmitted (bytes)
- Response latency
- Any error or refusal from the AI provider

---

## 8. RUNTIME PROTECTIONS (iOS-Specific)

### 8.1 Jailbreak Detection Implementation

Jailbreak detection must be multi-signal, not single-check. A single-check approach (e.g., only checking for Cydia.app) is bypassed by detection-evasion libraries within minutes of their publication. The following signals must be evaluated in combination:

**Signal Group 1 — Filesystem checks:**
- Check for existence of known jailbreak artifacts: `/Applications/Cydia.app`, `/private/var/lib/apt`, `/usr/sbin/sshd`, `/etc/apt`, `/private/var/stash`, `/usr/bin/ssh`, `/.bootstrapped_unc0ver`
- Attempt to write to `/private/test_jailbreak_write` — non-jailbroken apps cannot write outside their sandbox; if this succeeds, the device is compromised
- Check if `/bin/sh` is accessible: `FileManager.default.fileExists(atPath: "/bin/sh")`

**Signal Group 2 — Dynamic library injection detection:**
- Check loaded dylibs via `_dyld_image_count()` and `_dyld_get_image_name()` for known hooking frameworks: `substrate`, `cycript`, `frida`, `cynject`, `libhooker`
- `DYLD_INSERT_LIBRARIES` environment variable check — if set, it indicates dylib injection

**Signal Group 3 — Process integrity:**
- Attempt to call `fork()` — sandboxed apps cannot fork; if `fork()` returns 0 or positive, the device is jailbroken
- Check for `PT_DENY_ATTACH` bypass indicators — attach a signal handler for `SIGKILL` and detect if a debugger is attached via `sysctl` with `CTL_KERN`, `KERN_PROC`, `KERN_PROC_PID`
- Validate code signature via `SecStaticCodeCheckValidity`

**Signal Group 4 — Behavioral checks:**
- OpenURL scheme test: attempt to open `cydia://` — if the app can open this URL, Cydia is installed
- Symbolic link check: `/var/lib/undecimus`, `/usr/lib/tweaks` — jailbreaks often create symlinks into normally inaccessible areas

**Signal Group 5 — Apple App Attest:**
- Use `DCAppAttestService.shared.attestKey(_:clientDataHash:completionHandler:)` for cryptographic device integrity verification. This is the most reliable signal because it is hardware-backed via Apple's Secure Enclave attestation chain. Verify the attestation on the XQ backend — do not validate it client-side only.

**Response to detected compromise:**
Do not simply show an error and exit — this is easily bypassed by patching the check. Instead, implement a grace degradation:
1. Log the detection event to the secure audit channel
2. Alert the enterprise admin via the XQ backend
3. Force re-authentication via IDP
4. Drop to read-only mode (no offline cache access)
5. Clear in-memory keys
6. For enterprise deployments: trigger a policy-driven wipe of the offline cache
7. Present user with a message explaining device integrity requirements

The message must not say "jailbreak detected" (which helps the attacker know which specific check triggered) — say "device security requirements are not met."

### 8.2 Screenshot Prevention and Detection

As documented in Section 6.3, screenshots cannot be prevented. The implementation:

```swift
// Detect screen capture (recording) — implemented in the file viewer
NotificationCenter.default.addObserver(
    forName: UIScreen.capturedDidChangeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    if UIScreen.main.isCaptured {
        // Immediately blank/blur the content
        self?.applySecurityOverlay()
        // Log to audit trail
        self?.auditLogger.log(event: .screenRecordingDetected, fileId: self?.currentFileId)
        // Optionally alert admin for high-sensitivity content
        if self?.currentClassification.isHighSensitivity == true {
            self?.alertAdminOfRecordingAttempt()
        }
    } else {
        // Recording stopped — require biometric re-auth before restoring content
        self?.requireBiometricBeforeRestoringContent()
    }
}

// Detect screenshot after the fact
NotificationCenter.default.addObserver(
    forName: UIApplication.userDidTakeScreenshotNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.auditLogger.log(event: .screenshotTaken, fileId: self?.currentFileId)
    // For Restricted content: alert user that the screenshot was logged
    self?.showScreenshotCapturedWarning()
}
```

### 8.3 Screen Recording Detection

`UIScreen.main.isCaptured` returns true when:
- iOS Screen Recording (Control Center) is active
- AirPlay mirroring is active to an Apple TV or another Mac
- Sidecar (iPad as Mac display) is active
- ReplayKit recording is active

On detection, immediately blank the content view. This protects against the most common screen recording scenarios.

**Limitation**: On jailbroken devices, `UIScreen.main.isCaptured` can be hooked to return false even when recording is active. This is why jailbreak detection is a prerequisite control.

### 8.4 Background Blur Implementation

```swift
// In SceneDelegate — use scene lifecycle, not app lifecycle, for multi-window iPad support
func sceneWillResignActive(_ scene: UIScene) {
    // CRITICAL: Must be applied here, before snapshot is taken
    guard let windowScene = scene as? UIWindowScene else { return }
    windowScene.windows.forEach { window in
        window.addSubview(securityBlurView)
        securityBlurView.frame = window.bounds
    }
}

func sceneDidBecomeActive(_ scene: UIScene) {
    // Require biometric before removing
    LocalAuthentication.authenticate(reason: "Unlock XQ Workspace") { success, _ in
        DispatchQueue.main.async {
            if success {
                self.securityBlurView.removeFromSuperview()
            }
            // If biometric fails: keep the blur, show auth prompt
        }
    }
}
```

The blur overlay must be added to the window, not the view controller — otherwise it won't appear in the app switcher snapshot on iPad split-screen.

### 8.5 Copy/Paste Restriction

For custom document renderers:

```swift
class ProtectedDocumentView: UIView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Block copy, cut, paste, select all on protected content
        let blockedActions: [Selector] = [
            #selector(copy(_:)),
            #selector(cut(_:)),
            #selector(UIResponderStandardEditActions.paste),
            #selector(UIResponderStandardEditActions.selectAll)
        ]
        if blockedActions.contains(action) {
            auditLogger.log(event: .copyAttemptBlocked)
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    // Prevent the edit menu from appearing at all
    override var canBecomeFirstResponder: Bool { false }
}
```

**Important limitation**: If the document is rendered by a `WKWebView` or `UITextView`, copy prevention is harder — `WKWebView` has `configuration.preferences._allowCopy = false` (private API, do not use) and there is no reliable public API to prevent copy from `UITextView`. Use custom rendering for sensitive content. This is why the spec should use custom rendering pipelines rather than delegating to QuickLook for high-sensitivity content.

### 8.6 Share Sheet Filtering

```swift
// When a governed share must be presented — use whitelist, not blacklist
let activityVC = UIActivityViewController(
    activityItems: [sharedItem],
    applicationActivities: [XQSecureShareActivity()] // Custom XQ sharing action
)

// Whitelist ONLY XQ-approved activities
if #available(iOS 16.0, *) {
    // iOS 16+ supports allowedActivityTypes
    activityVC.allowedActivityTypes = [.xqSecureShare] // Custom type only
} else {
    // iOS 15 and below: use exclusion list
    activityVC.excludedActivityTypes = UIActivity.ActivityType.allSystemActivityTypes
        .filter { !allowedTypes.contains($0) }
}
```

For maximum security, do not use `UIActivityViewController` at all for the secure sharing flow. Implement a fully custom sharing UI that presents only XQ-governed options. This eliminates the share sheet attack surface entirely for the primary sharing workflow.

---

## 9. POLICY ENFORCEMENT SECURITY

### 9.1 RBAC/ABAC Model

The spec correctly identifies RBAC + ABAC as the required model. The implementation must enforce these server-side — client-side enforcement is advisory only.

**RBAC (Role-Based Access Control):**
- Roles are defined in the enterprise admin console and delivered via the authenticated policy channel
- Core roles for Phase 1: `User`, `PowerUser`, `Admin`, `ViewOnly`, `External`
- Role-to-permission mappings must be stored in the XQ backend, not in the app
- The app fetches the user's effective permissions at session establishment and caches them for the session duration
- Critical rule: never infer permissions from JWT claims alone — always validate against the XQ policy service for sensitive operations

**ABAC (Attribute-Based Access Control):**
- Attributes flow from: IDP user profile (department, clearance level, group memberships), device posture score, content classification, location, time
- The fuzzy logic policy engine described in the spec is the ABAC evaluation engine
- ABAC policies are authored by enterprise admins and delivered as signed policy bundles
- Policy bundle signature must be verified before application: RSA-PSS or ECDSA signature by XQ admin CA

**Enforcement architecture:**
- Permissions are evaluated at both the XQ backend (authoritative) and locally (for UX responsiveness)
- Local enforcement is used only to pre-filter UI options (e.g., hide "Download" button for view-only users) — not as a security control
- All actual access decisions (decryption key retrieval, share creation, offline cache write) must be validated by the XQ backend
- A client that bypasses local RBAC enforcement still hits the server-side policy check — local enforcement is a UX optimization, not a security boundary

### 9.2 Group-Based Controls

The spec describes Gmail groups as governance containers. The security implications:

- Group membership must be verified via the IDP or XQ backend — a user cannot self-assert group membership
- Group policy inheritance: when a file is shared to a group, the policy applied must be the intersection of the file owner's sharing permissions and the group's policy. The more restrictive policy wins.
- Group membership changes (user added/removed) must propagate to XQ key service within the policy-defined window. For high-sensitivity groups, this must be near-real-time.
- Shared folder encryption: all members of a shared workspace must have their public key in the XQ key service. When a member is removed, the shared folder key must be rotated (re-wrap for remaining members) — the removed member's access must not be maintained via their previously-obtained key copy.

### 9.3 IDP Attribute Enforcement

IDP attributes (from Entra, Okta, Google) must be verified at token issuance and refreshed on token renewal:

- `groups` claim: list of security groups the user belongs to — used for RBAC
- `department`, `jobTitle`, `officeLocation`: used for ABAC policies (e.g., "Finance department can access financial records")
- `deviceId` (Entra): device compliance state from Intune
- Custom claims configured by enterprise admin for their specific ABAC requirements

The app must not trust client-modifiable attributes. All IDP attributes must arrive via the signed JWT or the IDP's userinfo endpoint over a pinned connection.

### 9.4 Geofencing Implementation

Geofencing for data access control on iOS requires careful implementation:

- Use `CLLocationManager` with `requestWhenInUseAuthorization()` — do not request "always" authorization for a productivity app; this will reduce App Store approval risk and user trust
- For policy evaluation at file open: use `CLLocation` to determine current position against policy-defined geofences
- Geofence regions are specified in the policy bundle as GeoJSON or lat/lng + radius pairs
- Geofence check must be server-validated for high-sensitivity content: transmit current location to XQ policy service at file open time; local geofence check is pre-screening only
- When location permission is denied: fail closed for files with geofencing policies — do not grant access when the location cannot be verified

**Privacy consideration**: Location data transmitted to XQ backend for geofence verification must be disclosed in the app's privacy manifest (`PrivacyInfo.xcprivacy`) as required by Apple since iOS 17. The data must not be retained beyond the access decision.

**Geofencing accuracy**: iOS location accuracy varies (10m to 1km depending on signal). Geofence enforcement should use `kCLLocationAccuracyHundredMeters` or better; do not apply strict geofencing at building level via GPS alone without additional signals.

### 9.5 Dynamic Policy Update Security

Policy updates must be authenticated and integrity-protected:

```
Policy Update Flow:
1. App receives push notification that a policy update is available
   (or polls at configurable interval — default: 15 minutes)
2. App fetches policy bundle from XQ API over pinned TLS connection
3. App verifies policy bundle signature using stored XQ admin public key
   (policy signing key separate from API certificate)
4. App verifies policy bundle version number is monotonically increasing
   (reject rollback attacks — old policy versions must not override new ones)
5. App verifies policy bundle applies to this tenant + device
6. App applies new policy
7. App logs policy update receipt in local audit log
8. App re-evaluates all current access grants against new policy
   → Active file sessions re-evaluated immediately
   → Offline cache TTLs re-evaluated
   → Shared workspace memberships re-evaluated
```

**Policy rollback protection**: Store the current policy version number in Keychain (tamper-resistant). Reject any policy bundle with a version number equal to or less than the stored version. This prevents an attacker from replaying an older, more permissive policy.

---

## 10. AUDIT & COMPLIANCE

### 10.1 Required Audit Events

Every event in this list must generate an immutable audit record. This is non-negotiable for enterprise deployments.

**Authentication and Session Events:**
- User login (success/failure, IDP used, MFA method)
- Token refresh (success/failure)
- Session timeout / expiry
- Biometric authentication (success/failure)
- Device registration / deregistration
- MFA challenge issued
- Failed login lockout triggered

**File Access Events:**
- File opened (file ID, classification, user, device, timestamp, location hash)
- File viewed for duration (how long a file was open)
- File closed
- File downloaded / cached offline (user, device, file, policy that permitted it)
- Offline cache expiry / deletion
- File not accessible (policy denial — what policy, what reason)

**Sharing Events:**
- Share initiated (who, what file, what recipients, what permissions)
- Share link created (expiry, access type, geofence if applied)
- Share link accessed (by whom, when, from where)
- Share revoked (by whom, when)
- Share expiration triggered automatically

**Policy Events:**
- Policy bundle received and applied (version, timestamp)
- Policy violation detected (what rule, what action was blocked)
- AI classification result (file, result, confidence, provider used)
- User override of AI classification
- Admin override of AI classification or user permission

**Security Events:**
- Jailbreak detection triggered
- Screen recording detected
- Screenshot taken
- Certificate pinning failure
- Suspicious activity pattern detected
- Runtime integrity check failure
- App Attest failure

**Admin Events:**
- Admin login
- Policy created/modified/deleted
- User access escalation/revocation
- Audit log export
- Classification schema change

### 10.2 Audit Log Tamper Protection

Local audit logs (for offline scenarios) must be tamper-evident:

- Each log entry must be signed or HMACed using a key derived from the Secure Enclave root key
- Log entries are append-only — no modification or deletion API exists
- Log entries are chained: each entry includes a hash of the previous entry (blockchain-style chain of custody)
- When connectivity is restored, local audit logs are transmitted to the XQ backend over the pinned TLS connection
- Local audit log is a secondary record; the authoritative audit trail lives on the XQ backend
- If an attacker deletes the local log, the gap is detectable by the backend when the chain breaks

**Audit log data minimization**: Audit logs must not contain file content, encryption keys, or personal data beyond what is necessary for the audit event. Log file IDs (opaque identifiers), not file names. Log user IDs, not email addresses in the log record itself (resolve to email in the audit UI).

### 10.3 NIST Alignment

The following NIST controls are relevant to Phase 1 and must be addressed:

| NIST SP 800-53 Control | Relevance | Implementation |
|-----------------------|-----------|----------------|
| AC-2 (Account Management) | User and admin account lifecycle | IDP integration for provisioning/deprovisioning |
| AC-3 (Access Enforcement) | File and feature access control | RBAC/ABAC via XQ policy + IDP |
| AC-4 (Information Flow Enforcement) | Data cannot leave the container | Secure container model, egress controls |
| AC-17 (Remote Access) | SharePoint/repository access from device | TLS, certificate pinning, device registration |
| AU-2 (Event Logging) | What events to log | Section 10.1 above |
| AU-9 (Audit Record Protection) | Tamper-evident logs | HMAC chaining, Secure Enclave signing |
| AU-12 (Audit Record Generation) | Audit at every access decision point | Comprehensive event coverage |
| IA-2 (Identification and Authentication) | MFA for all users | IDP MFA enforcement |
| IA-5 (Authenticator Management) | Token storage and rotation | Keychain + Secure Enclave |
| SC-8 (Transmission Confidentiality) | TLS for all network traffic | TLS 1.3 + certificate pinning |
| SC-28 (Protection of Information at Rest) | Encrypted offline cache | AES-256-GCM + NSFileProtectionComplete |
| SI-3 (Malware Protection) | Jailbreak / runtime integrity | Jailbreak detection + App Attest |
| SI-7 (Software, Firmware, Integrity) | App integrity | Code signing + App Attest |
| CM-7 (Least Functionality) | Minimal permissions, no unnecessary features | Capability minimization, Info.plist permissions review |
| SC-12 (Cryptographic Key Management) | Key hierarchy, rotation, revocation | Secure Enclave KEK + XQ KMS |

### 10.4 Enterprise Compliance Requirements

| Regulation | Applicability | Key Requirements |
|-----------|--------------|-----------------|
| GDPR | Any EU personal data | Consent for telemetry; DPA with AI providers; right to erasure (delete user's encrypted files and keys) |
| HIPAA | PHI in enterprise health vertical | BAA with cloud AI providers before PHI classification; PHI audit logs retained 6 years |
| SOC 2 Type II | Enterprise SaaS tier | CC6 (logical access), CC7 (system operations), A1 (availability) — audit logging enables SOC 2 evidence |
| ISO 27001 | Enterprise certification | Information security management; the audit and policy systems provide the evidence trail |
| CMMC Level 2 | Defense industrial base (CUI) | Requires on-device-only AI for CUI; no cloud AI; detailed access logging; incident response plan |
| FedRAMP | Federal cloud authorization | If XQ SaaS targets federal customers; XQ API must be FedRAMP authorized or hosted in GovCloud |

---

## 11. SECURITY REQUIREMENTS MATRIX

| Feature | Security Requirement | Control | Verification Method |
|---------|---------------------|---------|-------------------|
| File import | All imported files encrypted before any disk write | AES-256-GCM with fresh DEK on import | Unit test: assert no plaintext on disk after import of test file |
| Offline cache | Cache encrypted and inaccessible outside app | AES-256-GCM + NSFileProtectionComplete + backup exclusion | Read app container via iExplorer or backup extraction tool; verify ciphertext only |
| Session tokens | Refresh tokens never written to plist, UserDefaults, or logs | Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly | Static analysis: grep for UserDefaults, FileManager writes in auth layer |
| Jailbreak detection | App degrades securely on jailbroken device | Multi-signal detection + App Attest | Test on jailbroken device via checkra1n or unc0ver; verify behavior |
| Screenshot | Screenshots logged and watermarked | UIApplication.userDidTakeScreenshotNotification + dynamic watermark | Test by taking screenshot during document view; verify audit log entry and watermark |
| Screen recording | Content blurred on recording detected | UIScreen.capturedDidChangeNotification → overlay applied | Test with iOS Screen Recording; verify content is obscured |
| Background blur | App blurred before switcher snapshot | Applied in sceneWillResignActive | Background app during document view; verify blur in switcher |
| Certificate pinning | All XQ API calls pinned | URLSessionDelegate with SPKI pinning | Use Charles Proxy with rogue certificate; verify connection failure |
| AI provider gate | Cloud AI not invoked for CUI/PHI without policy permission | AIProviderPolicyGate before every inference call | Unit test: assert localCoreMLProvider selected for CUI content; integration test with mock cloud provider |
| Copy prevention | Copy from protected document view blocked | canPerformAction override on custom renderer | Manual test: long-press in document view; verify no Copy option |
| Drag-and-drop | Drag disabled on protected content | UIDragInteraction disabled | iPad: attempt drag from document view to Files.app; verify blocked |
| Share sheet | Only XQ-approved destinations presented | UIActivityViewController.allowedActivityTypes or custom share UI | Invoke share during document view; verify AirDrop, Save to Files not available |
| OAuth redirect | Universal links used; no custom URL schemes | ASWebAuthenticationSession with HTTPS callback URL | Check Info.plist for CFBundleURLTypes; verify no xq:// scheme for OAuth |
| PKCE | PKCE required for all IDP flows | AppAuth-iOS / MSAL enforces PKCE | Capture OAuth request in Charles; verify code_challenge and code_challenge_method=S256 |
| Dynamic revocation | Access revoked within policy window | XQSecureAPI.validateAccess() called at file open | Revoke user in admin console; attempt file open; verify denial within SLA window |
| Geofencing | Files with geo policy inaccessible outside region | CLLocation check + server validation at file open | Enable geo policy; open file outside region; verify denial |
| Audit logging | All access events logged | Audit logger called at every decision point | Open file, share file, reject access; verify all events appear in admin audit view |
| Audit tamper protection | Local logs HMAC-chained | Secure Enclave-derived HMAC on each entry | Modify local log entry; verify chain break is detected on next sync |
| AI classification | PII detected in test document | On-device CoreML model | Pass known-PII test documents; verify correct classification ≥ 95% accuracy |
| Policy bundle | Policy signature verified before application | ECDSA signature verification on receipt | Tamper policy bundle bytes; verify rejection |
| App Attest | Device integrity verified at registration | DCAppAttestService.shared.attestKey | Test on simulator (expected failure); test on physical device (expected success) |
| iCloud backup exclusion | Offline cache excluded from backup | isExcludedFromBackupKey = true | Backup device; restore to new device; verify offline cache absent |
| Memory zeroing | Decryption keys zeroed after file close | Explicit memory zeroing in cleanup | Memory dump (on jailbroken test device) after file close; verify key not present |

---

## 12. SECURE CODING GUIDANCE — TOP 10 RULES FOR THIS APP

These are the ten rules that, if violated, directly undermine the product's security guarantees. They are ordered by blast radius.

**Rule 1: The Secure Enclave is the root of trust — never bypass it.**
All key material must originate from or be bound to the Secure Enclave. Never generate encryption keys using `UUID().uuidString` or `Data.random(count:)` without a Secure Enclave anchor. Use `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave` for root keys. Treat any code that handles raw key bytes without Secure Enclave involvement as a security defect.

**Rule 2: Plaintext file content never touches the filesystem.**
Decrypted file bytes exist only in RAM. When a file is opened for rendering, decrypt into a `Data` or `UnsafeRawBufferPointer`, pass to the renderer, and zero the buffer when the renderer closes. Use `memset_s()` (from Security.framework) for zeroing — the compiler will not optimize away `memset_s` unlike plain `memset`. Any `FileManager.createFile` call with unencrypted file content is a defect.

**Rule 3: All network calls to XQ API and IDP endpoints go through the certificate-pinned URLSession. No exceptions.**
Create a single `NetworkSession` class that owns the pinned `URLSession`. Inject it everywhere via the protocol interface. If any call site creates its own `URLSession()` without pinning, the entire pinning model is bypassed. Enforce this with a linting rule or code review gate.

**Rule 4: AI inference on sensitive content defaults to local. Cloud AI requires an explicit two-gate check.**
Gate 1: is cloud AI enabled in tenant policy? Gate 2: does this content's classification permit cloud AI? Both gates must return true. If either gate is false, use the local CoreML model. This check must be in the `AIProviderPolicyGate`, not in individual AI call sites. No ad-hoc cloud AI calls.

**Rule 5: Never trust client-side enforcement for security decisions.**
Copy prevention, share sheet filtering, and RBAC-based UI hiding are UX conveniences — not security controls. The security control is at the XQ API (key retrieval validation) and at the iOS Data Protection layer (encrypted at rest). Code reviews must reject any pattern where a client-side RBAC check is the sole guard for a data access or write operation.

**Rule 6: OAuth redirect URIs must use HTTPS universal links, not custom URL schemes.**
Check `Info.plist` for `CFBundleURLTypes` — OAuth redirect URLs registered there are exploitable. The correct approach: register `https://app.xqmsg.co/oauth/callback` as an Associated Domain, use `ASWebAuthenticationSession` with this URL. Any `xq://`, `xqsecure://`, or similar custom scheme in the OAuth flow is a defect.

**Rule 7: Jailbreak detection must precede key access.**
The jailbreak check is not a one-time splash screen check. It must be evaluated before every sensitive operation: before decrypting a file, before accessing the Keychain refresh token, before any XQ API call. Implement it as a mandatory guard in the `SecurityContext` that is threaded through all sensitive operations via DI.

**Rule 8: Audit every access decision — success and failure.**
Security auditors need the full picture. Log access grants and access denials. Log the reason for denial (policy, revocation, location, classification). A log that only contains successful accesses hides insider attacks (they succeed). A log that only contains failures hides the context of what was allowed.

**Rule 9: Policy bundles must be signed, versioned, and monotonically advancing.**
Never apply a policy bundle without verifying its signature. Never accept a policy bundle with a version number equal to or lower than the currently applied version. Store the applied version in Keychain. This prevents replay attacks where an attacker replays an older, more permissive policy.

**Rule 10: Memory protection on the AI inference path.**
On-device AI models process plaintext document content. The inference path is a memory exposure risk. Apply these practices: run AI inference in a background thread with `QoS: .utility` (not `.userInteractive`) to limit memory priority; bound input size before inference (reject oversized inputs); zero the input `Data` buffer after inference completes; monitor for anomalously long inference times (could indicate model poisoning causing infinite loops).

---

## 13. CRITICAL RISKS — TOP 5 UNMITIGATED RISKS

These are the risks that exist in the architectural gaps of the current specification and have not been fully addressed by any control described in the spec.

**CRITICAL RISK 1: Jailbreak + In-Memory Key Extraction**
Severity: Critical | Exploitability: High (tools widely available)

The Secure Enclave protects the root key but not the derived session keys or decrypted DEKs that exist in memory during file rendering. On a jailbroken device with a kernel exploit, an attacker can read the app's memory space and extract the decryption key during an active rendering session. This attack is demonstrated by tools like Fridump3. The spec's jailbreak detection is the primary mitigation, but jailbreak detection can be bypassed using Frida/Substrate hooks if the app does not detect the hooking framework itself.

Residual risk: Even with robust jailbreak detection, a zero-day jailbreak may be undetected at the time of attack. There is no complete mitigation for this risk on iOS for any app that must render decrypted content to screen.

Recommendation: Implement anti-hooking detection (check for Substrate, Frida, libhooker in loaded dylibs). Minimize the window during which decrypted content is in memory. Limit the amount of content decrypted at once (paginate document rendering — decrypt only the visible portion). Accept this as a residual risk and communicate it clearly in the security model documentation.

**CRITICAL RISK 2: Consumer-to-Enterprise Key Transition**
Severity: High | Exploitability: Medium (requires timing the transition window)

The spec does not define the cryptographic protocol for transitioning files from consumer (Secure Enclave-only key) to enterprise (XQ KMS key) tier. During this transition, files exist in a state where enterprise policy cannot be applied because the keys are not under XQ KMS control. If the transition fails mid-way (network failure, app crash), files may remain in a permanently inaccessible state (consumer keys overwritten, enterprise keys not yet established) or in an ungoverned state (consumer keys not yet overwritten, but enterprise policy incorrectly believes they are under governance).

Recommendation: Define the transition protocol before Phase 1 release. The transition must be atomic from the cryptographic standpoint: re-encrypt with enterprise keys, verify the enterprise-key version is readable, then delete the consumer-key version. Use a two-phase commit model with rollback capability. Audit log the transition completion.

**CRITICAL RISK 3: Dynamic Policy Downgrade via Compromised XQ Infrastructure**
Severity: High | Exploitability: Low (requires XQ infrastructure compromise)

The entire dynamic policy system depends on the integrity of the XQ backend. If an attacker compromises the XQ policy delivery infrastructure (or a supply chain attack on XQ's deployment), they can deliver a downgraded policy bundle to all devices. Because the app applies received policies, this could disable DLP controls, enable cloud AI for CUI content, or disable geofencing — for all enterprise tenants simultaneously. Policy signature verification mitigates this only if the signing key is held in a hardware security module separate from the policy delivery infrastructure, and the private key is never exposed to the policy delivery system.

Recommendation: XQ must publish the policy signing certificate and its chain of custody. Enterprise customers should be able to pin the expected policy signing certificate. The XQ platform must implement policy signing with HSM-held keys and provide a transparency mechanism (certificate transparency-style log) for policy bundle issuance. Require XQ to document their policy signing key management as part of the enterprise SLA.

**CRITICAL RISK 4: AI Model Substitution Attack**
Severity: High | Exploitability: Medium (requires app sandbox compromise, which requires jailbreak)

The spec says AI models run locally on-device. On a jailbroken device, an attacker with write access to the app's data directory could substitute a permissive AI model — one that always classifies content as "Public" regardless of actual content. This would cause the policy engine to apply minimal restrictions to all content, effectively disabling the AI-driven governance layer while leaving the app appearing to function normally. The audit logs would show "Public" classifications for all content, concealing the attack.

Recommendation: AI models must be stored in the app bundle (signed by Apple, immutable) rather than in the writable app data directory. Model integrity must be verified at load time using a SHA-256 hash of the model file compared against a hard-coded expected hash in the binary. If the hash does not match, fall to fail-closed behavior (treat all content as Restricted until model integrity is restored via app update).

**CRITICAL RISK 5: Audit Log Gap During Offline Periods**
Severity: Medium-High | Exploitability: Medium (requires deliberate offline mode abuse)

A user who knows the audit log syncs when connectivity is restored could perform sensitive operations while offline (viewing Restricted content, offline caching files they should not cache) and then — before connectivity is restored — clear the app's local data, perform a factory reset, or simply not reconnect. The local audit log would be destroyed before it reaches the backend. This is an audit gap that enables insider threats to operate undetected during offline periods.

Recommendation: Require enterprise policy validation before granting offline access to high-sensitivity content (Restricted/CUI). For content where audit continuity is required, offline access must be disabled by policy. The offline audit log should be written to a tamper-evident store that survives app data clears where possible (Keychain entries survive app reinstall on unmanaged devices; on MDM-managed devices, the MDM can enforce audit log retention). Accept that unmanaged devices in offline mode have an irreducible audit gap and communicate this clearly in the enterprise security documentation with recommended mitigations (MDM enrollment, disable offline for Restricted content).

---

**Document Scope Note**: This analysis covers Phase 1 (Secure File Vault). The introduction of Secure Email (Phase 2) expands the attack surface significantly — email parsing, MIME handling, attachment rendering, and SMTP/IMAP credential management each introduce new vulnerability classes. Phase 2 should receive a dedicated threat model before development begins. Phase 3 Secure Chat introduces real-time messaging security (forward secrecy, key distribution, message ordering attacks) which requires Signal Protocol or equivalent — this deserves its own architecture review.

**Specification References**: `/Users/brianwane/agentic-lab/apps/IOSXQ/spec.txt` — reviewed in full. XQ API specification at `https://xq.stoplight.io/` and XQ SDK at `https://github.com/XQ-Message-Inc/` were not reviewed and must be reviewed before the encryption integration in Section 5.2 is implemented. The actual XQ key management model (whether XQ holds a key fragment, the full DEK, or only a policy-bound access token) materially affects the security architecture and the "files never transit XQ infrastructure" claim.