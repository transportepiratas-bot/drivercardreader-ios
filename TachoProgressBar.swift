import SwiftUI

struct TachoProgressBar: View {
    let title: String
    let regulation: String
    let measured: TimeInterval
    let permitted: TimeInterval
    let remaining: TimeInterval?
    
    var progress: Double {
        if permitted <= 0 { return 0 }
        return min(measured / permitted, 1.0)
    }
    
    var isWarning: Bool {
        return measured > permitted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(regulation)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.globoAccent.opacity(0.8))
                }
                
                Spacer()
                
                if let rem = remaining {
                    Text(formatDuration(rem))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(rem < 3600 ? .globoWarning : .white)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                    
                    // Relleno con gradiente
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isWarning ? [.red, .orange] : [.globoAccent, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                        .shadow(color: (isWarning ? Color.red : Color.globoAccent).opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 12)
            
            HStack {
                Label(formatDuration(measured), systemImage: "clock.fill")
                Spacer()
                Text("Límite: \(formatDuration(permitted))")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let isNegative = seconds < 0
        let absoluteSeconds = abs(Int(seconds))
        let h = absoluteSeconds / 3600
        let m = (absoluteSeconds % 3600) / 60
        let sign = isNegative ? "-" : ""
        return "\(sign)\(h)h \(String(format: "%02d", m))m"
    }
}
