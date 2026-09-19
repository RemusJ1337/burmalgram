import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SGSimpleSettings
import SGSettingsUI

// MARK: - Dismissable Nav for TGExtra

private final class DismissableNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        if let firstVc = viewControllers.first, firstVc.navigationItem.leftBarButtonItem == nil {
            firstVc.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Закрыть",
                style: .done,
                target: self,
                action: #selector(dismissSelf)
            )
        }
    }
    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Entry Definition

private enum BurmalgramSettingsSection: Int32 {
    case main
    case privacy
    case chat
    case spoofing
    case info
}

private enum BurmalgramSettingsEntry: ItemListNodeEntry {
    // Section headers
    case headerMain(PresentationTheme, String)
    case headerPrivacy(PresentationTheme, String)
    case headerChat(PresentationTheme, String)
    case headerSpoofing(PresentationTheme, String)
    
    // Main
    case fakePremium(PresentationTheme, String, Bool)
    case customPhoneNumber(PresentationTheme, String, String)
    case customFont(PresentationTheme, String, String)
    case tgExtra(PresentationTheme, String, String)
    case swiftgram(PresentationTheme, String, String)
    
    // Privacy & Ghost
    case ghostMode(PresentationTheme, String, String)
    case deletedMessages(PresentationTheme, String, String)
    case hideStories(PresentationTheme, String, Bool)
    case warnOnStoriesOpen(PresentationTheme, String, Bool)
    case confirmCalls(PresentationTheme, String, Bool)
    case bypassCopyProtection(PresentationTheme, String, Bool)
    
    // Chat & UI Tweaks
    case secondsInMessages(PresentationTheme, String, Bool)
    case quickTranslateButton(PresentationTheme, String, Bool)
    case rearCamVideoNotes(PresentationTheme, String, Bool)
    case hideRecordingButton(PresentationTheme, String, Bool)
    case filePickerFix(PresentationTheme, String, Bool)
    case clearFilePickerCache(PresentationTheme, String, String)
    
    // Spoofing & Tools
    case deviceSpoof(PresentationTheme, String, String)
    case geoSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    case pluginIDE(PresentationTheme, String, String)
    
    // Info
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerMain, .fakePremium, .customPhoneNumber, .customFont, .tgExtra, .swiftgram:
            return BurmalgramSettingsSection.main.rawValue
        case .headerPrivacy, .ghostMode, .deletedMessages, .hideStories, .warnOnStoriesOpen, .confirmCalls, .bypassCopyProtection:
            return BurmalgramSettingsSection.privacy.rawValue
        case .headerChat, .secondsInMessages, .quickTranslateButton, .rearCamVideoNotes, .hideRecordingButton, .filePickerFix, .clearFilePickerCache:
            return BurmalgramSettingsSection.chat.rawValue
        case .headerSpoofing, .deviceSpoof, .geoSpoof, .voiceMorpher, .sendDelay, .pluginIDE:
            return BurmalgramSettingsSection.spoofing.rawValue
        case .info:
            return BurmalgramSettingsSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerMain: return 0
        case .fakePremium: return 1
        case .customPhoneNumber: return 2
        case .customFont: return 3
        case .tgExtra: return 4
        case .swiftgram: return 5
            
        case .headerPrivacy: return 10
        case .ghostMode: return 11
        case .deletedMessages: return 12
        case .hideStories: return 13
        case .warnOnStoriesOpen: return 14
        case .confirmCalls: return 15
        case .bypassCopyProtection: return 16
            
        case .headerChat: return 20
        case .secondsInMessages: return 21
        case .quickTranslateButton: return 22
        case .rearCamVideoNotes: return 23
        case .hideRecordingButton: return 24
        case .filePickerFix: return 25
        case .clearFilePickerCache: return 26
            
        case .headerSpoofing: return 30
        case .deviceSpoof: return 31
        case .geoSpoof: return 32
        case .voiceMorpher: return 33
        case .sendDelay: return 34
        case .pluginIDE: return 35
            
        case .info: return 40
        }
    }
    
    static func ==(lhs: BurmalgramSettingsEntry, rhs: BurmalgramSettingsEntry) -> Bool {
        switch lhs {
        case let .headerMain(lhsTheme, lhsText):
            if case let .headerMain(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .headerPrivacy(lhsTheme, lhsText):
            if case let .headerPrivacy(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .headerChat(lhsTheme, lhsText):
            if case let .headerChat(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .headerSpoofing(lhsTheme, lhsText):
            if case let .headerSpoofing(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .fakePremium(lhsTheme, lhsText, lhsValue):
            if case let .fakePremium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .customPhoneNumber(lhsTheme, lhsText, lhsValue):
            if case let .customPhoneNumber(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .customFont(lhsTheme, lhsText, lhsValue):
            if case let .customFont(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .tgExtra(lhsTheme, lhsText, lhsValue):
            if case let .tgExtra(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .swiftgram(lhsTheme, lhsText, lhsValue):
            if case let .swiftgram(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostMode(lhsTheme, lhsText, lhsValue):
            if case let .ghostMode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .deletedMessages(lhsTheme, lhsText, lhsValue):
            if case let .deletedMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideStories(lhsTheme, lhsText, lhsValue):
            if case let .hideStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .warnOnStoriesOpen(lhsTheme, lhsText, lhsValue):
            if case let .warnOnStoriesOpen(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .confirmCalls(lhsTheme, lhsText, lhsValue):
            if case let .confirmCalls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .bypassCopyProtection(lhsTheme, lhsText, lhsValue):
            if case let .bypassCopyProtection(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .secondsInMessages(lhsTheme, lhsText, lhsValue):
            if case let .secondsInMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .quickTranslateButton(lhsTheme, lhsText, lhsValue):
            if case let .quickTranslateButton(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .rearCamVideoNotes(lhsTheme, lhsText, lhsValue):
            if case let .rearCamVideoNotes(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideRecordingButton(lhsTheme, lhsText, lhsValue):
            if case let .hideRecordingButton(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .filePickerFix(lhsTheme, lhsText, lhsValue):
            if case let .filePickerFix(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .clearFilePickerCache(lhsTheme, lhsText, lhsValue):
            if case let .clearFilePickerCache(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .deviceSpoof(lhsTheme, lhsText, lhsValue):
            if case let .deviceSpoof(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .geoSpoof(lhsTheme, lhsText, lhsValue):
            if case let .geoSpoof(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .voiceMorpher(lhsTheme, lhsText, lhsValue):
            if case let .voiceMorpher(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .sendDelay(lhsTheme, lhsText, lhsValue):
            if case let .sendDelay(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pluginIDE(lhsTheme, lhsText, lhsValue):
            if case let .pluginIDE(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramSettingsEntry, rhs: BurmalgramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BurmalgramSettingsControllerArguments
        switch self {
        case let .headerMain(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .headerPrivacy(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .headerChat(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .headerSpoofing(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .fakePremium(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleFakePremium(value)
                }
            )
        case let .customPhoneNumber(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openCustomPhoneNumber()
                }
            )
        case let .customFont(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openCustomFont()
                }
            )
        case let .tgExtra(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openTGExtra()
                }
            )
        case let .swiftgram(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openSwiftgram()
                }
            )
            
        case let .ghostMode(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGhostMode()
                }
            )
        case let .deletedMessages(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openDeletedMessages()
                }
            )
        case let .hideStories(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleHideStories(value)
                }
            )
        case let .warnOnStoriesOpen(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleWarnOnStoriesOpen(value)
                }
            )
        case let .confirmCalls(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleConfirmCalls(value)
                }
            )
        case let .bypassCopyProtection(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleBypassCopyProtection(value)
                }
            )
            
        case let .secondsInMessages(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleSecondsInMessages(value)
                }
            )
        case let .quickTranslateButton(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleQuickTranslateButton(value)
                }
            )
        case let .rearCamVideoNotes(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleRearCamVideoNotes(value)
                }
            )
        case let .hideRecordingButton(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleHideRecordingButton(value)
                }
            )
        case let .filePickerFix(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleFilePickerFix(value)
                }
            )
        case let .clearFilePickerCache(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.clearFilePickerCache()
                }
            )
            
        case let .deviceSpoof(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openDeviceSpoof()
                }
            )
        case let .geoSpoof(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGeoSpoof()
                }
            )
        case let .voiceMorpher(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openVoiceMorpher()
                }
            )
        case let .sendDelay(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openSendDelay()
                }
            )
        case let .pluginIDE(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openPluginIDE()
                }
            )
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// MARK: - Arguments

private final class BurmalgramSettingsControllerArguments {
    let toggleFakePremium: (Bool) -> Void
    let openCustomPhoneNumber: () -> Void
    let openCustomFont: () -> Void
    let openTGExtra: () -> Void
    let openSwiftgram: () -> Void
    let openGhostMode: () -> Void
    let openDeletedMessages: () -> Void
    let toggleHideStories: (Bool) -> Void
    let toggleWarnOnStoriesOpen: (Bool) -> Void
    let toggleConfirmCalls: (Bool) -> Void
    let toggleBypassCopyProtection: (Bool) -> Void
    let toggleSecondsInMessages: (Bool) -> Void
    let toggleQuickTranslateButton: (Bool) -> Void
    let toggleRearCamVideoNotes: (Bool) -> Void
    let toggleHideRecordingButton: (Bool) -> Void
    let toggleFilePickerFix: (Bool) -> Void
    let clearFilePickerCache: () -> Void
    let openDeviceSpoof: () -> Void
    let openGeoSpoof: () -> Void
    let openVoiceMorpher: () -> Void
    let openSendDelay: () -> Void
    let openPluginIDE: () -> Void
    
    init(
        toggleFakePremium: @escaping (Bool) -> Void,
        openCustomPhoneNumber: @escaping () -> Void,
        openCustomFont: @escaping () -> Void,
        openTGExtra: @escaping () -> Void,
        openSwiftgram: @escaping () -> Void,
        openGhostMode: @escaping () -> Void,
        openDeletedMessages: @escaping () -> Void,
        toggleHideStories: @escaping (Bool) -> Void,
        toggleWarnOnStoriesOpen: @escaping (Bool) -> Void,
        toggleConfirmCalls: @escaping (Bool) -> Void,
        toggleBypassCopyProtection: @escaping (Bool) -> Void,
        toggleSecondsInMessages: @escaping (Bool) -> Void,
        toggleQuickTranslateButton: @escaping (Bool) -> Void,
        toggleRearCamVideoNotes: @escaping (Bool) -> Void,
        toggleHideRecordingButton: @escaping (Bool) -> Void,
        toggleFilePickerFix: @escaping (Bool) -> Void,
        clearFilePickerCache: @escaping () -> Void,
        openDeviceSpoof: @escaping () -> Void,
        openGeoSpoof: @escaping () -> Void,
        openVoiceMorpher: @escaping () -> Void,
        openSendDelay: @escaping () -> Void,
        openPluginIDE: @escaping () -> Void
    ) {
        self.toggleFakePremium = toggleFakePremium
        self.openCustomPhoneNumber = openCustomPhoneNumber
        self.openCustomFont = openCustomFont
        self.openTGExtra = openTGExtra
        self.openSwiftgram = openSwiftgram
        self.openGhostMode = openGhostMode
        self.openDeletedMessages = openDeletedMessages
        self.toggleHideStories = toggleHideStories
        self.toggleWarnOnStoriesOpen = toggleWarnOnStoriesOpen
        self.toggleConfirmCalls = toggleConfirmCalls
        self.toggleBypassCopyProtection = toggleBypassCopyProtection
        self.toggleSecondsInMessages = toggleSecondsInMessages
        self.toggleQuickTranslateButton = toggleQuickTranslateButton
        self.toggleRearCamVideoNotes = toggleRearCamVideoNotes
        self.toggleHideRecordingButton = toggleHideRecordingButton
        self.toggleFilePickerFix = toggleFilePickerFix
        self.clearFilePickerCache = clearFilePickerCache
        self.openDeviceSpoof = openDeviceSpoof
        self.openGeoSpoof = openGeoSpoof
        self.openVoiceMorpher = openVoiceMorpher
        self.openSendDelay = openSendDelay
        self.openPluginIDE = openPluginIDE
    }
}

// MARK: - State

private struct BurmalgramSettingsState: Equatable {
    var fakePremium: Bool
    var customFont: String
    var customPhoneNumber: String
    var deletedMessagesEnabled: Bool
    var ghostModeEnabled: Bool
    var ghostModeActiveCount: Int
    var activePluginsCount: Int
    var hideStories: Bool
    var warnOnStoriesOpen: Bool
    var confirmCalls: Bool
    var disableForwardRestriction: Bool
    var secondsInMessages: Bool
    var quickTranslateButton: Bool
    var startTelescopeWithRearCam: Bool
    var hideRecordingButton: Bool
    var fixFilePicker: Bool
    var deviceSpoofEnabled: Bool
    var geoSpoofEnabled: Bool
    var geoSpoofPresetName: String
    var voiceMorpherEnabled: Bool
    var voiceMorpherPresetName: String
    var sendDelayEnabled: Bool
    
    static func current() -> BurmalgramSettingsState {
        return BurmalgramSettingsState(
            fakePremium: SGSimpleSettings.shared.fakePremium,
            customFont: SGSimpleSettings.shared.customFont,
            customPhoneNumber: SGSimpleSettings.shared.customPhoneNumber,
            deletedMessagesEnabled: AntiDeleteManager.shared.isEnabled,
            ghostModeEnabled: GhostModeManager.shared.isEnabled,
            ghostModeActiveCount: GhostModeManager.shared.activeFeatureCount,
            activePluginsCount: GGPluginManager.shared.getPlugins().filter({ $0.isEnabled }).count,
            hideStories: SGSimpleSettings.shared.hideStories,
            warnOnStoriesOpen: SGSimpleSettings.shared.warnOnStoriesOpen,
            confirmCalls: SGSimpleSettings.shared.confirmCalls,
            disableForwardRestriction: SGSimpleSettings.shared.disableForwardRestriction,
            secondsInMessages: SGSimpleSettings.shared.secondsInMessages,
            quickTranslateButton: SGSimpleSettings.shared.quickTranslateButton,
            startTelescopeWithRearCam: SGSimpleSettings.shared.startTelescopeWithRearCam,
            hideRecordingButton: SGSimpleSettings.shared.hideRecordingButton,
            fixFilePicker: SGSimpleSettings.shared.fixFilePicker,
            deviceSpoofEnabled: DeviceSpoofManager.shared.isEnabled,
            geoSpoofEnabled: GeoSpoofManager.shared.isEnabled,
            geoSpoofPresetName: GeoSpoofManager.shared.presetName,
            voiceMorpherEnabled: VoiceMorpherManager.shared.isEnabled,
            voiceMorpherPresetName: VoiceMorpherManager.shared.selectedPreset.name,
            sendDelayEnabled: SendDelayManager.shared.isEnabled
        )
    }
}

// MARK: - Entries builder

private func burmalgramSettingsControllerEntries(
    presentationData: PresentationData,
    state: BurmalgramSettingsState
) -> [BurmalgramSettingsEntry] {
    var entries: [BurmalgramSettingsEntry] = []
    
    // MARK: - Section 1: Main Features
    entries.append(.headerMain(presentationData.theme, "ОСНОВНЫЕ ВОЗМОЖНОСТИ"))
    
    // Local Premium
    entries.append(.fakePremium(presentationData.theme, "Локальный Telegram Premium", state.fakePremium))
    
    // Custom Phone Number
    let phoneLabel = state.customPhoneNumber.isEmpty ? "Не задан" : state.customPhoneNumber
    entries.append(.customPhoneNumber(presentationData.theme, "Кастомный номер (визуальный)", phoneLabel))
    
    // Custom Font
    let fontName: String
    switch state.customFont {
    case "round": fontName = "SF Rounded"
    case "serif": fontName = "New York (Сериф)"
    case "monospace": fontName = "SF Mono"
    case "avenir": fontName = "Avenir Next"
    case "georgia": fontName = "Georgia"
    case "trebuchet": fontName = "Trebuchet MS"
    default: fontName = "По умолчанию"
    }
    entries.append(.customFont(presentationData.theme, "Шрифт приложения", fontName))
    
    // TGExtra Tweak Menu
    entries.append(.tgExtra(presentationData.theme, "Плагины TGExtra (Choco)", "Твики и меню"))
    
    // Swiftgram Settings
    entries.append(.swiftgram(presentationData.theme, "Все настройки Swiftgram", "Открыть"))
    
    // MARK: - Section 2: Privacy & Ghost
    entries.append(.headerPrivacy(presentationData.theme, "КОНФИДЕНЦИАЛЬНОСТЬ И ПРИЗРАК"))
    
    // Ghost Mode
    let ghostModeStatus = state.ghostModeEnabled ? "\(state.ghostModeActiveCount)/5" : "Выкл"
    entries.append(.ghostMode(presentationData.theme, "Режим призрака", ghostModeStatus))
    
    // Deleted Messages
    let deletedStatus = state.deletedMessagesEnabled ? "Вкл" : "Выкл"
    entries.append(.deletedMessages(presentationData.theme, "Анти-удаление сообщений", deletedStatus))
    
    // Stories privacy
    entries.append(.hideStories(presentationData.theme, "Скрыть панель историй", state.hideStories))
    entries.append(.warnOnStoriesOpen(presentationData.theme, "Предупреждать при открытии историй", state.warnOnStoriesOpen))
    
    // Confirm Calls
    entries.append(.confirmCalls(presentationData.theme, "Подтверждать звонки", state.confirmCalls))
    
    // Bypass Copy Protection
    entries.append(.bypassCopyProtection(presentationData.theme, "Запрет копирования (обход No-Save)", state.disableForwardRestriction))
    
    // MARK: - Section 3: Chat & Interface Tweaks
    entries.append(.headerChat(presentationData.theme, "ИНТЕРФЕЙС И ЧАТЫ"))
    
    entries.append(.secondsInMessages(presentationData.theme, "Секунды во времени сообщений", state.secondsInMessages))
    entries.append(.quickTranslateButton(presentationData.theme, "Кнопка быстрого перевода", state.quickTranslateButton))
    entries.append(.rearCamVideoNotes(presentationData.theme, "Кружочки с задней камеры", state.startTelescopeWithRearCam))
    entries.append(.hideRecordingButton(presentationData.theme, "Скрыть кнопку записи (микрофон)", state.hideRecordingButton))
    entries.append(.filePickerFix(presentationData.theme, "Фикс проводника файлов (TGExtra)", state.fixFilePicker))
    entries.append(.clearFilePickerCache(presentationData.theme, "Очистить кэш проводника файлов", "Очистить"))
    
    // MARK: - Section 4: Spoofing & Tools
    entries.append(.headerSpoofing(presentationData.theme, "СПУФИНГ И ИНСТРУМЕНТЫ"))
    
    let deviceSpoofStatus = state.deviceSpoofEnabled ? "Вкл" : "Выкл"
    entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства", deviceSpoofStatus))
    
    let geoSpoofStatus = state.geoSpoofEnabled ? state.geoSpoofPresetName : "Выкл"
    entries.append(.geoSpoof(presentationData.theme, "Подмена геопозиции (GPS)", geoSpoofStatus))
    
    let voiceMorpherStatus = state.voiceMorpherEnabled ? state.voiceMorpherPresetName : "Выкл"
    entries.append(.voiceMorpher(presentationData.theme, "Голосовой двойник (Морфер)", voiceMorpherStatus))
    
    let sendDelayStatus = state.sendDelayEnabled ? "Вкл" : "Выкл"
    entries.append(.sendDelay(presentationData.theme, "Отложка отправки сообщений", sendDelayStatus))
    
    let pluginStatus = state.activePluginsCount > 0 ? "\(state.activePluginsCount) активных" : "Выкл"
    entries.append(.pluginIDE(presentationData.theme, "Плагины GGPlugin (IDE)", pluginStatus))
    
    // MARK: - Section 5: Info
    entries.append(.info(presentationData.theme, "Burmalgram v12.9.2. Интегрированы Ghostgram, Swiftgram и плагины TGExtra. Локальный Telegram Premium разблокирует все иконки, бейджи, стикеры, реакции, расширенные лимиты и расшифровку голосовых."))
    
    return entries
}

// MARK: - Controller

public func burmalgramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController, Bool) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let stateValue = Atomic(value: BurmalgramSettingsState.current())
    let statePromise = ValuePromise(BurmalgramSettingsState.current(), ignoreRepeated: true)
    
    let updateState: ((BurmalgramSettingsState) -> BurmalgramSettingsState) -> Void = { f in
        let newState = stateValue.modify(f)
        statePromise.set(newState)
    }
    
    let arguments = BurmalgramSettingsControllerArguments(
        toggleFakePremium: { value in
            SGSimpleSettings.shared.fakePremium = value
            updateState { state in
                var s = state
                s.fakePremium = value
                return s
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let alert = textAlertController(
                context: context,
                title: "Локальный Premium",
                text: value ? "Локальный Premium включён!\nРазблокированы премиум-иконки, бейджи, реакции, лимиты и распознавание речи.\n\nРекомендуется перезапустить приложение для полного применения." : "Локальный Premium выключен.",
                actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
            )
            presentControllerImpl?(alert)
        },
        openCustomPhoneNumber: {
            let alert = UIAlertController(
                title: "Кастомный номер",
                message: "Введите желаемый номер (отображается визуально в профиле и настройках на вашем устройстве):",
                preferredStyle: .alert
            )
            alert.addTextField { textField in
                textField.placeholder = "+7 (999) 000-00-00"
                textField.text = SGSimpleSettings.shared.customPhoneNumber
                textField.keyboardType = .phonePad
            }
            alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { _ in
                SGSimpleSettings.shared.customPhoneNumber = ""
                updateState { state in
                    var s = state
                    s.customPhoneNumber = ""
                    return s
                }
            }))
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
                if let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    SGSimpleSettings.shared.customPhoneNumber = text
                    updateState { state in
                        var s = state
                        s.customPhoneNumber = text
                        return s
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(alert, animated: true, completion: nil)
            }
        },
        openCustomFont: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let alert = ActionSheetController(presentationData: presentationData)
            let items: [(String, String)] = [
                ("По умолчанию (iOS)", "default"),
                ("Скруглённый (SF Rounded)", "round"),
                ("С засечками (New York)", "serif"),
                ("Моноширинный (SF Mono)", "monospace"),
                ("Avenir Next", "avenir"),
                ("Georgia", "georgia"),
                ("Trebuchet MS", "trebuchet")
            ]
            alert.setItemGroups([
                ActionSheetItemGroup(items: items.map { title, value in
                    ActionSheetButtonItem(title: title, color: .accent, action: { [weak alert] in
                        alert?.dismissAnimated()
                        SGSimpleSettings.shared.customFont = value
                        updateState { state in
                            var s = state
                            s.customFont = value
                            return s
                        }
                    })
                }),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak alert] in
                        alert?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(alert)
        },
        openTGExtra: {
            if let tgExtraClass = NSClassFromString("TGExtra") as? UIViewController.Type {
                let ui = tgExtraClass.init()
                let navVC = DismissableNavigationController(rootViewController: ui)
                navVC.modalPresentationStyle = .fullScreen
                if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(navVC, animated: true, completion: nil)
                    return
                }
            }
            pushControllerImpl?(sgSettingsController(context: context), true)
        },
        openSwiftgram: {
            pushControllerImpl?(sgSettingsController(context: context), true)
        },
        openGhostMode: {
            pushControllerImpl?(ghostModeController(context: context), true)
        },
        openDeletedMessages: {
            pushControllerImpl?(deletedMessagesController(context: context), true)
        },
        toggleHideStories: { value in
            SGSimpleSettings.shared.hideStories = value
            updateState { state in
                var s = state
                s.hideStories = value
                return s
            }
        },
        toggleWarnOnStoriesOpen: { value in
            SGSimpleSettings.shared.warnOnStoriesOpen = value
            updateState { state in
                var s = state
                s.warnOnStoriesOpen = value
                return s
            }
        },
        toggleConfirmCalls: { value in
            SGSimpleSettings.shared.confirmCalls = value
            updateState { state in
                var s = state
                s.confirmCalls = value
                return s
            }
        },
        toggleBypassCopyProtection: { value in
            SGSimpleSettings.shared.disableForwardRestriction = value
            MiscSettingsManager.shared.bypassCopyProtection = value
            MiscSettingsManager.shared.isEnabled = true
            updateState { state in
                var s = state
                s.disableForwardRestriction = value
                return s
            }
        },
        toggleSecondsInMessages: { value in
            SGSimpleSettings.shared.secondsInMessages = value
            updateState { state in
                var s = state
                s.secondsInMessages = value
                return s
            }
        },
        toggleQuickTranslateButton: { value in
            SGSimpleSettings.shared.quickTranslateButton = value
            updateState { state in
                var s = state
                s.quickTranslateButton = value
                return s
            }
        },
        toggleRearCamVideoNotes: { value in
            SGSimpleSettings.shared.startTelescopeWithRearCam = value
            updateState { state in
                var s = state
                s.startTelescopeWithRearCam = value
                return s
            }
        },
        toggleHideRecordingButton: { value in
            SGSimpleSettings.shared.hideRecordingButton = value
            updateState { state in
                var s = state
                s.hideRecordingButton = value
                return s
            }
        },
        toggleFilePickerFix: { value in
            SGSimpleSettings.shared.fixFilePicker = value
            updateState { state in
                var s = state
                s.fixFilePicker = value
                return s
            }
        },
        clearFilePickerCache: {
            let uglyFixDirectory = (NSTemporaryDirectory() as NSString).appendingPathComponent("TGExtraFileFixUsingSomeUglyHacks")
            let _ = try? FileManager.default.removeItem(atPath: uglyFixDirectory)
            let alert = textAlertController(
                context: context,
                title: "Очистка кэша",
                text: "Кэш проводника файлов TGExtra очищен.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            )
            presentControllerImpl?(alert)
        },
        openDeviceSpoof: {
            pushControllerImpl?(deviceSpoofController(context: context), true)
        },
        openGeoSpoof: {
            pushControllerImpl?(geoSpoofController(context: context), true)
        },
        openVoiceMorpher: {
            pushControllerImpl?(voiceMorpherController(context: context), true)
        },
        openSendDelay: {
            pushControllerImpl?(sendDelayController(context: context), true)
        },
        openPluginIDE: {
            pushControllerImpl?(pluginListController(context: context), true)
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, BurmalgramSettingsControllerArguments)) in
        let entries = burmalgramSettingsControllerEntries(presentationData: presentationData, state: state)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Burmalgram"),
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
    
    // Refresh state when view appears
    controller.visibleBottomContentOffsetChanged = { _ in }
    controller.didAppear = { _ in
        let newState = BurmalgramSettingsState.current()
        let _ = stateValue.modify { _ in newState }
        statePromise.set(newState)
    }
    
    pushControllerImpl = { [weak controller] c, animated in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
