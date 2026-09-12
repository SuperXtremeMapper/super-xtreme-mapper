import CoreGraphics
import CoreText
import Foundation

@MainActor
enum MappingGuidePDF {
    enum RenderError: LocalizedError {
        case cannotCreateConsumer
        case cannotCreateContext
        case textDidNotAdvance

        var errorDescription: String? {
            switch self {
            case .cannotCreateConsumer: return "Could not create the PDF data consumer."
            case .cannotCreateContext: return "Could not create the PDF drawing context."
            case .textDidNotAdvance: return "Could not fit the guide text on a PDF page."
            }
        }
    }

    static func render(_ guide: MappingReferenceGuide) throws -> Data {
        try Task.checkCancellation()
        let result = NSMutableData()
        guard let consumer = CGDataConsumer(data: result) else {
            throw RenderError.cannotCreateConsumer
        }

        var pageBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &pageBox, nil) else {
            throw RenderError.cannotCreateContext
        }
        var contextIsClosed = false
        defer {
            if !contextIsClosed {
                context.closePDF()
            }
        }

        let body = try attributedDocument(for: guide)
        var lineBreakMode = CTLineBreakMode.byWordWrapping
        var lineSpacing = CGFloat(2)
        let paragraphStyle = withUnsafePointer(to: &lineBreakMode) { lineBreakPointer in
            withUnsafePointer(to: &lineSpacing) { lineSpacingPointer in
                let paragraphSettings = [
                    CTParagraphStyleSetting(
                        spec: .lineBreakMode,
                        valueSize: MemoryLayout<CTLineBreakMode>.size,
                        value: UnsafeRawPointer(lineBreakPointer)
                    ),
                    CTParagraphStyleSetting(
                        spec: .lineSpacingAdjustment,
                        valueSize: MemoryLayout<CGFloat>.size,
                        value: UnsafeRawPointer(lineSpacingPointer)
                    )
                ]
                return CTParagraphStyleCreate(paragraphSettings, paragraphSettings.count)
            }
        }
        body.addAttribute(
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String),
            value: paragraphStyle,
            range: NSRange(location: 0, length: body.length)
        )

        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let bodyRect = CGRect(x: 54, y: 58, width: pageBox.width - 108, height: pageBox.height - 104)
        var location = 0
        var pageNumber = 1

        repeat {
            try Task.checkCancellation()
            context.beginPDFPage(nil)
            let path = CGPath(rect: bodyRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: body.length - location),
                path,
                nil
            )
            try Task.checkCancellation()
            CTFrameDraw(frame, context)

            let visible = CTFrameGetVisibleStringRange(frame)
            if body.length > location, visible.length == 0 {
                context.endPDFPage()
                context.closePDF()
                contextIsClosed = true
                throw RenderError.textDidNotAdvance
            }

            drawFooter(pageNumber: pageNumber, revision: guide.revision, in: context, pageBox: pageBox)
            context.endPDFPage()
            location += visible.length
            pageNumber += 1
        } while location < body.length

        context.closePDF()
        contextIsClosed = true
        return result as Data
    }

    private static func attributedDocument(for guide: MappingReferenceGuide) throws -> NSMutableAttributedString {
        let document = NSMutableAttributedString()
        let foreground = CGColor(gray: 0.08, alpha: 1)
        let subdued = CGColor(gray: 0.35, alpha: 1)

        func append(_ text: String, fontName: String, size: CGFloat, color: CGColor = foreground) {
            document.append(NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(fontName as CFString, size, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
            ]))
        }

        append("\(guide.title)\n", fontName: "Helvetica-Bold", size: 21)
        append("Revision: \(guide.revision)\n\n", fontName: "Helvetica", size: 9, color: subdued)
        for section in guide.sections {
            try Task.checkCancellation()
            append("\(section.heading)\n", fontName: "Helvetica-Bold", size: 15)
            for paragraph in section.paragraphs {
                try Task.checkCancellation()
                append("\(paragraph)\n\n", fontName: "Helvetica", size: 10.5)
            }
        }
        return document
    }

    private static func drawFooter(pageNumber: Int, revision: String, in context: CGContext, pageBox: CGRect) {
        let footer = "Revision \(revision)  •  Page \(pageNumber)"
        let attributed = NSAttributedString(string: footer, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 8, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.35, alpha: 1)
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 54, y: 30)
        CTLineDraw(line, context)
    }
}
