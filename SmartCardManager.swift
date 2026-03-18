import Foundation
import CryptoTokenKit
import Combine

class SmartCardManager: NSObject, ObservableObject {
    @Published var slotName: String?
    @Published var isCardPresent = false
    @Published var isReading = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = "Buscando lector..."
    @Published var lastError: String?
    
    var onDataRead: ((Data) -> Void)?
    
    private let slotManager = TKSmartCardSlotManager.default
    private var currentSlot: TKSmartCardSlot?
    
    override init() {
        super.init()
        observeSlots()
    }
    
    func observeSlots() {
        guard let manager = slotManager else {
            statusMessage = "Lector no compatible con este dispositivo"
            return
        }
        
        // Observar cambios en los slots
        manager.addObserver(self, forKeyPath: "slotNames", options: [.initial, .new], context: nil)
        
        if let firstSlot = manager.slotNames.first {
            self.setupSlot(named: firstSlot)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "slotNames" {
            DispatchQueue.main.async {
                if let names = self.slotManager?.slotNames, let first = names.first {
                    self.setupSlot(named: first)
                } else {
                    self.slotName = nil
                    self.statusMessage = "Conecte su lector de tarjetas"
                }
            }
        }
    }
    
    private func setupSlot(named name: String) {
        self.slotName = name
        self.statusMessage = "Lector detectado: \(name)"
        
        slotManager?.getSlot(withName: name) { slot in
            self.currentSlot = slot
            self.checkCardPresence()
        }
    }
    
    func checkCardPresence() {
        guard let slot = currentSlot else { return }
        
        // Observamos el estado de la tarjeta en el slot
        // TKSmartCardSlotState: missing, empty, probing, dataReceived, ...
        if slot.state == .validCard {
            DispatchQueue.main.async {
                self.isCardPresent = true
                self.statusMessage = "Tarjeta detectada. Lista para leer."
            }
        } else {
            DispatchQueue.main.async {
                self.isCardPresent = false
                self.statusMessage = "Inserte su tarjeta de conductor"
            }
        }
    }
    
    func startReadingCard() {
        guard let slot = currentSlot, slot.state == .validCard else {
            lastError = "No hay tarjeta en el lector"
            return
        }
        
        isReading = true
        progress = 0.0
        statusMessage = "Estableciendo conexión segura..."
        
        let card = slot.makeSmartCard()
        card?.beginSession { success, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = "Error de sesión: \(error.localizedDescription)"
                    self.isReading = false
                }
                return
            }
            
            // Secuencia Real de Comandos (Estándar ISO 7816-4)
            self.executeTachoProtocol(card: card!)
        }
    }
    
    private func executeTachoProtocol(card: TKSmartCard) {
        // 1. SELECT Application (AID del Tacógrafo)
        // CLA: 00, INS: A4 (Select), P1: 04 (By Name), P2: 0C (First record)
        card.send(ins: 0xA4, p1: 0x04, p2: 0x0C, data: TachoConstants.tachographAID, le: nil) { response, sw, error in
            guard error == nil, sw == 0x9000 else {
                self.handleReadError("Error al seleccionar aplicación TACHO: \(String(format: "%04X", sw))")
                return
            }
            
            self.updateProgress(0.2, "Aplicación seleccionada. Leyendo Identificación...")
            
            // 2. Select EF Identification (0x0520)
            self.selectFile(card: card, fid: TachoConstants.ef_Identification) { success in
                if success {
                    self.readBinary(card: card) { data in
                        // En este punto tenemos el binario de identificación
                        // Continuamos con el resto de archivos (Actividades, Vehículos...)
                        self.updateProgress(0.5, "Lectura de actividades en curso...")
                        self.simulateRemainingRead(data: data)
                    }
                }
            }
        }
    }

    private func selectFile(card: TKSmartCard, fid: UInt16, completion: @escaping (Bool) -> Void) {
        let fidData = Data([UInt8(fid >> 8), UInt8(fid & 0xFF)])
        // INS: A4, P1: 02 (Select EF), P2: 0C
        card.send(ins: 0xA4, p1: 0x02, p2: 0x0C, data: fidData, le: nil) { _, sw, error in
            if sw == 0x9000 {
                completion(true)
            } else {
                self.handleReadError("Error Select EF (\(String(format: "%04X", fid))): \(String(format: "%04X", sw))")
                completion(false)
            }
        }
    }

    private func readBinary(card: TKSmartCard, completion: @escaping (Data) -> Void) {
        // READ BINARY: INS: B0, P1: Offset High, P2: Offset Low, Le: Length
        card.send(ins: 0xB0, p1: 0x00, p2: 0x00, data: nil, le: 0) { response, sw, error in
            if sw == 0x9000 || (sw & 0xFF00) == 0x6100 {
                completion(response ?? Data())
            } else {
                self.handleReadError("Error Read Binary: \(String(format: "%04X", sw))")
            }
        }
    }

    private func handleReadError(_ msg: String) {
        DispatchQueue.main.async {
            self.lastError = msg
            self.isReading = false
            self.statusMessage = "Error en la lectura"
        }
    }

    private func updateProgress(_ val: Double, _ msg: String) {
        DispatchQueue.main.async {
            self.progress = val
            self.statusMessage = msg
        }
    }

    private func simulateRemainingRead(data: Data) {
        // Simulamos la lectura del resto por brevedad en este ejemplo
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateProgress(1.0, "Lectura completada")
            self.isReading = false
            self.onDataRead?(data) // Enviamos el bloque de identificación al parser
        }
    }
}
