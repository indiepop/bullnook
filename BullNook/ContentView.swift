//
//  ContentView.swift
//  BullNook
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DailyPickView()
                .tabItem {
                    Label("每日推荐", systemImage: "flame")
                }

            WatchlistView()
                .tabItem {
                    Label("自选股", systemImage: "star")
                }

            HistoricalPicksView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .accentColor(Color.appAccentGold)
    }
}

#Preview {
    ContentView()
}
