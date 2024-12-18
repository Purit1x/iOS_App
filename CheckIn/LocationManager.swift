import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // 降低精度要求
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            if manager.authorizationStatus == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            if let location = locations.first {
                self.location = location
                
                // 获取地点名称
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                    DispatchQueue.main.async {
                        self?.placemark = placemarks?.first
                    }
                }
                
                // 获取到位置后停止更新
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    // 手动刷新位置
    func refreshLocation() {
        locationManager.startUpdatingLocation()
    }
} 