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
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .ignoresSafeArea(.all)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建窗口") {
                    let userActivity = NSUserActivity(activityType: "com.purit1x.CheckIn.newWindow")
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}

// 应用程序委托
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
