import SwiftUI

struct ContentView: View {
    @StateObject var readerVM = ReaderViewModel()
    
    init() {
        // Configuración de apariencia de la TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "#1A2B47")
        
        // Color de iconos no seleccionados
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        
        // Color de iconos seleccionados
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        TabView {
            ReaderView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Dashboard", systemImage: "speedometer")
                }
            
            SummaryView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Actividad", systemImage: "chart.bar")
                }
            
            CalendarView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Calendario", systemImage: "calendar")
                }
            
            ArchiveView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Archivos", systemImage: "archivebox.fill")
                }
            
            InaccuraciesView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Faltas", systemImage: "exclamationmark.triangle")
                }
                
            VehiclesView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Vehículos", systemImage: "car.fill")
                }
            
            EventsView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Eventos", systemImage: "bolt.badge.a.fill")
                }
            
            NavigationView {
                PlanningView()
                    .environmentObject(readerVM)
            }
            .tabItem {
                Label("Pronóstico", systemImage: "timer")
            }
            
            CountriesView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Países", systemImage: "globe.europe.africa")
                }
            
            FileContentView()
                .environmentObject(readerVM)
                .tabItem {
                    Label("Archivo", systemImage: "doc.text")
                }
        }
        .accentColor(.white)
    }
}
