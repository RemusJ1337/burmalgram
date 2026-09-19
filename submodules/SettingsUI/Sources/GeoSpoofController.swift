import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

// MARK: - Entry Definition

private enum GeoSpoofSection: Int32 {
    case enable
    case presets
    case custom
}

private enum GeoSpoofEntry: ItemListNodeEntry {
    case enableHeader(PresentationTheme, String)
    case enableToggle(PresentationTheme, String, Bool)
    case enableInfo(PresentationTheme, String)
    case presetsHeader(PresentationTheme, String)
    case preset(PresentationTheme, String, Double, Double, Bool)
    case customHeader(PresentationTheme, String)
    case customLatitude(PresentationTheme, String, String)
    case customLongitude(PresentationTheme, String, String)
    case customInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .enableHeader, .enableToggle, .enableInfo:
            return GeoSpoofSection.enable.rawValue
        case .presetsHeader, .preset:
            return GeoSpoofSection.presets.rawValue
        case .customHeader, .customLatitude, .customLongitude, .customInfo:
            return GeoSpoofSection.custom.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .enableHeader: return 0
        case .enableToggle: return 1
        case .enableInfo: return 2
        case .presetsHeader: return 3
        case let .preset(_, name, _, _, _): return 10 + Int32(abs(name.hashValue % 1000))
        case .customHeader: return 2000
        case .customLatitude: return 2001
        case .customLongitude: return 2002
        case .customInfo: return 2003
        }
    }
    
    static func ==(lhs: GeoSpoofEntry, rhs: GeoSpoofEntry) -> Bool {
        switch lhs {
        case let .enableHeader(lhsTheme, lhsText):
            if case let .enableHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .enableToggle(lhsTheme, lhsText, lhsValue):
            if case let .enableToggle(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .enableInfo(lhsTheme, lhsText):
            if case let .enableInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .presetsHeader(lhsTheme, lhsText):
            if case let .presetsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .preset(lhsTheme, lhsName, lhsLat, lhsLon, lhsSelected):
            if case let .preset(rhsTheme, rhsName, rhsLat, rhsLon, rhsSelected) = rhs,
               lhsTheme === rhsTheme, lhsName == rhsName, lhsLat == rhsLat, lhsLon == rhsLon, lhsSelected == rhsSelected {
                return true
            }
            return false
        case let .customHeader(lhsTheme, lhsText):
            if case let .customHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .customLatitude(lhsTheme, lhsTitle, lhsValue):
            if case let .customLatitude(rhsTheme, rhsTitle, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                return true
            }
            return false
        case let .customLongitude(lhsTheme, lhsTitle, lhsValue):
            if case let .customLongitude(rhsTheme, rhsTitle, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue {
                return true
            }
            return false
        case let .customInfo(lhsTheme, lhsText):
            if case let .customInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: GeoSpoofEntry, rhs: GeoSpoofEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GeoSpoofControllerArguments
        switch self {
        case let .enableHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .enableToggle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleEnabled(value)
            })
        case let .enableInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .presetsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .preset(_, name, lat, lon, selected):
            let subtitle = String(format: "%.4f, %.4f", lat, lon)
            return ItemListCheckboxItem(presentationData: presentationData, title: "\(name) (\(subtitle))", style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectPreset(name, lat, lon)
            })
        case let .customHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .customLatitude(_, title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title), text: value, placeholder: "55.7558", sectionId: self.section, textUpdated: { text in
                arguments.updateLatitude(text)
            }, action: {})
        case let .customLongitude(_, title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title), text: value, placeholder: "37.6173", sectionId: self.section, textUpdated: { text in
                arguments.updateLongitude(text)
            }, action: {})
        case let .customInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// MARK: - Arguments

private final class GeoSpoofControllerArguments {
    let toggleEnabled: (Bool) -> Void
    let selectPreset: (String, Double, Double) -> Void
    let updateLatitude: (String) -> Void
    let updateLongitude: (String) -> Void
    
    init(
        toggleEnabled: @escaping (Bool) -> Void,
        selectPreset: @escaping (String, Double, Double) -> Void,
        updateLatitude: @escaping (String) -> Void,
        updateLongitude: @escaping (String) -> Void
    ) {
        self.toggleEnabled = toggleEnabled
        self.selectPreset = selectPreset
        self.updateLatitude = updateLatitude
        self.updateLongitude = updateLongitude
    }
}

// MARK: - State

private struct GeoSpoofControllerState: Equatable {
    var isEnabled: Bool
    var currentPresetName: String
    var latitude: Double
    var longitude: Double
}

// MARK: - Entries Builder

private func geoSpoofControllerEntries(presentationData: PresentationData, state: GeoSpoofControllerState) -> [GeoSpoofEntry] {
    var entries: [GeoSpoofEntry] = []
    let theme = presentationData.theme
    
    entries.append(.enableHeader(theme, "ФЕЙКОВАЯ ГЕОЛОКАЦИЯ"))
    entries.append(.enableToggle(theme, "Включить подмену геопозиции", state.isEnabled))
    entries.append(.enableInfo(theme, "Подменяет данные GPS при отправке геопозиции, трансляции локации и поиске людей рядом (TGExtra & Swiftgram)."))
    
    entries.append(.presetsHeader(theme, "ГОРОДА И ПРЕСЕТЫ"))
    for preset in GeoSpoofManager.defaultPresets {
        let isSelected = (state.currentPresetName == preset.name) ||
            (abs(state.latitude - preset.latitude) < 0.001 && abs(state.longitude - preset.longitude) < 0.001)
        entries.append(.preset(theme, preset.name, preset.latitude, preset.longitude, isSelected))
    }
    
    entries.append(.customHeader(theme, "ТОЧНЫЕ КООРДИНАТЫ"))
    entries.append(.customLatitude(theme, "Широта (Lat): ", String(format: "%.5f", state.latitude)))
    entries.append(.customLongitude(theme, "Долгота (Lon): ", String(format: "%.5f", state.longitude)))
    entries.append(.customInfo(theme, "Укажите собственные координаты в десятичном формате. Изменения сохраняются и применяются мгновенно."))
    
    return entries
}

// MARK: - Controller Factory

public func geoSpoofController(context: AccountContext) -> ViewController {
    let manager = GeoSpoofManager.shared
    
    let initialState = GeoSpoofControllerState(
        isEnabled: manager.isEnabled,
        currentPresetName: manager.presetName,
        latitude: manager.latitude,
        longitude: manager.longitude
    )
    
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    let updateState: ((inout GeoSpoofControllerState) -> Void) -> Void = { modifier in
        let _ = stateValue.modify { state in
            var updated = state
            modifier(&updated)
            statePromise.set(updated)
            return updated
        }
    }
    
    let arguments = GeoSpoofControllerArguments(
        toggleEnabled: { enabled in
            manager.isEnabled = enabled
            updateState { state in
                state.isEnabled = enabled
            }
        },
        selectPreset: { name, lat, lon in
            manager.setPreset(GeoPreset(name: name, latitude: lat, longitude: lon))
            updateState { state in
                state.currentPresetName = name
                state.latitude = lat
                state.longitude = lon
            }
        },
        updateLatitude: { text in
            if let val = Double(text.replacingOccurrences(of: ",", with: ".")) {
                manager.latitude = val
                manager.presetName = "Пользовательские"
                updateState { state in
                    state.latitude = val
                    state.currentPresetName = "Пользовательские"
                }
            }
        },
        updateLongitude: { text in
            if let val = Double(text.replacingOccurrences(of: ",", with: ".")) {
                manager.longitude = val
                manager.presetName = "Пользовательские"
                updateState { state in
                    state.longitude = val
                    state.currentPresetName = "Пользовательские"
                }
            }
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, GeoSpoofControllerArguments)) in
        let entries = geoSpoofControllerEntries(presentationData: presentationData, state: state)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Геолокация"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.didAppear = { _ in
        let latest = GeoSpoofControllerState(
            isEnabled: manager.isEnabled,
            currentPresetName: manager.presetName,
            latitude: manager.latitude,
            longitude: manager.longitude
        )
        let _ = stateValue.modify { _ in latest }
        statePromise.set(latest)
    }
    
    return controller
}
