import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class PDFGenerator {
    static func generateReport(for driver: Driver, activities: [DriverActivity]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "GloboFleet Mobile",
            kCGPDFContextAuthor: "GloboFleet"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Informe_\(driver.lastName).pdf")
        
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                
                // Header
                let title = "INFORME DE ACTIVIDADES - GLOBOFLEET"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18)
                ]
                title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
                
                // Conductor info
                let info = "Conductor: \(driver.firstName) \(driver.lastName)\nID Tarjeta: \(driver.id)\nFecha: \(Date().description)"
                info.draw(at: CGPoint(x: 50, y: 100), withAttributes: nil)
                
                // Resumen
                let summary = "Total Actividades: \(activities.count)"
                summary.draw(at: CGPoint(x: 50, y: 160), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12)])
            }
            return url
        } catch {
            print("Error generando PDF: \(error)")
            return nil
        }
    }
}
