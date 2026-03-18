import SwiftUI

struct SettingsView: View {
    @State private var googleAccount = "wyllyy9@gmail.com"
    @State private var language = "Español 🇪🇸"
    @State private var fileFormat = "TGD (Spanish Binary Data)"
    @State private var compatibility = "Lectura de datos de tipo G2v2 (incluidos G1 y G2v1)"
    @State private var useCardTimestamp = true
    @State private var fastRead = false
    @State private var baseCountry = "España"
    @State private var busPassengerTransport = false
    
    var body: some View {
        ZStack {
            Color(hex: "2D3E33").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header (Ya manejado por el NavigationView si se usa, pero Lobol tiene un estilo custom)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // Ajustes básicos
                        SettingsSectionHeader(title: "Ajustes básicos")
                        
                        SettingsRow(title: "Cuenta Google", value: googleAccount)
                        SettingsRow(title: "Idioma", value: language)
                        SettingsRow(title: "Formato de nombre de archivo", value: fileFormat)
                        SettingsRow(title: "Nivel de compatibilidad de la tarjeta", value: compatibility)
                        
                        SettingsToggleRow(title: "Marca de tiempo de la tarjeta", subtitle: "La marca de tiempo de descarga se escribirá en la tarjeta", isOn: $useCardTimestamp)
                        
                        SettingsToggleRow(title: "Lectura rápida de tarjetas", subtitle: "Lectura de tarjetas con configuraciones optimizadas", isOn: $fastRead)
                        
                        // Legislaciones
                        SettingsSectionHeader(title: "Legislaciones")
                        
                        SettingsRow(title: "País base", value: baseCountry)
                        
                        SettingsToggleRow(title: "Transporte de pasajeros en autobús", subtitle: "Periodo de descanso semanal no mayor a cada 12 días", isOn: $busPassengerTransport)
                        
                        // Resumen de tiempo de trabajo
                        SettingsSectionHeader(title: "Resumen de tiempo de trabajo")
                        
                        SettingsRow(title: "Marco de tiempo de trabajo", value: "4 meses", showInfo: true)
                        SettingsRow(title: "Horas de trabajo diarias", value: "10 horas")
                        SettingsRow(title: "Periodo nocturno", value: "00:00 - 04:00", showInfo: true)
                        
                        // Agregar el resto de secciones si es necesario...
                        
                        // Colores del gráfico (Apariencia)
                        SettingsSectionHeader(title: "Apariencia")
                        
                        SettingsRow(title: "Formato de duración", value: "hh:mm (04:30 = 04.50)")
                        SettingsRow(title: "Unidad de distancia", value: "Kilómetro (km)")
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Colores del gráfico")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            HStack(spacing: 15) {
                                ColorDot(color: Color(hex: "9B59B6"), icon: "steeringwheel")
                                ColorDot(color: Color(hex: "F39C12"), icon: "hammer.fill")
                                ColorDot(color: .gray, icon: "square", isAvailability: true)
                                ColorDot(color: Color(hex: "3498DB"), icon: "bed.double.fill")
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Text("Driver Card Reader")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Pro")
                        .font(.headline)
                        .italic()
                        .foregroundColor(Color(hex: "E67E22"))
                }
            }
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color.yellow)
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    var showInfo: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                if showInfo {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(hex: "3498DB"))
                        .font(.system(size: 12))
                }
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 13))
                .italic()
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            
            Text(subtitle)
                .font(.system(size: 12))
                .italic()
                .foregroundColor(Color.green.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
    }
}

struct ColorDot: View {
    let color: Color
    let icon: String
    let isAvailability: Bool
    
    init(color: Color, icon: String, isAvailability: Bool = false) {
        self.color = color
        self.icon = icon
        self.isAvailability = isAvailability
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Group {
                if isAvailability {
                    // Cuadrado con diagonal para disponibilidad
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        Path { path in
                            let size: CGFloat = 10
                            path.move(to: CGPoint(x: size, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: size))
                        }
                        .stroke(Color.gray, lineWidth: 1)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 40, height: 15)
        }
    }
}
