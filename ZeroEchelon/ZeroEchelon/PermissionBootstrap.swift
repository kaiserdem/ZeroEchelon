import AVFoundation
import CoreLocation
import Foundation
import Speech
import UserNotifications

/// Asks for runtime permissions once at launch (notifications, location, speech, microphone).
@MainActor
enum PermissionBootstrap {
    private static var didRun = false

    static func requestAllOnLaunch() async {
        guard !didRun else { return }
        didRun = true

        await requestNotifications()
        await requestLocationWhenInUse()
        await requestSpeechRecognition()
        await requestMicrophone()
    }

    private static func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func requestLocationWhenInUse() async {
        let manager = LocationPermissionProbe.shared
        await manager.requestWhenInUseIfNeeded()
    }

    private static func requestSpeechRecognition() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .notDetermined else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                cont.resume()
            }
        }
    }

    private static func requestMicrophone() async {
        if #available(iOS 17.0, *) {
            _ = await AVAudioApplication.requestRecordPermission()
            return
        }
        let session = AVAudioSession.sharedInstance()
        // On older iOS, `.undetermined` is the only state that shows a prompt.
        guard session.recordPermission == .undetermined else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.requestRecordPermission { _ in
                cont.resume()
            }
        }
    }
}

/// Tiny CLLocationManager owner — permission prompt only (coordinates still filled by protocol later).
@MainActor
private final class LocationPermissionProbe: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionProbe()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseIfNeeded() async {
        switch manager.authorizationStatus {
        case .notDetermined:
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                continuation = cont
                manager.requestWhenInUseAuthorization()
            }
        default:
            return
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            guard status != .notDetermined else { return }
            continuation?.resume()
            continuation = nil
        }
    }
}
