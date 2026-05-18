import Foundation
import PDFKit
import XQCore

// MARK: - Orchestrator

/// On-device AI orchestrator using regex-based NER to detect PHI, PII, PCI,
/// credentials, and financial data. Runs entirely in-process; no bytes leave
/// the device. CUI/PHI-local constraint is structural — this type holds no
/// network client and cannot be refactored to call a remote endpoint.
struct OnDeviceAIOrchestrator: AIOrchestrator {

    func provider(for sensitivity: SensitivityLevel, policy: PolicyBundle) -> any AIProvider {
        OnDeviceAIProvider()
    }

    func scanAndClassify(
        fileData: Data,
        mimeType: String,
        policy: PolicyBundle
    ) async throws -> AIClassificationResult {
        let start = Date()
        let text = extractText(from: fileData, mimeType: mimeType)
        let entities = detectEntities(in: text)
        let riskScore = calculateRisk(entities: entities)
        let sensitivity = inferSensitivity(entities: entities)
        let processingMs = Int(Date().timeIntervalSince(start) * 1000)

        return AIClassificationResult(
            fileId: UUID(),
            sensitivity: sensitivity,
            riskScore: riskScore,
            entities: entities,
            modelVersion: "OnDevice-NER-1.0",
            processingMs: max(processingMs, 1),
            wasCloudProcessed: false
        )
    }

    // MARK: - Text Extraction

    func extractText(from data: Data, mimeType: String) -> String {
        if data.isEmpty { return "" }
        switch mimeType {
        case "application/pdf":
            return extractPDFText(from: data)
        case let m where m.hasPrefix("text/"):
            return String(data: data, encoding: .utf8) ?? ""
        default:
            // "strings" approach: extract printable ASCII runs from binary/compressed data.
            // Catches uncompressed XML, metadata blocks, and plain-text fragments inside
            // Office ZIP archives (DOCX/XLSX/PPTX) without requiring a ZIP library.
            return extractPrintableStrings(from: data)
        }
    }

    private func extractPDFText(from data: Data) -> String {
        guard let doc = PDFDocument(data: data) else { return "" }
        return (0..<doc.pageCount)
            .compactMap { doc.page(at: $0)?.string }
            .joined(separator: "\n")
    }

    private func extractPrintableStrings(from data: Data, minRun: Int = 6) -> String {
        var result = [String]()
        var current = [UInt8]()
        current.reserveCapacity(256)
        for byte in data {
            if (byte >= 0x20 && byte < 0x7F) || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                current.append(byte)
            } else {
                if current.count >= minRun, let s = String(bytes: current, encoding: .utf8) {
                    result.append(s)
                }
                current.removeAll(keepingCapacity: true)
            }
        }
        if current.count >= minRun, let s = String(bytes: current, encoding: .utf8) {
            result.append(s)
        }
        return result.joined(separator: " ")
    }

    // MARK: - Entity Detection

    func detectEntities(in text: String) -> [AIEntity] {
        guard !text.isEmpty else { return [] }

        let hipaaBlock = CitedControl(
            framework: .hipaa,
            controlId: "HIPAA-164.502",
            title: "Uses and disclosures of protected health information",
            description: "Covered entities may not use or disclose PHI except as permitted by HIPAA.",
            enforcement: .block
        )
        let nistWarn = CitedControl(
            framework: .nistSP80053,
            controlId: "NIST-AC-3",
            title: "Access Enforcement",
            description: "Enforce approved authorizations for logical access to system resources.",
            enforcement: .warn
        )
        let nistAudit = CitedControl(
            framework: .nistSP80053,
            controlId: "NIST-AC-3",
            title: "Access Enforcement",
            description: "Enforce approved authorizations for logical access to system resources.",
            enforcement: .audit
        )
        let xqBlock = CitedControl(
            framework: .xqPolicy,
            controlId: "XQ-PCI-001",
            title: "Payment Card Data Protection",
            description: "PCI-scoped data must never be stored unencrypted or shared externally.",
            enforcement: .block
        )

        var entities = [AIEntity]()

        // PHI — SSN
        for m in find(#"\b\d{3}[- ]\d{2}[- ]\d{4}\b"#, in: text, max: 3) {
            entities.append(entity(.phi, value: "SSN: \(redactSSN(m))", confidence: 0.98, control: hipaaBlock))
        }
        // PHI — MRN / Patient ID
        for m in find(#"(?i)(?:MRN|Patient\s*ID|PatID|MR#)[\s:#]+[\w\-]{4,20}"#, in: text, max: 3) {
            entities.append(entity(.phi, value: m.trimmingCharacters(in: .whitespaces), confidence: 0.93, control: hipaaBlock))
        }
        // PHI — Date of Birth
        for m in find(#"(?i)(?:DOB|Date of Birth|D\.O\.B\.?)[\s:]+\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}"#, in: text, max: 2) {
            entities.append(entity(.phi, value: m.trimmingCharacters(in: .whitespaces), confidence: 0.91, control: hipaaBlock))
        }
        // PHI — Clinical context
        for m in find(#"(?i)(?:Diagnosis|Medication|Prescription|Treatment Plan)[\s:]+[^\n]{6,60}"#, in: text, max: 2) {
            entities.append(entity(.phi, value: m.trimmingCharacters(in: .whitespaces), confidence: 0.76, control: hipaaBlock))
        }
        // PCI — Credit card
        for m in find(#"\b(?:\d{4}[\s\-]){3}\d{4}\b"#, in: text, max: 2) {
            entities.append(entity(.pciData, value: "Card: \(maskCC(m))", confidence: 0.97, control: xqBlock))
        }
        // Credential — AWS key
        for m in find(#"AKIA[0-9A-Z]{16}"#, in: text, max: 2) {
            entities.append(entity(.credential, value: String(m.prefix(8)) + "…", confidence: 0.99, control: nistWarn))
        }
        // Credential — generic secret/token
        for m in find(#"(?i)(?:api[_\-]?key|secret[_\-]?key|access[_\-]?token|bearer|passwd|password)[\s:='"]+([A-Za-z0-9+/\-_.]{16,})"#,
                      in: text, max: 2, group: 1) {
            entities.append(entity(.credential, value: String(m.prefix(8)) + "…", confidence: 0.90, control: nistWarn))
        }
        // PII — Email
        for m in find(#"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#, in: text, max: 4) {
            entities.append(entity(.pii, value: m, confidence: 0.99, control: nistAudit))
        }
        // PII — US phone
        for m in find(#"(?:\+1[\s\-]?)?\(?\d{3}\)?[\s\-\.]\d{3}[\s\-\.]\d{4}"#, in: text, max: 3) {
            let v = m.trimmingCharacters(in: .whitespaces)
            guard !v.contains("/") else { continue }
            entities.append(entity(.pii, value: v, confidence: 0.83, control: nistAudit))
        }
        // Financial — revenue/budget amounts
        for m in find(#"(?i)(?:revenue|salary|budget|income|payment|invoice|contract value)[^\$\n]*\$\s*[\d,]+(?:\.\d{1,2})?\s*(?:M|B|K|million|billion|thousand)?"#,
                      in: text, max: 3) {
            entities.append(entity(.financial, value: m.trimmingCharacters(in: .whitespaces), confidence: 0.85, control: nistAudit))
        }

        return entities
    }

    // MARK: - Risk & Sensitivity

    func calculateRisk(entities: [AIEntity]) -> Int {
        guard !entities.isEmpty else { return 5 }
        let raw = entities.reduce(0) { acc, e in
            switch e.type {
            case .phi:        return acc + 25
            case .pciData:    return acc + 20
            case .credential: return acc + 18
            case .pii:        return acc + 10
            case .financial:  return acc + 8
            }
        }
        return min(raw, 100)
    }

    func inferSensitivity(entities: [AIEntity]) -> SensitivityLevel {
        if entities.contains(where: { $0.type == .phi || $0.type == .pciData }) { return .restricted }
        if entities.contains(where: { $0.type == .credential }) { return .confidential }
        if entities.filter({ $0.type == .financial }).count >= 3 { return .confidential }
        if entities.contains(where: { $0.type == .pii || $0.type == .financial }) { return .internal_ }
        return .internal_
    }

    // MARK: - Private Helpers

    private func entity(
        _ type: AIEntity.EntityType,
        value: String,
        confidence: Float,
        control: CitedControl
    ) -> AIEntity {
        AIEntity(id: UUID(), type: type, value: value, confidence: confidence, citedControl: control)
    }

    private func find(_ pattern: String, in text: String, max: Int, group: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range)
            .prefix(max)
            .compactMap { result -> String? in
                let g = group < result.numberOfRanges ? group : 0
                let r = result.range(at: g)
                guard r.location != NSNotFound else { return nil }
                return nsText.substring(with: r)
            }
    }

    private func redactSSN(_ ssn: String) -> String {
        let d = ssn.filter { $0.isNumber }
        return d.count == 9 ? "***-**-\(d.suffix(4))" : "***-**-****"
    }

    private func maskCC(_ cc: String) -> String {
        let d = cc.filter { $0.isNumber }
        return d.count >= 4 ? "****-****-****-\(d.suffix(4))" : "****-****-****-****"
    }
}

// MARK: - AIProvider wrapper

private struct OnDeviceAIProvider: AIProvider {
    let isLocalOnly = true

    func classify(fileData: Data, mimeType: String, policy: PolicyBundle) async throws -> AIClassificationResult {
        try await OnDeviceAIOrchestrator().scanAndClassify(fileData: fileData, mimeType: mimeType, policy: policy)
    }

    func extractEntities(from text: String, policy: PolicyBundle) async throws -> [AIEntity] {
        OnDeviceAIOrchestrator().detectEntities(in: text)
    }

    func scoreRisk(file: SecureFile, entities: [AIEntity], policy: PolicyBundle) async throws -> Int {
        OnDeviceAIOrchestrator().calculateRisk(entities: entities)
    }
}
