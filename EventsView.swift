import SwiftUI

struct EventsView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F172A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if readerVM.events.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(readerVM.events) { event in
                                EventRow(event: event)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Eventos y Fallos")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Registros técnicos del tacógrafo")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1E293B"))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.8))
            
            Text("No se detectaron eventos técnicos")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Tu tacógrafo no tiene registros de incidentes o fallos de seguridad en el periodo analizado.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct EventRow: View {
    let event: TachoEvent
    
    var isFault: Bool {
        event.type.contains("Fallo")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isFault ? "exclamationmark.octagon.fill" : "info.circle.fill")
                    .foregroundColor(isFault ? .red : .blue)
                
                Text(event.type)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if let plate = event.vehiclePlate {
                    Text(plate)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Label(event.start.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                
                if event.start != event.end {
                    Text("→")
                    Text(event.end.formatted(date: .omitted, time: .shortened))
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "#1E293B"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFault ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct EventsView_Previews: PreviewProvider {
    static var previews: some View {
        EventsView()
            .environmentObject(ReaderViewModel())
    }
}
