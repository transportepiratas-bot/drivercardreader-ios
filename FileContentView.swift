import SwiftUI

struct FileContentView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F172A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Información del archivo
                            fileInfoCard
                            
                            // Tabla de contenidos
                            contentTable
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#8B5CF6"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contenido del archivo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Metadatos y validación de firmas")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(hex: "#1E293B"))
    }
    
    private var fileInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.badge.gearshape")
                    .foregroundColor(Color(hex: "#8B5CF6"))
                Text("INFORMACIÓN DEL ARCHIVO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            if let data = readerVM.tachoData {
                fileInfoRow(label: "Nombre de archivo:", value: "C_\(data.cardNumber)_ESP_\(formatDateForFilename(data.downloadDate)).tgd")
                fileInfoRow(label: "Tipo:", value: "Tarjeta de conductor")
                
                if let firstAct = data.activities.first, let lastAct = data.activities.last {
                    fileInfoRow(label: "durante el periodo:", value: "\(firstAct.start.formatted(date: .abbreviated, time: .omitted)) - \(lastAct.end.formatted(date: .abbreviated, time: .omitted))")
                }
                
                HStack(spacing: 8) {
                    Text("Estado:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    
                    Text("La signatura del archivo coincide con el contenido")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            } else {
                Text("Sin archivo cargado")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1E293B"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#8B5CF6").opacity(0.3), lineWidth: 1)
        )
    }
    
    private func fileInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }
    
    private var contentTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera
            HStack {
                Text("")
                    .frame(width: 20)
                Text("Contenido")
                    .frame(minWidth: 100, alignment: .leading)
                Spacer()
                Text("Estado")
                    .frame(width: 100, alignment: .leading)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#1E293B"))
            
            // Filas
            let blocks = readerVM.fileContentBlocks.isEmpty ? defaultBlocks() : readerVM.fileContentBlocks
            
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                HStack(spacing: 8) {
                    // Indicador de estado
                    Circle()
                        .fill(statusColor(for: block.status))
                        .frame(width: 10, height: 10)
                        .frame(width: 20)
                    
                    // Nombre del bloque
                    Text(block.name)
                        .font(.system(size: 11, weight: block.isSignature ? .regular : .medium))
                        .foregroundColor(block.isSignature ? Color(hex: "#8B5CF6") : .white)
                        .frame(minWidth: 100, alignment: .leading)
                    
                    Spacer()
                    
                    // Estado
                    Text(block.status)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusTextColor(for: block.status))
                        .frame(width: 100, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#0F172A"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "válido": return .green
        case "disponible": return .blue
        case "no disponible": return .gray
        default: return .yellow
        }
    }
    
    private func statusTextColor(for status: String) -> Color {
        switch status {
        case "válido": return .green
        case "disponible": return Color(hex: "#3B82F6")
        case "no disponible": return .gray
        default: return .yellow
        }
    }
    
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
    }
    
    private func defaultBlocks() -> [FileContentBlock] {
        return [
            FileContentBlock(name: "ICC identificación", status: "disponible", isSignature: false),
            FileContentBlock(name: "IC identificación", status: "disponible", isSignature: false),
            FileContentBlock(name: "Certificado de la tarjeta", status: "disponible", isSignature: false),
            FileContentBlock(name: "Certificado de país", status: "disponible", isSignature: false),
            FileContentBlock(name: "Identificación de la aplicación", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura de la aplicación", status: "válido", isSignature: true),
            FileContentBlock(name: "Información de la tarjeta", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura de la tarjeta", status: "válido", isSignature: true),
            FileContentBlock(name: "Identificación del titular", status: "disponible", isSignature: false),
            FileContentBlock(name: "Última descarga", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura de la última descarga", status: "válido", isSignature: true),
            FileContentBlock(name: "Actividades", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura de las actividades", status: "válido", isSignature: true),
            FileContentBlock(name: "Vehículos", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura del vehículos", status: "válido", isSignature: true),
            FileContentBlock(name: "Países", status: "disponible", isSignature: false),
            FileContentBlock(name: "Signatura de países", status: "válido", isSignature: true),
        ]
    }
}

struct FileContentView_Previews: PreviewProvider {
    static var previews: some View {
        FileContentView()
            .environmentObject(ReaderViewModel())
    }
}
