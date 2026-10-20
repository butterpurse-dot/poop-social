import Foundation
import CoreLocation
import Combine

/// Small, focused location wrapper. Only ever asks for "when in use".
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var hasRequested = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    func request() {
        guard status == .notDetermined, !hasRequested else { return }
        hasRequested = true
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        coordinate = last.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — the map falls back to the city default.
    }
}
