import SwiftUI
import UniformTypeIdentifiers

struct ArchiveView: View {
    @ObservedObject var storage = StorageManager.shared
    @EnvironmentObject var readerVM: ReaderViewModel
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("IMPORTAR ARCHIVO").foregroundColor(.white.opacity(0.6))) {
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.globoAccent)
                            Text("Importar archivo .TGD")
                                .foregroundColor(.globoAccent)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                Section(header: Text("CONDUCTORES REGISTRADOS").foregroundColor(.white.opacity(0.6))) {
                    if storage.drivers.isEmpty {
                        Text("No hay conductores en el archivo")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .listRowBackground(Color.white.opacity(0.05))
                    } else {
                        ForEach(storage.drivers) { driver in
                            HStack(spacing: 15) {
                                ZStack {
                                    Circle().fill(Color.globoAccent.opacity(0.2)).frame(width: 40, height: 40)
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.globoAccent)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("\(driver.firstName) \(driver.lastName)")
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                    Text("ID: \(driver.id)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        .onDelete { indexSet in
                            storage.drivers.remove(atOffsets: indexSet)
                            // Nota: En una app real, también deberíamos persistir después de borrar
                        }
                    }
                }
                
                Section(header: Text("HISTORIAL DE ARCHIVOS").foregroundColor(.white.opacity(0.6))) {
                    ForEach(storage.importedFiles) { file in
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.globoWarning)
                            VStack(alignment: .leading) {
                                Text(file.fileName)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("Importado el \(file.importDate, style: .date)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            
                            // Botón de exportación
                            Button(action: { exportFile(file) }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.globoAccent)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .onDelete { indexSet in
                        storage.importedFiles.remove(atOffsets: indexSet)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color.globoBlue)
            .navigationTitle("Archivo")
            .toolbar {
                EditButton().foregroundColor(.white)
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { data, url in
                    readerVM.processData(data)
                }
            }
        }
    }
    
    private func exportFile(_ file: TachoFile) {
        // En una app real, aquí buscaríamos al driver y las actividades
        // Para este ejemplo, compartimos el nombre del archivo
        let text = "Informe de Tacógrafo GloboFleet: \(file.fileName)\nImportado el \(file.importDate.description)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true, completion: nil)
        }
    }
}
