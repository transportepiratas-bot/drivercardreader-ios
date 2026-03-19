import SwiftUI

struct CountriesView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F172A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if readerVM.countryRecords.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // Cabecera de tabla
                                tableHeader
                                
                                ForEach(Array(readerVM.countryRecords.enumerated()), id: \.element.id) { index, record in
                                    CountryRow(record: record, isEven: index % 2 == 0)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#3B82F6"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Países")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(readerVM.countryRecords.count) Grabaciones")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Contador de países únicos
                let uniqueCountries = Set(readerVM.countryRecords.map { $0.country })
                VStack(alignment: .trailing) {
                    Text("\(uniqueCountries.count)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "#3B82F6"))
                    Text("PAÍSES")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(hex: "#1E293B"))
    }
    
    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("CS")
                .frame(width: 30, alignment: .center)
            Text("Fecha")
                .frame(width: 120, alignment: .leading)
            Text("País")
                .frame(minWidth: 80, alignment: .leading)
            Text("Tacómetro")
                .frame(width: 80, alignment: .trailing)
            Text("Modo")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(.white.opacity(0.5))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#1E293B"))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.4))
            
            Text("Sin registros de países")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Los registros de entradas y salidas de países aparecerán aquí cuando se cargue un archivo de tarjeta.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct CountryRow: View {
    let record: CountryRecord
    let isEven: Bool
    
    private var isStart: Bool {
        record.mode.contains("Inicio")
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Semana
            Text("\(record.weekNumber)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: 30, alignment: .center)
                .foregroundColor(.white)
            
            // Fecha
            VStack(alignment: .leading, spacing: 1) {
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                Text(record.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            .frame(width: 120, alignment: .leading)
            
            // País + Región
            VStack(alignment: .leading, spacing: 1) {
                Text(record.country)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                if !record.region.isEmpty {
                    Text("(\(record.region))")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#3B82F6"))
                }
            }
            .frame(minWidth: 80, alignment: .leading)
            
            // Tacómetro
            Text("\(record.odometer) Km")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .trailing)
            
            // Modo (Inicio/Final con indicador)
            HStack(spacing: 3) {
                Circle()
                    .fill(isStart ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(isStart ? "Ini" : "Fin")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isStart ? .green : .orange)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isEven ? Color.clear : Color.white.opacity(0.03))
    }
}

struct CountriesView_Previews: PreviewProvider {
    static var previews: some View {
        CountriesView()
            .environmentObject(ReaderViewModel())
    }
}
