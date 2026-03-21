import SwiftUI

struct VehiclesView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Uso de Vehículos")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#0F172A"))
            
            if readerVM.vehiclesUsed.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No hay datos de vehículos disponibles.")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0F172A"))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Resumen
                        HStack {
                            Text("\(readerVM.vehiclesUsed.count) Grabaciones")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            let totalDist = readerVM.vehiclesUsed.reduce(0) { $0 + $1.distance }
                            Text("Total: \(totalDist) Km")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        ForEach(readerVM.vehiclesUsed) { record in
                            VehicleRecordCard(record: record)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .background(Color(hex: "#0F172A"))
            }
        }
    }
}

struct VehicleRecordCard: View {
    let record: VehicleUsageRecord
    
    // Formatters
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "es_ES")
        df.timeZone = TimeZone.current
        return df
    }()
    
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        df.timeZone = TimeZone.current
        return df
    }()
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Cabecera: Fecha y matrícula
            HStack {
                Text(dateFormatter.string(from: record.start))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(record.plate)
                    .font(.subheadline)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                    .foregroundColor(Color(hex: "#38BDF8"))
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Fila de tiempos
            HStack {
                VStack(alignment: .leading) {
                    Text("Periodo")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(timeFormatter.string(from: record.start)) - \(timeFormatter.string(from: record.end))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Duración")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatDuration(record.duration))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            
            // Fila de Odómetro
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Inicio (Km)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(record.initialOdometer)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .center) {
                    Text("Fin (Km)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(record.finalOdometer)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Distancia")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(record.distance) Km")
                        .font(.headline)
                        .foregroundColor(record.distance > 0 ? .green : .white)
                }
            }
        }
        .padding()
        .background(Color(hex: "#1E293B"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
