import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    @State private var pdfData: Data?
    @State private var showingShareSheet = false
    @State private var selectedVehicle: String? = nil
    @State private var selectedTab = 0 // 0: Actividades, 1: Jornadas
    
    var body: some View {
        ZStack {
            Color.globoBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header con info del conductor
                if let data = readerVM.tachoData {
                    DriverInfoHeader(data: data, selectedVehicle: $selectedVehicle)
                }
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Resumen de Tiempos
                        let filtered = filteredActivities(from: readerVM.tachoData?.activities ?? [])
                        let drivingHours = filtered.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration } / 3600
                        let workHours = filtered.filter { $0.type == .work }.reduce(0) { $0 + $1.duration } / 3600
                        let breakHours = filtered.filter { $0.type == .breakOrRest }.reduce(0) { $0 + $1.duration } / 3600
                        
                        HStack(spacing: 12) {
                            StatCard(title: "CONDUCCIÓN", value: String(format: "%.1fh", drivingHours), icon: "steeringwheel", color: .globoAccent)
                            StatCard(title: "TRABAJO", value: String(format: "%.1fh", workHours), icon: "hammer.fill", color: .globoWarning)
                            StatCard(title: "DESCANSO", value: String(format: "%.1fh", breakHours), icon: "bed.double.fill", color: .globoSuccess)
                        }
                        .padding(.horizontal)
                        
                        // Kilometraje
                        HStack {
                            VStack(alignment: .leading) {
                                Text("KILOMETRAJE")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.5))
                                let km = drivingHours * 80
                                Text(String(format: "%.0f km", km))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "road.lanes")
                                .font(.title)
                                .foregroundColor(.globoAccent)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Timeline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CRONOGRAMA DE ACTIVIDADES")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white.opacity(0.5))
                            
                            let timelineActivities = filteredActivities(from: readerVM.tachoData?.activities ?? [])
                            InteractiveTimelineView(activities: timelineActivities)
                                .frame(height: 120)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Selector de vista
                        Picker("", selection: $selectedTab) {
                            Text("Actividades").tag(0)
                            Text("Jornadas").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .background(Color.globoBlue)
                        
                        // Lista de datos
                        if let data = readerVM.tachoData {
                            if selectedTab == 0 {
                                // Lista de actividades
                                let listActivities = filteredActivities(from: data.activities)
                                if !listActivities.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ÚLTIMAS ACTIVIDADES")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        ForEach(listActivities.sorted(by: { $0.start > $1.start }).prefix(20)) { activity in
                                            ActivityRow(activity: activity)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            } else {
                                // Lista de Jornadas (Shifts)
                                if !readerVM.shifts.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("RESUMEN DE JORNADAS")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        ForEach(readerVM.shifts) { shift in
                                            ShiftRow(shift: shift)
                                        }
                                    }
                                    .padding(.horizontal)
                                } else {
                                    Text("No hay jornadas calculadas")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Resumen")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func filteredActivities(from activities: [DriverActivity]) -> [DriverActivity] {
        return activities.filter { activity in
            if let targetVehicle = selectedVehicle {
                return activity.vehiclePlate == targetVehicle
            }
            return true
        }
    }
}

struct DriverInfoHeader: View {
    let data: DDDParser.TachoBinaryData
    @Binding var selectedVehicle: String?
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.globoAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(data.driverName) \(data.driverSurname)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("ID: \(data.cardNumber)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    if !data.company.isEmpty {
                        Text(data.company)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 10) {
                    Button(action: {
                        if let pdf = ReportGenerator.generateActivityReport(data: data) {
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Informe_GloboFleet.pdf")
                            try? pdf.write(to: url)
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = scene.windows.first?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }
                    }) {
                        Label("PDF", systemImage: "doc.text.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.globoAccent)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    // Calculamos actividades con el filtro aquí también
                    let filteredActivities = data.activities.filter { activity in
                         if let targetVehicle = selectedVehicle {
                             return activity.vehiclePlate == targetVehicle
                         }
                         return true
                    }
                    Text("\(filteredActivities.count)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.globoAccent)
                    Text("actividades")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Vehículos utilizados
            if !data.vehicles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(data.vehicles, id: \.self) { vehicle in
                            Button(action: {
                                if selectedVehicle == vehicle {
                                    selectedVehicle = nil
                                } else {
                                    selectedVehicle = vehicle
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "car.fill")
                                        .font(.caption)
                                    Text(vehicle)
                                        .font(.caption)
                                    if selectedVehicle == vehicle {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.globoAccent)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedVehicle == vehicle ? Color.globoAccent.opacity(0.3) : Color.white.opacity(0.1))
                                .cornerRadius(15)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let activity: DriverActivity
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }
    
    var body: some View {
        HStack {
            Text(timeFormatter.string(from: activity.start))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 60)
            
            Group {
                if activity.type == .availability {
                    availabilityIcon()
                        .foregroundColor(colorFor(activity.type))
                } else {
                    Image(systemName: iconFor(activity.type))
                        .foregroundColor(colorFor(activity.type))
                }
            }
            .frame(width: 30)
            
            Text(nameFor(activity.type))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(durationString(activity.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
    
    private func iconFor(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "steeringwheel"
        case .work: return "hammer.fill"
        case .availability: return "square"
        case .breakOrRest: return "bed.double.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    // Vista personalizada para el icono de disponibilidad
    private func availabilityIcon() -> some View {
        ZStack {
            // Cuadrado base
            Image(systemName: "square")
                .font(.system(size: 12))
            
            // Línea diagonal de arriba a la derecha hacia abajo a la izquierda
            Path { path in
                let size: CGFloat = 12
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
        }
    }
    
    private func colorFor(_ type: ActivityType) -> Color {
        switch type {
        case .driving: return .globoAccent
        case .work: return .globoWarning
        case .availability: return .gray
        case .breakOrRest: return .globoSuccess
        case .unknown: return .gray
        }
    }
    
    private func nameFor(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "CONDUCCIÓN"
        case .work: return "TRABAJO"
        case .availability: return "DISPONIBLE"
        case .breakOrRest: return "DESCANSO"
        case .unknown: return "?"
        }
    }
    
    private func durationString(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let h = mins / 60
        let m = mins % 60
        return String(format: "%02d:%02d", h, m)
    }
}

struct ShiftRow: View {
    let shift: TachoShift
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.start.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(shift.start.formatted(date: .omitted, time: .shortened))
                        Text("→")
                        Text(shift.end.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f km", shift.distance))
                        .font(.headline)
                        .foregroundColor(.globoAccent)
                    
                    Text("Distancia")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack(spacing: 20) {
                smallStat(title: "Conduc.", value: formatTime(shift.drivingTime), color: .globoAccent)
                smallStat(title: "Trab.", value: formatTime(shift.workTime), color: .globoWarning)
                smallStat(title: "Dispon.", value: formatTime(shift.availabilityTime), color: .gray)
                smallStat(title: "Pausa", value: formatTime(shift.restTime), color: .globoSuccess)
            }
            .padding()
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func smallStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return String(format: "%dh %02dm", mins / 60, mins % 60)
    }
}
