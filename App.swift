import SwiftUI

@main
struct DriverCardReaderApp: App {
    @StateObject private var readerVM = ReaderViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(readerVM)
        }
    }
}
