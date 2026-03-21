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
                
                HStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(riskColor)
                    Text("Infracción detectada")
                        .font(.caption2)
                        .foregroundColor(riskColor)
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
