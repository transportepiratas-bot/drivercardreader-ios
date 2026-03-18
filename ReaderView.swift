import SwiftUI
import UniformTypeIdentifiers

struct ReaderView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    @State private var showingFilePicker = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedVehicle: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.globoBlue.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // HEADER
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Gf Mobile")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.white)
                                Text(readerVM.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.globoAccent)
                            }
                            Spacer()
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.globoAccent)
                                .font(.title2)
                        }
                        .padding(.horizontal)
                        
                        // SELECTOR DE FECHAS
                        VStack(spacing: 8) {
                            HStack {
                                Text("PERIODO")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Desde")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                                
                                Text("→")
                                    .foregroundColor(.white.opacity(0.5))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hasta")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                    DatePicker("", selection: $endDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // RESUMEN DEL PERIODO SELECCIONADO
                        if let data = readerVM.tachoData {
                            let filteredActivities = filterActivities(data.activities)

                            let summary = calculateSummary(activities: filteredActivities)
                            
                            // ESTADÍSTICAS PRINCIPALES
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    StatBox(title: "CONDUCCIÓN", value: String(format: "%.1fh", summary.drivingHours), icon: "steeringwheel", color: .globoAccent)
                                    StatBox(title: "TRABAJO", value: String(format: "%.1fh", summary.workHours), icon: "hammer.fill", color: .globoWarning)
                                    StatBox(title: "DESCANSO", value: String(format: "%.1fh", summary.breakHours), icon: "bed.double.fill", color: .globoSuccess)
                                }
                                
                                HStack(spacing: 12) {
                                    StatBox(title: "TRABAJO EFECTIVO", value: String(format: "%.1fh", summary.effectiveWork), icon: "clock.fill", color: .white)
                                    StatBox(title: "DÍAS", value: "\(summary.daysCount)", icon: "calendar", color: .white)
                                    StatBox(title: "KM EST.", value: String(format: "%.0f", summary.estimatedKM), icon: "road.lanes", color: .white)
                                }
                            }
                            .padding(.horizontal)
                            
                            // DETALLE DE TIEMPOS
                            VStack(spacing: 8) {
                                Text("DETALLE DEL PERIODO")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                DetailRow(label: "Tiempo de conducción", value: String(format: "%.1f horas", summary.drivingHours))
                                DetailRow(label: "Tiempo de trabajo", value: String(format: "%.1f horas", summary.workHours))
                                DetailRow(label: "Tiempo de descanso", value: String(format: "%.1f horas", summary.breakHours))
                                DetailRow(label: "Trabajo efectivo (conducción + trabajo)", value: String(format: "%.1f horas", summary.effectiveWork))
                                DetailRow(label: "Días con actividad", value: "\(summary.daysCount) días")
                                DetailRow(label: "Kilómetros estimados", value: String(format: "%.0f km", summary.estimatedKM))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // INFORMACIÓN DEL CONDUCTOR
                        if let data = readerVM.tachoData {
                            DriverCard(data: data)
                        }
                        
                        // PRONÓSTICO (NUEVO)
                        if readerVM.tachoData != nil {
                            NavigationLink(destination: PlanningView()) {
                                ForecastCard(info: readerVM.planningInfo)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // INFRACCIONES
                        if readerVM.infringements.count > 0 {
                            NavigationLink(destination: InaccuraciesView()) {
                                InfringementsCard(count: readerVM.infringements.count)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // EVENTOS Y AVERÍAS
                        if readerVM.events.count > 0 {
                            NavigationLink(destination: EventsView()) {
                                EventsCard(count: readerVM.events.count)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // VEHÍCULOS
                        if let data = readerVM.tachoData, !data.vehicles.isEmpty {
                            VehiclesCard(vehicles: data.vehicles, selectedVehicle: $selectedVehicle)
                        }
                        
                        // BOTONES
                        VStack(spacing: 12) {
                            ActionButton(title: "LEER TARJETA", icon: "creditcard.viewfinder", color: .globoAccent) {}
                            ActionButton(title: "IMPORTAR .TGD", icon: "doc.badge.arrow.up", color: .white.opacity(0.1)) {
                                showingFilePicker = true
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { data, _ in
                    readerVM.processData(data)
                }
            }
        }
    }
    
    private func filterActivities(_ activities: [DriverActivity]) -> [DriverActivity] {
        return activities.filter { activity in
            let dateMatch = activity.start >= startDate && activity.start <= endDate
            
            if let targetVehicle = selectedVehicle {
                // Filtro estricto por matrícula
                return dateMatch && activity.vehiclePlate == targetVehicle
            }
            return dateMatch
        }
    }
    
    private func calculateSummary(activities: [DriverActivity]) -> ActivitySummary {
        let drivingHours = activities.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration } / 3600
        let workHours = activities.filter { $0.type == .work }.reduce(0) { $0 + $1.duration } / 3600
        let breakHours = activities.filter { $0.type == .breakOrRest }.reduce(0) { $0 + $1.duration } / 3600
        let effectiveWork = drivingHours + workHours
        let estimatedKM = drivingHours * 80 // promedio 80 km/h
        
        let calendar = Calendar.current
        let daysSet = Set(activities.map { calendar.startOfDay(for: $0.start) })
        let daysCount = daysSet.count
        
        return ActivitySummary(
            drivingHours: drivingHours,
            workHours: workHours,
            breakHours: breakHours,
            effectiveWork: effectiveWork,
            estimatedKM: estimatedKM,
            daysCount: daysCount
        )
    }
}

struct ActivitySummary {
    var drivingHours: Double = 0
    var workHours: Double = 0
    var breakHours: Double = 0
    var effectiveWork: Double = 0
    var estimatedKM: Double = 0
    var daysCount: Int = 0
}

// MARK: - Componentes

struct StatBox: View {
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
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
}

struct DriverCard: View {
    let data: DDDParser.TachoBinaryData
    
    private var utcDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.globoAccent)
                
                VStack(alignment: .leading) {
                    Text("\(data.driverName) \(data.driverSurname)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("ID: \(data.cardNumber)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    if !data.company.isEmpty {
                        Text(data.company)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
            }
            
            if !data.activities.isEmpty {
                Divider().background(Color.white.opacity(0.2))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Primera actividad")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                        if let firstActivity = data.activities.min(by: { $0.start < $1.start }) {
                            Text(utcDateFormatter.string(from: firstActivity.start))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Última actividad")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                        if let lastActivity = data.activities.max(by: { $0.start < $1.start }) {
                            Text(utcDateFormatter.string(from: lastActivity.start))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InfringementsCard: View {
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.globoDanger)
            VStack(alignment: .leading) {
                Text("INFRACCIONES")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white.opacity(0.5))
                Text("\(count) detectadas")
                    .font(.headline)
                    .foregroundColor(.globoDanger)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct VehiclesCard: View {
    let vehicles: [String]
    @Binding var selectedVehicle: String?
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VEHÍCULOS")
                .font(.caption)
                .bold()
                .foregroundColor(.white.opacity(0.5))
            
            ForEach(vehicles, id: \.self) { vehicle in
                Button(action: {
                    if selectedVehicle == vehicle {
                        selectedVehicle = nil
                    } else {
                        selectedVehicle = vehicle
                    }
                }) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(selectedVehicle == vehicle ? .globoAccent : .gray)
                        Text(vehicle)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedVehicle == vehicle {
                            Image(systemName: "checkmark")
                                .foregroundColor(.globoAccent)
                        }
                    }
                    .padding(.vertical, 4)
                    .background(selectedVehicle == vehicle ? Color.globoAccent.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Mostrar información del vehículo seleccionado
                if selectedVehicle == vehicle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Información del vehículo")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Contar actividades por vehículo
                        if let data = readerVM.tachoData {
                            let vehicleActivities = data.activities.filter { $0.vehiclePlate == vehicle }
                            
                            Text("\(vehicleActivities.count) actividades registradas")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            // Estadísticas básicas
                            let totalDuration = vehicleActivities.reduce(0) { $0 + $1.duration }
                            let drivingDuration = vehicleActivities.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration }
                            
                            HStack {
                                Text("Tiempo total: \(Int(totalDuration / 3600))h \(Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60))m")
                                Spacer()
                                Text("Conducción: \(Int(drivingDuration / 3600))h \(Int((drivingDuration.truncatingRemainder(dividingBy: 3600)) / 60))m")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.5)
            }
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct EventsCard: View {
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.globoAccent)
            VStack(alignment: .leading) {
                Text("EVENTOS Y AVERÍAS")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white.opacity(0.5))
                Text("\(count) registros técnicos")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// PRONÓSTICO CARD
struct ForecastCard: View {
    let info: PlanningInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PRONÓSTICO", systemImage: "timer")
                    .font(.caption.bold())
                    .foregroundColor(.globoAccent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(formatDuration(info.remainingContinuousDriving))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Conducción Cont.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Divider().frame(height: 30).background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading) {
                    if let nextRest = info.dailyRestNeededAt {
                        Text(nextRest.formatted(date: .omitted, time: .shortened))
                            .font(.title2.bold())
                            .foregroundColor(.globoWarning)
                    } else {
                        Text("--:--")
                            .font(.title2.bold())
                            .foregroundColor(.white.opacity(0.2))
                    }
                    Text("Próximo Descanso")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data, URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes: [UTType] = [
            .data,
            .item,
            .init(filenameExtension: "tgd") ?? .data,
            .init(filenameExtension: "ddd") ?? .data,
            .init(filenameExtension: "c1b") ?? .data,
            .init(filenameExtension: "esm") ?? .data
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    parent.onPick(data, url)
                }
            }
        }
    }
}
