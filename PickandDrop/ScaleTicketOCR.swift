//
//  ScaleTicketOCR.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 8/2/26.
//

//
//  ScaleTicketOCR.swift
//  PickandDrop
//

import Foundation
import UIKit
import ImageIO
@preconcurrency import Vision

struct ScannedLoadTicketData: Sendable {

    var pickupTicket = ""
    var pickupTons = ""

    var deliveryTicket = ""
    var deliveryTons = ""

    var truckNumber = ""
    var rawText = ""
}

enum TicketScanMode {
    case combined
    case pickupOnly
    case deliveryOnly
}

enum ScaleTicketOCR {

    static func scan(
        image: UIImage,
        mode: TicketScanMode = .combined
    ) async throws -> ScannedLoadTicketData {

        guard let imageData = image.jpegData(
            compressionQuality: 0.95
        ) else {
            throw OCRFailure.invalidImage
        }

        let orientationRawValue =
            cgImageOrientation(
                from: image.imageOrientation
            ).rawValue

        let recognizedText = try await Task.detached(
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

            let request = VNRecognizeTextRequest()

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let orientation =
                CGImagePropertyOrientation(
                    rawValue: orientationRawValue
                ) ?? .up

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            try handler.perform([request])

            let observations =
                request.results ?? []

            let lines = observations.compactMap {
                $0.topCandidates(1).first?.string
            }

            return lines.joined(separator: "\n")

        }.value

        switch mode {
            
        case .combined:
            return parse(text: recognizedText)
            
        case .pickupOnly:
            return parsePickupOnly(
                text: recognizedText
            )
            
        case .deliveryOnly:
            return parseDeliveryOnly(
                text: recognizedText
            )
        }
    }

    // MARK: - Ticket parsing
    
    private static func parsePickupOnly(
        text: String
    ) -> ScannedLoadTicketData {
        
        var result = ScannedLoadTicketData()
        result.rawText = text
        
        let upper = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")
            .uppercased()
        
        // BRC ticket numbers are seven digits
        // and currently begin with 1.
        result.pickupTicket =
        firstMatch(
            pattern: #"\b(1\d{6})\b"#,
            in: upper
        ) ?? ""
        
        // Most reliable method:
        // net pounds ÷ 2,000.
        if let netWeight = findNetWeight(in: upper) {
            
            result.pickupTons =
            String(
                format: "%.2f",
                netWeight / 2000.0
            )
            
        } else {
            
            result.pickupTons =
            firstPositiveDecimal(
                after: "QTY",
                in: upper
            )
            ?? firstRepeatedDecimal(
                in: upper
            )
            ?? ""
        }
        
        result.truckNumber =
        findTruckNumber(in: upper)
        
        return result
    }
    
    private static func parseDeliveryOnly(
        text: String
    ) -> ScannedLoadTicketData {
        
        var result = ScannedLoadTicketData()
        result.rawText = text
        
        let upper = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")
            .uppercased()
        
        // HoneyGo ticket numbers are six digits
        // and currently begin with 4.
        result.deliveryTicket =
        firstMatch(
            pattern: #"\b(4\d{5})\b"#,
            in: upper
        ) ?? ""
        
        // Again, net weight is the safest value.
        if let netWeight = findNetWeight(in: upper) {
            
            result.deliveryTons =
            String(
                format: "%.2f",
                netWeight / 2000.0
            )
            
        } else {
            
            result.deliveryTons =
            firstPositiveDecimal(
                after: "NET TONS",
                in: upper
            )
            ?? firstPositiveDecimal(
                after: "TONS",
                in: upper
            )
            ?? firstPositiveDecimal(
                after: "QTY",
                in: upper
            )
            ?? firstRepeatedDecimal(
                in: upper
            )
            ?? ""
        }
        
        result.truckNumber =
        findTruckNumber(in: upper)
        
        return result
    }
    
    private static func findTruckNumber(
        in text: String
    ) -> String {
        
        firstMatch(
            pattern: #"\bPD\s*([0-9IYL]{1,4})\b"#,
            in: text
        )
        .map {
            "PD" + cleanOCRDigits($0)
        }
        ?? ""
    }

    private static func parse(
        text: String
    ) -> ScannedLoadTicketData {

        var result = ScannedLoadTicketData()
        result.rawText = text

        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")

        let upper = normalized.uppercased()

        // Split where the actual second ticket begins.
        let brcMarker =
            upper.range(
                of: "BALTIMORE\nRECYCLING CENTER",
                options: .backwards
            )
            ?? upper.range(
                of: "GROSS WEIGHT",
                options: .backwards
            )

        let honeySection: String
        let brcSection: String

        if let brcMarker {
            honeySection =
                String(upper[..<brcMarker.lowerBound])

            brcSection =
                String(upper[brcMarker.lowerBound...])
        } else {
            honeySection = upper
            brcSection = upper
        }

        // MARK: HoneyGo / delivery

        result.deliveryTons =
            firstRepeatedDecimal(
                in: honeySection
            )
            ?? firstPositiveDecimal(
                after: "TONS",
                in: honeySection
            )
            ?? ""

        result.deliveryTicket =
            firstMatch(
                pattern: #"\b(4\d{5})\b"#,
                in: upper
            ) ?? ""

        // MARK: BRC / pickup

        result.pickupTicket =
            firstMatch(
                pattern: #"\b(1\d{6})\b"#,
                in: upper
            ) ?? ""

        // Most reliable BRC method:
        // convert NET WEIGHT pounds into tons.
        if let netWeight = findNetWeight(in: brcSection) {

            result.pickupTons =
                String(
                    format: "%.2f",
                    netWeight / 2000.0
                )

        } else {

            result.pickupTons =
                firstPositiveDecimal(
                    after: "QTY",
                    in: brcSection
                ) ?? ""
        }

        // MARK: Truck number

        result.truckNumber =
            firstMatch(
                pattern: #"\bPD\s*([0-9IYL]{1,4})\b"#,
                in: upper
            )
            .map { "PD" + cleanOCRDigits($0) }
            ?? ""

        return result
    }
    // MARK: - Section extraction

    private static func section(
        in text: String,
        startingAt startText: String,
        endingAt endText: String?
    ) -> String? {

        guard let startRange =
            text.range(of: startText)
        else {
            return nil
        }

        let remainder =
            String(text[startRange.lowerBound...])

        guard
            let endText,
            let searchStart =
                remainder.index(
                    remainder.startIndex,
                    offsetBy: min(
                        startText.count,
                        remainder.count
                    ),
                    limitedBy: remainder.endIndex
                ),
            let endRange =
                remainder.range(
                    of: endText,
                    range:
                        searchStart..<remainder.endIndex
                )
        else {
            return remainder
        }

        return String(
            remainder[..<endRange.lowerBound]
        )
    }

    // MARK: - Regex helper

    private static func firstMatch(
        pattern: String,
        in text: String
    ) -> String? {

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        else {
            return nil
        }

        let fullRange = NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )

        guard
            let match = regex.firstMatch(
                in: text,
                range: fullRange
            ),
            match.numberOfRanges > 1,
            let resultRange = Range(
                match.range(at: 1),
                in: text
            )
        else {
            return nil
        }

        return String(text[resultRange])
    }
    
    private static func firstRepeatedDecimal(
        in text: String
    ) -> String? {

        guard let regex = try? NSRegularExpression(
            pattern: #"\b(\d{1,3}\.\d{2})\b"#,
            options: []
        ) else {
            return nil
        }

        let range = NSRange(
            text.startIndex..<text.endIndex,
            in: text
        )

        let matches = regex.matches(
            in: text,
            range: range
        )

        var values: [String: Int] = [:]

        for match in matches {
            guard
                match.numberOfRanges > 1,
                let swiftRange = Range(
                    match.range(at: 1),
                    in: text
                )
            else {
                continue
            }

            let value = String(text[swiftRange])

            guard
                let number = Double(value),
                number > 0,
                number < 100
            else {
                continue
            }

            values[value, default: 0] += 1
        }

        return values
            .filter { $0.value >= 2 }
            .max { $0.value < $1.value }?
            .key
    }

    private static func cleanOCRDigits(
        _ text: String
    ) -> String {

        text
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "Y", with: "9")
            .filter(\.isNumber)
    }
    
    private static func firstPositiveDecimal(
        after marker: String,
        in text: String
    ) -> String? {

        guard let markerRange = text.range(of: marker) else {
            return nil
        }

        let remaining =
            String(text[markerRange.upperBound...])

        guard let regex = try? NSRegularExpression(
            pattern: #"\d{1,3}[.-]\d{1,2}"#
        ) else {
            return nil
        }

        let range = NSRange(
            remaining.startIndex..<remaining.endIndex,
            in: remaining
        )

        for match in regex.matches(in: remaining, range: range).prefix(10) {

            guard let swiftRange = Range(match.range, in: remaining) else {
                continue
            }

            let cleaned = String(remaining[swiftRange])
                .replacingOccurrences(of: "-", with: ".")

            if let value = Double(cleaned),
               value > 0,
               value < 100 {

                return String(format: "%.2f", value)
            }
        }

        return nil
    }
    
    private static func findNetWeight(
        in text: String
    ) -> Double? {

        let searchText: String

        if let start = text.range(of: "GROSS WEIGHT") {

            let remaining =
                String(text[start.lowerBound...])

            if let end =
                remaining.range(of: "QTY") ??
                remaining.range(of: "DESCRIPTION") {

                searchText =
                    String(remaining[..<end.lowerBound])

            } else {
                searchText = remaining
            }

        } else {
            searchText = text
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"\b\d{4,6}(?:\.\d+)?\b"#
        ) else {
            return nil
        }

        let range = NSRange(
            searchText.startIndex..<searchText.endIndex,
            in: searchText
        )

        let weights: [Double] =
            regex.matches(
                in: searchText,
                range: range
            )
            .compactMap { match in

                guard let swiftRange =
                    Range(match.range, in: searchText)
                else {
                    return nil
                }

                let cleaned =
                    String(searchText[swiftRange])
                        .replacingOccurrences(of: ",", with: "")

                guard
                    let value = Double(cleaned),
                    value >= 10_000,
                    value <= 200_000
                else {
                    return nil
                }

                return value
            }

        guard weights.count >= 3 else {
            return nil
        }

        for gross in weights {
            for tare in weights where tare < gross {
                for net in weights {

                    let calculatedNet = gross - tare

                    if abs(calculatedNet - net) < 100 {
                        return net
                    }
                }
            }
        }

        return nil
    }

    private static func cleanTruckNumber(
        _ text: String
    ) -> String {

        text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "Y", with: "9")
    }

    // MARK: - Image orientation

    private static func cgImageOrientation(
        from orientation: UIImage.Orientation
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

enum OCRFailure: LocalizedError, Sendable {

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
