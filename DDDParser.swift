import Foundation

/// Motor de análisis para archivos .ddd / .tgd
/// Implementado según Reglamento (UE) 165/2014, Apéndice 1C – Data Dictionary
class DDDParser {
    
    // MARK: - Structures
    
    struct TachoBinaryData {
        var driverName: String = "CONDUCTOR"
        var driverSurname: String = "DESCONOCIDO"
        var cardNumber: String = "ES-000000000-00"
        var company: String = ""
        var licenseNumber: String = ""
        var downloadDate: Date = Date()
        var activities: [DriverActivity] = []
        var events: [TachoEvent] = []
        var shifts: [TachoShift] = []
        var vehicles: [String] = []
        var vehicleUsage: [VehicleUsageRecord] = []
        var countries: [String] = []
        var countryRecords: [CountryRecord] = []
        var fileContentBlocks: [FileContentBlock] = []
        var speedProfile: [SpeedRecord] = []
        var dailyMileage: [DailyMileage] = []
        var specialCases: [SpecialCase] = []
        var speedViolations: [SpeedViolation] = []
        var remainingDrivingTime: Double = 0
        var remainingBreakTime: Double = 0
        var infringements: [Infringement] = []
        var planning: PlanningInfo = PlanningInfo()
    }
    struct SpeedRecord {
        var date: Date = Date()
        var avgSpeed: Double = 0
        var maxSpeed: Double = 0
    }
    
    struct DailyMileage {
        var date: Date = Date()
        var mileage: Double = 0
    }
    
    struct SpecialCase {
        var caseType: String = ""
        var startDate: Date = Date()
        var endDate: Date = Date()
    }
    
    struct SpeedViolation {
        var date: Date = Date()
        var speed: Double = 0
        var limit: Double = 0
        var vehiclePlate: String = ""
    }
    
    enum ParserError: Error {
        case invalidFile
        case endOfFile
    }
    
    func parse(fileData: Data) throws -> TachoBinaryData {
        var result = TachoBinaryData()
        let bytes = [UInt8](fileData)
        
        print("DDDParser: analizando \(fileData.count) bytes")
         
        // 1. Parse TGD Blocks: FID (2B) + Type (1B) + Length (2B) + Data (NB)
        let activitiesFromBlocks = result.activities
        parseTGDBlocks(bytes: bytes, result: &result)
        
        // 2. Usar solo parser de bloques TGD (no heurístico para evitar duplicados)
        print("DDDParser: Parser TGD encontró \(result.activities.count) actividades")
        
        // 3. Extraer nombre del conductor si no se encontró
        if result.driverSurname == "DESCONOCIDO" || result.driverSurname.isEmpty {
            extractDriverInfo(bytes: bytes, result: &result)
        }
        
        // 4. Calcular infracciones        // 4. Extraer resumen
        // Assuming textName and textSurname are defined elsewhere or meant to be placeholders
        // For now, using existing result.driverName and result.driverSurname
        let textName = result.driverName
        let textSurname = result.driverSurname

        result.driverName = textName.trimmingCharacters(in: .whitespacesAndNewlines)
        result.driverSurname = textSurname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 5. Asignar vehículos a las actividades basándonos en los tiempos de uso
        if !result.vehicleUsage.isEmpty {
            for i in 0..<result.activities.count {
                let activity = result.activities[i]
                let activityEnd = activity.start.addingTimeInterval(activity.duration)
                
                for usage in result.vehicleUsage {
                    // Verificar si la actividad se superpone con el uso del vehículo
                    if activity.start <= usage.end && activityEnd >= usage.start {
                        result.activities[i].vehiclePlate = usage.plate
                        break
                    }
                }
            }
        }
        
        // 4. Calcular infracciones y planificación (moved from original position)
        let analysis = GloboFleetEngine.analyze(activities: result.activities)
        result.infringements = analysis.infringements
        result.shifts = analysis.shifts
        result.planning = GloboFleetEngine.calculatePlanning(activities: result.activities)
        
        // 5. Generar bloques de contenido del archivo
        result.fileContentBlocks = generateFileContentBlocks(result: result)
        
        print("DDDParser resumen final: act=\(result.activities.count), name=\(result.driverName), vehicles=\(result.vehicles.count)")
        print("DDDParser: conductor = \(result.driverName) \(result.driverSurname)")
        
        return result
    }
    
    // MARK: - TGD Block Parser
    
    enum TGDFileType {
        case driverCard     // Archivo de tarjeta de conductor
        case vehicleUnit     // Archivo de unidad de vehículo (VU)
        case unknown
    }
    
    /// Recorre el archivo en formato TGD: FID (2 bytes) + Type (1 byte) + Length (2 bytes big-endian)
    private func parseTGDBlocks(bytes: [UInt8], result: inout TachoBinaryData) {
        var offset = 0
        let validTimestampMin: UInt32 = 1451606400 // 2016-01-01
        let validTimestampMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400
        
        // Detectar tipo de archivo
        let fileType = detectTGDFileType(bytes: bytes)
        print("DDDParser: Tipo de archivo detectado: \(fileType)")
        
        var blocksParsed = 0
        var activityBlocksFound = 0
        
        while offset + 5 <= bytes.count {
            // TGD Block: FID (2 bytes big-endian) + Type (1 byte) + Length (2 bytes big-endian) + Data
            let fid = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            let type = bytes[offset + 2]
            // Length en big-endian (_network byte order)
            let len = Int(bytes[offset + 3]) << 8 | Int(bytes[offset + 4])
            
            // Validar para evitar loops infinitos
            guard len > 0, len < 100000, offset + 5 + len <= bytes.count else {
                offset += 1
                continue
            }
            
            let dataStart = offset + 5
            
            // type == 0 es Data. type == 1 es Signature (ignorar)
            if type == 0 {
                let payloadEnd = min(dataStart + len, bytes.count)
                let payload = Array(bytes[dataStart ..< payloadEnd])
                
                switch fid {
                case 0x0520: // EF_IDENTIFICATION (Card Number, Driver Name)
                    parseIdentification(payload: payload, result: &result)
                    blocksParsed += 1
                    
                case 0x0504: // EF_DRIVER_ACTIVITY_DATA (Driver Card)
                    print("DDDParser: procesando 0x0504 (Actividades de Tarjeta) len=\(len) offset=\(offset)")
                    let parsed = parseEFDriverActivityData(payload: payload, result: &result)
                    if !parsed.isEmpty {
                        result.activities.append(contentsOf: parsed)
                        activityBlocksFound += 1
                    }
                    blocksParsed += 1
                    
                case 0x0501: // EF_VEHICLE_UNIT_ACTIVITY (VU - Vehicle Unit)
                    print("DDDParser: procesando 0x0501 (Actividades de VU) len=\(len) offset=\(offset)")
                    let parsed = parseEFVUActivityData(payload: payload, result: &result)
                    if !parsed.isEmpty {
                        result.activities.append(contentsOf: parsed)
                        activityBlocksFound += 1
                    }
                    blocksParsed += 1
                    
                case 0x0505: // EF_VEHICLES_USED
                    print("DDDParser: procesando 0x0505 (Vehículos) len=\(len)")
                    extractVehiclePlates(payload: payload, result: &result)
                    blocksParsed += 1
                    
                case 0x0502: // EF_EVENTS_DATA
                    print("DDDParser: procesando 0x0502 (Eventos)")
                    let events = parseEventsOrFaults(payload: payload, isEvent: true)
                    result.events.append(contentsOf: events)
                    blocksParsed += 1
                    
                case 0x0503: // EF_FAULTS_DATA
                    print("DDDParser: procesando 0x0503 (Fallos)")
                    let faults = parseEventsOrFaults(payload: payload, isEvent: false)
                    result.events.append(contentsOf: faults)
                    blocksParsed += 1
                    
                case 0x0506: // EF_PLACES (Card Places Daily Work Period)
                    print("DDDParser: procesando 0x0506 (Países) len=\(len)")
                    parseCountryRecords(payload: payload, result: &result)
                    blocksParsed += 1
                    
                case 0x050E: // EF_CARD_DOWNLOAD o EF_VU_DOWNLOAD
                    if payload.count >= 4 {
                        let ts = UInt32(payload[0]) << 24 | UInt32(payload[1]) << 16 |
                                 UInt32(payload[2]) << 8  | UInt32(payload[3])
                        if ts >= validTimestampMin && ts <= validTimestampMax {
                            result.downloadDate = Date(timeIntervalSince1970: TimeInterval(ts))
                        }
                    }
                    blocksParsed += 1
                    
                // Bloques específicos del VU
                case 0x0507: // EF_VU_IDENTIFICATION
                    print("DDDParser: procesando 0x0507 (ID del VU)")
                    parseVUIdentification(payload: payload, result: &result)
                    blocksParsed += 1
                    
                case 0x0508: // EF_VU_DOWNLOAD
                    print("DDDParser: procesando 0x0508 (Descarga VU)")
                    if payload.count >= 4 {
                        let ts = UInt32(payload[0]) << 24 | UInt32(payload[1]) << 16 |
                                 UInt32(payload[2]) << 8  | UInt32(payload[3])
                        if ts >= validTimestampMin && ts <= validTimestampMax {
                            result.downloadDate = Date(timeIntervalSince1970: TimeInterval(ts))
                        }
                    }
                    blocksParsed += 1
                    
                default:
                    break
                }
            }
            
            offset = dataStart + len
        }
        
        print("DDDParser: Bloques parseados: \(blocksParsed), Bloques de actividad: \(activityBlocksFound)")
    }
    
    /// Detecta si el archivo TGD es de tarjeta de conductor o de VU
    private func detectTGDFileType(bytes: [UInt8]) -> TGDFileType {
        // Si contiene bloque 0x0520 con datos de identificación de conductor -> Driver Card
        // Si contiene bloque 0x0507 con datos de VU -> Vehicle Unit
        
        var hasDriverIdentification = false
        var hasVUIdentification = false
        var hasCardActivity = false
        var hasVUActivity = false
        
        var offset = 0
        while offset + 5 <= bytes.count {
            let fid = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            let type = bytes[offset + 2]
            let len = Int(bytes[offset + 3]) << 8 | Int(bytes[offset + 4])
            
            guard offset + 5 + len <= bytes.count else { break }
            
            if type == 0 {
                switch fid {
                case 0x0520: hasDriverIdentification = true
                case 0x0507: hasVUIdentification = true
                case 0x0504: hasCardActivity = true
                case 0x0501: hasVUActivity = true
                default: break
                }
            }
            
            offset += 5 + len
        }
        
        print("DDDParser: Detección - DriverID=\(hasDriverIdentification), VUID=\(hasVUIdentification), CardAct=\(hasCardActivity), VUAct=\(hasVUActivity)")
        
        if hasVUIdentification || hasVUActivity {
            return .vehicleUnit
        } else if hasDriverIdentification || hasCardActivity {
            return .driverCard
        }
        
        // Si no se detectó ninguno, usar heurística basada en el primer byte
        if bytes.count > 0 {
            if bytes[0] == 0x00 {
                return .driverCard
            } else if bytes[0] == 0x76 || bytes[0] == 0x56 { // 'v' o 'V'
                return .vehicleUnit
            }
        }
        
        return .unknown
    }
    
    // MARK: - VU Data Parsers
    
    /// Parsea datos de identificación del VU (Vehicle Unit)
    private func parseVUIdentification(payload: [UInt8], result: inout TachoBinaryData) {
        // VU Identification contiene:
        // - VU Part Number (16 bytes)
        // - VU Serial Number (16 bytes)
        // - VU Approval Number (8 bytes)
        // etc.
        
        if payload.count >= 16 {
            let vuPartNumber = extractString(from: payload, offset: 0, length: 16).trimmingCharacters(in: .whitespaces)
            if !vuPartNumber.isEmpty {
                print("DDDParser: VU Part Number: \(vuPartNumber)")
                // Guardar como nombre de conductor para archivos VU
                if result.driverSurname == "DESCONOCIDO" {
                    result.driverSurname = "VU: \(vuPartNumber)"
                }
            }
        }
    }
    
    /// Parsea datos de actividades del VU (Vehicle Unit)
    /// Los archivos de VU almacenan actividades de forma diferente que las tarjetas
    private func parseEFVUActivityData(payload: [UInt8], result: inout TachoBinaryData) -> [DriverActivity] {
        var activities: [DriverActivity] = []
        
        guard payload.count > 4 else { return activities }
        
        // VU Activity data tiene estructura similar pero con offset diferente
        // En archivos VU, los registros diarios pueden empezar en offset 2
        
        let validTsMin: UInt32 = 1451606400 // 2016-01-01
        let validTsMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400
        
        // Intentar encontrar registros de actividad
        var offset = 0
        
        while offset + 12 <= payload.count {
            // Buscar estructura de registro diario
            // prevLen (2B) + recLen (2B) + timestamp (4B) + ...
            
            let prevLen = Int(payload[offset]) << 8 | Int(payload[offset + 1])
            let recLen = Int(payload[offset + 2]) << 8 | Int(payload[offset + 3])
            
            guard recLen >= 12, recLen <= 2900, offset + recLen <= payload.count else {
                offset += 1
                continue
            }
            
            let ts = UInt32(payload[offset + 4]) << 24 | UInt32(payload[offset + 5]) << 16 |
                     UInt32(payload[offset + 6]) << 8  | UInt32(payload[offset + 7])
            
            guard ts >= validTsMin && ts <= validTsMax else {
                offset += 1
                continue
            }
            
            let recordDate = Date(timeIntervalSince1970: TimeInterval(ts))
            let adjustedRecordDate = recordDate
            
            print("DDDParser: VU registro diario fecha=\(recordDate) recLen=\(recLen)")
            
            // Parsear actividades del VU
            // En VU, las actividades también usan ActivityChangeInfo de 2 bytes
            let actStart = offset + 12
            let actEnd = offset + recLen
            
            var vuActivities: [(minute: Int, activityCode: Int, actType: ActivityType)] = []
            
            for ai in stride(from: actStart, to: actEnd - 1, by: 2) {
                guard ai + 1 < payload.count else { break }
                
                let hi = UInt16(payload[ai])
                let lo = UInt16(payload[ai + 1])
                let word = hi << 8 | lo
                
                // Bits del ActivityChangeInfo:
                // Bit 15: s - ranura
                // Bit 14: c - régimen
                // Bit 13: p - estado tarjeta
                // Bits 12-11: aa - tipo actividad
                // Bits 10-0: t - minutos
                
                let slot = Int((word >> 15) & 0x01)
                let cardOut = Int((word >> 13) & 0x01)
                let activityCode = Int((word >> 11) & 0x03)
                let minutes = Int(word & 0x07FF)
                
                // En VU, solo procesar actividades de la ranura 0 (conductor)
                // y cuando la tarjeta está insertada
                guard slot == 0 && cardOut == 0 && minutes < 1440 else { continue }
                
                let actType: ActivityType
                switch activityCode {
                case 0: actType = .breakOrRest
                case 1: actType = .availability
                case 2: actType = .work
                case 3: actType = .driving
                default: actType = .unknown
                }
                
                vuActivities.append((minute: minutes, activityCode: activityCode, actType: actType))
            }
            
            // Ordenar por minuto
            vuActivities.sort { $0.minute < $1.minute }
            
            // Calcular duraciones
            for i in 0..<vuActivities.count {
                let current = vuActivities[i]
                
                // Lógica de cierre (Sync con DriverActivity)
                var nextMinute: Int
                if i + 1 < vuActivities.count {
                    nextMinute = vuActivities[i + 1].minute
                } else {
                    if current.activityCode == 0 { // .breakOrRest
                        nextMinute = 1440
                    } else {
                        nextMinute = min(current.minute + 1, 1440)
                    }
                }
                
                if nextMinute > current.minute {
                    let durationSecs = Double((nextMinute - current.minute) * 60)
                    let start = adjustedRecordDate.addingTimeInterval(TimeInterval(current.minute * 60))
                    
                    if durationSecs >= 60 {
                        activities.append(DriverActivity(
                            type: current.actType,
                            start: start,
                            duration: durationSecs,
                            isSlotInserted: true,
                            vehiclePlate: nil
                        ))
                    }
                }
            }
            
            offset += recLen
        }
        
        print("DDDParser: parseEFVUActivityData → \(activities.count) actividades")
        return activities
    }
    
    // MARK: - EF_Identification Parser
    
    private func parseIdentification(payload: [UInt8], result: inout TachoBinaryData) {
        // According to Annex 1C, EF_Identification is 143 bytes long.
        // It contains:
        // InstitutionName (35) -> optional or not starting here
        // CardNumber (16)
        // CardIssuingMemberState (3)
        // CardHolderName: HolderSurname (35), HolderFirstNames (35)
        // HolderBirthDate (4), ...
        
        // In the TGD payload, CardNumber typically starts around offset 5
        // but we can extract strictly by looking at the fixed lengths.
        // Actually, let's use the known offsets for Gen1/Gen2 cards.
        
        // Let's use robust extraction by doing the same text-based heuristics on the payload,
        // or just use specific known offsets:
        if payload.count >= 16 {
            result.cardNumber = extractString(from: payload, offset: 0, length: 16)
        }
        
        // Offsets can vary, so let's try 36 for surname and 71 for firstname
        // In our hex dump: '45 34 ...' is at the start (offset 0).
        // Then '01' at 16.
        // Then InstitutionName `44 47 20 ...` at 17, length 35.
        // Then '63 0C 01' ... 
        // Then Surname at 58, length 35.
        // Then FirstName at 93, length 35.
        
        if payload.count >= 93 {
            let surname = extractString(from: payload, offset: 58, length: 35)
            if !surname.isEmpty { result.driverSurname = surname }
            
            if payload.count >= 128 {
                let name = extractString(from: payload, offset: 93, length: 35)
                if !name.isEmpty { result.driverName = name }
            }
        }
        
        print("DDDParser: ID bloque payload len=\(payload.count) -> '\(result.driverSurname)' '\(result.driverName)' '\(result.cardNumber)'")
    }
    
    // MARK: - Events & Faults Parser
    
    private func parseEventsOrFaults(payload: [UInt8], isEvent: Bool) -> [TachoEvent] {
        var results: [TachoEvent] = []
        guard payload.count >= 24 else { return results }
        
        let validTsMin: UInt32 = 1451606400 // 2016-01-01
        let validTsMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400 // Hasta 1 año futuro
        
        var offset = 0
        
        while offset + 24 <= payload.count {
            // Evaluamos si en offset + 1 hay un timestamp de inicio válido
            let startTs = UInt32(payload[offset + 1]) << 24 | UInt32(payload[offset + 2]) << 16 |
                          UInt32(payload[offset + 3]) << 8  | UInt32(payload[offset + 4])
            
            if startTs >= validTsMin && startTs <= validTsMax {
                let endTs = UInt32(payload[offset + 5]) << 24 | UInt32(payload[offset + 6]) << 16 |
                            UInt32(payload[offset + 7]) << 8  | UInt32(payload[offset + 8])
                
                // Verificamos que el endTs tenga sentido
                if endTs == 0 || (endTs >= startTs && endTs <= validTsMax) {
                    let typeCode = payload[offset]
                    let startDate = Date(timeIntervalSince1970: TimeInterval(startTs))
                    let endDate = endTs > 0 ? Date(timeIntervalSince1970: TimeInterval(endTs)) : startDate
                    
                    let typeStr: String
                    if isEvent {
                        switch typeCode {
                        case 0x01: typeStr = "Inserción tarjeta no válida"
                        case 0x02: typeStr = "Conflicto de tarjetas"
                        case 0x03: typeStr = "Solape de tiempo"
                        case 0x04: typeStr = "Conducción sin tarjeta"
                        case 0x05: typeStr = "Inserción tarjeta en conducción"
                        case 0x06: typeStr = "Última sesión no cerrada"
                        case 0x07: typeStr = "Exceso de velocidad"
                        case 0x08: typeStr = "Interrupción suministro"
                        default: typeStr = "Evento técnico (\(typeCode))"
                        }
                    } else {
                        typeStr = "Fallo del sistema (\(typeCode))"
                    }
                    
                    results.append(TachoEvent(
                        type: typeStr,
                        start: startDate,
                        end: endDate,
                        vehiclePlate: nil // Se puede extraer de los 15 bytes siguientes si se desea
                    ))
                    
                    offset += 24 // Saltamos el registro completo
                    continue
                }
            }
            offset += 1 // Avanzamos byte a byte para evitar desalineaciones por cabeceras
        }
        return results
    }
    
    // MARK: - EF_DriverActivityData Parser (EU Standard)
    
    /// Parsea el bloque EF_DriverActivityData según la especificación EU Reg 165/2014
    private func parseEFDriverActivityData(payload: [UInt8], result: inout TachoBinaryData) -> [DriverActivity] {
        var activities: [DriverActivity] = []
        
        // EF_DriverActivityData structure:
        // activityPointerOldestDayRecord: 2 bytes
        // activityPointerNewestRecord   : 2 bytes
        // activityDailyRecords          : buffer circular con CardActivityDailyRecord
        
        guard payload.count > 4 else { return activities }
        
        let oldestPtr = Int(payload[0]) << 8 | Int(payload[1])
        let newestPtr = Int(payload[2]) << 8 | Int(payload[3])
        let bufStart = 4
        let bufEnd = payload.count
        let bufLen = bufEnd - bufStart
        
        guard bufLen > 12 else { return activities }
        
        print("DDDParser: EF_DriverActivityData payload len=\(payload.count) oldest=\(oldestPtr) newest=\(newestPtr)")
        
        // Build linearised buffer handling cyclic wrap-around
        var buf: [UInt8]
        let adjustedOldest = min(oldestPtr, bufLen)
        let adjustedNewest = min(newestPtr, bufLen)
        
        if adjustedNewest < adjustedOldest {
            // Wrapped: oldest is part-way through; data continues from buf start
            let part1 = Array(payload[bufStart + adjustedOldest ..< bufEnd])
            let part2 = Array(payload[bufStart ..< bufStart + adjustedOldest])
            buf = part1 + part2
        } else {
            buf = Array(payload[bufStart ..< bufEnd])
        }
        
        // Parse daily records from linearised buffer
        var idx = 0
        
        let validTsMin: UInt32 = 1451606400 // 2016-01-01
        let validTsMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400
        
        while idx + 12 <= buf.count {
            let prevLen  = Int(buf[idx]) << 8 | Int(buf[idx + 1])
            let recLen   = Int(buf[idx + 2]) << 8 | Int(buf[idx + 3])
            
            guard recLen >= 12, idx + recLen <= buf.count else {
                idx += 1
                continue
            }
            
            // Validate timestamp
            let ts = UInt32(buf[idx + 4]) << 24 | UInt32(buf[idx + 5]) << 16 |
                     UInt32(buf[idx + 6]) << 8  | UInt32(buf[idx + 7])
            
            guard ts >= validTsMin && ts <= validTsMax else {
                idx += 1
                continue
            }
            
            let recordDate = Date(timeIntervalSince1970: TimeInterval(ts))
            
            // Usamos la fecha original UTC (el desfase de 7 horas era incorrecto)
            let adjustedRecordDate = recordDate
            
            print("DDDParser: registro diario fecha=\(recordDate) recLen=\(recLen)")
            
            // Parse ActivityChangeInfo records (start at offset 12 = after header)
            let actStart = idx + 12
            let actEnd   = idx + recLen
            
            // Filtramos solo las actividades del CONDUCTOR (slot 0) y excluimos extracciones de tarjeta
            var driverActivities: [(minute: Int, activityCode: Int, actType: ActivityType)] = []
            
            for actIdx in stride(from: actStart, to: actEnd - 1, by: 2) {
                guard actIdx + 1 < buf.count else { break }
                
                let hi = UInt16(buf[actIdx])
                let lo = UInt16(buf[actIdx + 1])
                let word = hi << 8 | lo
                
                // Bits según especificación:
                // Bit 15 (bit 0 del byte alto): s - ranura (0=conductor, 1=segundo conductor)
                // Bit 14 (bit 1 del byte alto): c - régimen de conducción / entrada manual
                // Bit 13 (bit 2 del byte alto): p - estado de tarjeta (0=insertada, 1=no insertada)
                // Bits 12-11 (bits 4-3 del byte alto): aa - tipo de actividad
                // Bits 10-0 (byte bajo + bits 0-3 del byte alto): t - minutos desde 00:00
                
                let slot = Int((word >> 15) & 0x01)  // Solo ranura 0 (conductor)
                let cardOut = Int((word >> 13) & 0x01)  // 0=insertada, 1=no insertada
                let activityCode = Int((word >> 11) & 0x03)
                let minutes = Int(word & 0x07FF)
                
                // Solo procesamos actividades del conductor (slot 0)
                // Y solo cuando la tarjeta está insertada (cardOut == 0)
                // Las extracciones de tarjeta (cardOut == 1) no cuentan como actividad
                guard slot == 0 && cardOut == 0 && minutes < 1440 else { continue }
                
                let actType: ActivityType
                switch activityCode {
                case 0: actType = .breakOrRest
                case 1: actType = .availability
                case 2: actType = .work
                case 3: actType = .driving
                default: actType = .unknown
                }
                
                driverActivities.append((minute: minutes, activityCode: activityCode, actType: actType))
            }
            
            // Ordenar por minuto para asegurar secuencia correcta
            driverActivities.sort { $0.minute < $1.minute }
            
            // Calcular duraciones entre cambios consecutivos
            for i in 0..<driverActivities.count {
                let current = driverActivities[i]
                
                // Si es la última actividad del día, intentamos determinar el fin real
                var nextMinute: Int
                if i + 1 < driverActivities.count {
                    nextMinute = driverActivities[i + 1].minute
                } else {
                    // Si es la última actividad:
                    if current.activityCode == 0 { // .breakOrRest
                        nextMinute = 1440 // El descanso puede durar hasta medianoche
                    } else {
                        // Para Trabajo/Conducción, si no hay cierre, limitamos la extensión 
                        // para evitar el error de "9h 6m" cuando era menos.
                        nextMinute = min(current.minute + 1, 1440)
                    }
                }
                
                // Solo crear actividad si hay tiempo entre este cambio y el siguiente
                if nextMinute > current.minute {
                    let durationSecs = Double((nextMinute - current.minute) * 60)
                    let start = adjustedRecordDate.addingTimeInterval(TimeInterval(current.minute * 60))
                    
                    // Ignorar actividades de duración muy corta (< 1 minuto) como ruido
                    if durationSecs >= 60 {
                        activities.append(DriverActivity(
                            type: current.actType,
                            start: start,
                            duration: durationSecs,
                            isSlotInserted: true,
                            vehiclePlate: nil
                        ))
                    }
                }
            }
            
            idx += recLen
        }
        
        print("DDDParser: parseEFDriverActivityData → \(activities.count) actividades")
        return activities
    }
    
    // MARK: - Heuristic scan for daily records
    
    /// Recorre todo el archivo buscando patrones válidos de actividad
    /// Este método es un fallback robusto para archivos con estructura no estándar
    private func scanForDailyRecords(bytes: [UInt8], result: inout TachoBinaryData) -> [DriverActivity] {
        var activities: [DriverActivity] = []
        let validTsMin: UInt32 = 1451606400 // 2016-01-01
        let validTsMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400
        
        print("DDDParser: Iniciando escaneo heurístico de \(bytes.count) bytes")
        
        // 1. Buscar específicamente bloques 0x0504 dispersos
        print("DDDParser: Buscando bloques 0x0504...")
        var blocksFound = 0
        var i = 0
        while i < bytes.count - 6 {
            // Buscar patrón 0x05 0x04 (FID de Activity Data)
            if bytes[i] == 0x05 && bytes[i + 1] == 0x04 {
                let type = bytes[i + 2]
                let len = Int(bytes[i + 3]) << 8 | Int(bytes[i + 4])
                
                // Validar bloque
                if type == 0 && len > 12 && len < 100000 && i + 5 + len <= bytes.count {
                    let payloadEnd = min(i + 5 + len, bytes.count)
                    let payload = Array(bytes[i + 5 ..< payloadEnd])
                    
                    print("DDDParser: Encontrado bloque 0x0504 en offset \(i), len=\(len)")
                    let parsed = parseEFDriverActivityData(payload: payload, result: &result)
                    
                    if !parsed.isEmpty {
                        activities.append(contentsOf: parsed)
                        blocksFound += 1
                    }
                    
                    i += 5 + len
                    continue
                }
            }
            i += 1
        }
        print("DDDParser: Bloques 0x0504 encontrados: \(blocksFound), actividades: \(activities.count)")
        
        // 2. Buscar bloques 0x0501 (VU Activity)
        print("DDDParser: Buscando bloques 0x0501...")
        i = 0
        while i < bytes.count - 6 {
            if bytes[i] == 0x05 && bytes[i + 1] == 0x01 {
                let type = bytes[i + 2]
                let len = Int(bytes[i + 3]) << 8 | Int(bytes[i + 4])
                
                if type == 0 && len > 12 && len < 100000 && i + 5 + len <= bytes.count {
                    let payloadEnd = min(i + 5 + len, bytes.count)
                    let payload = Array(bytes[i + 5 ..< payloadEnd])
                    
                    print("DDDParser: Encontrado bloque 0x0501 en offset \(i), len=\(len)")
                    let parsed = parseEFVUActivityData(payload: payload, result: &result)
                    
                    if !parsed.isEmpty {
                        activities.append(contentsOf: parsed)
                    }
                    
                    i += 5 + len
                    continue
                }
            }
            i += 1
        }
        
        // 3. Escanear buscando registros de actividad (ActivityChangeInfo) dispersos
        // Este es el método más robusto para archivos con datos corruptos o no estándar
        print("DDDParser: Buscando registros ActivityChangeInfo dispersos...")
        
        var foundRecords = 0
        var j = 0
        while j < bytes.count - 11 {
            // Buscar timestamp válido seguido de datos de actividad
            let ts = UInt32(bytes[j]) << 24 | UInt32(bytes[j + 1]) << 16 |
                     UInt32(bytes[j + 2]) << 8  | UInt32(bytes[j + 3])
            
            if ts >= validTsMin && ts <= validTsMax {
                let recordDate = Date(timeIntervalSince1970: TimeInterval(ts))
                let recLen = Int(bytes[j + 8]) << 8 | Int(bytes[j + 9])
                
                // Verificar si parece un registro válido (12-30000 bytes)
                if recLen >= 12 && recLen <= 30000 && j + 10 + recLen <= bytes.count {
                    let actStart = j + 10
                    let actEnd = min(j + 10 + recLen, bytes.count)
                    
                    // Contar ActivityChangeInfo válidos
                    var validCount = 0
                    for k in stride(from: actStart, to: actEnd - 1, by: 2) {
                        guard k + 1 < bytes.count else { break }
                        let word = UInt16(bytes[k]) << 8 | UInt16(bytes[k + 1])
                        let minutes = Int(word & 0x07FF)
                        if minutes < 1440 { validCount += 1 }
                    }
                    
                    let totalWords = (actEnd - actStart) / 2
                    if totalWords > 0 && validCount > totalWords / 2 {
                        // Parsear actividades
                        var driverActivities: [(minute: Int, actType: ActivityType)] = []
                        
                        for k in stride(from: actStart, to: actEnd - 1, by: 2) {
                            guard k + 1 < bytes.count else { break }
                            let hi = UInt16(bytes[k])
                            let lo = UInt16(bytes[k + 1])
                            let word = hi << 8 | lo
                            
                            let slot = Int((word >> 15) & 0x01)
                            let cardOut = Int((word >> 13) & 0x01)
                            let activityCode = Int((word >> 11) & 0x03)
                            let minutes = Int(word & 0x07FF)
                            
                            guard slot == 0 && cardOut == 0 && minutes < 1440 else { continue }
                            
                            let actType: ActivityType
                            switch activityCode {
                            case 0: actType = .breakOrRest
                            case 1: actType = .availability
                            case 2: actType = .work
                            case 3: actType = .driving
                            default: actType = .unknown
                            }
                            
                            driverActivities.append((minute: minutes, actType: actType))
                        }
                        
                        driverActivities.sort { $0.minute < $1.minute }
                        
                        // Solo añadir si no está duplicado
                        let isDuplicate = activities.contains { act in
                            abs(act.start.timeIntervalSince(recordDate)) < 3600
                        }
                        
                        if !isDuplicate {
                            for k in 0..<driverActivities.count {
                                let current = driverActivities[k]
                                let nextMinute = k + 1 < driverActivities.count ? driverActivities[k + 1].minute : 1440
                                
                                if nextMinute > current.minute {
                                    let durationSecs = Double((nextMinute - current.minute) * 60)
                                    let start = recordDate.addingTimeInterval(TimeInterval(current.minute * 60))
                                    
                                    if durationSecs >= 60 {
                                        activities.append(DriverActivity(
                                            type: current.actType,
                                            start: start,
                                            duration: durationSecs,
                                            isSlotInserted: true,
                                            vehiclePlate: nil
                                        ))
                                    }
                                }
                            }
                            foundRecords += 1
                        }
                        
                        j += 10 + recLen
                        continue
                    }
                }
            }
            j += 1
        }
        
        print("DDDParser: Registros de actividad encontrados: \(foundRecords)")
        print("DDDParser: Total actividades del escaneo: \(activities.count)")
        
        // Eliminar duplicados
        var uniqueActivities: [DriverActivity] = []
        for act in activities {
            let isDupe = uniqueActivities.contains { existing in
                abs(existing.start.timeIntervalSince(act.start)) < 60 && existing.type == act.type
            }
            if !isDupe {
                uniqueActivities.append(act)
            }
        }
        
        print("DDDParser: Actividades únicas tras pasos 1-3: \(uniqueActivities.count)")
        
        // 4. Escaneo adicional buscando bloques TGD con cabecera (FID+Type+Length)
        print("DDDParser: buscando bloques TGD con cabecera FID+Type+Length...")
        i = 0
        while i + 12 < bytes.count {
            let recLen = Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
            
            let currentI = i
            let dataCount = bytes.count
            guard recLen >= 12, recLen <= 30000, currentI + recLen <= dataCount else {
                i += 1
                continue
            }
            
            let ts = UInt32(bytes[i + 4]) << 24 | UInt32(bytes[i + 5]) << 16 |
                     UInt32(bytes[i + 6]) << 8  | UInt32(bytes[i + 7])
            
            if ts >= validTsMin && ts <= validTsMax {
                let recordDate = Date(timeIntervalSince1970: TimeInterval(ts))
                let adjustedRecordDate = recordDate
                
                var goodCount = 0
                let actStart = i + 12
                let actEnd   = min(i + recLen, bytes.count - 1)
                
                for ai in stride(from: actStart, to: actEnd - 1, by: 2) {
                    guard ai + 1 < bytes.count else { break }
                    let word = UInt16(bytes[ai]) << 8 | UInt16(bytes[ai + 1])
                    if (word & 0x07FF) < 1440 { goodCount += 1 }
                }
                
                let totalWords = (actEnd - actStart) / 2
                if totalWords > 0 && goodCount > totalWords / 2 {
                    print("DDDParser: heurístico Step 4 encontró registro en offset \(i)")
                    var step4Acts: [DriverActivity] = []
                    for ai in stride(from: actStart, to: actEnd - 1, by: 2) {
                        guard ai + 1 < bytes.count else { break }
                        let word = UInt16(bytes[ai]) << 8 | UInt16(bytes[ai + 1])
                        let slot = Int((word >> 15) & 0x01)
                        let cardOut = Int((word >> 13) & 0x01)
                        let activityCode = Int((word >> 11) & 0x03)
                        let minutes = Int(word & 0x07FF)
                        
                        guard slot == 0 && cardOut == 0 && minutes < 1440 else { continue }
                        
                        let actType: ActivityType
                        switch activityCode {
                        case 0: actType = .breakOrRest
                        case 1: actType = .availability
                        case 2: actType = .work
                        case 3: actType = .driving
                        default: actType = .unknown
                        }
                        
                        let start = adjustedRecordDate.addingTimeInterval(TimeInterval(minutes * 60))
                        let isDupe = (uniqueActivities + step4Acts).contains { existing in
                            abs(existing.start.timeIntervalSince(start)) < 60 && existing.type == actType
                        }
                        
                        if !isDupe {
                            // Determinamos duración (heurística simple para este paso)
                            step4Acts.append(DriverActivity(type: actType, start: start, duration: 60, isSlotInserted: true, vehiclePlate: nil))
                        }
                    }
                    uniqueActivities.append(contentsOf: step4Acts)
                    i += recLen
                    continue
                }
            }
            i += 1
        }
        
        print("DDDParser: Actividades finales tras Step 4: \(uniqueActivities.count)")
        return uniqueActivities
    }

    
    // MARK: - Driver Info Extraction
    
    /// Extrae nombre del conductor usando regex de secuencias de mayúsculas
    private func extractDriverInfo(bytes: [UInt8], result: inout TachoBinaryData) {
        guard let text = String(bytes: bytes, encoding: .isoLatin1) else { return }
        
        // Card number pattern: 2-letter country code + digits + letter + digits
        let cardPattern = "[A-Z]{2}[A-Z0-9]{11,18}"
        if let regex = try? NSRegularExpression(pattern: cardPattern) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range, in: text) {
                let candidate = String(text[swiftRange])
                if candidate.first?.isLetter == true {
                    result.cardNumber = candidate
                }
            }
        }
        
        // Name pattern: uppercase words 3+ chars, not known abbreviations
        let excluded: Set<String> = ["UTC","CAN","VIN","ISO","ECE","ADR","TGD","DDD","ESM","DGT","GPS","KMH","EUR"]
        let nameRegex = try? NSRegularExpression(pattern: "[A-ZÁÉÍÓÚÜÑ]{3,}(?:[- ][A-ZÁÉÍÓÚÜÑ]{2,})*")
        
        var candidates: [String] = []
        if let nameRegex = nameRegex {
            let nsText = text as NSString
            let matches = nameRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for m in matches {
                let s = nsText.substring(with: m.range)
                if !excluded.contains(s) && s.count >= 3 && s.count <= 40 {
                    candidates.append(s)
                }
            }
        }
        
        if let surname = candidates.first {
            result.driverSurname = surname
        }
        if candidates.count > 1 {
            result.driverName = candidates[1]
        }
    }
    
    // MARK: - Vehicle Plates
    
    private func extractVehiclePlates(payload: [UInt8], result: inout TachoBinaryData) {
        guard payload.count >= 2 else { return }
        let _ = Int(payload[0]) << 8 | Int(payload[1]) // vehiclePointerNewestRecord
        
        var offset = 2
        var plates: [String] = []
        
        while offset + 31 <= payload.count {
            // Odometer is 3 bytes (offset+0 and offset+3)
            let initialOdometer = Int(payload[offset]) << 16 | Int(payload[offset + 1]) << 8 | Int(payload[offset + 2])
            let finalOdometer = Int(payload[offset + 3]) << 16 | Int(payload[offset + 4]) << 8 | Int(payload[offset + 5])
            
            // vehicleFirstUse (offset+6, 4 bytes)
            let firstUseSec = UInt32(payload[offset + 6]) << 24 |
                              UInt32(payload[offset + 7]) << 16 |
                              UInt32(payload[offset + 8]) << 8 |
                              UInt32(payload[offset + 9])
            
            // vehicleLastUse (offset+10, 4 bytes)
            let lastUseSec = UInt32(payload[offset + 10]) << 24 |
                             UInt32(payload[offset + 11]) << 16 |
                             UInt32(payload[offset + 12]) << 8 |
                             UInt32(payload[offset + 13])
            
            // vehicleRegistrationNumber (offset+15, 14 bytes)
            let plateBytes = Array(payload[(offset + 15) ..< (offset + 29)])
            
            if let text = String(bytes: plateBytes, encoding: .ascii) {
                // Limpiamos la matrícula (es posible que esté rellenada con 0x00 o espacios)
                let cleanPlate = text.components(separatedBy: "\0").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if !cleanPlate.isEmpty {
                    if !plates.contains(cleanPlate) {
                        plates.append(cleanPlate)
                    }
                    
                    if firstUseSec > 0 {
                        // Las fechas de los vehículos ya vienen bien en la tarjeta (UTC normal), no necesitan desfase
                        let startDate = Date(timeIntervalSince1970: TimeInterval(firstUseSec))
                        // Si no hay fecha de fin, usar la fecha actual en lugar de un año en el futuro
                        let endDate = lastUseSec == 0 ? Date() : Date(timeIntervalSince1970: TimeInterval(lastUseSec))
                        
                        result.vehicleUsage.append(VehicleUsageRecord(plate: cleanPlate, start: startDate, end: endDate, initialOdometer: initialOdometer, finalOdometer: finalOdometer))
                    }
                }
            }
            offset += 31 // Tamaño del registro CardVehicleRecord
        }
        
        result.vehicles = plates
    }
    
    // MARK: - Country Records Parser (0x0506 EF_PLACES)
    
    /// Parsea registros de países/regiones (CardPlaceDailyWorkPeriod)
    /// Formato por registro: EntryTime(4B) + EntryCountry(1B) + EntryRegion(1B) + VehicleOdometer(3B)
    private func parseCountryRecords(payload: [UInt8], result: inout TachoBinaryData) {
        let validTimestampMin: UInt32 = 1451606400
        let validTimestampMax: UInt32 = UInt32(Date().timeIntervalSince1970) + 365 * 86400
        let recordSize = 10 // Cada registro CardPlaceDailyWorkPeriod = 10 bytes
        
        var offset = 0
        // Saltar el contador de registros si existe (2 bytes)
        if payload.count > 2 {
            let count = Int(payload[0]) << 8 | Int(payload[1])
            if count > 0 && count * recordSize + 2 <= payload.count {
                offset = 2
            }
        }
        
        var weekCounter = 0
        var lastWeekDate: Date?
        let calendar = Calendar.current
        
        while offset + recordSize <= payload.count {
            // EntryTime: 4 bytes big-endian (UNIX timestamp)
            let ts = UInt32(payload[offset]) << 24 | UInt32(payload[offset + 1]) << 16 |
                     UInt32(payload[offset + 2]) << 8 | UInt32(payload[offset + 3])
            
            guard ts >= validTimestampMin && ts <= validTimestampMax else {
                offset += recordSize
                continue
            }
            
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            
            // Country code: 1 byte
            let countryCode = payload[offset + 4]
            // Region code: 1 byte
            let regionCode = payload[offset + 5]
            
            // Vehicle odometer: 3 bytes big-endian
            let odometer = Int(payload[offset + 6]) << 16 | Int(payload[offset + 7]) << 8 | Int(payload[offset + 8])
            
            // Tipo (modo): bit 0x80 del byte offset+9 indica inicio vs final
            let modeByte = payload[offset + 9]
            let mode = (modeByte & 0x01) == 0 ? "Inicio (Tarjeta insertada)" : "Final (Tarjeta extraída)"
            
            // Calcular semana
            if let lastDate = lastWeekDate {
                let weekOfLast = calendar.component(.weekOfYear, from: lastDate)
                let weekOfCurrent = calendar.component(.weekOfYear, from: date)
                if weekOfCurrent != weekOfLast {
                    weekCounter += 1
                }
            }
            lastWeekDate = date
            
            let country = DDDParser.countryName(for: countryCode)
            let region = DDDParser.regionName(for: regionCode, country: countryCode)
            
            let record = CountryRecord(
                weekNumber: weekCounter + 1,
                date: date,
                country: country,
                region: region,
                odometer: odometer,
                mode: mode
            )
            result.countryRecords.append(record)
            
            offset += recordSize
        }
        
        print("DDDParser: \(result.countryRecords.count) registros de países parseados")
    }
    
    /// Códigos de país del tacógrafo (ISO 3166 simplificado)
    static func countryName(for code: UInt8) -> String {
        switch code {
        case 0x00: return "Sin información"
        case 0x01: return "Austria"
        case 0x02: return "Albania"
        case 0x03: return "Andorra"
        case 0x04: return "Armenia"
        case 0x05: return "Azerbaiyán"
        case 0x06: return "Bélgica"
        case 0x07: return "Bulgaria"
        case 0x08: return "Bosnia"
        case 0x09: return "Bielorrusia"
        case 0x0A: return "Suiza"
        case 0x0B: return "Chipre"
        case 0x0C: return "República Checa"
        case 0x0D: return "Alemania"
        case 0x0E: return "Dinamarca"
        case 0x0F: return "España"
        case 0x10: return "Estonia"
        case 0x11: return "Francia"
        case 0x12: return "Finlandia"
        case 0x13: return "Liechtenstein"
        case 0x14: return "Islas Feroe"
        case 0x15: return "Reino Unido"
        case 0x16: return "Georgia"
        case 0x17: return "Grecia"
        case 0x18: return "Hungría"
        case 0x19: return "Croacia"
        case 0x1A: return "Italia"
        case 0x1B: return "Irlanda"
        case 0x1C: return "Islandia"
        case 0x1D: return "Kazajistán"
        case 0x1E: return "Luxemburgo"
        case 0x1F: return "Lituania"
        case 0x20: return "Letonia"
        case 0x21: return "Malta"
        case 0x22: return "Mónaco"
        case 0x23: return "Moldavia"
        case 0x24: return "Macedonia del Norte"
        case 0x25: return "Noruega"
        case 0x26: return "Países Bajos"
        case 0x27: return "Portugal"
        case 0x28: return "Polonia"
        case 0x29: return "Rumanía"
        case 0x2A: return "San Marino"
        case 0x2B: return "Rusia"
        case 0x2C: return "Suecia"
        case 0x2D: return "Eslovaquia"
        case 0x2E: return "Eslovenia"
        case 0x2F: return "Turkmenistán"
        case 0x30: return "Turquía"
        case 0x31: return "Ucrania"
        case 0x32: return "Vaticano"
        case 0x33: return "Yugoslavia/Serbia"
        default: return "País (\(String(format: "0x%02X", code)))"
        }
    }
    
    /// Códigos de región
    static func regionName(for code: UInt8, country: UInt8) -> String {
        if code == 0x00 { return "" }
        // Regiones españolas
        if country == 0x0F {
            switch code {
            case 0x01: return "Andalucía"
            case 0x02: return "Aragón"
            case 0x03: return "Asturias"
            case 0x04: return "Cantabria"
            case 0x05: return "Cataluña"
            case 0x06: return "Castilla y León"
            case 0x07: return "Castilla-La Mancha"
            case 0x08: return "Valencia"
            case 0x09: return "Extremadura"
            case 0x0A: return "Galicia"
            case 0x0B: return "Baleares"
            case 0x0C: return "Canarias"
            case 0x0D: return "La Rioja"
            case 0x0E: return "Madrid"
            case 0x0F: return "Murcia"
            case 0x10: return "Navarra"
            case 0x11: return "País Vasco"
            default: return "Región \(code)"
            }
        }
        return "Región \(code)"
    }
    
    // MARK: - File Content Blocks Generator
    
    private func generateFileContentBlocks(result: TachoBinaryData) -> [FileContentBlock] {
        var blocks: [FileContentBlock] = []
        
        blocks.append(FileContentBlock(name: "ICC identificación", status: !result.cardNumber.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "IC identificación", status: !result.cardNumber.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Certificado de la tarjeta", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Certificado de país", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Identificación de la aplicación", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de la aplicación de identificación", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Información de la tarjeta", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de identificación de la tarjeta", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Identificación del titular de la tarjeta", status: !result.driverSurname.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Última descarga", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de la última descarga", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Información del permiso de conducir", status: !result.licenseNumber.isEmpty ? "disponible" : "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de información del permiso de conducir", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Incidentes", status: result.events.contains(where: { !$0.type.contains("Fallo") }) ? "disponible" : "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de incidentes", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Errores", status: result.events.contains(where: { $0.type.contains("Fallo") }) ? "disponible" : "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de errores", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Actividades", status: !result.activities.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de las actividades", status: !result.activities.isEmpty ? "válido" : "no disponible", isSignature: true))
        blocks.append(FileContentBlock(name: "Vehículos", status: !result.vehicleUsage.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura del vehículos", status: !result.vehicleUsage.isEmpty ? "válido" : "no disponible", isSignature: true))
        blocks.append(FileContentBlock(name: "Países", status: !result.countryRecords.isEmpty ? "disponible" : "no disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de países", status: !result.countryRecords.isEmpty ? "válido" : "no disponible", isSignature: true))
        blocks.append(FileContentBlock(name: "Uso actual", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura del uso actual", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Control de las actividades", status: "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura del control de las actividades", status: "válido", isSignature: true))
        blocks.append(FileContentBlock(name: "Casos especiales", status: !result.specialCases.isEmpty ? "disponible" : "disponible", isSignature: false))
        blocks.append(FileContentBlock(name: "Signatura de casos especiales", status: "válido", isSignature: true))
        
        return blocks
    }
    
    // MARK: - Utilities
    
    private func findBlock(pattern: [UInt8], in bytes: [UInt8]) -> Int? {
        guard bytes.count > pattern.count else { return nil }
        for i in 0 ..< bytes.count - pattern.count {
            if Array(bytes[i ..< i + pattern.count]) == pattern { return i }
        }
        return nil
    }
    
    private func extractString(from bytes: [UInt8], offset: Int, length: Int) -> String {
        guard offset >= 0, offset + length <= bytes.count else { return "" }
        let sub = Array(bytes[offset ..< offset + length])
        
        // Find first uppercase letter (A-Z) - this is where the actual name starts
        var startIndex = 0
        for (i, byte) in sub.enumerated() {
            if byte >= 65 && byte <= 90 { // A-Z
                startIndex = i
                break
            }
        }
        
        // Extract from start index, filtering to only printable ASCII
        let filtered = Array(sub[startIndex...]).filter { $0 >= 32 && $0 < 127 }
        
        return (String(bytes: filtered, encoding: .isoLatin1) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ReaderViewModel

class ReaderViewModel: ObservableObject {
    @Published var statusMessage = "Sistema GloboFleet Listo"
    @Published var dailyDriving: Double = 0.0
    @Published var dailyWork: Double = 0.0
    @Published var infringements: [Infringement] = []
    @Published var planningInfo: PlanningInfo = PlanningInfo()
    @Published var tachoData: DDDParser.TachoBinaryData?
    @Published var remainingDrivingTime: Double = 0.0
    @Published var remainingBreakTime: Double = 0.0
    @Published var totalMileage: Double = 0.0
    @Published var speedViolationsCount: Int = 0
    @Published var events: [TachoEvent] = []
    @Published var shifts: [TachoShift] = []
    @Published var vehiclesUsed: [VehicleUsageRecord] = []
    @Published var countryRecords: [CountryRecord] = []
    @Published var fileContentBlocks: [FileContentBlock] = []
    
    private let parser = DDDParser()
    
    func processData(_ data: Data) {
        self.statusMessage = "Analizando archivo..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("ReaderVM: datos recibidos: \(data.count) bytes")
            
            do {
                let parsed = try self.parser.parse(fileData: data)
                
                print("ReaderVM: conductor=\(parsed.driverName) \(parsed.driverSurname)")
                print("ReaderVM: actividades=\(parsed.activities.count)")
                print("ReaderVM: infracciones=\(parsed.infringements.count)")
                
                DispatchQueue.main.async {
                    self.tachoData = parsed
                    self.infringements = parsed.infringements
                    self.planningInfo = parsed.planning
                    self.events = parsed.events
                    self.shifts = parsed.shifts
                    self.vehiclesUsed = parsed.vehicleUsage
                    self.countryRecords = parsed.countryRecords
                    self.fileContentBlocks = parsed.fileContentBlocks
                    
                    guard !parsed.activities.isEmpty else {
                        self.statusMessage = "Sin actividades – formato no reconocido"
                        return
                    }
                    
                    // Persistir
                    let driver = Driver(
                        id: parsed.cardNumber,
                        firstName: parsed.driverName,
                        lastName: parsed.driverSurname,
                        expiryDate: nil
                    )
                    let fileName = "Importado_\(parsed.driverSurname).tgd"
                    let tachoFile = TachoFile(
                        fileName: fileName,
                        importDate: Date(),
                        driverId: parsed.cardNumber,
                        rawData: data
                    )
                    StorageManager.shared.saveFile(tachoFile, driver: driver)
                    
                    // KPIs
                    let drivingSecs = parsed.activities.filter { $0.type == .driving }.reduce(0.0) { $0 + $1.duration }
                    let workSecs    = parsed.activities.filter { $0.type == .work }.reduce(0.0) { $0 + $1.duration }
                    let breakSecs   = parsed.activities.filter { $0.type == .breakOrRest }.reduce(0.0) { $0 + $1.duration }
                    
                    self.dailyDriving          = drivingSecs / 3600
                    self.dailyWork             = (drivingSecs + workSecs) / 3600
                    self.remainingDrivingTime  = max(0, 9.0 - self.dailyDriving)
                    self.remainingBreakTime    = max(0, 45.0 - breakSecs / 60)
                    self.totalMileage          = (drivingSecs / 3600) * 80
                    self.speedViolationsCount  = 0  // no speed data in card files
                    
                    if parsed.infringements.isEmpty {
                        self.statusMessage = "OK – \(parsed.activities.count) actividades analizadas"
                    } else {
                        self.statusMessage = "\(parsed.infringements.count) infracción(es) detectada(s)"
                    }
                }
            } catch {
                print("ReaderVM: error \(error)")
                DispatchQueue.main.async {
                    self.statusMessage = "Error: formato de archivo no compatible"
                }
            }
    }
}

}
