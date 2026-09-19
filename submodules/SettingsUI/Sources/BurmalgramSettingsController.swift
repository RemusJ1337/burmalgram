import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - Entry Definition

private enum BurmalgramSettingsSection: Int32 {
    case features
}

private enum BurmalgramSettingsEntry: ItemListNodeEntry {
    case deletedMessages(PresentationTheme, String, String)
    case ghostMode(PresentationTheme, String, String)
    case tgExtra(PresentationTheme, String, String)
    case pluginIDE(PresentationTheme, String, String)
    case misc(PresentationTheme, String, String)
    case deviceSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return BurmalgramSettingsSection.features.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .deletedMessages:
            return 0
        case .ghostMode:
            return 1
        case .tgExtra:
            return 2
        case .pluginIDE:
            return 3
        case .misc:
            return 4
        case .deviceSpoof:
            return 5
        case .voiceMorpher:
            return 6
        case .sendDelay:
            return 7
        case .info:
            return 8
        }
    }
    
    static func ==(lhs: BurmalgramSettingsEntry, rhs: BurmalgramSettingsEntry) -> Bool {
        switch lhs {
        case let .deletedMessages(lhsTheme, lhsText, lhsValue):
            if case let .deletedMessages(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .ghostMode(lhsTheme, lhsText, lhsValue):
            if case let .ghostMode(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .tgExtra(lhsTheme, lhsText, lhsValue):
            if case let .tgExtra(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .pluginIDE(lhsTheme, lhsText, lhsValue):
            if case let .pluginIDE(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .misc(lhsTheme, lhsText, lhsValue):
            if case let .misc(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .deviceSpoof(lhsTheme, lhsText, lhsValue):
            if case let .deviceSpoof(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .voiceMorpher(lhsTheme, lhsText, lhsValue):
            if case let .voiceMorpher(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .sendDelay(lhsTheme, lhsText, lhsValue):
            if case let .sendDelay(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: BurmalgramSettingsEntry, rhs: BurmalgramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BurmalgramSettingsControllerArguments
        switch self {
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
        case let .misc(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openMisc()
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
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// MARK: - Arguments

private final class BurmalgramSettingsControllerArguments {
    let openDeletedMessages: () -> Void
    let openGhostMode: () -> Void
    let openTGExtra: () -> Void
    let openPluginIDE: () -> Void
    let openMisc: () -> Void
    let openDeviceSpoof: () -> Void
    let openVoiceMorpher: () -> Void
    let openSendDelay: () -> Void
    
    init(
        openDeletedMessages: @escaping () -> Void,
        openGhostMode: @escaping () -> Void,
        openTGExtra: @escaping () -> Void,
        openPluginIDE: @escaping () -> Void,
        openMisc: @escaping () -> Void,
        openDeviceSpoof: @escaping () -> Void,
        openVoiceMorpher: @escaping () -> Void,
        openSendDelay: @escaping () -> Void
    ) {
        self.openDeletedMessages = openDeletedMessages
        self.openGhostMode = openGhostMode
        self.openTGExtra = openTGExtra
        self.openPluginIDE = openPluginIDE
        self.openMisc = openMisc
        self.openDeviceSpoof = openDeviceSpoof
        self.openVoiceMorpher = openVoiceMorpher
        self.openSendDelay = openSendDelay
    }
}

// MARK: - State

private struct BurmalgramSettingsState: Equatable {
    var deletedMessagesEnabled: Bool
    var ghostModeEnabled: Bool
    var ghostModeActiveCount: Int
    var activePluginsCount: Int
    var miscEnabled: Bool
    var miscActiveCount: Int
    var deviceSpoofEnabled: Bool
    var voiceMorpherEnabled: Bool
    var voiceMorpherPresetName: String
    var sendDelayEnabled: Bool
    
    static func current() -> BurmalgramSettingsState {
        return BurmalgramSettingsState(
            deletedMessagesEnabled: AntiDeleteManager.shared.isEnabled,
            ghostModeEnabled: GhostModeManager.shared.isEnabled,
            ghostModeActiveCount: GhostModeManager.shared.activeFeatureCount,
            activePluginsCount: GGPluginManager.shared.getPlugins().filter({ $0.isEnabled }).count,
            miscEnabled: MiscSettingsManager.shared.isEnabled,
            miscActiveCount: MiscSettingsManager.shared.activeFeatureCount,
            deviceSpoofEnabled: DeviceSpoofManager.shared.isEnabled,
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
    
    // Deleted Messages
    let deletedStatus = state.deletedMessagesEnabled ? "Вкл" : "Выкл"
    entries.append(.deletedMessages(presentationData.theme, "Удалённые сообщения", deletedStatus))
    
    // Ghost Mode
    let ghostModeStatus = state.ghostModeEnabled ? "\(state.ghostModeActiveCount)/5" : "Выкл"
    entries.append(.ghostMode(presentationData.theme, "Режим призрака", ghostModeStatus))
    
    // TGExtra Plugins
    entries.append(.tgExtra(presentationData.theme, "Плагины TGExtra (Choco)", "Твики и меню"))
    
    // GGPlugin IDE
    let pluginStatus = state.activePluginsCount > 0 ? "\(state.activePluginsCount) активных" : "Выкл"
    entries.append(.pluginIDE(presentationData.theme, "Плагины GGPlugin (IDE)", pluginStatus))
    
    // Misc
    let miscStatus = state.miscEnabled ? "\(state.miscActiveCount)/5" : "Выкл"
    entries.append(.misc(presentationData.theme, "Прочее", miscStatus))
    
    // Device Spoofing
    let deviceSpoofStatus = state.deviceSpoofEnabled ? "Вкл" : "Выкл"
    entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства", deviceSpoofStatus))
    
    // Voice Morpher
    let voiceMorpherStatus = state.voiceMorpherEnabled ? state.voiceMorpherPresetName : "Выкл"
    entries.append(.voiceMorpher(presentationData.theme, "Голосовой двойник", voiceMorpherStatus))
    
    // Send Delay
    let sendDelayStatus = state.sendDelayEnabled ? "Вкл" : "Выкл"
    entries.append(.sendDelay(presentationData.theme, "Отложка сообщений", sendDelayStatus))
    
    // Info
    entries.append(.info(presentationData.theme, "Функции Burmalgram, Ghostgram и плагины TGExtra. Скрытые отметки о прочтении, обход таймеров, сохранение запрещённого контента, поддержка JS-скриптов GGAPI и интеграция твиков TGExtra."))
    
    return entries
}

// MARK: - Controller

public func burmalgramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController, Bool) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let stateValue = Atomic(value: BurmalgramSettingsState.current())
    let statePromise = ValuePromise(BurmalgramSettingsState.current(), ignoreRepeated: true)
    
    let arguments = BurmalgramSettingsControllerArguments(
        openDeletedMessages: {
            pushControllerImpl?(deletedMessagesController(context: context), true)
        },
        openGhostMode: {
            pushControllerImpl?(ghostModeController(context: context), true)
        },
        openTGExtra: {
            if let tgExtraClass = NSClassFromString("TGExtra") as? NSObject.Type,
               let displayVc = tgExtraClass.init() as? ViewController {
                pushControllerImpl?(displayVc, true)
            } else {
                let alert = textAlertController(
                    context: context,
                    title: "Плагин TGExtra",
                    text: "TGExtra активирован в системе приложения.\n\nБыстрый доступ к интерфейсу твика:\n• Удерживайте экран 3 пальцами (3-finger long press)\n• Либо нажмите 5 раз на вкладку «Чаты».",
                    actions: [TextAlertAction(type: .defaultAction, title: "Понятно", action: {})]
                )
                presentControllerImpl?(alert)
            }
        },
        openPluginIDE: {
            pushControllerImpl?(pluginListController(context: context), true)
        },
        openMisc: {
            pushControllerImpl?(miscController(context: context), true)
        },
        openDeviceSpoof: {
            pushControllerImpl?(deviceSpoofController(context: context), true)
        },
        openVoiceMorpher: {
            pushControllerImpl?(voiceMorpherController(context: context), true)
        },
        openSendDelay: {
            pushControllerImpl?(sendDelayController(context: context), true)
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
