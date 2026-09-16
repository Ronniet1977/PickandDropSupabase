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
    
    let pickupLocation: String
    let pickupTicket: String
    let pickupTons: Double
    
    let dropoffLocation: String
    let deliveryTicket: String
    
    let driver: String
    
    let billingType: String
    
    let ratePerTon: Double
    let fuelSurchargePerTon: Double
    let ratePerLoad: Double
    let ratePerHour: Double
    let billableHours: Double
    
    var loadRevenue: Double {
        
        switch billingType {
            
        case "per_load":
            return ratePerLoad
            
        case "per_hour":
            return ratePerHour * billableHours
            
        default:
            return pickupTons * ratePerTon
        }
    }
    
    var fuelSurcharge: Double {
        
        guard billingType == "per_ton" else {
            return 0
        }
        
        return pickupTons * fuelSurchargePerTon
    }
    
    var total: Double {
        loadRevenue + fuelSurcharge
    }
    
    var rateDescription: String {
        
        switch billingType {
            
        case "per_load":
            return String(
                format: "$%.2f/load",
                ratePerLoad
            )
            
        case "per_hour":
            return String(
                format: "$%.2f/hr",
                ratePerHour
            )
            
        default:
            return String(
                format: "$%.2f/ton",
                ratePerTon
            )
        }
    }
    
    var fuelDescription: String {
        
        guard billingType == "per_ton" else {
            return "—"
        }
        
        return String(
            format: "$%.2f",
            fuelSurchargePerTon
        )
    }
}

enum WeeklyInvoiceGenerator {

    static func createWeeklyInvoicePDF(
        settings: SupabaseCompanySettings,
        weekDate: Date,
        loads: [SupabaseLoad],
        dropoffLocation: String,
        archived: Bool = false
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

        let safeDropoff =
            dropoffLocation
                .replacingOccurrences(of: " ", with: "-")

        let fileName =
            archived
            ? "Archived-Weekly-Invoice-\(safeDropoff)-\(fileFormatter.string(from: weekDate)).pdf"
            : "Weekly-Invoice-\(safeDropoff)-\(fileFormatter.string(from: weekDate)).pdf"

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
            guard load.is_archived == archived else {
                continue
            }
            
            guard
                (load.dropoff_location ?? "")
                    .caseInsensitiveCompare(dropoffLocation)
                    == .orderedSame
            else {
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

            let billingType =
            load.billing_type
            ?? "per_ton"
            
            let storedRatePerTon =
            load.rate_per_ton ?? 0
            
            let storedFuelSurcharge =
            load.fuel_surcharge_per_ton ?? 0
            
            let ratePerTon: Double
            let fuelSurchargePerTon: Double
            
            if billingType == "per_ton" {
                
                ratePerTon =
                storedRatePerTon > 0
                ? storedRatePerTon
                : settings.rate_per_ton
                
                fuelSurchargePerTon =
                storedFuelSurcharge > 0
                ? storedFuelSurcharge
                : settings.fuel_surcharge_per_ton
                
            } else {
                
                ratePerTon = 0
                fuelSurchargePerTon = 0
            }
            
            let ratePerLoad =
            load.rate_per_load ?? 0
            
            let ratePerHour =
            load.rate_per_hour ?? 0
            
            let billableHours =
            load.billable_hours ?? 0
            
            print(
                "💵 Invoice:",
                load.dropoff_location ?? "Unknown",
                billingType
            )
            
            rows.append(
                WeeklyInvoiceRow(
                    date: deliveredDate,
                    
                    pickupLocation:
                        load.pickup_location
                    ?? settings.pickup_company_name,
                    
                    pickupTicket: pickupTicket,
                    pickupTons: pickupTons,
                    
                    dropoffLocation:
                        load.dropoff_location
                    ?? settings.dropoff_company_name,
                    
                    deliveryTicket: deliveryTicket,
                    driver: driver,
                    billingType:
                        billingType,
                    
                    ratePerTon:
                        ratePerTon,
                    
                    fuelSurchargePerTon:
                        fuelSurchargePerTon,
                    
                    ratePerLoad:
                        ratePerLoad,
                    
                    ratePerHour:
                        ratePerHour,
                    
                    billableHours:
                        billableHours
                )
            )
        }
        
        let totalTons =
        rows.reduce(0.0) {
            $0 + $1.pickupTons
        }
        
        let loadRevenue =
        rows.reduce(0.0) {
            $0 + $1.loadRevenue
        }
        
        let fuelSurcharge =
        rows.reduce(0.0) {
            $0 + $1.fuelSurcharge
        }
        
        let invoiceTotal =
        loadRevenue + fuelSurcharge

        let startDate = weekInterval.start

        let endDate =
            calendar.date(
                byAdding: .day,
                value: 6,
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

                    // MARK: Company

                    drawText(
                        settings.trucking_company_name,
                        x: leftX,
                        y: 22,
                        font: .boldSystemFont(ofSize: 20),
                        width: leftWidth
                    )

                    drawText(
                        "Route: \(settings.pickup_company_name) → \(dropoffLocation)",
                        x: leftX,
                        y: 49,
                        font: .systemFont(ofSize: 10),
                        width: leftWidth
                    )

                    // MARK: Invoice title

                    drawText(
                        archived
                        ? "Archived Weekly Invoice"
                        : "Weekly Invoice",
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

                    // MARK: Billing rate

                    let billingText: String

                    if let firstRow = rows.first {

                        switch firstRow.billingType {

                        case "per_load":
                            billingText = String(
                                format: "Rate: $%.2f/load",
                                firstRow.ratePerLoad
                            )

                        case "per_hour":
                            billingText = String(
                                format: "Rate: $%.2f/hour",
                                firstRow.ratePerHour
                            )

                        default:
                            billingText = String(
                                format:
                                    "Rate: $%.2f/ton • Fuel Surcharge: $%.2f/ton",
                                firstRow.ratePerTon,
                                firstRow.fuelSurchargePerTon
                            )
                        }

                    } else {
                        billingText = ""
                    }

                    drawText(
                        billingText,
                        x: leftX,
                        y: 63,
                        font: .systemFont(ofSize: 8.5),
                        width: 340
                    )

                    // MARK: Invoice info

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
                    
                    let font = UIFont.boldSystemFont(ofSize: 6.9)
                    let textY = y + 4
                    
                    drawText("#",
                             x: 32,
                             y: textY,
                             font: font,
                             width: 20,
                             alignment: .center,
                             color: .white)
                    
                    drawText("Date",
                             x: 54,
                             y: textY,
                             font: font,
                             width: 44,
                             color: .white)
                    
                    drawText("Pickup",
                             x: 100,
                             y: textY,
                             font: font,
                             width: 54,
                             color: .white)
                    
                    drawText("Ticket",
                             x: 156,
                             y: textY,
                             font: font,
                             width: 68,
                             color: .white)
                    
                    drawText("Tons",
                             x: 226,
                             y: textY,
                             font: font,
                             width: 40,
                             color: .white)
                    
                    drawText("Dropoff",
                             x: 268,
                             y: textY,
                             font: font,
                             width: 58,
                             color: .white)
                    
                    drawText("Ticket",
                             x: 328,
                             y: textY,
                             font: font,
                             width: 68,
                             color: .white)
                    
                    drawText("Rate",
                             x: 398,
                             y: textY,
                             font: font,
                             width: 50,
                             color: .white)
                    
                    drawText("Fuel",
                             x: 450,
                             y: textY,
                             font: font,
                             width: 50,
                             color: .white)
                    
                    drawText("Total",
                             x: 502,
                             y: textY,
                             font: font,
                             width: 58,
                             color: .white)
                    
                    drawText("Driver",
                             x: 562,
                             y: textY,
                             font: font,
                             width: 192,
                             color: .white)
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
                    
                    let font = UIFont.systemFont(ofSize: 6.8)
                    let textY = y + 2.5
                    
                    drawText(
                        "\(number)",
                        x: 32,
                        y: textY,
                        font: font,
                        width: 20,
                        alignment: .center
                    )
                    
                    drawText(
                        formatter.string(from: row.date),
                        x: 54,
                        y: textY,
                        font: font,
                        width: 44
                    )
                    
                    drawText(
                        row.pickupLocation,
                        x: 100,
                        y: textY,
                        font: font,
                        width: 54
                    )
                    
                    drawText(
                        row.pickupTicket,
                        x: 156,
                        y: textY,
                        font: font,
                        width: 68
                    )
                    
                    drawText(
                        String(format: "%.2f", row.pickupTons),
                        x: 226,
                        y: textY,
                        font: font,
                        width: 40
                    )
                    
                    drawText(
                        row.dropoffLocation,
                        x: 268,
                        y: textY,
                        font: font,
                        width: 58
                    )
                    
                    drawText(
                        row.deliveryTicket,
                        x: 328,
                        y: textY,
                        font: font,
                        width: 68
                    )
                    
                    drawText(
                        row.rateDescription,
                        x: 398,
                        y: textY,
                        font: font,
                        width: 50
                    )
                    
                    drawText(
                        row.fuelDescription,
                        x: 450,
                        y: textY,
                        font: font,
                        width: 50
                    )
                    
                    drawText(
                        String(format: "$%.2f", row.total),
                        x: 502,
                        y: textY,
                        font: font,
                        width: 58
                    )
                    
                    drawText(
                        row.driver,
                        x: 562,
                        y: textY,
                        font: font,
                        width: 192
                    )
                }
                
                func drawTotals(at y: CGFloat) {
                    
                    drawText(
                        "Invoice Totals",
                        x: 30,
                        y: y + 18,
                        font: .boldSystemFont(ofSize: 15),
                        width: 180
                    )
                    
                    let boxX: CGFloat = 485
                    let boxWidth: CGFloat = 275
                    let boxHeight: CGFloat = 92
                    
                    UIColor.black.setStroke()
                    
                    UIBezierPath(
                        roundedRect: CGRect(
                            x: boxX,
                            y: y,
                            width: boxWidth,
                            height: boxHeight
                        ),
                        cornerRadius: 8
                    ).stroke()
                    
                    drawText(
                        "Total Tons:",
                        x: boxX + 15,
                        y: y + 10,
                        font: .boldSystemFont(ofSize: 9.5),
                        width: 105
                    )
                    
                    drawText(
                        String(format: "%.2f", totalTons),
                        x: boxX + 145,
                        y: y + 10,
                        font: .systemFont(ofSize: 9.5),
                        width: 110,
                        alignment: .right
                    )
                    
                    drawText(
                        "Load Revenue:",
                        x: boxX + 15,
                        y: y + 29,
                        font: .boldSystemFont(ofSize: 9.5),
                        width: 110
                    )
                    
                    drawText(
                        String(format: "$%.2f", loadRevenue),
                        x: boxX + 145,
                        y: y + 29,
                        font: .systemFont(ofSize: 9.5),
                        width: 110,
                        alignment: .right
                    )
                    
                    drawText(
                        "Fuel Surcharge:",
                        x: boxX + 15,
                        y: y + 48,
                        font: .boldSystemFont(ofSize: 9.5),
                        width: 110
                    )
                    
                    drawText(
                        String(format: "$%.2f", fuelSurcharge),
                        x: boxX + 145,
                        y: y + 48,
                        font: .systemFont(ofSize: 9.5),
                        width: 110,
                        alignment: .right
                    )
                    
                    let dividerY = y + 69
                    
                    UIBezierPath(
                        rect: CGRect(
                            x: boxX + 12,
                            y: dividerY,
                            width: boxWidth - 24,
                            height: 0.5
                        )
                    ).fill()
                    
                    drawText(
                        "Grand Total:",
                        x: boxX + 15,
                        y: y + 73,
                        font: .boldSystemFont(ofSize: 11),
                        width: 110
                    )
                    
                    drawText(
                        String(format: "$%.2f", invoiceTotal),
                        x: boxX + 145,
                        y: y + 73,
                        font: .boldSystemFont(ofSize: 11),
                        width: 110,
                        alignment: .right
                    )
                }
                
                var currentPage = 1
                var rowsOnCurrentPage = 0
                var y: CGFloat = 0
                
                context.beginPage()
                drawInvoiceHeader()
                
                y = 82
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
                
                if y + 92 > pageHeight - 20 {
                    
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
