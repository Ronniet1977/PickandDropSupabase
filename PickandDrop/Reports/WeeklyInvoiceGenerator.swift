//
//  WeeklyInvoiceGenerator.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/23/26.
//
import Foundation
import PDFKit
import UIKit

struct WeeklyInvoiceRow {

    let date: Date

    let pickupTicket: String
    let pickupTons: Double

    let deliveryTicket: String

    let driver: String

    let rate: Double

    var total: Double {
        pickupTons * rate
    }
}

enum WeeklyInvoiceGenerator {

    static func createWeeklyInvoicePDF(
        settings: CompanySettings,
        weekDate: Date
    ) -> URL? {

        let pageWidth: CGFloat = 792
        let pageHeight: CGFloat = 612

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: pageWidth,
                height: pageHeight
            )
        )

        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd"

        let fileName =
            "Weekly-Invoice-\(fileFormatter.string(from: Date())).pdf"

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(fileName)

    let folder = StorageManager.truckReportsFolder()

    let files =
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )) ?? []

        let finalCSVs = files.filter {
            $0.lastPathComponent.contains("FINAL") &&
            $0.pathExtension == "csv"
        }

        print("📄 FINAL CSVs:", finalCSVs.count)

        let calendar = Calendar.current

        guard let weekInterval =
            calendar.dateInterval(
                of: .weekOfYear,
                for: weekDate
            )
        else {
            return nil
        }
        
    var rows: [WeeklyInvoiceRow] = []

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    for file in finalCSVs {

        guard let text =
            try? String(contentsOf: file)
        else { continue }

        let lines = text.components(separatedBy: "\n")
            .dropFirst()

        for line in lines {

            let columns =
                line.components(separatedBy: ",")

            if columns.count < 11 { continue }

            let date =
                dateFormatter.date(from: columns[0])
                ?? Date()
            
            if !weekInterval.contains(date) {
                continue
            }

            let driver =
                columns[2]
                    .replacingOccurrences(of: "\"", with: "")

            let pickupTicket =
                columns[4]
                    .replacingOccurrences(of: "\"", with: "")

            let pickupTons =
                Double(columns[5]) ?? 0

            let deliveryTicket =
                columns[6]
                    .replacingOccurrences(of: "\"", with: "")
            
            if pickupTicket.isEmpty { continue }

            if pickupTons <= 0 {
                continue
            }

            rows.append(

                WeeklyInvoiceRow(
                    date: date,
                    pickupTicket: pickupTicket,
                    pickupTons: pickupTons,
                    deliveryTicket: deliveryTicket,
                    driver: driver,
                    rate: settings.ratePerTon
                )
            )
        }
    }

        let totalTons = rows.reduce(0.0) {
            $0 + $1.pickupTons
        }

        let grandTotal = rows.reduce(0.0) {
            $0 + $1.total
        }
        
        let sortedDates = rows
            .map { $0.date }
            .sorted()

        let startDate = weekInterval.start

        let endDate =
            Calendar.current.date(
                byAdding: .day,
                value: -1,
                to: weekInterval.end
            ) ?? weekInterval.end

        let weekFormatter = DateFormatter()
        weekFormatter.dateStyle = .short

        let weekRange =
            "\(weekFormatter.string(from: startDate)) - \(weekFormatter.string(from: endDate))"

        do {

            try renderer.writePDF(to: url) { context in

                context.beginPage()

                var y: CGFloat = 40

                func drawText(
                    _ text: String,
                    x: CGFloat,
                    y: CGFloat,
                    font: UIFont,
                    width: CGFloat = 520,
                    alignment: NSTextAlignment = .left
                ) {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = alignment

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .paragraphStyle: paragraph
                    ]

                    text.draw(
                        in: CGRect(x: x, y: y, width: width, height: 30),
                        withAttributes: attributes
                    )
                }

                // Header
                drawText(settings.truckingCompanyName, x: 40, y: y, font: .boldSystemFont(ofSize: 26))
                y += 34

                drawText("Weekly Invoice", x: 40, y: y, font: .boldSystemFont(ofSize: 20))
                y += 30

                drawText("Route: \(settings.pickupCompanyName) → \(settings.dropoffCompanyName)", x: 40, y: y, font: .systemFont(ofSize: 13))
                y += 24

                drawText(
                    "Week: \(weekRange)", x: 40, y: y, font: .systemFont(ofSize: 14))
                y += 34

                // Table Header
                UIColor.systemGray5.setFill()
                UIBezierPath(
                    rect: CGRect(
                        x: 40,
                        y: y,
                        width: 712,
                        height: 28
                    )
                ).fill()

                drawText("Date", x: 48, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 55)
                drawText("\(settings.pickupCompanyName) Ticket", x: 105, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 85)
                drawText("Tons", x: 195, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 55)
                drawText("\(settings.dropoffCompanyName) Ticket", x: 250, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 110)
                drawText("Rate", x: 365, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 60)
                drawText("Total", x: 430, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 70)
                drawText("Driver", x: 500, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 70)

                y += 34

                let formatter = DateFormatter()
                formatter.dateStyle = .short

                for row in rows {
                    drawText(formatter.string(from: row.date), x: 48, y: y, font: .systemFont(ofSize: 9), width: 55)
                    drawText(row.pickupTicket, x: 105, y: y, font: .systemFont(ofSize: 9), width: 85)
                    drawText(String(format: "%.2f", row.pickupTons), x: 195, y: y, font: .systemFont(ofSize: 9), width: 55)
                    drawText(row.deliveryTicket, x: 250, y: y, font: .systemFont(ofSize: 9), width: 110)
                    drawText(String(format: "$%.2f", row.rate), x: 365, y: y, font: .systemFont(ofSize: 9), width: 60)
                    drawText(String(format: "$%.2f", row.total), x: 430, y: y, font: .systemFont(ofSize: 9), width: 70)
                    drawText(row.driver, x: 500, y: y, font: .systemFont(ofSize: 9), width: 70)

                    y += 22

                    if y > 700 {
                        context.beginPage()
                        y = 40
                    }
                }

                y += 20

                // Totals Box
                UIColor.black.setStroke()
                UIBezierPath(rect: CGRect(x: 460, y: y, width: 260, height: 80)).stroke()

                drawText("Total Tons:", x: 480, y: y + 12, font: .boldSystemFont(ofSize: 13), width: 100)
                drawText(String(format: "%.2f", totalTons), x: 610, y: y + 12, font: .systemFont(ofSize: 13), width: 90)

                drawText("Amount Due:", x: 480, y: y + 42, font: .boldSystemFont(ofSize: 15), width: 120)
                drawText(String(format: "$%.2f", grandTotal), x: 610, y: y + 42, font: .boldSystemFont(ofSize: 15), width: 100)
            }

            print("✅ Weekly Invoice PDF:", url)

            return url

        } catch {

            print("❌ Weekly invoice failed:", error)

            return nil
        }
    }
}
