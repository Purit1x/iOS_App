import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // 配置窗口场景
        configureWindowScene(windowScene)
        
        // 创建并配置窗口
        let window = createWindow(with: windowScene)
        self.window = window
        window.makeKeyAndVisible()
    }
    
    private func configureWindowScene(_ windowScene: UIWindowScene) {
        // 设置窗口标题
        windowScene.title = "签到记录"
        
        // 配置窗口行为
        if windowScene.session.role == .windowApplication {
            // 设置窗口支持全屏
            if let sizeRestrictions = windowScene.sizeRestrictions {
                sizeRestrictions.allowsFullScreen = true
            }
        }
    }
    
    private func createWindow(with windowScene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: windowScene)
        
        // 创建内容视图
        let contentView = ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        // 配置视图控制器
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .systemBackground
        
        // 设置视图控制器属性
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }
        
        // 配置窗口属性
        window.rootViewController = hostingController
        window.backgroundColor = .systemBackground
        
        // 设置窗口frame为全屏
        window.frame = UIScreen.main.bounds
        
        return window
    }
    
    // 支持通过用户活动创建新窗口
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == "com.purit1x.CheckIn.newWindow" {
            guard let windowScene = scene as? UIWindowScene else { return }
            
            // 配置新窗口场景
            configureWindowScene(windowScene)
            
            // 创建并配置窗口
            let window = createWindow(with: windowScene)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    // 处理场景断开连接
    func sceneDidDisconnect(_ scene: UIScene) {
        // 清理资源
    }
    
    // 场景进入前台
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 恢复状态
    }
    
    // 场景进入后台
    func sceneWillResignActive(_ scene: UIScene) {
        // 保存状态
    }
    
    // 支持状态恢复
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return nil
    }
} 