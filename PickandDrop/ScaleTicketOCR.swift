import Foundation
import UIKit
import ImageIO
@preconcurrency import Vision


// MARK: - Result

struct ScannedLoadTicketData: Sendable {
    
    var pickupTicket = ""
    var pickupTons = ""
    
    var deliveryTicket = ""
    var deliveryTons = ""
    
    var truckNumber = ""
    var rawText = ""
}


// MARK: - Scan Mode

enum TicketScanMode {
    
    case combined
    case pickupOnly
    case deliveryOnly
}


// MARK: - OCR

enum ScaleTicketOCR {
    
    static func scan(
        image: UIImage,
        mode: TicketScanMode = .combined
    ) async throws -> ScannedLoadTicketData {
        
        guard let imageData =
                image.jpegData(
                    compressionQuality: 0.98
                )
        else {
            throw OCRFailure.invalidImage
        }
        
        let orientationRawValue =
        cgImageOrientation(
            from: image.imageOrientation
        )
        .rawValue
        
        let recognizedText =
        try await Task.detached(
            priority: .userInitiated
        ) {
            
            guard
                let imageSource =
                    CGImageSourceCreateWithData(
                        imageData as CFData,
                        nil
                    ),
                
                    let cgImage =
                    CGImageSourceCreateImageAtIndex(
                        imageSource,
                        0,
                        nil
                    )
            else {
                throw OCRFailure.invalidImage
            }
            
            let request =
            VNRecognizeTextRequest()
            
            request.recognitionLevel =
                .accurate
            
            request.usesLanguageCorrection =
            true
            
            request.recognitionLanguages =
            ["en-US"]
            
            request.customWords = [
                "BALTIMORE",
                "RECYCLING",
                "HONEYGO",
                "HONEY-GO",
                "GROSS WEIGHT",
                "TARE WEIGHT",
                "NET WEIGHT",
                "NET TONS",
                "TICKET",
                "VEHICLE",
                "PD"
            ]
            
            let orientation =
            CGImagePropertyOrientation(
                rawValue:
                    orientationRawValue
            )
            ?? .up
            
            let handler =
            VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )
            
            try handler.perform(
                [request]
            )
            
            let observations =
            request.results ?? []
            
            let lines =
            observations.compactMap {
                observation in
                
                observation
                    .topCandidates(1)
                    .first?
                    .string
            }
            
            guard !lines.isEmpty else {
                throw OCRFailure.noTextFound
            }
            
            return lines.joined(
                separator: "\n"
            )
            
        }.value
        
        print("📷 RAW SCALE TICKET OCR")
        print(recognizedText)
        
        switch mode {
            
        case .pickupOnly:
            
            let result =
            parsePickupOnly(
                text: recognizedText
            )
            
            debug(result)
            
            return result
            
        case .deliveryOnly:
            
            let result =
            parseDeliveryOnly(
                text: recognizedText
            )
            
            debug(result)
            
            return result
            
        case .combined:
            
            let result =
            parseCombined(
                text: recognizedText
            )
            
            debug(result)
            
            return result
        }
    }
    
    
    // MARK: - BRC / Pickup
    
    private static func parsePickupOnly(
        text: String
    ) -> ScannedLoadTicketData {
        
        var result =
        ScannedLoadTicketData()
        
        result.rawText = text
        
        let normalized =
        normalize(text)
        
        // BRC examples:
        // 1092282
        //
        // Prefer a ticket-looking 7 digit number
        // beginning with 1.
        result.pickupTicket =
        findBRCTicket(
            in: normalized
        )
        
        result.pickupTons =
        findTons(
            in: normalized,
            ticketType: .brc
        )
        
        result.truckNumber =
        findTruckNumber(
            in: normalized
        )
        
        return result
    }
    
    
    // MARK: - HoneyGo / Delivery
    
    private static func parseDeliveryOnly(
        text: String
    ) -> ScannedLoadTicketData {
        
        var result =
        ScannedLoadTicketData()
        
        result.rawText = text
        
        let normalized =
        normalize(text)
        
        // HoneyGo examples:
        // 456339
        //
        // Prefer a 6 digit ticket number
        // beginning with 4.
        result.deliveryTicket =
        findHoneyGoTicket(
            in: normalized
        )
        
        result.deliveryTons =
        findTons(
            in: normalized,
            ticketType: .honeyGo
        )
        
        result.truckNumber =
        findTruckNumber(
            in: normalized
        )
        
        return result
    }
    
    
    // MARK: - Combined
    
    private static func parseCombined(
        text: String
    ) -> ScannedLoadTicketData {
        
        var result =
        ScannedLoadTicketData()
        
        result.rawText = text
        
        let normalized =
        normalize(text)
        
        let brcSection =
        ticketSection(
            in: normalized,
            primaryMarkers: [
                "BALTIMORE RECYCLING",
                "BALTIMORE\nRECYCLING"
            ],
            otherMarkers: [
                "HONEYGO RUN",
                "HONEYGO",
                "HONEY-GO"
            ]
        )
        ?? normalized
        
        let honeySection =
        ticketSection(
            in: normalized,
            primaryMarkers: [
                "HONEYGO RUN",
                "HONEYGO",
                "HONEY-GO"
            ],
            otherMarkers: [
                "BALTIMORE RECYCLING",
                "BALTIMORE\nRECYCLING"
            ]
        )
        ?? normalized
        
        result.pickupTicket =
        findBRCTicket(
            in: brcSection
        )
        
        result.pickupTons =
        findTons(
            in: brcSection,
            ticketType: .brc
        )
        
        result.deliveryTicket =
        findHoneyGoTicket(
            in: honeySection
        )
        
        result.deliveryTons =
        findTons(
            in: honeySection,
            ticketType: .honeyGo
        )
        
        result.truckNumber =
        findTruckNumber(
            in: normalized
        )
        
        return result
    }
    
    
    // MARK: - Ticket Type
    
    private enum ScaleTicketType {
        
        case brc
        case honeyGo
    }
    
    
    // MARK: - Tons
    
    private static func findTons(
        in text: String,
        ticketType: ScaleTicketType
    ) -> String {
        
        // HoneyGo literally prints:
        //
        // NET TONS 20.57
        //
        // so this is our best first choice.
        if let netTons =
            numberNearMarker(
                "NET TONS",
                in: text,
                minimum: 0.1,
                maximum: 100
            ) {
            
            return formatTons(
                netTons
            )
        }
        
        // Next safest source:
        //
        // NET WEIGHT / 2,000
        if let netWeight =
            labeledWeight(
                marker: "NET WEIGHT",
                in: text
            ) {
            
            let tons =
            netWeight / 2000.0
            
            if validTons(tons) {
                return formatTons(tons)
            }
        }
        
        // If OCR caught gross and tare but
        // missed NET WEIGHT, calculate it.
        if
            let gross =
                labeledWeight(
                    marker: "GROSS WEIGHT",
                    in: text
                ),
            
                let tare =
                labeledWeight(
                    marker: "TARE WEIGHT",
                    in: text
                ),
            
                gross > tare
        {
            
            let net =
            gross - tare
            
            let tons =
            net / 2000.0
            
            if validTons(tons) {
                return formatTons(tons)
            }
        }
        
        // Last attempt:
        // find a mathematically consistent
        // gross / tare / net group.
        if let netWeight =
            findValidatedNetWeight(
                in: text
            ) {
            
            let tons =
            netWeight / 2000.0
            
            if validTons(tons) {
                return formatTons(tons)
            }
        }
        
        // BRC typically shows:
        //
        // QTY 21.95 TN
        //
        // Use this only after weight checks.
        if ticketType == .brc {
            
            if let qtyTons =
                numberNearMarker(
                    "QTY",
                    in: text,
                    minimum: 0.1,
                    maximum: 100
                ) {
                
                return formatTons(
                    qtyTons
                )
            }
        }
        
        // General decimal fallback.
        if let decimal =
            likelyTonsDecimal(
                in: text
            ) {
            
            return formatTons(
                decimal
            )
        }
        
        return ""
    }
    
    
    // MARK: - Labeled Weight
    
    private static func labeledWeight(
        marker: String,
        in text: String
    ) -> Double? {
        
        guard let markerRange =
                text.range(
                    of: marker,
                    options: .caseInsensitive
                )
        else {
            return nil
        }
        
        let remaining =
        String(
            text[
                markerRange.upperBound...
            ]
        )
        
        let limited =
        String(
            remaining.prefix(100)
        )
        
        let values =
        numericValues(
            in: limited
        )
        
        return values.first {
            value in
            
            value >= 1_000 &&
            value <= 200_000
        }
    }
    
    
    // MARK: - Number After Marker
    
    private static func numberNearMarker(
        _ marker: String,
        in text: String,
        minimum: Double,
        maximum: Double
    ) -> Double? {
        
        guard let markerRange =
                text.range(
                    of: marker,
                    options: .caseInsensitive
                )
        else {
            return nil
        }
        
        let remaining =
        String(
            text[
                markerRange.upperBound...
            ]
        )
        
        // Keep the search local to the label.
        let nearby =
        String(
            remaining.prefix(120)
        )
        
        let values =
        numericValues(
            in: nearby
        )
        
        return values.first {
            $0 >= minimum &&
            $0 <= maximum
        }
    }
    
    
    // MARK: - Validated Net Weight
    
    private static func findValidatedNetWeight(
        in text: String
    ) -> Double? {
        
        let values =
        numericValues(
            in: text
        )
        .filter {
            $0 >= 10_000 &&
            $0 <= 200_000
        }
        
        guard values.count >= 3 else {
            return nil
        }
        
        for gross in values {
            
            for tare in values
            where tare < gross {
                
                let calculatedNet =
                gross - tare
                
                for net in values {
                    
                    // Scale tickets are exact in
                    // normal circumstances, but
                    // allow a little OCR tolerance.
                    if abs(
                        calculatedNet - net
                    ) <= 100 {
                        
                        return net
                    }
                }
            }
        }
        
        return nil
    }
    
    
    // MARK: - Tons Decimal Fallback
    
    private static func likelyTonsDecimal(
        in text: String
    ) -> Double? {
        
        guard let regex =
                try? NSRegularExpression(
                    pattern:
                        #"\b(\d{1,2}[.,]\d{1,2})\b"#,
                    options: []
                )
        else {
            return nil
        }
        
        let range =
        NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )
        
        let matches =
        regex.matches(
            in: text,
            range: range
        )
        
        var candidates: [Double] = []
        
        for match in matches {
            
            guard
                match.numberOfRanges > 1,
                
                    let swiftRange =
                    Range(
                        match.range(at: 1),
                        in: text
                    )
            else {
                continue
            }
            
            let valueString =
            String(
                text[swiftRange]
            )
            .replacingOccurrences(
                of: ",",
                with: "."
            )
            
            guard
                let value =
                    Double(valueString),
                
                    value > 1,
                value < 50
            else {
                continue
            }
            
            candidates.append(value)
        }
        
        // Tons on these loads are generally
        // meaningful two-decimal values.
        //
        // Prefer values in a realistic range.
        return candidates.first {
            $0 >= 5 &&
            $0 <= 40
        }
        ?? candidates.first
    }
    
    
    // MARK: - BRC Ticket
    
    private static func findBRCTicket(
        in text: String
    ) -> String {
        
        // Known BRC format:
        // seven digits, currently starts 1.
        if let ticket =
            firstMatch(
                pattern:
                    #"\b(1\d{6})\b"#,
                in: text
            ) {
            
            return ticket
        }
        
        // Label-based fallback.
        return ticketAfterLabel(
            in: text,
            digitCount:
                7
        )
        ?? ""
    }
    
    
    // MARK: - HoneyGo Ticket
    
    private static func findHoneyGoTicket(
        in text: String
    ) -> String {
        
        // Known HoneyGo format:
        // six digits, currently starts 4.
        if let ticket =
            firstMatch(
                pattern:
                    #"\b(4\d{5})\b"#,
                in: text
            ) {
            
            return ticket
        }
        
        return ticketAfterLabel(
            in: text,
            digitCount:
                6
        )
        ?? ""
    }
    
    
    // MARK: - Ticket Label Fallback
    
    private static func ticketAfterLabel(
        in text: String,
        digitCount: Int
    ) -> String? {
        
        let markers = [
            "TICKET #",
            "TICKET#",
            "TICKET"
        ]
        
        for marker in markers {
            
            guard let range =
                    text.range(
                        of: marker,
                        options:
                                .caseInsensitive
                    )
            else {
                continue
            }
            
            let remaining =
            String(
                text[
                    range.upperBound...
                ]
            )
            
            let nearby =
            String(
                remaining.prefix(80)
            )
            
            let pattern =
            #"\b(\d{"#
            + "\(digitCount)"
            + #"})\b"#
            
            if let value =
                firstMatch(
                    pattern: pattern,
                    in: nearby
                ) {
                
                return value
            }
        }
        
        return nil
    }
    
    
    // MARK: - Truck Number
    
    private static func findTruckNumber(
        in text: String
    ) -> String {
        
        guard let raw =
                firstMatch(
                    pattern:
                        #"\bPD\s*[-:]?\s*([0-9IOLYS]{1,4})\b"#,
                    in: text
                )
        else {
            return ""
        }
        
        let cleaned =
        cleanOCRDigits(
            raw
        )
        
        guard !cleaned.isEmpty else {
            return ""
        }
        
        return "PD\(cleaned)"
    }
    
    
    // MARK: - Numeric Extraction
    
    private static func numericValues(
        in text: String
    ) -> [Double] {
        
        // Captures:
        //
        // 80,360
        // 80,360.00
        // 41140
        // 20.57
        //
        guard let regex =
                try? NSRegularExpression(
                    pattern:
                        #"\b[0-9OIL]{1,3}(?:,[0-9OIL]{3})+(?:\.[0-9OIL]{1,2})?\b|\b[0-9OIL]{1,6}(?:\.[0-9OIL]{1,2})?\b"#,
                    options:
                        [.caseInsensitive]
                )
        else {
            return []
        }
        
        let range =
        NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )
        
        return regex.matches(
            in: text,
            range: range
        )
        .compactMap {
            match in
            
            guard let swiftRange =
                    Range(
                        match.range,
                        in: text
                    )
            else {
                return nil
            }
            
            var value =
            String(
                text[swiftRange]
            )
            .uppercased()
            
            // OCR corrections only inside
            // numeric candidates.
            value =
            value
                .replacingOccurrences(
                    of: "O",
                    with: "0"
                )
                .replacingOccurrences(
                    of: "I",
                    with: "1"
                )
                .replacingOccurrences(
                    of: "L",
                    with: "1"
                )
                .replacingOccurrences(
                    of: ",",
                    with: ""
                )
            
            return Double(value)
        }
    }
    
    
    // MARK: - Normalization
    
    private static func normalize(
        _ text: String
    ) -> String {
        
        text
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\t",
                with: " "
            )
            .replacingOccurrences(
                of: "–",
                with: "-"
            )
            .replacingOccurrences(
                of: "—",
                with: "-"
            )
            .uppercased()
    }
    
    
    // MARK: - Combined Section Helper
    
    private static func ticketSection(
        in text: String,
        primaryMarkers: [String],
        otherMarkers: [String]
    ) -> String? {
        
        var startRange:
        Range<String.Index>?
        
        for marker in primaryMarkers {
            
            if let range =
                text.range(
                    of: marker,
                    options:
                            .caseInsensitive
                ) {
                
                startRange = range
                break
            }
        }
        
        guard let startRange else {
            return nil
        }
        
        let remainder =
        String(
            text[
                startRange.lowerBound...
            ]
        )
        
        var earliestEnd:
        String.Index?
        
        for marker in otherMarkers {
            
            if let range =
                remainder.range(
                    of: marker,
                    options:
                            .caseInsensitive
                ) {
                
                if range.lowerBound !=
                    remainder.startIndex {
                    
                    if earliestEnd == nil ||
                        range.lowerBound <
                        earliestEnd! {
                        
                        earliestEnd =
                        range.lowerBound
                    }
                }
            }
        }
        
        if let earliestEnd {
            
            return String(
                remainder[
                    ..<earliestEnd
                ]
            )
        }
        
        return remainder
    }
    
    
    // MARK: - Regex Helper
    
    private static func firstMatch(
        pattern: String,
        in text: String
    ) -> String? {
        
        guard let regex =
                try? NSRegularExpression(
                    pattern: pattern,
                    options:
                        [.caseInsensitive]
                )
        else {
            return nil
        }
        
        let fullRange =
        NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )
        
        guard
            let match =
                regex.firstMatch(
                    in: text,
                    range: fullRange
                ),
            
                match.numberOfRanges > 1,
            
                let resultRange =
                Range(
                    match.range(at: 1),
                    in: text
                )
        else {
            return nil
        }
        
        return String(
            text[resultRange]
        )
    }
    
    
    // MARK: - OCR Digit Cleanup
    
    private static func cleanOCRDigits(
        _ text: String
    ) -> String {
        
        text
            .uppercased()
            .replacingOccurrences(
                of: "O",
                with: "0"
            )
            .replacingOccurrences(
                of: "I",
                with: "1"
            )
            .replacingOccurrences(
                of: "L",
                with: "1"
            )
            .replacingOccurrences(
                of: "Y",
                with: "9"
            )
            .replacingOccurrences(
                of: "S",
                with: "5"
            )
            .filter(\.isNumber)
    }
    
    
    // MARK: - Formatting
    
    private static func validTons(
        _ value: Double
    ) -> Bool {
        
        value > 0 &&
        value < 100
    }
    
    private static func formatTons(
        _ value: Double
    ) -> String {
        
        String(
            format: "%.2f",
            value
        )
    }
    
    
    // MARK: - Debug
    
    private static func debug(
        _ result:
        ScannedLoadTicketData
    ) {
        
        print("🎫 OCR RESULT")
        print(
            "Pickup ticket:",
            result.pickupTicket
        )
        print(
            "Pickup tons:",
            result.pickupTons
        )
        print(
            "Delivery ticket:",
            result.deliveryTicket
        )
        print(
            "Delivery tons:",
            result.deliveryTons
        )
        print(
            "Truck:",
            result.truckNumber
        )
    }
    
    
    // MARK: - Image Orientation
    
    private static func cgImageOrientation(
        from orientation:
        UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        
        switch orientation {
            
        case .up:
            return .up
            
        case .down:
            return .down
            
        case .left:
            return .left
            
        case .right:
            return .right
            
        case .upMirrored:
            return .upMirrored
            
        case .downMirrored:
            return .downMirrored
            
        case .leftMirrored:
            return .leftMirrored
            
        case .rightMirrored:
            return .rightMirrored
            
        @unknown default:
            return .up
        }
    }
}


// MARK: - Errors

enum OCRFailure:
    LocalizedError,
    Sendable {
    
    case invalidImage
    case noTextFound
    
    var errorDescription: String? {
        
        switch self {
            
        case .invalidImage:
            return "The ticket photo could not be read."
            
        case .noTextFound:
            return "No readable ticket text was found."
        }
    }
}
