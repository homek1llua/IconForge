import SwiftUI

@main
struct IconForgeApp: App {
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(homeViewModel)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var homeVM: HomeViewModel
    
    var body: some View {
        TabView {
            HomeView()
                .environmentObject(homeVM)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            AppsListView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }
            
            PacksListView()
                .tabItem {
                    Label("Packs", systemImage: "tray.full")
                }
            
            RestoreView()
                .tabItem {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.purple)
    }
}
