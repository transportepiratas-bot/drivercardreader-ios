import Foundation

/// Localización al español extraída y adaptada de la APK original de Lobol Team
struct L10n {
    
    // Títulos de Pantallas
    static let app_name = "Driver Card Reader"
    static let main_dashboard = "Panel"
    static let main_reader = "Lector de Tarjeta"
    static let main_archive = "Historial"
    static let main_settings = "Ajustes"
    
    // Dashboard y Alertas de 28 Días
    static let next_reading_in = "PRÓXIMA LECTURA"
    static let days_unit = "DÍAS"
    static let deadline_warning = "Recuerde leer la tarjeta antes del %@"
    static let status_all_right = "Todo está correcto"
    
    // Lector (Reader)
    static let reader_status_disconnected = "Desconectado"
    static let reader_status_reading = "Leyendo datos de la tarjeta..."
    static let reader_status_success = "Lectura completada con éxito"
    static let reader_status_error = "Error al leer la tarjeta"
    static let reader_instruction = "Conecte su lector de tarjetas USB-C o Lightning"
    static let btn_start_reading = "INICIAR LECTURA"
    static let btn_cancel_reading = "CANCELAR LECTURA"
    
    // Actividades y Tiempos
    static let activity_driving = "Conducción"
    static let activity_rest = "Descanso"
    static let activity_work = "Trabajo"
    static let activity_availability = "Disponibilidad"
    
    // Normativa Europea (Reglamento 561/2006)
    struct Regulations {
        static let article_7_title = "Reglamento (CE) no 561/2006 - Artículo 7"
        static let article_7_desc = "Tras un período de conducción de cuatro horas y media, el conductor hará una pausa ininterrumpida de al menos 45 minutos."
        static let country_code_warning = "El conductor introducirá en el tacógrafo digital el símbolo de los países en que comience y termine su período de trabajo diario."
    }
    
    // Menú de Ajustes
    static let settings_general = "General"
    static let settings_reminders = "Recordatorios"
    static let settings_company = "Datos de Empresa"
    static let settings_about = "Acerca de la Aplicación"
}
