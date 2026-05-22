//
//  InvoiceGenerator.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import PDFKit

struct InvoiceGenerator {
    
    static func createInvoicePDF(
        companyName: String,
        pickupCompany: String,
        dropoffCompany: String,
        invoiceTitle: String = "Invoice",
        driverName: String,
        truckNumber: String,
        loads: [CSVLoad],
        ratePerTon: Double,
        useDeliveryTons: Bool
    ) -> URL? {
        
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let safeDriver = driverName.replacingOccurrences(of: " ", with: "_")
        let safeTruck = truckNumber.replacingOccurrences(of: " ", with: "_")
        let safeCompany =
            companyName.replacingOccurrences(of: " ", with: "_")

        let fileName = "\(safeCompany)_Invoice_\(safeDriver)_Truck_\(safeTruck).pdf"
        let url = StorageManager
            .truckReportsFolder()
            .appendingPathComponent(fileName)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
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
                
                // MARK: - Header
                
                drawText(companyName, x: 40, y: y, font: .boldSystemFont(ofSize: 26))
                y += 34
                
                drawText(invoiceTitle, x: 40, y: y, font: .boldSystemFont(ofSize: 20))
                y += 34
                
                drawText(
                    "Route: \(pickupCompany) → \(dropoffCompany)",
                    x: 40,
                    y: y,
                    font: .systemFont(ofSize: 13)
                )

                y += 24
                
                drawText("Driver: \(driverName)", x: 40, y: y, font: .systemFont(ofSize: 14))
                y += 22
                
                drawText("Truck: \(truckNumber)", x: 40, y: y, font: .systemFont(ofSize: 14))
                y += 22
                
                drawText("Date: \(Date().formatted(date: .abbreviated, time: .omitted))", x: 40, y: y, font: .systemFont(ofSize: 14))
                y += 34
                
                // MARK: - Table Header
                
                let headerY = y
                
                UIColor.systemGray5.setFill()
                UIBezierPath(rect: CGRect(x: 40, y: headerY, width: 532, height: 28)).fill()
                
                drawText("Ticket", x: 48, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 90)
                drawText("Driver", x: 135, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 130)
                drawText("Date", x: 270, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 90)
                drawText("Tons", x: 370, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 60)
                drawText("Rate", x: 435, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 60)
                drawText("Total", x: 500, y: y + 6, font: .boldSystemFont(ofSize: 11), width: 70)
                
                y += 34
                
                // MARK: - Rows
                
                var totalTons = 0.0
                var grandTotal = 0.0
                
                for load in loads {

                    let tons = useDeliveryTons
                        ? load.deliveryTons
                        : load.pickupTons
                    let lineTotal = tons * ratePerTon

                    totalTons += tons
                    grandTotal += lineTotal

                    let tonsString = String(format: "%.2f", tons)
                    let rateString = String(format: "$%.2f", ratePerTon)
                    let totalString = String(format: "$%.2f", lineTotal)

                    let ticket = useDeliveryTons
                        ? load.deliveryTicket
                        : load.pickupTicket

                    drawText(
                        ticket,
                        x: 48,
                        y: y,
                        font: .systemFont(ofSize: 10),
                        width: 80
                    )

                    drawText(load.driverName, x: 135, y: y, font: .systemFont(ofSize: 10), width: 125)

                    drawText(
                        load.date,
                        x: 270,
                        y: y,
                        font: .systemFont(ofSize: 10),
                        width: 90
                    )

                    drawText(
                        tonsString,
                        x: 370,
                        y: y,
                        font: .systemFont(ofSize: 10),
                        width: 55
                    )

                    drawText(
                        rateString,
                        x: 435,
                        y: y,
                        font: .systemFont(ofSize: 10),
                        width: 60
                    )

                    drawText(
                        totalString,
                        x: 500,
                        y: y,
                        font: .systemFont(ofSize: 10),
                        width: 70
                    )

                    y += 22
                    
                    if y > 700 {
                        context.beginPage()
                        y = 40
                    }
                }
                
                y += 20
                
                // MARK: - Totals
                
                UIColor.black.setStroke()
                UIBezierPath(rect: CGRect(x: 360, y: y, width: 212, height: 80)).stroke()
                
                let totalTonsString = String(format: "%.2f", totalTons)
                let grandTotalString = String(format: "$%.2f", grandTotal)

                drawText(
                    "Total Tons:",
                    x: 375,
                    y: y + 12,
                    font: .boldSystemFont(ofSize: 13),
                    width: 90
                )

                drawText(
                    totalTonsString,
                    x: 485,
                    y: y + 12,
                    font: .systemFont(ofSize: 13),
                    width: 70
                )

                drawText(
                    "Amount Due:",
                    x: 375,
                    y: y + 42,
                    font: .boldSystemFont(ofSize: 15),
                    width: 100
                )

                drawText(
                    grandTotalString,
                    x: 485,
                    y: y + 42,
                    font: .boldSystemFont(ofSize: 15),
                    width: 80
                )
            }
            
            return url
            
        } catch {
            print("PDF invoice error:", error)
            return nil
        }
    }
}
