//
//  CheckInApp.swift
//  CheckIn
//
//  Created by 徐乙巽 on 2024/12/18.
//

import SwiftUI

@main
struct CheckInApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(.automatic)
        .commands {
            SidebarCommands()
            CommandGroup(after: .newItem) {
                Button("新建签到窗口") {
                    openNewWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        
        WindowGroup("签到详情") {
            CheckInDetailWindow()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(.automatic)
    }
    
    private func openNewWindow() {
        let url = URL(string: "checkin://new")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct CheckInDetailWindow: View {
    var body: some View {
        NavigationView {
            Text("请从主窗口选择签到记录")
                .navigationTitle("签到详情")
        }
    }
}
