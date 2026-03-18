import SwiftUI

struct PlanningView: View {
    @EnvironmentObject var readerVM: ReaderViewModel
    
    var body: some View {
        ZStack {
            Color.globoBlue.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Detallado
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        nextMilestoneCard
                        
                        let info = readerVM.planningInfo
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CONDUCCIÓN")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 4)
                            
                            TachoProgressBar(
                                title: "Conducción Ininterrumpida",
                                regulation: "Art 7. Reg (CE) 561/2006",
                                measured: info.remainingContinuousDriving,
                                permitted: info.limitContinuousDriving,
                                remaining: max(0, info.limitContinuousDriving - info.remainingContinuousDriving)
                            )
                            
                            TachoProgressBar(
                                title: "Conducción Diaria",
                                regulation: "Art 6.1 Reg (CE) 561/2006",
                                measured: info.dailyDrivingTotal,
                                permitted: info.limitDailyDriving,
                                remaining: info.remainingDailyDriving
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TRABAJO Y SEMANAL")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 4)
                                
                            TachoProgressBar(
                                title: "Conducción Semanal",
                                regulation: "Art 6.2 Reg (CE) 561/2006",
                                measured: info.weeklyDrivingTotal,
                                permitted: info.limitWeeklyDriving,
                                remaining: max(0, info.limitWeeklyDriving - info.weeklyDrivingTotal)
                            )
                            
                            TachoProgressBar(
                                title: "Conducción Bisemanal",
                                regulation: "Art 6.3 Reg (CE) 561/2006",
                                measured: info.biweeklyDrivingTotal,
                                permitted: info.limitBiweeklyDriving,
                                remaining: max(0, info.limitBiweeklyDriving - info.biweeklyDrivingTotal)
                            )
                            
                            TachoProgressBar(
                                title: "Trabajo Semanal Total",
                                regulation: "Dir. 2002/15/CE",
                                measured: info.weeklyWorkTotal,
                                permitted: info.limitWeeklyWork,
                                remaining: max(0, info.limitWeeklyWork - info.weeklyWorkTotal)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("PRONÓSTICO")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estado Legal")
                    .font(.subheadline)
                    .foregroundColor(.globoAccent)
                Text("Cálculo según 561/2006")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            if let nextDownload = readerVM.planningInfo.nextDownloadDue {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("PRÓXIMA DESCARGA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Text(nextDownload.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
    
    private var nextMilestoneCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.globoAccent)
                Text("SIGUIENTE DESCANSO NECESARIO")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            
            if let restTime = readerVM.planningInfo.dailyRestNeededAt {
                HStack(alignment: .firstTextBaseline) {
                    let timeRemaining = restTime.timeIntervalSinceNow
                    if timeRemaining > 0 {
                        Text(formatTimeRemaining(timeRemaining))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("restantes")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("DESCANSAR YA")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                
                Text("Debes iniciar un descanso antes de las \(restTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Text("--:--")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%02dh %02dm", h, m)
    }
}
