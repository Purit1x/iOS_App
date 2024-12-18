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
    }
}
