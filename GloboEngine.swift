import Foundation

/// Motor de Reglas GloboFleet - Reglamento 561/2006
class GloboFleetEngine {
    
    static func analyze(activities: [DriverActivity]) -> AnalysisResults {
        let sorted = activities.sorted { $0.start < $1.start }
        
        let infringements = checkInfringements(activities: sorted)
        let shifts = calculateShifts(activities: sorted)
        
        // Mock summary for now (needs more work for daily aggregation)
        let summary = DailySummary(date: Date(), totalDriving: 0, totalWork: 0, totalRest: 0)
        
        return AnalysisResults(infringements: infringements, summary: summary, shifts: shifts)
    }
    
    private static func checkInfringements(activities: [DriverActivity]) -> [Infringement] {
        var results: [Infringement] = []
        results.append(contentsOf: checkContinuousDriving(activities))
        results.append(contentsOf: checkDailyDriving(activities))
        results.append(contentsOf: checkWorkingTime(activities))
        return results
    }
    
    private static func checkWorkingTime(_ activities: [DriverActivity]) -> [Infringement] {
        var violations: [Infringement] = []
        let calendar = Calendar.current
        
        // Agrupar por semanas ISO
        let groups = Dictionary(grouping: activities) { activity in
            calendar.component(.weekOfYear, from: activity.start)
        }
        
        for (week, weekActs) in groups {
            let workTime = weekActs.filter { $0.type == .driving || $0.type == .work }.reduce(0) { $0 + $1.duration }
            if workTime > 216000 { // 60 horas = 216000s
                violations.append(Infringement(
                    title: "Exceso Trabajo Semanal (WTD)",
                    description: "Se han superado las 60h de trabajo semanal en la semana \(week) (\(Int(workTime/3600))h).",
                    severity: .serious,
                    article: "Dir. 2002/15/CE",
                    timestamp: weekActs.first?.start ?? Date(),
                    vehiclePlate: nil // Weekly work doesn't belong to a single vehicle
                ))
            }
        }
        return violations
    }
    
    private static func checkContinuousDriving(_ activities: [DriverActivity]) -> [Infringement] {
        var violations: [Infringement] = []
        var drivingBuffer: TimeInterval = 0
        var breakPart1: Bool = false
        
        for activity in activities {
            if activity.type == .driving {
                drivingBuffer += activity.duration
                
                if drivingBuffer > 16200 { // > 4h 30m
                    let excessMin = Int((drivingBuffer - 16200) / 60)
                    violations.append(Infringement(
                        title: "Exceso Conducción Ininterrumpida",
                        description: "Más de 4h 30m de conducción sin pausa reglamentaria (\(Int(drivingBuffer/3600))h \(Int(drivingBuffer.truncatingRemainder(dividingBy: 3600)/60))m). Exceso: \(excessMin) min.",
                        severity: excessMin > 30 ? .verySerious : .serious,
                        article: "Art. 7 Reg. 561/2006",
                        timestamp: activity.start,
                        vehiclePlate: activity.vehiclePlate
                    ))
                    drivingBuffer = 0 
                    breakPart1 = false
                }
            } else if activity.type == .breakOrRest || activity.type == .availability {
                if activity.duration >= 2700 { // Pausa de 45m completa (o descanso diario/semanal)
                    drivingBuffer = 0
                    breakPart1 = false
                } else if !breakPart1 && activity.duration >= 900 { // Primera parte de 15m
                    breakPart1 = true
                } else if breakPart1 && activity.duration >= 1800 { // Segunda parte de 30m
                    drivingBuffer = 0
                    breakPart1 = false
                }
            }
        }
        return violations
    }
    
    private static func checkDailyDriving(_ activities: [DriverActivity]) -> [Infringement] {
        var violations: [Infringement] = []
        let calendar = Calendar.current
        
        let groups = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.start)
        }
        
        for (date, dailyActs) in groups {
            let totalDriving = dailyActs.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration }
            
            if totalDriving > 32400 { // 9 horas
                let excessMin = Int((totalDriving - 32400) / 60)
                violations.append(Infringement(
                    title: "Exceso Conducción Diaria",
                    description: "Conducción diaria superior a 9h (\(Int(totalDriving/3600))h \(Int(totalDriving.truncatingRemainder(dividingBy: 3600)/60))m). Exceso: \(excessMin) min.",
                    severity: totalDriving > 36000 ? .verySerious : .minor, // >10h es Muy Grave en algunos contextos
                    article: "Art. 6.1 Reg. 561/2006",
                    timestamp: date,
                    vehiclePlate: dailyActs.first(where: { $0.type == .driving })?.vehiclePlate
                ))
            }
        }
        return violations
    }
    
    static func calculatePlanning(activities: [DriverActivity]) -> PlanningInfo {
        var info = PlanningInfo()
        let sorted = activities.sorted { $0.start < $1.start }
        let now = Date()
        
        // 1. Conducción Continua (Regla 4h 30m)
        var currentDrivingBuffer: TimeInterval = 0
        var found30 = false
        var found15Before30 = false
        
        for act in sorted.reversed() {
            if act.type == .driving {
                currentDrivingBuffer += act.duration
            } else if act.type == .breakOrRest || act.type == .availability {
                if act.duration >= 2700 { // 45 min
                    break
                } else if !found30 && act.duration >= 1800 { // 30 min
                    found30 = true
                } else if found30 && !found15Before30 && act.duration >= 900 { // 15 min antes de los 30
                    found15Before30 = true
                    break
                }
            }
        }
        
        info.remainingContinuousDriving = currentDrivingBuffer
        info.nextMandatoryBreak = now.addingTimeInterval(max(0, 16200 - currentDrivingBuffer))
        
        // 2. Conducción Diaria Restante (Hoy)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayActs = sorted.filter { calendar.startOfDay(for: $0.start) == today }
        let drivingToday = todayActs.filter { $0.type == .driving }.reduce(0) { $0 + $1.duration }
        info.dailyDrivingTotal = drivingToday
        info.remainingDailyDriving = max(0, 32400 - drivingToday) // 9h limit
        
        // 3. Totales Semanales y Bisemanales
        // Calculate start of current week (Monday)
        var comp = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comp.weekday = 2 // Monday
        let startOfWeek = calendar.date(from: comp) ?? now.addingTimeInterval(-7 * 24 * 3600)
        
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfWeek) ?? now.addingTimeInterval(-14 * 24 * 3600)

        info.weeklyDrivingTotal = sorted.filter { $0.start >= startOfWeek && $0.type == .driving }.reduce(0) { $0 + $1.duration }
        info.weeklyWorkTotal = sorted.filter { $0.start >= startOfWeek && ($0.type == .driving || $0.type == .work) }.reduce(0) { $0 + $1.duration }
        
        info.biweeklyDrivingTotal = sorted.filter { $0.start >= startOfLastWeek && $0.type == .driving }.reduce(0) { $0 + $1.duration }
        
        // 5. Próximo Descanso Diario (15h límite desde inicio jornada)
        var shiftStart = today
        for act in sorted.reversed() {
            if act.type == .breakOrRest && act.duration >= 32400 {
                shiftStart = act.end
                break
            }
        }
        info.dailyRestNeededAt = shiftStart.addingTimeInterval(15 * 3600)
        
        // 6. Próximo Descanso Semanal (Max 144h desde fin de descanso semanal anterior)
        var lastWeeklyRestEnd = calendar.date(byAdding: .day, value: -6, to: now)!
        for act in sorted.reversed() {
            if act.type == .breakOrRest && act.duration >= 90000 { // 25h+ (descanso semanal)
                lastWeeklyRestEnd = act.end
                break
            }
        }
        info.weeklyRestNeededAt = lastWeeklyRestEnd.addingTimeInterval(144 * 3600)

        // 6. Próxima Descarga Obligatoria (Regla 28 días para tarjeta)
        if let lastAct = sorted.last {
            info.nextDownloadDue = calendar.date(byAdding: .day, value: 28, to: lastAct.end)
        }
        
        return info
    }
    static func calculateShifts(activities: [DriverActivity]) -> [TachoShift] {
        var shifts: [TachoShift] = []
        guard !activities.isEmpty else { return [] }
        
        var currentShiftActivities: [DriverActivity] = []
        
        for activity in activities {
            // Un descanso de >= 9h marca el fin de la jornada según Reg. 561/2006
            if activity.type == .breakOrRest && activity.duration >= 32400 { // 9 horas
                if !currentShiftActivities.isEmpty {
                    shifts.append(createShift(from: currentShiftActivities))
                    currentShiftActivities = []
                }
            } else {
                currentShiftActivities.append(activity)
            }
        }
        
        if !currentShiftActivities.isEmpty {
            shifts.append(createShift(from: currentShiftActivities))
        }
        
        return shifts.reversed() // Más reciente primero
    }
    
    private static func createShift(from activities: [DriverActivity]) -> TachoShift {
        let start = activities.first!.start
        let end = activities.last!.end
        
        var shift = TachoShift(start: start, end: end)
        for act in activities {
            switch act.type {
            case .driving: shift.drivingTime += act.duration
            case .work: shift.workTime += act.duration
            case .breakOrRest: shift.restTime += act.duration
            case .availability: shift.availabilityTime += act.duration
            case .unknown: break
            }
            shift.distance += act.distance ?? 0
        }
        return shift
    }
}
