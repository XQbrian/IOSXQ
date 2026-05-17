import UIKit
import PDFKit
import XQCore

/// Generates realistic in-memory document content for the stub FileViewer.
///
/// For PDF MIME types this renders a single-page US-letter PDF with a
/// sensitivity-tinted header, a typeset body of content tailored to the
/// specific filename (financial, medical, legal, etc.), a diagonal
/// watermark, and a page footer. The output is a real `application/pdf`
/// byte stream consumed by `PDFDocumentView`.
///
/// For non-PDF MIME types (DOCX, XLSX, PPTX) the caller should fall back to
/// `genericDocumentPreview` — those formats are not rendered through
/// PDFKit. The method `pdfData(for:)` still returns an empty `Data` for
/// non-PDF files so the caller can decide what to display.
///
/// Marked `@MainActor` because UIKit drawing APIs are main-actor isolated
/// under Swift 6 strict concurrency.
@MainActor
struct DocumentContentGenerator {

    /// Returns rendered PDF bytes for a `SecureFile`. For non-PDF MIME
    /// types this returns `Data()` and the caller should render a
    /// generic preview instead.
    static func pdfData(for file: SecureFile) -> Data {
        guard file.mimeType == "application/pdf" else { return Data() }
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawPage(file: file, in: pageRect)
        }
    }

    // MARK: - Drawing

    private static func drawPage(file: SecureFile, in rect: CGRect) {
        // Header band tinted by sensitivity classification.
        let headerColor = headerColor(for: file.sensitivity)
        headerColor.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: 56)).fill()

        // Classification label in the header.
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.white,
            .kern: 0.8
        ]
        (sensitivityLabel(for: file.sensitivity) as NSString)
            .draw(at: CGPoint(x: 20, y: 20), withAttributes: headerAttrs)

        // Right-aligned source provider tag in the header.
        let providerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            .kern: 0.4
        ]
        let providerText = "XQ ENCRYPTED · \(file.sourceProvider.rawValue.uppercased())"
        let providerSize = (providerText as NSString).size(withAttributes: providerAttrs)
        (providerText as NSString).draw(
            at: CGPoint(x: rect.width - providerSize.width - 20, y: 22),
            withAttributes: providerAttrs
        )

        // Title — derived from filename.
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        ]
        let title = (file.name as NSString).deletingPathExtension
        (title as NSString).draw(at: CGPoint(x: 36, y: 76), withAttributes: titleAttrs)

        // Divider beneath the title.
        UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1).setStroke()
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: 36, y: 110))
        divider.addLine(to: CGPoint(x: rect.width - 36, y: 110))
        divider.lineWidth = 0.5
        divider.stroke()

        // Body paragraphs.
        let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 10
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]
        let bodyText = bodyContent(for: file)
        let bodyRect = CGRect(x: 36, y: 126, width: rect.width - 72, height: rect.height - 180)
        (bodyText as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)

        // Footer.
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.systemGray
        ]
        ("Page 1 of 12 · \(file.name) · XQ Encrypted" as NSString).draw(
            at: CGPoint(x: 36, y: rect.height - 28),
            withAttributes: footerAttrs
        )

        // Diagonal watermark, drawn last so it sits above text.
        let wmText = sensitivityLabel(for: file.sensitivity) + " · brian@xqmsg.com"
        let wmAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .black),
            .foregroundColor: headerColor.withAlphaComponent(0.06)
        ]
        let wmSize = (wmText as NSString).size(withAttributes: wmAttrs)
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.saveGState()
            ctx.translateBy(x: rect.width / 2, y: rect.height / 2)
            ctx.rotate(by: -CGFloat.pi / 6)
            (wmText as NSString).draw(
                at: CGPoint(x: -wmSize.width / 2, y: -wmSize.height / 2),
                withAttributes: wmAttrs
            )
            ctx.restoreGState()
        }
    }

    // MARK: - Sensitivity styling

    private static func headerColor(for s: SensitivityLevel) -> UIColor {
        switch s {
        case .restricted:   return UIColor(red: 0.48, green: 0.00, blue: 0.20, alpha: 1)
        case .confidential: return UIColor(red: 0.43, green: 0.30, blue: 0.00, alpha: 1)
        case .internal_:    return UIColor(red: 0.05, green: 0.28, blue: 0.63, alpha: 1)
        case .public_:      return UIColor(red: 0.11, green: 0.37, blue: 0.13, alpha: 1)
        }
    }

    private static func sensitivityLabel(for s: SensitivityLevel) -> String {
        switch s {
        case .restricted:   return "RESTRICTED"
        case .confidential: return "CONFIDENTIAL"
        case .internal_:    return "INTERNAL"
        case .public_:      return "PUBLIC"
        }
    }

    // MARK: - Body content per file

    private static func bodyContent(for file: SecureFile) -> String {
        switch file.name {
        case "Q4-Financial-Report.pdf":
            return """
            FINANCIAL PERFORMANCE SUMMARY — Q4 2025

            Revenue & Margins
            Total Revenue: $124.7M (+18.3% YoY)
            Gross Profit: $83.9M · Gross Margin: 67.3%
            Operating Income: $31.2M · EBITDA: $38.4M
            Net Income: $22.1M · EPS (diluted): $0.84

            Patient Financial Assistance Program
            Patients Served: 1,247 · Total Assistance: $3.2M

            PROTECTED HEALTH INFORMATION — RESTRICTED ACCESS
            Patient ID: 847293-A  DOB: 03/14/1968  SSN: ***-**-4821
            Patient ID: 912847-B  DOB: 07/22/1975  SSN: ***-**-9034
            Patient ID: 103928-C  DOB: 11/05/1991  SSN: ***-**-6617

            ⚠ This document contains PHI subject to HIPAA §164.502.
            Unauthorized disclosure is prohibited. All access is audit-logged.
            """
        case "Patient-Records-Q1.pdf":
            return """
            PATIENT RECORDS — Q1 2026 — STRICTLY CONFIDENTIAL

            Record 1: John D., MRN: 847293-A
            DOB: 03/14/1968 · SSN: ***-**-4821
            Diagnosis: Hypertension, Type 2 Diabetes
            Medications: Metformin 1000mg, Lisinopril 10mg
            Attending Physician: Dr. A. Chen, MD

            Record 2: Mary S., MRN: 912847-B
            DOB: 07/22/1975 · SSN: ***-**-9034
            Diagnosis: Breast Cancer Stage II
            Treatment: Chemotherapy Cycle 3 of 6
            Attending Physician: Dr. R. Patel, MD

            ⚠ PHI — HIPAA PRIVACY RULE APPLIES
            """
        case "Budget-2026-Final.xlsx":
            return """
            BUDGET 2026 — FINAL APPROVED VERSION

            Department Allocations
            Engineering:     $18.4M  (+12%)
            Sales & Mktg:    $14.2M  (+8%)
            G&A:              $6.8M  (-3%)
            R&D:             $11.6M  (+22%)

            Headcount Plan
            Existing HC: 847 · New Hires Q1: 34 · New Hires Q2: 28

            Capital Expenditure: $4.2M
            Software Licenses:   $3.1M

            CFO APPROVED — BOARD REVIEWED 12/10/2025
            """
        case "Client-Contract-Acme.pdf":
            return """
            SERVICE AGREEMENT

            PARTIES
            XQ Message, Inc. ("Provider") and Acme Corporation ("Client")

            TERM
            Effective Date: January 1, 2026
            Initial Term: 24 months
            Auto-renewal: 12 months unless 90-day written notice

            FINANCIAL TERMS
            Annual License Fee: $840,000
            Professional Services: $120,000/yr
            Payment: Net 30 from invoice date

            CONFIDENTIALITY
            Both parties agree to maintain strict confidentiality of all
            exchanged information for 5 years post-termination.
            """
        case "Security-Audit-2025.pdf":
            return """
            ANNUAL SECURITY AUDIT — FY 2025

            Scope
            SOC 2 Type II controls across infrastructure, application,
            and people domains. Audit window: 01/01/2025 – 12/31/2025.

            Key Findings
            • 0 critical findings
            • 3 high-severity findings (all remediated within 30 days)
            • 11 medium-severity observations (remediation in progress)

            Cited Controls
            NIST AC-3   Access Enforcement       PASS
            NIST AU-2   Event Logging             PASS
            NIST SC-13  Cryptographic Protection  PASS
            NIST IR-4   Incident Handling         OBSERVATION

            CONFIDENTIAL — Distribution limited to Audit Committee.
            """
        default:
            let name = (file.name as NSString).deletingPathExtension
            return """
            \(name.uppercased())

            Classification: \(sensitivityLabel(for: file.sensitivity))
            Encrypted: AES-256-GCM · Key ID: \(file.encryptedKeyId)
            Source: \(file.sourceProvider.rawValue)

            This document has been classified and encrypted by XQ Secure
            Workspaces. AI analysis completed on-device. No content
            transmitted to external servers.

            [Document content encrypted — tap to view with authorized access]
            """
        }
    }
}
