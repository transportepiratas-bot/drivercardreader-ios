import Foundation
import PDFKit
import UIKit

class ReportGenerator {
    
    /// Genera un informe PDF profesional con el resumen de actividades e infracciones
    static func generateActivityReport(data: DDDParser.TachoBinaryData, vehicleFilter: String? = nil) -> Data? {
        // Filtrar actividades por vehículo si se especifica
        let filteredActivities: [DriverActivity]
        let reportTitle: String
        
        if let vehicle = vehicleFilter {
            filteredActivities = data.activities.filter { $0.vehiclePlate == vehicle }
            reportTitle = "Informe de Conducción - \(vehicle)"
        } else {
            filteredActivities = data.activities
            reportTitle = "Informe de Conducción - \(data.driverName) \(data.driverSurname)"
        }
        
        let pdfMetaData = [
            kCGPDFContextTitle: reportTitle,
            kCGPDFContextAuthor: "Driver Card Reader iOS Pro"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { (context) in
            context.beginPage()
            
            // --- HEADER ---
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 100)
            UIColor(hex: "2D3E33").setFill()
            context.fill(headerRect)
            
            let title = "REPORTE TÉCNICO DE ACTIVIDADES"
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            title.draw(at: CGPoint(x: 40, y: 35), withAttributes: titleAttributes)
            
            let subtitle = "Cumplimiento Reglamento (UE) 561/2006"
            let subtitleFont = UIFont.systemFont(ofSize: 10)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.lightGray
            ]
            subtitle.draw(at: CGPoint(x: 40, y: 65), withAttributes: subtitleAttributes)
            
            // --- INFO CONDUCTOR (TABLE-LIKE) ---
            var currentY: CGFloat = 130
            drawSectionHeader(context, title: "DATOS DEL CONDUCTOR", y: currentY, width: pageWidth)
            currentY += 40
            
            let driverInfo = [
                ("Nombre Completo:", "\(data.driverName) \(data.driverSurname)"),
                ("Nº Tarjeta:", data.cardNumber),
                ("Fecha Generación:", Date().formatted(date: .long, time: .shortened)),
                ("Estado:", data.infringements.isEmpty ? "SIN INFRACCIONES" : "CON INFRACCIONES")
            ]
            
            for (label, value) in driverInfo {
                drawInfoRow(context, label: label, value: value, x: 50, y: currentY)
                currentY += 25
            }
            
            // --- RESUMEN DE TIEMPOS (TOTAL ARCHIVO) ---
            currentY += 20
            let sectionTitle = vehicleFilter != nil ? "RESUMEN DEL VEHÍCULO" : "RESUMEN ACUMULADO DEL ARCHIVO"
            drawSectionHeader(context, title: sectionTitle, y: currentY, width: pageWidth)
            currentY += 40
            
            let totalDriving = filteredActivities.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration }
            let totalWork = filteredActivities.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
            let totalRest = filteredActivities.filter { $0.type == .breakOrRest }.reduce(0) { $0 + $1.duration }
            let totalAvail = filteredActivities.filter { $0.type == .availability }.reduce(0) { $0 + $1.duration }
            
            drawInfoRow(context, label: "Total Conducción:", value: formatDuration(totalDriving), x: 50, y: currentY)
            currentY += 25
            drawInfoRow(context, label: "Total Trabajo:", value: formatDuration(totalWork), x: 50, y: currentY)
            currentY += 25
            drawInfoRow(context, label: "Total Descanso:", value: formatDuration(totalRest), x: 50, y: currentY)
            currentY += 25
            drawInfoRow(context, label: "Total Disponibilidad:", value: formatDuration(totalAvail), x: 50, y: currentY)
            currentY += 25
            drawInfoRow(context, label: "Total Actividades:", value: "\(filteredActivities.count)", x: 50, y: currentY)
            currentY += 40
            
            // --- RESUMEN DE JORNADAS ---
            if !data.shifts.isEmpty {
                drawSectionHeader(context, title: "ÚLTIMAS JORNADAS (SHIFTS)", y: currentY, width: pageWidth)
                currentY += 40
                
                for shift in data.shifts.prefix(5) {
                    let shiftText = "\(shift.start.formatted(date: .abbreviated, time: .shortened)) - \(formatDuration(shift.drivingTime)) conducción"
                    shiftText.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black])
                    currentY += 20
                    
                    if currentY > pageHeight - 100 {
                        context.beginPage()
                        currentY = 50
                    }
                }
                currentY += 20
            }
            
            // --- INFRACCIONES (SI EXISTEN) ---
            drawSectionHeader(context, title: "DETALLE DE INFRACCIONES", y: currentY, width: pageWidth, color: .red)
            currentY += 40
            
            if data.infringements.isEmpty {
                "No se han detectado infracciones en el periodo analizado.".draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray])
            } else {
                for infr in data.infringements {
                    let infrTitle = "\(infr.severity.rawValue): \(infr.title)"
                    let infrFont = UIFont.boldSystemFont(ofSize: 11)
                    infrTitle.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: infrFont, .foregroundColor: UIColor.black])
                    
                    currentY += 15
                    let infrDesc = "\(infr.description) (Art: \(infr.article))"
                    let descFont = UIFont.systemFont(ofSize: 9)
                    infrDesc.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: descFont, .foregroundColor: UIColor.gray])
                    
                    currentY += 30
                    if currentY > pageHeight - 100 {
                        context.beginPage()
                        currentY = 50
                    }
                }
            }
            
            // --- PIE DE PÁGINA ---
            let footerText = "Este informe es un documento generado automáticamente. Verifique siempre los datos con el tacógrafo original."
            let footerFont = UIFont.italicSystemFont(ofSize: 8)
            let footerAttributes: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footerX = (pageWidth - footerText.size(withAttributes: footerAttributes).width) / 2
            footerText.draw(at: CGPoint(x: footerX, y: pageHeight - 50), withAttributes: footerAttributes)
        }
        
        return pdfData
    }
    
    private static func drawSectionHeader(_ context: UIGraphicsPDFRendererContext, title: String, y: CGFloat, width: CGFloat, color: UIColor = UIColor(hex: "2D3E33")) {
        let rect = CGRect(x: 40, y: y, width: width - 80, height: 25)
        color.withAlphaComponent(0.1).setFill()
        context.fill(rect)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y + 25))
        path.addLine(to: CGPoint(x: width - 40, y: y + 25))
        color.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        let font = UIFont.boldSystemFont(ofSize: 12)
        title.draw(at: CGPoint(x: 45, y: y + 5), withAttributes: [.font: font, .foregroundColor: color])
    }
    
    private static func drawInfoRow(_ context: UIGraphicsPDFRendererContext, label: String, value: String, x: CGFloat, y: CGFloat) {
        let labelFont = UIFont.boldSystemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 11)
        
        label.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: labelFont, .foregroundColor: UIColor.darkGray])
        value.draw(at: CGPoint(x: x + 150, y: y), withAttributes: [.font: valueFont, .foregroundColor: UIColor.black])
    }
    
    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return "\(mins / 60)h \(mins % 60)m"
    }
}

// Extensions handled in ColorExtensions.swift
