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
                
                let tableX: CGFloat = 30
                let tableWidth: CGFloat = 732
                let tableHeaderHeight: CGFloat = 17
                let rowHeight: CGFloat = 12
                let rowsPerPage = 36
                
                let invoiceNumber =
                "INV-" +
                Date().formatted(
                    .dateTime.year().month(.twoDigits).day(.twoDigits)
                )
                .replacingOccurrences(of: "/", with: "")
                
                let generatedDate =
                Date().formatted(
                    date: .abbreviated,
                    time: .shortened
                )
                
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                
                func drawText(
                    _ text: String,
                    x: CGFloat,
                    y: CGFloat,
                    font: UIFont,
                    width: CGFloat,
                    alignment: NSTextAlignment = .left,
                    color: UIColor = .black
                ) {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = alignment
                    paragraph.lineBreakMode = .byTruncatingTail
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraph
                    ]
                    
                    text.draw(
                        in: CGRect(
                            x: x,
                            y: y,
                            width: width,
                            height: 26
                        ),
                        withAttributes: attributes
                    )
                }
                
                func drawInvoiceHeader() {
                    
                    let pageMargin: CGFloat = 30
                    
                    let leftWidth: CGFloat = 260
                    let centerWidth: CGFloat = 210
                    let rightWidth: CGFloat = 220
                    
                    let leftX = pageMargin
                    let centerX = (pageWidth - centerWidth) / 2
                    let rightX = pageWidth - pageMargin - rightWidth
                    
                    drawText(
                        settings.trucking_company_name,
                        x: leftX,
                        y: 22,
                        font: .boldSystemFont(ofSize: 20),
                        width: leftWidth
                    )
                    
                    drawText(
                        "Route: \(settings.pickup_company_name) → \(settings.dropoff_company_name)",
                        x: leftX,
                        y: 49,
                        font: .systemFont(ofSize: 9.5),
                        width: leftWidth
                    )
                    
                    drawText(
                        "Weekly Invoice",
                        x: centerX,
                        y: 22,
                        font: .boldSystemFont(ofSize: 20),
                        width: centerWidth,
                        alignment: .center
                    )
                    
                    drawText(
                        "Week: \(weekRange)",
                        x: centerX,
                        y: 49,
                        font: .systemFont(ofSize: 11),
                        width: centerWidth,
                        alignment: .center
                    )
                    
                    drawText(
                        "Invoice #: \(invoiceNumber)",
                        x: rightX,
                        y: 24,
                        font: .boldSystemFont(ofSize: 8),
                        width: rightWidth,
                        alignment: .right
                    )
                    
                    drawText(
                        "Generated: \(generatedDate)",
                        x: rightX,
                        y: 41,
                        font: .systemFont(ofSize: 7.5),
                        width: rightWidth,
                        alignment: .right
                    )
                }
                
                func drawContinuationHeader(pageNumber: Int) {
                    
                    drawText(
                        settings.trucking_company_name,
                        x: 30,
                        y: 20,
                        font: .boldSystemFont(ofSize: 15),
                        width: 250
                    )
                    
                    drawText(
                        "Weekly Invoice — Continued",
                        x: 270,
                        y: 20,
                        font: .boldSystemFont(ofSize: 15),
                        width: 250,
                        alignment: .center
                    )
                    
                    drawText(
                        "Page \(pageNumber)",
                        x: 650,
                        y: 22,
                        font: .systemFont(ofSize: 8),
                        width: 110,
                        alignment: .right
                    )
                }
                
                func drawTableHeader(at y: CGFloat) {
                    
                    UIColor.systemBlue.setFill()
                    
                    UIBezierPath(
                        rect: CGRect(
                            x: tableX,
                            y: y,
                            width: tableWidth,
                            height: tableHeaderHeight
                        )
                    ).fill()
                    
                    let font = UIFont.boldSystemFont(ofSize: 7.5)
                    let textY = y + 4
                    
                    drawText(
                        "#",
                        x: 34,
                        y: textY,
                        font: font,
                        width: 22,
                        alignment: .center,
                        color: .white
                    )
                    
                    drawText(
                        "Date",
                        x: 60,
                        y: textY,
                        font: font,
                        width: 50,
                        color: .white
                    )
                    
                    drawText(
                        "\(settings.pickup_company_name) Ticket",
                        x: 112,
                        y: textY,
                        font: font,
                        width: 86,
                        color: .white
                    )
                    
                    drawText(
                        "Tons",
                        x: 200,
                        y: textY,
                        font: font,
                        width: 46,
                        color: .white
                    )
                    
                    drawText(
                        "\(settings.dropoff_company_name) Ticket",
                        x: 248,
                        y: textY,
                        font: font,
                        width: 100,
                        color: .white
                    )
                    
                    drawText(
                        "Rate",
                        x: 350,
                        y: textY,
                        font: font,
                        width: 52,
                        color: .white
                    )
                    
                    drawText(
                        "Total",
                        x: 404,
                        y: textY,
                        font: font,
                        width: 58,
                        color: .white
                    )
                    
                    drawText(
                        "Driver",
                        x: 464,
                        y: textY,
                        font: font,
                        width: 290,
                        color: .white
                    )
                }
                
                func drawRow(
                    _ row: WeeklyInvoiceRow,
                    number: Int,
                    at y: CGFloat
                ) {
                    
                    if number.isMultiple(of: 2) {
                        UIColor.systemBlue
                            .withAlphaComponent(0.06)
                            .setFill()
                    } else {
                        UIColor.white.setFill()
                    }
                    
                    UIBezierPath(
                        rect: CGRect(
                            x: tableX,
                            y: y,
                            width: tableWidth,
                            height: rowHeight
                        )
                    ).fill()
                    
                    let font = UIFont.systemFont(ofSize: 7.25)
                    let textY = y + 2.5
                    
                    drawText(
                        "\(number)",
                        x: 34,
                        y: textY,
                        font: font,
                        width: 22,
                        alignment: .center
                    )
                    
                    drawText(
                        formatter.string(from: row.date),
                        x: 60,
                        y: textY,
                        font: font,
                        width: 50
                    )
                    
                    drawText(
                        row.pickupTicket,
                        x: 112,
                        y: textY,
                        font: font,
                        width: 86
                    )
                    
                    drawText(
                        String(format: "%.2f", row.pickupTons),
                        x: 200,
                        y: textY,
                        font: font,
                        width: 46
                    )
                    
                    drawText(
                        row.deliveryTicket,
                        x: 248,
                        y: textY,
                        font: font,
                        width: 100
                    )
                    
                    drawText(
                        String(format: "$%.2f", row.rate),
                        x: 350,
                        y: textY,
                        font: font,
                        width: 52
                    )
                    
                    drawText(
                        String(format: "$%.2f", row.total),
                        x: 404,
                        y: textY,
                        font: font,
                        width: 58
                    )
                    
                    drawText(
                        row.driver,
                        x: 464,
                        y: textY,
                        font: font,
                        width: 290
                    )
                }
                
                func drawTotals(at y: CGFloat) {
                    
                    drawText(
                        "Invoice Totals",
                        x: 30,
                        y: y + 10,
                        font: .boldSystemFont(ofSize: 15),
                        width: 180
                    )
                    
                    UIColor.black.setStroke()
                    
                    UIBezierPath(
                        rect: CGRect(
                            x: 505,
                            y: y,
                            width: 255,
                            height: 55
                        )
                    ).stroke()
                    
                    drawText(
                        "Total Tons:",
                        x: 520,
                        y: y + 9,
                        font: .boldSystemFont(ofSize: 10),
                        width: 90
                    )
                    
                    drawText(
                        String(format: "%.2f", totalTons),
                        x: 640,
                        y: y + 9,
                        font: .systemFont(ofSize: 10),
                        width: 100
                    )
                    
                    drawText(
                        "Amount Due:",
                        x: 520,
                        y: y + 30,
                        font: .boldSystemFont(ofSize: 11),
                        width: 100
                    )
                    
                    drawText(
                        String(format: "$%.2f", grandTotal),
                        x: 640,
                        y: y + 30,
                        font: .boldSystemFont(ofSize: 11),
                        width: 100
                    )
                }
                
                var currentPage = 1
                var rowsOnCurrentPage = 0
                var y: CGFloat = 0
                
                context.beginPage()
                drawInvoiceHeader()
                
                y = 72
                drawTableHeader(at: y)
                y += tableHeaderHeight
                
                for (index, row) in rows.enumerated() {
                    
                    if rowsOnCurrentPage == rowsPerPage {
                        
                        currentPage += 1
                        rowsOnCurrentPage = 0
                        
                        context.beginPage()
                        drawContinuationHeader(pageNumber: currentPage)
                        
                        y = 45
                        drawTableHeader(at: y)
                        y += tableHeaderHeight
                    }
                    
                    drawRow(
                        row,
                        number: index + 1,
                        at: y
                    )
                    
                    y += rowHeight
                    rowsOnCurrentPage += 1
                }
                
                y += 10
                
                if y + 55 > pageHeight - 20 {
                    
                    currentPage += 1
                    context.beginPage()
                    
                    drawContinuationHeader(pageNumber: currentPage)
                    
                    drawTotals(at: 65)
                    
                } else {
                    
                    drawTotals(at: y)
                }
            }

            print("✅ Weekly Invoice PDF:", url)

            return url

        } catch {

            print("❌ Weekly invoice failed:", error)

            return nil
        }
    }
}
