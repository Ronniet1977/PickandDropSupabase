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

        let iso = ISO8601DateFormatter()

        for load in loads {

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
                drawText(settings.trucking_company_name, x: 40, y: y, font: .boldSystemFont(ofSize: 26))
                y += 34

                drawText("Weekly Invoice", x: 40, y: y, font: .boldSystemFont(ofSize: 20))
                y += 30

                drawText("Route: \(settings.pickup_company_name) → \(settings.dropoff_company_name)", x: 40, y: y, font: .systemFont(ofSize: 13))
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
                drawText("\(settings.pickup_company_name) Ticket", x: 105, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 85)
                drawText("Tons", x: 195, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 55)
                drawText("\(settings.dropoff_company_name) Ticket", x: 250, y: y + 6, font: .boldSystemFont(ofSize: 10), width: 110)
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
