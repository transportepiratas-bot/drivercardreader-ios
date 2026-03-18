import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    @State private var viewMode = 0 // 0: Detalle, 1: Mes
    @State private var selectedVehicle: String = "Todos"
    @State private var selectedDay: Date? = nil
    @State private var showingDayDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let data = readerVM.tachoData, !data.activities.isEmpty {
                    // Fila de filtros
                    HStack {
                        // Picker de vista
                        Picker("Vista", selection: $viewMode) {
                            Text("Detalle").tag(0)
                            Text("Mensual").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Spacer()
                        
                        // Picker de vehículo
                        if !data.vehicles.isEmpty {
                            Picker("Vehículo", selection: $selectedVehicle) {
                                Text("Todos").tag("Todos")
                                ForEach(data.vehicles, id: \.self) { vehicle in
                                    Text(vehicle).tag(vehicle)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 150)
                        }
                    }
                    .padding()
                    
                    // Información del vehículo seleccionado
                    if selectedVehicle != "Todos" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.globoAccent)
                                Text(selectedVehicle)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            // Estadísticas del vehículo
                            let vehicleActivities = data.activities.filter { _ in true } // Placeholder
                            let totalDuration = vehicleActivities.reduce(0) { $0 + $1.duration }
                            let hours = totalDuration / 3600
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(vehicleActivities.count)")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.globoAccent)
                                    Text("Actividades")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                VStack {
                                    Text("\(Int(hours))h")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.globoAccent)
                                    Text("Tiempo total")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    if viewMode == 0 {
                        ScrollView {
                            VStack(spacing: 20) {
                                ForEach(groupedActivities(data.activities), id: \.key) { day, acts in
                                    DayActivityRow(date: day, activities: acts)
                                }
                            }
                            .padding()
                        }
                    } else {
                        MonthlyGridView(
                            activities: data.activities, 
                            infringements: data.infringements,
                            onDayTapped: { date in
                                selectedDay = date
                                showingDayDetail = true
                            }
                        )
                    }
                } else {
                    VStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No hay actividades para mostrar")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            .background(Color.globoBlue.edgesIgnoringSafeArea(.all))
            .navigationTitle("Calendario")
            .sheet(isPresented: $showingDayDetail) {
                if let day = selectedDay, let data = readerVM.tachoData {
                    DayDetailSheet(date: day, activities: data.activities)
                }
            }
        }
    }
    
    private func groupedActivities(_ activities: [DriverActivity]) -> [(key: Date, value: [DriverActivity])] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let grouped = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.start) }
        return grouped.sorted { $0.key > $1.key }
    }
}

struct MonthlyGridView: View {
    let activities: [DriverActivity]
    let infringements: [Infringement]
    var onDayTapped: ((Date) -> Void)? = nil
    
    @State private var selectedMonth: Date = Date()
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    var utccalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    var body: some View {
        VStack {
            // Month selector
            HStack {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left").foregroundColor(.white)
                }
                Text(monthYearString)
                    .font(.headline)
                    .foregroundColor(.white)
                Button(action: { changeMonth(1) }) {
                    Image(systemName: "chevron.right").foregroundColor(.white)
                }
            }
            .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                    Text(day).font(.caption2).bold().foregroundColor(.gray)
                }
                
                ForEach(daysInMonth(), id: \.self) { day in
                    if day > 0 {
                        MonthDayCell(
                            day: day,
                            drivingHours: getHoursForDay(day, type: .driving),
                            workHours: getHoursForDay(day, type: .work),
                            restHours: getHoursForDay(day, type: .breakOrRest),
                            availHours: getHoursForDay(day, type: .availability),
                            onTap: {
                                if let date = getDateForDay(day) {
                                    onDayTapped?(date)
                                }
                            }
                        )
                    } else {
                        Color.clear.frame(height: 50)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Instrucciones
            Text("Toca un día para ver sus registros")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 8)
            
            // Leyenda detallada
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    LegendItem(text: "Conducción", color: .globoAccent)
                    LegendItem(text: "Trabajo", color: .globoWarning)
                }
                HStack(spacing: 16) {
                    LegendItem(text: "Descanso", color: .globoSuccess)
                    LegendItem(text: "Disponibilidad", color: .blue, isAvailability: true)
                }
            }
            .padding(.bottom)
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        return formatter.string(from: selectedMonth)
    }
    
    private func changeMonth(_ delta: Int) {
        selectedMonth = utccalendar.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
    }
    
    private func daysInMonth() -> [Int] {
        let range = utccalendar.range(of: .day, in: .month, for: selectedMonth)!
        let firstDay = utccalendar.date(from: utccalendar.dateComponents([.year, .month], from: selectedMonth))!
        let weekday = utccalendar.component(.weekday, from: firstDay)
        
        var days = [Int]()
        // Ajustar para que lunes = 1
        let emptyDays = weekday == 1 ? 6 : weekday - 2
        for _ in 0..<emptyDays {
            days.append(0)
        }
        days.append(contentsOf: Array(range))
        return days
    }
    
    private func getHoursForDay(_ day: Int, type: ActivityType) -> Double {
        guard let monthInterval = utccalendar.dateInterval(of: .month, for: selectedMonth) else { return 0 }
        var components = utccalendar.dateComponents([.year, .month], from: selectedMonth)
        components.day = day
        guard let date = utccalendar.date(from: components) else { return 0 }
        
        let dayStart = utccalendar.startOfDay(for: date)
        let dayEnd = utccalendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        return activities
            .filter { $0.start >= dayStart && $0.start < dayEnd && $0.type == type }
            .reduce(0) { $0 + $1.duration } / 3600
    }
    
    private func getDateForDay(_ day: Int) -> Date? {
        var components = utccalendar.dateComponents([.year, .month], from: selectedMonth)
        components.day = day
        return utccalendar.date(from: components)
    }
}

struct MonthDayCell: View {
    let day: Int
    let drivingHours: Double
    let workHours: Double
    let restHours: Double
    let availHours: Double
    var onTap: (() -> Void)? = nil
    
    private var totalHours: Double {
        drivingHours + workHours + restHours + availHours
    }
    
    private var statusColor: Color {
        if totalHours == 0 { return .white.opacity(0.05) }
        if drivingHours > 0 { return .globoAccent }
        return .gray
    }
    
    var body: some View {
        Button(action: {
            if totalHours > 0 {
                onTap?()
            }
        }) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                if totalHours > 0 {
                    // Barras de tiempo
                    VStack(spacing: 1) {
                        if drivingHours > 0 {
                            ActivityBar(hours: drivingHours, color: .globoAccent, maxHeight: 12)
                        }
                        if workHours > 0 {
                            ActivityBar(hours: workHours, color: .globoWarning, maxHeight: 12)
                        }
                        if restHours > 0 {
                            ActivityBar(hours: restHours, color: .globoSuccess, maxHeight: 12)
                        }
                        if availHours > 0 {
                            ActivityBar(hours: availHours, color: .blue, maxHeight: 12)
                        }
                    }
                    
                    Text(String(format: "%.1fh", totalHours))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("-")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.2))
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(statusColor.opacity(0.3))
            .cornerRadius(4)
        }
        .disabled(totalHours == 0)
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityBar: View {
    let hours: Double
    let color: Color
    let maxHeight: CGFloat
    
    private var barHeight: CGFloat {
        let h = min(hours / 8, 1) * maxHeight
        return max(h, 3)
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: barHeight)
            .cornerRadius(1)
            .help(String(format: "%.1fh", hours))
    }
}

struct LegendItem: View {
    let text: String
    let color: Color
    let isAvailability: Bool
    
    init(text: String, color: Color, isAvailability: Bool = false) {
        self.text = text
        self.color = color
        self.isAvailability = isAvailability
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if isAvailability {
                // Cuadrado con diagonal para disponibilidad
                ZStack {
                    Rectangle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Path { path in
                        let size: CGFloat = 8
                        path.move(to: CGPoint(x: size, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: size))
                    }
                    .stroke(Color.white, lineWidth: 1)
                }
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(text).font(.caption2).foregroundColor(.gray)
        }
    }
}

struct DayActivityRow: View {
    let date: Date
    let activities: [DriverActivity]
    @State private var isExpanded = false
    
    private var utcDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.timeZone = TimeZone(secondsFromGMT: 0)!
        return f
    }
    
    private var utcTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.timeZone = TimeZone(secondsFromGMT: 0)!
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(utcDateFormatter.string(from: date))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Carril de 24h
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 25)
                    
                    ForEach(activities) { act in
                        ActivitySegment(activity: act, totalWidth: geo.size.width)
                    }
                }
            }
            .frame(height: 25)
            .cornerRadius(4)
            
            if isExpanded {
                VStack(spacing: 8) {
                    Divider().background(Color.white.opacity(0.2))
                    ForEach(activities) { act in
                        HStack(spacing: 12) {
                            Group {
                                if act.type == .availability {
                                    availabilityIcon()
                                        .foregroundColor(colorFor(act.type))
                                } else {
                                    Image(systemName: iconFor(act.type))
                                        .foregroundColor(colorFor(act.type))
                                }
                            }
                            .frame(width: 20)
                            
                            VStack(alignment: .leading) {
                                Text(labelFor(act.type))
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                Text("\(utcTimeFormatter.string(from: act.start)) - \(utcTimeFormatter.string(from: act.end))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Text(formatDuration(act.duration))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? Color.globoAccent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func iconFor(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "steeringwheel"
        case .work: return "hammer.fill"
        case .breakOrRest: return "bed.double.fill"
        case .availability: return "square" // Icono personalizado de cuadrado con diagonal
        case .unknown: return "questionmark"
        }
    }
    
    // Vista personalizada para el icono de disponibilidad
    private func availabilityIcon() -> some View {
        ZStack {
            // Cuadrado base
            Image(systemName: "square")
                .font(.system(size: 10))
            
            // Línea diagonal de arriba a la derecha hacia abajo a la izquierda
            Path { path in
                let size: CGFloat = 10
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
    }
    
    private func labelFor(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "Conducción"
        case .work: return "Trabajo"
        case .breakOrRest: return "Descanso"
        case .availability: return "Disponibilidad"
        default: return "Otro"
        }
    }
    
    private func colorFor(_ type: ActivityType) -> Color {
        switch type {
        case .driving: return .globoAccent
        case .work: return .globoWarning
        case .breakOrRest: return .globoSuccess
        case .availability: return .blue
        default: return .gray
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

struct ActivitySegment: View {
    let activity: DriverActivity
    let totalWidth: CGFloat
    
    var body: some View {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startHour = CGFloat(calendar.component(.hour, from: activity.start))
        let startMin = CGFloat(calendar.component(.minute, from: activity.start))
        let startPos = ((startHour * 60) + startMin) * (totalWidth / 1440)
        
        let durationWidth = (activity.duration / 60) * (totalWidth / 1440)
        
        return Rectangle()
            .fill(colorFor(activity.type))
            .frame(width: max(durationWidth, 1), height: 30)
            .offset(x: startPos)
    }
    
    private func colorFor(_ type: ActivityType) -> Color {
        switch type {
        case .driving: return .globoAccent
        case .work: return .globoWarning
        case .availability: return .blue
        case .breakOrRest: return .globoSuccess
        case .unknown: return .gray
        }
    }
}

struct DayDetailSheet: View {
    let date: Date
    let activities: [DriverActivity]
    @Environment(\.dismiss) var dismiss
    
    private var utccalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private var dayActivities: [DriverActivity] {
        let dayStart = utccalendar.startOfDay(for: date)
        let dayEnd = utccalendar.date(byAdding: .day, value: 1, to: dayStart)!
        return activities
            .filter { $0.start >= dayStart && $0.start < dayEnd }
            .sorted { $0.start < $1.start }
    }
    
    private var dayTotals: (driving: Double, work: Double, rest: Double, avail: Double, distance: Double) {
        let driving = dayActivities.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration }
        let work = dayActivities.filter { $0.type == .work }.reduce(0) { $0 + $1.duration }
        let rest = dayActivities.filter { $0.type == .breakOrRest }.reduce(0) { $0 + $1.duration }
        let avail = dayActivities.filter { $0.type == .availability }.reduce(0) { $0 + $1.duration }
        let distance = dayActivities.compactMap { $0.distance }.reduce(0, +)
        return (driving / 3600, work / 3600, rest / 3600, avail / 3600, distance / 1000)
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        f.timeZone = TimeZone(secondsFromGMT: 0)!
        return f
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.timeZone = TimeZone(secondsFromGMT: 0)!
        return f
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.globoBlue.edgesIgnoringSafeArea(.all)
                
                if dayActivities.isEmpty {
                    VStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No hay actividades para este día")
                            .foregroundColor(.gray)
                            .padding()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Resumen del día
                            VStack(spacing: 12) {
                                Text(dateFormatter.string(from: date))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text(String(format: "%.1fh", dayTotals.driving))
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.globoAccent)
                                        Text("Conducción")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    VStack {
                                        Text(String(format: "%.1fh", dayTotals.work))
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.globoWarning)
                                        Text("Trabajo")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    VStack {
                                        Text(String(format: "%.1fh", dayTotals.rest))
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.globoSuccess)
                                        Text("Descanso")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    VStack {
                                        Text(String(format: "%.1fh", dayTotals.avail))
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.blue)
                                        Text("Disponibilidad")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                
                                if dayTotals.distance > 0 {
                                    HStack {
                                        Image(systemName: "car.fill")
                                            .foregroundColor(.globoAccent)
                                        Text(String(format: "%.0f km", dayTotals.distance))
                                            .foregroundColor(.white)
                                    }
                                    .font(.subheadline)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Carril de 24h
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Línea de tiempo")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 40)
                                        
                                        ForEach(dayActivities) { act in
                                            ActivitySegment(activity: act, totalWidth: geo.size.width)
                                        }
                                        
                                        // Marcas de horas
                                        ForEach(0..<24, id: \.self) { hour in
                                            let pos = CGFloat(hour) * (geo.size.width / 24)
                                            VStack {
                                                Rectangle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(width: 1, height: 8)
                                                Text("\(hour)")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.white.opacity(0.3))
                                            }
                                            .offset(x: pos)
                                        }
                                    }
                                }
                                .frame(height: 40)
                                .cornerRadius(4)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            // Lista de actividades
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Registros (\(dayActivities.count))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal)
                                
                                ForEach(dayActivities) { act in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(colorFor(act.type))
                                            .frame(width: 12, height: 12)
                                        
                                        Text(labelFor(act.type))
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .frame(width: 100, alignment: .leading)
                                        
                                        Text("\(timeFormatter.string(from: act.start)) - \(timeFormatter.string(from: act.end))")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Spacer()
                                        
                                        Text(formatDuration(act.duration))
                                            .font(.subheadline)
                                            .monospacedDigit()
                                            .foregroundColor(.white)
                                        
                                        if let distance = act.distance, distance > 0 {
                                            Text("\(Int(distance / 1000)) km")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    
                                    if act.id != dayActivities.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                            .padding(.vertical)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                }
            }
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
    
    private func labelFor(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "Conducción"
        case .work: return "Trabajo"
        case .breakOrRest: return "Descanso"
        case .availability: return "Disponibilidad"
        default: return "Otro"
        }
    }
    
    private func colorFor(_ type: ActivityType) -> Color {
        switch type {
        case .driving: return .globoAccent
        case .work: return .globoWarning
        case .breakOrRest: return .globoSuccess
        case .availability: return .blue
        default: return .gray
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
