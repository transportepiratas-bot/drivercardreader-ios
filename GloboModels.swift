import Foundation

/// Estructuras de datos profesionales para GloboFleet Mobile

public enum ActivityType: Int, Codable {
    case breakOrRest = 0
    case availability = 1
    case work = 2
    case driving = 3
    case unknown = 9
}

public struct Driver: Identifiable, Codable {
    public let id: String // Card Number
    public let firstName: String
    public let lastName: String
    public let expiryDate: Date?
}

public struct VehicleUsageRecord: Identifiable, Codable {
    public var id = UUID()
    public let plate: String
    public let start: Date
    public let end: Date
    public let initialOdometer: Int
    public let finalOdometer: Int
    
    public var distance: Int {
        return max(0, finalOdometer - initialOdometer)
    }
    public var duration: TimeInterval {
        return end.timeIntervalSince(start)
    }
}

public struct DriverActivity: Identifiable, Codable {
    public var id = UUID()
    public let type: ActivityType
    public let start: Date
    public let duration: TimeInterval
    public let isSlotInserted: Bool
    public var vehiclePlate: String? = nil
    public var distance: Double? = nil
    
    public var end: Date {
        return start.addingTimeInterval(duration)
    }
}

public struct TachoFile: Identifiable, Codable {
    public var id = UUID()
    public let fileName: String
    public let importDate: Date
    public let driverId: String
    public let rawData: Data
}

/// Resultado de análisis profesional
public struct AnalysisResults: Codable {
    public let infringements: [Infringement]
    public let summary: DailySummary
    public let shifts: [TachoShift]
}

public struct TachoShift: Identifiable, Codable {
    public var id = UUID()
    public let start: Date
    public let end: Date
    public var drivingTime: TimeInterval = 0
    public var workTime: TimeInterval = 0
    public var restTime: TimeInterval = 0
    public var availabilityTime: TimeInterval = 0
    public var distance: Double = 0
}

public struct DailySummary: Codable {
    public let date: Date
    public let totalDriving: TimeInterval
    public let totalWork: TimeInterval
    public let totalRest: TimeInterval
}

public struct Infringement: Identifiable, Codable {
    public var id = UUID()
    public let title: String
    public let description: String
    public let severity: Severity
    public let article: String
    public let timestamp: Date
    public let vehiclePlate: String?
    
    public enum Severity: String, Codable {
        case minor = "Leve"
        case serious = "Grave"
        case verySerious = "Muy Grave"
    }
}

public struct TachoEvent: Identifiable, Codable {
    public var id = UUID()
    public let type: String
    public let start: Date
    public let end: Date
    public let vehiclePlate: String?
}

/// Información de Planificación proactiva estilo GloboFleet Pro
public struct PlanningInfo: Codable {
    public var remainingDailyDriving: TimeInterval = 0
    public var remainingContinuousDriving: TimeInterval = 0 // "Tiempo de conducir sin interrupción"
    public var nextMandatoryBreak: Date?
    public var nextDailyRestDue: Date?

    public var weeklyDrivingTotal: TimeInterval = 0 // "Tiempo de conducir semanal"
    public var weeklyWorkTotal: TimeInterval = 0 // "Tiempo de trabajo semanal"
    public var biweeklyDrivingTotal: TimeInterval = 0 // "Tiempo de conducir por 2 semanas"

    public var dailyDrivingTotal: TimeInterval = 0 // "Tiempo diario de conducción"

    // Optional variables that the engine will calculate based on approximation
    public var dailyRestNeededAt: Date? // "Tiempo hasta el siguiente periodo de descanso diario"
    public var weeklyRestNeededAt: Date? // "Tiempo hasta el siguiente descanso por semana"
    
    // Limits (Permitted values)
    public var limitContinuousDriving: TimeInterval = 4.5 * 3600 // 4h 30m
    public var limitDailyDriving: TimeInterval = 9.0 * 3600 // 9h (can be extended to 10h twice a week)
    public var limitWeeklyDriving: TimeInterval = 56.0 * 3600 // 56h
    public var limitBiweeklyDriving: TimeInterval = 90.0 * 3600 // 90h
    public var limitWeeklyWork: TimeInterval = 60.0 * 3600 // 60h

    public var nextDownloadDue: Date?
}

/// Registro de entrada/salida de un país (Países tab)
public struct CountryRecord: Identifiable, Codable {
    public var id = UUID()
    public let weekNumber: Int
    public let date: Date
    public let country: String
    public let region: String
    public let odometer: Int
    public let mode: String // "Inicio" o "Final"
}

/// Bloque de contenido del archivo TGD (Contenido del archivo tab) 
public struct FileContentBlock: Identifiable {
    public var id = UUID()
    public let name: String
    public let status: String // "disponible", "válido", "no disponible"
    public let isSignature: Bool
}
