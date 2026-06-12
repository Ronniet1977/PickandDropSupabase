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
        settings: SupabaseCompanySettings,
        weekDate: Date,
        loads: [SupabaseLoad]
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

        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        guard let weekInterval =
            calendar.dateInterval(
                of: .weekOfYear,
                for: weekDate
            )
        else {
            return nil
        }
        
    var rows: [WeeklyInvoiceRow] = []

        let iso = ISO8601DateFormatter()

        for load in loads {
            if load.is_archived == true {
                continue
            }

            guard
                let deliveredAt = load.delivered_at,
                let pickupTicket = load.pickup_ticket_number,
                let deliveryTicket = load.delivery_ticket_number,
                let driver = load.driver_name
            else {
                continue
            }

            guard let deliveredDate = iso.date(from: deliveredAt) else {
                continue
            }

            guard weekInterval.contains(deliveredDate) else {
                continue
            }

            let pickupTons = load.pickup_tons ?? 0

            guard pickupTons > 0 else {
                continue
            }

            rows.append(
                WeeklyInvoiceRow(
                    date: deliveredDate,
                    pickupTicket: pickupTicket,
                    pickupTons: pickupTons,
                    deliveryTicket: deliveryTicket,
                    driver: driver,
                    rate: settings.rate_per_ton
                )
            )
        }
        
        let totalTons = rows.reduce(0.0) {
            $0 + $1.pickupTons
        }

        let grandTotal = rows.reduce(0.0) {
            $0 + $1.total
        }

        let startDate = weekInterval.start

        let endDate =
            calendar.date(
                byAdding: .day,
                value: 5,
                to: weekInterval.start
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
                    alignment: NSTextAlignment = .left,
                    color: UIColor = .black
                ) {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = alignment

                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraph
                    ]

                    text.draw(
                        in: CGRect(x: x, y: y, width: width, height: 30),
                        withAttributes: attributes
                    )
                }
                
                let invoiceNumber =
                    "INV-" +
                    Date().formatted(
                        .dateTime.year().month(.twoDigits).day(.twoDigits)
                    )
                    .replacingOccurrences(of: "/", with: "")

                let generatedDate =
                    Date().formatted(date: .abbreviated, time: .shortened)

                // Header
                drawText(
                    settings.trucking_company_name,
                    x: 40,
                    y: 35,
                    font: .boldSystemFont(ofSize: 26)
                )

                drawText(
                    "Route: \(settings.pickup_company_name) → \(settings.dropoff_company_name)",
                    x: 40,
                    y: 70,
                    font: .systemFont(ofSize: 13)
                )

                drawText(
                    "Weekly Invoice",
                    x: 260,
                    y: 35,
                    font: .boldSystemFont(ofSize: 24),
                    width: 260,
                    alignment: .center
                )

                drawText(
                    "Week: \(weekRange)",
                    x: 260,
                    y: 68,
                    font: .systemFont(ofSize: 16),
                    width: 260,
                    alignment: .center
                )

                drawText(
                    "Invoice #: \(invoiceNumber)",
                    x: 560,
                    y: 35,
                    font: .boldSystemFont(ofSize: 10),
                    width: 160,
                    alignment: .right
                )

                drawText(
                    "Generated: \(generatedDate)",
                    x: 520,
                    y: 52,
                    font: .systemFont(ofSize: 9),
                    width: 200,
                    alignment: .right
                )
                y = 100

                // Table Header
                UIColor.systemBlue.setFill()
                UIBezierPath(
                    rect: CGRect(
                        x: 40,
                        y: y,
                        width: 712,
                        height: 20
                    )
                ).fill()

                drawText("Date", x: 48, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 55,color: .white)
                drawText("\(settings.pickup_company_name) Ticket", x: 105, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 85,color: .white)
                drawText("Tons", x: 195, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 55,color: .white)
                drawText("\(settings.dropoff_company_name) Ticket", x: 250, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 110,color: .white)
                drawText("Rate", x: 365, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 60,color: .white)
                drawText("Total", x: 430, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 70,color: .white)
                drawText("Driver", x: 500, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 70,color: .white)

                y += 24

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

                    y += 20

                    if y > 700 {
                        context.beginPage()
                        y = 40
                    }
                }

                y += 20

                let pageHeight = renderer.format.bounds.height

                if y + 100 > pageHeight - 40 {
                    context.beginPage()
                    y = 40

                    drawText(
                        "Invoice Totals",
                        x: 40,
                        y: y,
                        font: .boldSystemFont(ofSize: 20)
                    )

                    y += 40
                }

                // Totals Box
                UIColor.black.setStroke()
                UIBezierPath(
                    rect: CGRect(
                        x: 430,
                        y: y,
                        width: 260,
                        height: 80
                    )
                ).stroke()

                drawText("Total Tons:", x: 450, y: y + 12, font: .boldSystemFont(ofSize: 13), width: 100)
                drawText(String(format: "%.2f", totalTons), x: 580, y: y + 12, font: .systemFont(ofSize: 13), width: 90)

                drawText("Amount Due:", x: 450, y: y + 42, font: .boldSystemFont(ofSize: 15), width: 120)
                drawText(String(format: "$%.2f", grandTotal), x: 580, y: y + 42, font: .boldSystemFont(ofSize: 15), width: 100)
            }

            print("✅ Weekly Invoice PDF:", url)

            return url

        } catch {

            print("❌ Weekly invoice failed:", error)

            return nil
        }
    }
}
