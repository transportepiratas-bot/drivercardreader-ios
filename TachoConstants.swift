import Foundation

/// Constantes técnicas según el estándar ISO 7816-4 y el Reglamento (UE) 165/2014
struct TachoConstants {
    /// Application Identifier (AID) del tacógrafo digital
    /// "FF 54 41 43 48 4F" -> " TACHO"
    static let tachographAID = Data([0xFF, 0x54, 0x41, 0x43, 0x48, 0x4F])
    
    /// Elementary Files (EF) IDs
    static let ef_Identification: UInt16 = 0x0520
    static let ef_Card_Certificate: UInt16 = 0x0002
    static let ef_CA_Certificate: UInt16 = 0x0001
    static let ef_Activity_Data: UInt16 = 0x0504
    static let ef_Vehicles_Used: UInt16 = 0x0505
    static let ef_Places: UInt16 = 0x0506
    static let ef_Current_Usage: UInt16 = 0x0507
    static let ef_Control_Activity: UInt16 = 0x0508
}
