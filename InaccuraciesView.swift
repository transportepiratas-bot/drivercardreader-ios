import SwiftUI

struct InaccuraciesView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    @State private var selectedVehicle: String? = nil
    
    var body: some View {
        ZStack {
            Color.globoBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // --- Cabecera de Riesgo ---
                RiskLevelHeader(infringements: filteredInfringements)
                
                // --- Filtro por Matrícula ---
                if let data = readerVM.tachoData, !data.vehicles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(data.vehicles, id: \.self) { vehicle in
                                Button(action: {
                                    if selectedVehicle == vehicle {
                                        selectedVehicle = nil
                                    } else {
                                        selectedVehicle = vehicle
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "truck.box.fill")
                                            .font(.caption2)
                                        Text(vehicle)
                                            .font(.caption2)
                                            .bold()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedVehicle == vehicle ? Color.globoAccent.opacity(0.4) : Color.white.opacity(0.1))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedVehicle == vehicle ? Color.globoAccent : Color.clear, lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 15)
                    }
                    .background(Color.black.opacity(0.1))
                }
                
                if filteredInfringements.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.globoSuccess)
                        Text("No se detectaron infracciones")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Su conducción cumple con el Reg. 561/2006.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(filteredInfringements) { infringement in
                                InfringementCard(infringement: infringement)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Informe de Infracciones")
    }
    
    private var filteredInfringements: [Infringement] {
        if let targetVehicle = selectedVehicle {
            return readerVM.infringements.filter { $0.vehiclePlate == targetVehicle || $0.vehiclePlate == nil }
        }
        return readerVM.infringements
    }
}

struct RiskLevelHeader: View {
    let infringements: [Infringement]
    
    var body: some View {
        VStack(spacing: 8) {
            Text("NIVEL DE RIESGO")
                .font(.caption2)
                .bold()
                .tracking(2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(riskLevelTitle)
                .font(.system(.title, design: .rounded))
                .bold()
                .foregroundColor(riskLevelColor)
            
            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(i < riskLevelIndex ? riskLevelColor : Color.white.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .frame(width: 150)
        }
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.2))
    }
    
    private var riskLevelIndex: Int {
        if infringements.isEmpty { return 1 }
        if infringements.contains(where: { $0.severity == .verySerious }) { return 4 }
        if infringements.contains(where: { $0.severity == .serious }) { return 3 }
        return 2
    }
    
    private var riskLevelTitle: String {
        switch riskLevelIndex {
        case 1: return "BAJO"
        case 2: return "LEVE"
        case 3: return "MEDIO"
        default: return "ALTO"
        }
    }
    
    private var riskLevelColor: Color {
        switch riskLevelIndex {
        case 1: return .globoSuccess
        case 2: return .globoWarning
        case 3: return .orange
        default: return .globoDanger
        }
    }
}

struct InfringementCard: View {
    let infringement: Infringement
    @State private var showRegulation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera color según severidad
            HStack {
                Text(infringement.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                
                if let plate = infringement.vehiclePlate {
                    Text(plate)
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 4)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(2)
                        .padding(.leading, 4)
                }
                
                Spacer()
                Text(severityLabel)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(riskColor.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "calendar")
                    Text(dateRangeString)
                        .font(.caption)
                    Spacer()
                    Text(infringement.article)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.globoAccent)
                }
                .foregroundColor(.gray)
                
                Text(infringement.description)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(nil)
                
                Button(action: {
                    showRegulation = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(riskColor)
                        Text("Ver normativa")
                            .font(.caption2)
                            .foregroundColor(riskColor)
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showRegulation) {
            RegulationDetailView(infringement: infringement)
        }
    }
    
    private var riskColor: Color {
        switch infringement.severity {
        case .minor: return .globoWarning
        case .serious: return .orange
        case .verySerious: return .globoDanger
        }
    }
    
    private var severityLabel: String {
        switch infringement.severity {
        case .minor: return "LEVE"
        case .serious: return "GRAVE"
        case .verySerious: return "MUY GRAVE"
        }
    }
    
    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.timeZone = TimeZone.current // Explicitly use device's local timezone
        return formatter.string(from: infringement.timestamp)
    }
}

struct RegulationDetailView: View {
    let infringement: Infringement
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(infringement.article)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.globoAccent)
                        
                        Text(infringement.title)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Descripción de la infracción
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Descripción de la infracción")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.globoAccent)
                        
                        Text(infringement.description)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Normativa aplicable
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Normativa aplicable")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.globoAccent)
                        
                        Text(getRegulationText())
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Consecuencias
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Consecuencias")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.globoAccent)
                        
                        Text(getConsequences())
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.globoBlue.edgesIgnoringSafeArea(.all))
            .navigationTitle("Normativa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(.globoAccent)
                }
            }
        }
    }
    
    private func getRegulationText() -> String {
        // Mapear artículos a textos de normativa
        switch infringement.article {
        case "Art. 6 - Tiempo de conducción diario":
            return "Reglamento (CE) 561/2006, Artículo 6:\n\n• La conducción diaria no puede exceder las 9 horas.\n• Puede ampliarse a 10 horas dos veces por semana.\n• La conducción debe interrumpirse cada 4 horas y media."
            
        case "Art. 7 - Tiempo de conducción semanal":
            return "Reglamento (CE) 561/2006, Artículo 7:\n\n• La conducción semanal no puede exceder las 56 horas.\n• La conducción en dos semanas consecutivas no puede superar las 90 horas."
            
        case "Art. 8 - Descanso diario":
            return "Reglamento (CE) 561/2006, Artículo 8:\n\n• El descanso diario debe ser de al menos 11 horas.\n• Puede reducirse a 9 horas tres veces por semana.\n• El descanso puede fraccionarse en dos períodos."
            
        case "Art. 12 - Pausas":
            return "Reglamento (CE) 561/2006, Artículo 12:\n\n• Después de 4 horas y media de conducción, el conductor debe hacer una pausa de al menos 45 minutos.\n• La pausa puede dividirse en dos períodos de 15 y 30 minutos."
            
        default:
            return "Reglamento (CE) 561/2006 sobre los tiempos de conducción y descanso de los conductores de transporte por carretera.\n\nEsta normativa establece los límites máximos de conducción y los tiempos mínimos de descanso para garantizar la seguridad vial."
        }
    }
    
    private func getConsequences() -> String {
        switch infringement.severity {
        case .minor:
            return "Infracción LEVE:\n• Sanción económica de 100 a 200 euros.\n• No implica pérdida de puntos."
            
        case .serious:
            return "Infracción GRAVE:\n• Sanción económica de 200 a 500 euros.\n• Pérdida de 2 puntos del permiso de conducción.\n• Posible inmovilización del vehículo."
            
        case .verySerious:
            return "Infracción MUY GRAVE:\n• Sanción económica de 500 a 2.000 euros.\n• Pérdida de 4 puntos del permiso de conducción.\n• Inmovilización del vehículo.\n• Posible suspensión del permiso."
        }
    }
}
