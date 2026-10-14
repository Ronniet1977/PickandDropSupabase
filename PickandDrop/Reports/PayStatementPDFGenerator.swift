import Foundation
import UIKit

struct PayStatementData {
    
    let companyName: String
    
    let driverName: String
    let truckNumber: String
    let statementNumber: String
    let ytdEarnings: Double
    
    let weekStart: Date
    let weekEnd: Date
    
    let hourlyPay: Double
    let perLoadPay: Double
    let percentageLoadPay: Double
    
    let completedLoads: Int
    let hourlyJobs: Int
    
    let grossPay: Double
    
    let deductions: Double
    
    var netPay: Double {
        grossPay - deductions
    }
}

enum PayStatementPDFGenerator {
    
    static func createPDF(
        statement: PayStatementData
    ) -> URL? {
        
        let pageWidth: CGFloat = 792
        let pageHeight: CGFloat = 612
        
        let renderer =
        UIGraphicsPDFRenderer(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: pageWidth,
                height: pageHeight
            )
        )
        
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd"
        
        let safeDriver =
        statement.driverName
            .replacingOccurrences(
                of: " ",
                with: "-"
            )
        
        let fileName =
        "Pay-Statement-\(safeDriver)-\(fileFormatter.string(from: statement.weekEnd)).pdf"
        
        let url =
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(fileName)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let weekText =
        "\(dateFormatter.string(from: statement.weekStart)) - \(dateFormatter.string(from: statement.weekEnd))"
        
        let generatedText =
        Date().formatted(
            date: .abbreviated,
            time: .shortened
        )
        
        let charcoal =
        UIColor(
            red: 0.24,
            green: 0.24,
            blue: 0.24,
            alpha: 1
        )
        
        let gold =
        UIColor(
            red: 0.96,
            green: 0.69,
            blue: 0.23,
            alpha: 1
        )
        
        let lightBackground =
        UIColor(
            red: 0.96,
            green: 0.96,
            blue: 0.96,
            alpha: 1
        )
        
        do {
            
            try renderer.writePDF(
                to: url
            ) { context in
                
                context.beginPage()
                
                guard let cg =
                        UIGraphicsGetCurrentContext()
                else {
                    return
                }
                
                func drawText(
                    _ text: String,
                    x: CGFloat,
                    y: CGFloat,
                    width: CGFloat,
                    height: CGFloat = 24,
                    font: UIFont,
                    color: UIColor = .black,
                    alignment: NSTextAlignment = .left
                ) {
                    
                    let paragraph =
                    NSMutableParagraphStyle()
                    
                    paragraph.alignment =
                    alignment
                    
                    let attributes:
                    [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraph
                    ]
                    
                    text.draw(
                        in: CGRect(
                            x: x,
                            y: y,
                            width: width,
                            height: height
                        ),
                        withAttributes: attributes
                    )
                }
                
                func money(
                    _ value: Double
                ) -> String {
                    
                    String(
                        format: "$%.2f",
                        value
                    )
                }
                
                // MARK: Background
                
                cg.setFillColor(
                    lightBackground.cgColor
                )
                
                cg.fill(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: pageWidth,
                        height: pageHeight
                    )
                )
                
                // MARK: Header
                
                cg.setFillColor(
                    charcoal.cgColor
                )
                
                cg.fill(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: pageWidth,
                        height: 250
                    )
                )
                
                drawText(
                    statement.companyName.uppercased(),
                    x: 50,
                    y: 30,
                    width: 430,
                    height: 50,
                    font:
                            .boldSystemFont(
                                ofSize: 34
                            ),
                    color: gold
                )
                
                drawText(
                    "PAY STATEMENT",
                    x: 52,
                    y: 85,
                    width: 300,
                    font:
                            .systemFont(
                                ofSize: 14,
                                weight: .medium
                            ),
                    color: .white
                )
                
                drawText(
                    "PAY PERIOD",
                    x: 540,
                    y: 35,
                    width: 200,
                    font:
                            .systemFont(
                                ofSize: 10,
                                weight: .medium
                            ),
                    color: .white,
                    alignment: .right
                )
                
                drawText(
                    weekText,
                    x: 470,
                    y: 54,
                    width: 270,
                    font:
                            .boldSystemFont(
                                ofSize: 13
                            ),
                    color: .white,
                    alignment: .right
                )
                
                drawText(
                    "Generated \(generatedText)",
                    x: 470,
                    y: 75,
                    width: 270,
                    font:
                            .systemFont(
                                ofSize: 8
                            ),
                    color:
                            .white.withAlphaComponent(
                                0.7
                            ),
                    alignment: .right
                )
                
                drawText(
                    "STATEMENT #",
                    x: 470,
                    y: 98,
                    width: 270,
                    font:
                            .systemFont(
                                ofSize: 8,
                                weight: .medium
                            ),
                    color:
                            .white.withAlphaComponent(
                                0.7
                            ),
                    alignment: .right
                )
                
                drawText(
                    statement.statementNumber,
                    x: 470,
                    y: 112,
                    width: 270,
                    font:
                            .boldSystemFont(
                                ofSize: 10
                            ),
                    color: .white,
                    alignment: .right
                )
                
                // MARK: Driver info
                
                drawText(
                    "Driver",
                    x: 55,
                    y: 145,
                    width: 150,
                    font:
                            .systemFont(
                                ofSize: 9
                            ),
                    color:
                            .white.withAlphaComponent(
                                0.7
                            )
                )
                
                drawText(
                    statement.driverName,
                    x: 55,
                    y: 163,
                    width: 280,
                    font:
                            .boldSystemFont(
                                ofSize: 15
                            ),
                    color: .white
                )
                
                drawText(
                    "Truck",
                    x: 410,
                    y: 145,
                    width: 100,
                    font:
                            .systemFont(
                                ofSize: 9
                            ),
                    color:
                            .white.withAlphaComponent(
                                0.7
                            )
                )
                
                drawText(
                    statement.truckNumber,
                    x: 410,
                    y: 163,
                    width: 180,
                    font:
                            .boldSystemFont(
                                ofSize: 15
                            ),
                    color: .white
                )
                
                drawText(
                    "Position",
                    x: 610,
                    y: 145,
                    width: 100,
                    font:
                            .systemFont(
                                ofSize: 9
                            ),
                    color:
                            .white.withAlphaComponent(
                                0.7
                            )
                )
                
                drawText(
                    "Driver",
                    x: 610,
                    y: 163,
                    width: 130,
                    font:
                            .boldSystemFont(
                                ofSize: 15
                            ),
                    color: .white
                )
                
                // MARK: Section headers
                
                cg.setFillColor(
                    gold.cgColor
                )
                
                cg.fill(
                    CGRect(
                        x: 55,
                        y: 235,
                        width: 310,
                        height: 28
                    )
                )
                
                cg.fill(
                    CGRect(
                        x: 430,
                        y: 235,
                        width: 310,
                        height: 28
                    )
                )
                
                drawText(
                    "EARNINGS",
                    x: 55,
                    y: 240,
                    width: 310,
                    font:
                            .boldSystemFont(
                                ofSize: 13
                            ),
                    alignment: .center
                )
                
                drawText(
                    "SUMMARY",
                    x: 430,
                    y: 240,
                    width: 310,
                    font:
                            .boldSystemFont(
                                ofSize: 13
                            ),
                    alignment: .center
                    
                )
                
                // MARK: Earnings
                
                let leftLabelX: CGFloat = 75
                let leftValueX: CGFloat = 260
                
                var y: CGFloat = 285
                
                drawText(
                    "Hourly Jobs",
                    x: leftLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    money(statement.hourlyPay),
                    x: leftValueX,
                    y: y,
                    width: 90,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                y += 30
                
                drawText(
                    "Per Load Pay",
                    x: leftLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    money(statement.perLoadPay),
                    x: leftValueX,
                    y: y,
                    width: 90,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                y += 30
                
                drawText(
                    "Percentage Pay",
                    x: leftLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    money(
                        statement.percentageLoadPay
                    ),
                    x: leftValueX,
                    y: y,
                    width: 90,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                // MARK: Summary
                
                let rightLabelX: CGFloat = 450
                let rightValueX: CGFloat = 635
                
                y = 285
                
                drawText(
                    "Completed Loads",
                    x: rightLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    "\(statement.completedLoads)",
                    x: rightValueX,
                    y: y,
                    width: 80,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                y += 30
                
                drawText(
                    "Hourly Jobs",
                    x: rightLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    "\(statement.hourlyJobs)",
                    x: rightValueX,
                    y: y,
                    width: 80,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                y += 30
                
                drawText(
                    "Deductions",
                    x: rightLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    money(
                        statement.deductions
                    ),
                    x: rightValueX,
                    y: y,
                    width: 80,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                y += 30
                
                drawText(
                    "YTD Earnings",
                    x: rightLabelX,
                    y: y,
                    width: 170,
                    font:
                            .systemFont(
                                ofSize: 11
                            )
                )
                
                drawText(
                    money(
                        statement.ytdEarnings
                    ),
                    x: rightValueX,
                    y: y,
                    width: 80,
                    font:
                            .boldSystemFont(
                                ofSize: 11
                            ),
                    alignment: .right
                )
                
                // MARK: Total earnings bar
                
                cg.setFillColor(
                    gold.cgColor
                )
                
                cg.fill(
                    CGRect(
                        x: 55,
                        y: 420,
                        width: 685,
                        height: 34
                    )
                )
                
                drawText(
                    "TOTAL EARNINGS",
                    x: 75,
                    y: 428,
                    width: 200,
                    font:
                            .boldSystemFont(
                                ofSize: 12
                            )
                )
                
                drawText(
                    money(statement.grossPay),
                    x: 550,
                    y: 428,
                    width: 165,
                    font:
                            .boldSystemFont(
                                ofSize: 13
                            ),
                    alignment: .right
                )
                
                // MARK: Net pay
                
                cg.setFillColor(
                    charcoal.cgColor
                )
                
                cg.fill(
                    CGRect(
                        x: 430,
                        y: 468,
                        width: 310,
                        height: 52
                    )
                )
                
                drawText(
                    "NET PAY",
                    x: 450,
                    y: 482,
                    width: 120,
                    font:
                            .boldSystemFont(
                                ofSize: 16
                            ),
                    color: .white
                )
                
                drawText(
                    money(statement.netPay),
                    x: 575,
                    y: 481,
                    width: 145,
                    font:
                            .boldSystemFont(
                                ofSize: 18
                            ),
                    color: .white,
                    alignment: .right
                )
                
                // MARK: Footer
                
                drawText(
                    "Generated by Pick & Drop",
                    x: 55,
                    y: 552,
                    width: 300,
                    font:
                            .systemFont(
                                ofSize: 8
                            ),
                    color: .darkGray
                )
                
                cg.setStrokeColor(
                    UIColor.darkGray.cgColor
                )
                
                cg.setLineWidth(1)
                
                cg.move(
                    to: CGPoint(
                        x: 500,
                        y: 555
                    )
                )
                
                cg.addLine(
                    to: CGPoint(
                        x: 720,
                        y: 555
                    )
                )
                
                cg.strokePath()
                
                drawText(
                    "Driver Signature",
                    x: 500,
                    y: 560,
                    width: 220,
                    font:
                            .italicSystemFont(
                                ofSize: 8
                            ),
                    color: .darkGray,
                    alignment: .center
                )
            }
            
            return url
            
        } catch {
            
            print(
                "❌ Pay statement PDF failed:",
                error
            )
            
            return nil
        }
    }
}

