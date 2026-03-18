import Foundation

/// Gestor de Almacenamiento Local para GloboFleet
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var drivers: [Driver] = [] {
        didSet { persist() }
    }
    @Published var importedFiles: [TachoFile] = [] {
        didSet { persist() }
    }
    
    private let driversKey = "globofleet_drivers"
    private let filesKey = "globofleet_files"
    
    init() {
        loadData()
    }
    
    func saveFile(_ file: TachoFile, driver: Driver) {
        // Evitaremos duplicados de conductores
        if !drivers.contains(where: { $0.id == driver.id }) {
            drivers.append(driver)
        }
        
        // El archivo se añade y disparará el persist vía didSet
        importedFiles.append(file)
    }
    
    func persist() {
        if let encodedDrivers = try? JSONEncoder().encode(drivers) {
            UserDefaults.standard.set(encodedDrivers, forKey: driversKey)
        }
        if let encodedFiles = try? JSONEncoder().encode(importedFiles) {
            UserDefaults.standard.set(encodedFiles, forKey: filesKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: driversKey),
           let decoded = try? JSONDecoder().decode([Driver].self, from: data) {
            drivers = decoded
        }
        if let data = UserDefaults.standard.data(forKey: filesKey),
           let decoded = try? JSONDecoder().decode([TachoFile].self, from: data) {
            importedFiles = decoded
        }
    }
}
