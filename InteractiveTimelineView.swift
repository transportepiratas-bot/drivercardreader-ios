import SwiftUI

struct InteractiveTimelineView: View {
    let activities: [DriverActivity]
    @State private var zoomLevel: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            ScrollView(.horizontal, showsIndicators: true) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Fondo del timeline
                        Color.white.opacity(0.05)
                        
                        // Renderizado de actividades
                        HStack(spacing: 0) {
                            ForEach(0..<activities.count, id: \.self) { index in
                                let activity = activities[index]
                                ActivityBlock(activity: activity, zoom: zoomLevel)
                            }
                        }
                    }
                }
                .frame(width: calculateTotalWidth(), height: 120)
            }
            .frame(height: 140)
            .background(Color.black.opacity(0.3))
            
            // Controles de zoom
            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $zoomLevel, in: 0.5...5.0)
                Image(systemName: "plus.magnifyingglass")
            }
            .foregroundColor(.secondary)
            .padding()
        }
    }
    
    private func calculateTotalWidth() -> CGFloat {
        // Un cálculo simple basado en la duración total
        let totalDuration = activities.reduce(0) { $0 + $1.duration }
        return CGFloat(totalDuration / 60) * zoomLevel // 1 pixel por minuto con zoom 1.0
    }
}

struct ActivityBlock: View {
    let activity: DriverActivity
    let zoom: CGFloat
    
    var body: some View {
        let width = CGFloat(activity.duration / 60) * zoom
        
        VStack(spacing: 0) {
            Rectangle()
                .fill(colorForActivity(activity.type))
                .frame(width: max(width, 1), height: 60)
            
            // Icono pequeño de la actividad
            Group {
                if activity.type == .availability {
                    availabilityIcon()
                } else {
                    Image(systemName: iconForActivity(activity.type))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(height: 20)
        }
        .tooltip(activityInfo())
    }
    
    private func colorForActivity(_ type: ActivityType) -> Color {
        switch type {
        case .driving: return Color(hex: "9B59B6") // Púrpura/Lavanda oficial
        case .work: return Color(hex: "F39C12")    // Naranja/Amarillo
        case .availability: return Color(hex: "3498DB") // Cian/Azul Claro
        case .breakOrRest: return Color.white.opacity(0.8) // Blanco
        case .unknown: return Color.gray
        }
    }
    
    private func iconForActivity(_ type: ActivityType) -> String {
        switch type {
        case .driving: return "steeringwheel"
        case .work: return "hammer.fill"
        case .availability: return "square" // Usaremos un icono personalizado para disponibilidad
        case .breakOrRest: return "bed.double.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    // Vista personalizada para el icono de disponibilidad (cuadrado con diagonal)
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
    
    private func activityInfo() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Explicitly use UTC timezone
        return "\(formatter.string(from: activity.start)) - \(Int(activity.duration/60))min"
    }
}

// Extension simple para simular tooltip (se puede ampliar)
extension View {
    func tooltip(_ text: String) -> some View {
        self.overlay(
            Text("") // Aquí se podría implementar un popup real al pulsar
        )
    }
}
