import Foundation
import CoreLocation

public struct GeoPreset: Equatable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    
    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

public final class GeoSpoofManager {
    public static let shared = GeoSpoofManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let isEnabled = "TGExtraFakeLocation"
        static let latitude = "TGExtraSavedLatitude"
        static let longitude = "TGExtraSavedLongitude"
        static let presetName = "Burmalgram.GeoSpoofPreset"
    }
    
    public static let defaultPresets: [GeoPreset] = [
        GeoPreset(name: "Москва", latitude: 55.7558, longitude: 37.6173),
        GeoPreset(name: "Санкт-Петербург", latitude: 59.9343, longitude: 30.3351),
        GeoPreset(name: "Лондон", latitude: 51.5074, longitude: -0.1278),
        GeoPreset(name: "Нью-Йорк", latitude: 40.7128, longitude: -74.0060),
        GeoPreset(name: "Токио", latitude: 35.6762, longitude: 139.6503),
        GeoPreset(name: "Дубай", latitude: 25.2048, longitude: 55.2708),
        GeoPreset(name: "Париж", latitude: 48.8566, longitude: 2.3522),
    ]
    
    public var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
            notifyChanged()
        }
    }
    
    public var latitude: Double {
        get {
            let val = defaults.double(forKey: Keys.latitude)
            return val == 0.0 ? 55.7558 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.latitude)
            notifyChanged()
        }
    }
    
    public var longitude: Double {
        get {
            let val = defaults.double(forKey: Keys.longitude)
            return val == 0.0 ? 37.6173 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.longitude)
            notifyChanged()
        }
    }
    
    public var presetName: String {
        get { defaults.string(forKey: Keys.presetName) ?? "Москва" }
        set {
            defaults.set(newValue, forKey: Keys.presetName)
            notifyChanged()
        }
    }
    
    public func setPreset(_ preset: GeoPreset) {
        presetName = preset.name
        latitude = preset.latitude
        longitude = preset.longitude
    }
    
    public static let settingsChangedNotification = Notification.Name("GeoSpoofSettingsChanged")
    
    private func notifyChanged() {
        NotificationCenter.default.post(name: GeoSpoofManager.settingsChangedNotification, object: nil)
    }
    
    private init() {
        if defaults.object(forKey: Keys.isEnabled) == nil {
            defaults.set(false, forKey: Keys.isEnabled)
            defaults.set(55.7558, forKey: Keys.latitude)
            defaults.set(37.6173, forKey: Keys.longitude)
            defaults.set("Москва", forKey: Keys.presetName)
        }
    }
}
