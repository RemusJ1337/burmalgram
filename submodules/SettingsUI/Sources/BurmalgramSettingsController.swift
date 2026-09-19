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
import TelegramUIPreferences

// MARK: - Font & Helper Utilities

private let burmalgramFontOptions: [(String, String)] = [
    ("default", "По умолчанию (San Francisco)"),
    ("round", "Скруглённый (SF Pro Rounded)"),
    ("serif", "С засечками (New York Serif)"),
    ("monospace", "Моноширинный (SF Mono)"),
    ("avenir", "Avenir Next"),
    ("georgia", "Georgia"),
    ("trebuchet", "Trebuchet MS"),
    ("helvetica", "Helvetica Neue"),
    ("futura", "Futura"),
    ("palatino", "Palatino"),
    ("menlo", "Menlo (Code)"),
    ("optima", "Optima"),
    ("baskerville", "Baskerville"),
    ("copperplate", "Copperplate"),
    ("gill", "Gill Sans"),
    ("snell", "Snell Roundhand (Рукописный)"),
    ("markerfelt", "Marker Felt")
]

private func burmalgramFontDisplayName(_ key: String) -> String {
    for (fontKey, title) in burmalgramFontOptions {
        if fontKey == key {
            return title
        }
    }
    return "По умолчанию"
}

private func presentBurmalgramFontPicker(context: AccountContext, onSelect: @escaping (String) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let actionSheet = ActionSheetController(presentationData: presentationData)
    var items: [ActionSheetItem] = [
        ActionSheetTextItem(title: "Выберите шрифт интерфейса")
    ]
    let current = SGSimpleSettings.shared.customFont
    for (key, title) in burmalgramFontOptions {
        items.append(ActionSheetButtonItem(title: title, color: .accent, font: key == current ? .bold : .default, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            SGSimpleSettings.shared.customFont = key
            onSelect(key)
        }))
    }
    items.append(ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
        actionSheet?.dismissAnimated()
    }))
    actionSheet.setItemGroups([ActionSheetItemGroup(items: items)])
    
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
       let rootVC = window.rootViewController {
        rootVC.present(actionSheet, animated: true, completion: nil)
    }
}

private func presentBurmalgramPhoneEditor(context: AccountContext, onComplete: @escaping () -> Void) {
    let alert = UIAlertController(
        title: "Кастомный номер телефона",
        message: "Введите текст или номер для отображения в профиле и настройках (например, +7 (777) 777-77-77, BURMALDA, VIP 001):",
        preferredStyle: .alert
    )
    alert.addTextField { textField in
        textField.text = SGSimpleSettings.shared.customPhoneNumber
        textField.placeholder = "Оставьте пустым для сброса"
    }
    alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { _ in
        let newPhone = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        SGSimpleSettings.shared.customPhoneNumber = newPhone
        onComplete()
    }))
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
       let rootVC = window.rootViewController {
        rootVC.present(alert, animated: true, completion: nil)
    }
}

private func applyBurmalgramTheme(context: AccountContext, themeKey: String) {
    SGSimpleSettings.shared.burmalgramTheme = themeKey
    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
        var current = current
        
        switch themeKey {
        case "midnight": // Тёмная (Черная / Midnight Black)
            let baseThemeRef: PresentationThemeReference = .builtin(.night)
            let accentColor: UInt32 = 0x2ea6ff
            let bubbleColors: [UInt32] = [0x182533, 0x243b55]
            let wallpaper: TelegramWallpaper = .color(0x0a0f1d)
            var accents = current.themeSpecificAccentColors
            accents[baseThemeRef.index] = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            var wallpapers = current.themeSpecificChatWallpapers
            wallpapers[baseThemeRef.index] = wallpaper
            current.theme = baseThemeRef
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "sparkling": // Сверкающая (Sparkling Star / Сапфир)
            let baseThemeRef: PresentationThemeReference = .builtin(.nightAccent)
            let accentColor: UInt32 = 0x3e95ff
            let bubbleColors: [UInt32] = [0x1e3c72, 0x2a5298]
            let wallpaper: TelegramWallpaper = .color(0x0b132b)
            var accents = current.themeSpecificAccentColors
            accents[baseThemeRef.index] = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            var wallpapers = current.themeSpecificChatWallpapers
            wallpapers[baseThemeRef.index] = wallpaper
            current.theme = baseThemeRef
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "neon": // Неон (Neon Blue / Киберпанк)
            let baseThemeRef: PresentationThemeReference = .builtin(.night)
            let accentColor: UInt32 = 0x00e5ff
            let bubbleColors: [UInt32] = [0x00416a, 0x0072ff]
            let wallpaper: TelegramWallpaper = .color(0x030811)
            var accents = current.themeSpecificAccentColors
            accents[baseThemeRef.index] = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            var wallpapers = current.themeSpecificChatWallpapers
            wallpapers[baseThemeRef.index] = wallpaper
            current.theme = baseThemeRef
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "titanium": // Титан (Titanium Metal / Графит)
            let baseThemeRef: PresentationThemeReference = .builtin(.night)
            let accentColor: UInt32 = 0x95a5a6
            let bubbleColors: [UInt32] = [0x2c3e50, 0x34495e]
            let wallpaper: TelegramWallpaper = .color(0x131518)
            var accents = current.themeSpecificAccentColors
            accents[baseThemeRef.index] = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            var wallpapers = current.themeSpecificChatWallpapers
            wallpapers[baseThemeRef.index] = wallpaper
            current.theme = baseThemeRef
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        default: // Reset
            current.theme = .builtin(.dayClassic)
        }
        
        return current
    }).start()
}

// MARK: - 1. Main Hub: BurmalgramSettingsController

private enum BurmalgramMainSection: Int32 {
    case categories
    case quickAccess
    case info
}

private enum BurmalgramMainEntry: ItemListNodeEntry {
    case headerCategories(PresentationTheme, String)
    case customization(PresentationTheme, String, String)
    case privacy(PresentationTheme, String, String)
    case tools(PresentationTheme, String, String)
    case swiftgram(PresentationTheme, String, String)
    
    case headerQuick(PresentationTheme, String)
    case fakePremium(PresentationTheme, String, Bool)
    case ghostMode(PresentationTheme, String, Bool)
    case antiDelete(PresentationTheme, String, Bool)
    case customFont(PresentationTheme, String, String)
    
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerCategories, .customization, .privacy, .tools, .swiftgram:
            return BurmalgramMainSection.categories.rawValue
        case .headerQuick, .fakePremium, .ghostMode, .antiDelete, .customFont:
            return BurmalgramMainSection.quickAccess.rawValue
        case .info:
            return BurmalgramMainSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerCategories: return 0
        case .customization: return 1
        case .privacy: return 2
        case .tools: return 3
        case .swiftgram: return 4
        case .headerQuick: return 10
        case .fakePremium: return 11
        case .ghostMode: return 12
        case .antiDelete: return 13
        case .customFont: return 14
        case .info: return 20
        }
    }
    
    static func ==(lhs: BurmalgramMainEntry, rhs: BurmalgramMainEntry) -> Bool {
        switch lhs {
        case let .headerCategories(lhsTheme, lhsText):
            if case let .headerCategories(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .customization(lhsTheme, lhsText, lhsValue):
            if case let .customization(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .privacy(lhsTheme, lhsText, lhsValue):
            if case let .privacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .tools(lhsTheme, lhsText, lhsValue):
            if case let .tools(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .swiftgram(lhsTheme, lhsText, lhsValue):
            if case let .swiftgram(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerQuick(lhsTheme, lhsText):
            if case let .headerQuick(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .fakePremium(lhsTheme, lhsText, lhsValue):
            if case let .fakePremium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostMode(lhsTheme, lhsText, lhsValue):
            if case let .ghostMode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .antiDelete(lhsTheme, lhsText, lhsValue):
            if case let .antiDelete(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .customFont(lhsTheme, lhsText, lhsValue):
            if case let .customFont(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramMainEntry, rhs: BurmalgramMainEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramMainArguments
        switch self {
        case let .headerCategories(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .customization(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.chatAppearance, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openCustomization()
            })
        case let .privacy(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.security, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openPrivacy()
            })
        case let .tools(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.settings, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openTools()
            })
        case let .swiftgram(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.proxy, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openSwiftgram()
            })
        case let .headerQuick(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .fakePremium(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFakePremium(val)
            })
        case let .ghostMode(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostMode(val)
            })
        case let .antiDelete(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDelete(val)
            })
        case let .customFont(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.selectFont()
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class BurmalgramMainArguments {
    let openCustomization: () -> Void
    let openPrivacy: () -> Void
    let openTools: () -> Void
    let openSwiftgram: () -> Void
    let toggleFakePremium: (Bool) -> Void
    let toggleGhostMode: (Bool) -> Void
    let toggleAntiDelete: (Bool) -> Void
    let selectFont: () -> Void
    
    init(
        openCustomization: @escaping () -> Void,
        openPrivacy: @escaping () -> Void,
        openTools: @escaping () -> Void,
        openSwiftgram: @escaping () -> Void,
        toggleFakePremium: @escaping (Bool) -> Void,
        toggleGhostMode: @escaping (Bool) -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        selectFont: @escaping () -> Void
    ) {
        self.openCustomization = openCustomization
        self.openPrivacy = openPrivacy
        self.openTools = openTools
        self.openSwiftgram = openSwiftgram
        self.toggleFakePremium = toggleFakePremium
        self.toggleGhostMode = toggleGhostMode
        self.toggleAntiDelete = toggleAntiDelete
        self.selectFont = selectFont
    }
}

public func burmalgramSettingsController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramMainArguments(
        openCustomization: {
            pushControllerImpl?(burmalgramCustomizationController(context: context))
        },
        openPrivacy: {
            pushControllerImpl?(burmalgramPrivacyController(context: context))
        },
        openTools: {
            pushControllerImpl?(burmalgramToolsController(context: context))
        },
        openSwiftgram: {
            pushControllerImpl?(sgSettingsController(context: context))
        },
        toggleFakePremium: { val in
            SGSimpleSettings.shared.fakePremium = val
            reloadPromise.set(true)
        },
        toggleGhostMode: { val in
            GhostModeManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        toggleAntiDelete: { val in
            AntiDeleteManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        selectFont: {
            presentBurmalgramFontPicker(context: context, onSelect: { _ in
                reloadPromise.set(true)
            })
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramMainEntry] = []
        
        entries.append(.headerCategories(presentationData.theme, "РАЗДЕЛЫ НАСТРОЕК"))
        entries.append(.customization(presentationData.theme, "Кастомизация и оформление", "Темы, Шрифты, Premium"))
        entries.append(.privacy(presentationData.theme, "Конфиденциальность и Ghost", "Ghost Mode, Сообщения"))
        entries.append(.tools(presentationData.theme, "Инструменты и подмена", "GPS, Устройства, Память"))
        entries.append(.swiftgram(presentationData.theme, "Настройки Swiftgram", "Сетевые опции"))
        
        entries.append(.headerQuick(presentationData.theme, "БЫСТРЫЙ ДОСТУП"))
        entries.append(.fakePremium(presentationData.theme, "Локальный Telegram Premium", SGSimpleSettings.shared.fakePremium))
        entries.append(.ghostMode(presentationData.theme, "Режим призрака (Ghost Mode)", GhostModeManager.shared.isEnabled))
        entries.append(.antiDelete(presentationData.theme, "Сохранять удалённые сообщения", AntiDeleteManager.shared.isEnabled))
        entries.append(.customFont(presentationData.theme, "Шрифт интерфейса", burmalgramFontDisplayName(SGSimpleSettings.shared.customFont)))
        
        entries.append(.info(presentationData.theme, "Burmalgram v12.9.2 (build 3731)\nБаза: Telegram-iOS / Swiftgram / Ghostgram\nВсе модификации работают локально."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Burmalgram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

// MARK: - 2. Sub-Menu: BurmalgramCustomizationController

private enum BurmalgramCustomizationSection: Int32 {
    case premium
    case themes
    case visuals
    case chats
}

private enum BurmalgramCustomizationEntry: ItemListNodeEntry {
    case headerPremium(PresentationTheme, String)
    case fakePremium(PresentationTheme, String, Bool)
    case fakePremiumInfo(PresentationTheme, String)
    
    case headerThemes(PresentationTheme, String)
    case themeMidnight(PresentationTheme, String, String)
    case themeSparkling(PresentationTheme, String, String)
    case themeNeon(PresentationTheme, String, String)
    case themeTitanium(PresentationTheme, String, String)
    case themeReset(PresentationTheme, String, String)
    case themeFooter(PresentationTheme, String)
    
    case headerVisuals(PresentationTheme, String)
    case customFont(PresentationTheme, String, String)
    case customPhone(PresentationTheme, String, String)
    case hidePhone(PresentationTheme, String, Bool)
    
    case headerChats(PresentationTheme, String)
    case secondsInMessages(PresentationTheme, String, Bool)
    case quickTranslate(PresentationTheme, String, Bool)
    case hideRecording(PresentationTheme, String, Bool)
    case rearCam(PresentationTheme, String, Bool)
    case compactChatList(PresentationTheme, String, Bool)
    case compactPreview(PresentationTheme, String, Bool)
    case foldersAtBottom(PresentationTheme, String, Bool)
    case wideTabBar(PresentationTheme, String, Bool)
    case disableSnap(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .headerPremium, .fakePremium, .fakePremiumInfo:
            return BurmalgramCustomizationSection.premium.rawValue
        case .headerThemes, .themeMidnight, .themeSparkling, .themeNeon, .themeTitanium, .themeReset, .themeFooter:
            return BurmalgramCustomizationSection.themes.rawValue
        case .headerVisuals, .customFont, .customPhone, .hidePhone:
            return BurmalgramCustomizationSection.visuals.rawValue
        case .headerChats, .secondsInMessages, .quickTranslate, .hideRecording, .rearCam, .compactChatList, .compactPreview, .foldersAtBottom, .wideTabBar, .disableSnap:
            return BurmalgramCustomizationSection.chats.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerPremium: return 0
        case .fakePremium: return 1
        case .fakePremiumInfo: return 2
        case .headerThemes: return 10
        case .themeMidnight: return 11
        case .themeSparkling: return 12
        case .themeNeon: return 13
        case .themeTitanium: return 14
        case .themeReset: return 15
        case .themeFooter: return 16
        case .headerVisuals: return 20
        case .customFont: return 21
        case .customPhone: return 22
        case .hidePhone: return 23
        case .headerChats: return 30
        case .secondsInMessages: return 31
        case .quickTranslate: return 32
        case .hideRecording: return 33
        case .rearCam: return 34
        case .compactChatList: return 35
        case .compactPreview: return 36
        case .foldersAtBottom: return 37
        case .wideTabBar: return 38
        case .disableSnap: return 39
        }
    }
    
    static func ==(lhs: BurmalgramCustomizationEntry, rhs: BurmalgramCustomizationEntry) -> Bool {
        switch lhs {
        case let .headerPremium(lhsTheme, lhsText):
            if case let .headerPremium(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .fakePremium(lhsTheme, lhsText, lhsValue):
            if case let .fakePremium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .fakePremiumInfo(lhsTheme, lhsText):
            if case let .fakePremiumInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .headerThemes(lhsTheme, lhsText):
            if case let .headerThemes(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .themeMidnight(lhsTheme, lhsText, lhsValue):
            if case let .themeMidnight(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeSparkling(lhsTheme, lhsText, lhsValue):
            if case let .themeSparkling(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeNeon(lhsTheme, lhsText, lhsValue):
            if case let .themeNeon(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeTitanium(lhsTheme, lhsText, lhsValue):
            if case let .themeTitanium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeReset(lhsTheme, lhsText, lhsValue):
            if case let .themeReset(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeFooter(lhsTheme, lhsText):
            if case let .themeFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .headerVisuals(lhsTheme, lhsText):
            if case let .headerVisuals(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .customFont(lhsTheme, lhsText, lhsValue):
            if case let .customFont(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .customPhone(lhsTheme, lhsText, lhsValue):
            if case let .customPhone(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hidePhone(lhsTheme, lhsText, lhsValue):
            if case let .hidePhone(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerChats(lhsTheme, lhsText):
            if case let .headerChats(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .secondsInMessages(lhsTheme, lhsText, lhsValue):
            if case let .secondsInMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .quickTranslate(lhsTheme, lhsText, lhsValue):
            if case let .quickTranslate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideRecording(lhsTheme, lhsText, lhsValue):
            if case let .hideRecording(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .rearCam(lhsTheme, lhsText, lhsValue):
            if case let .rearCam(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactChatList(lhsTheme, lhsText, lhsValue):
            if case let .compactChatList(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactPreview(lhsTheme, lhsText, lhsValue):
            if case let .compactPreview(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .foldersAtBottom(lhsTheme, lhsText, lhsValue):
            if case let .foldersAtBottom(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .wideTabBar(lhsTheme, lhsText, lhsValue):
            if case let .wideTabBar(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableSnap(lhsTheme, lhsText, lhsValue):
            if case let .disableSnap(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramCustomizationEntry, rhs: BurmalgramCustomizationEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramCustomizationArguments
        switch self {
        case let .headerPremium(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .fakePremium(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFakePremium(val)
            })
        case let .fakePremiumInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .headerThemes(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .themeMidnight(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("midnight")
            })
        case let .themeSparkling(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("sparkling")
            })
        case let .themeNeon(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("neon")
            })
        case let .themeTitanium(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("titanium")
            })
        case let .themeReset(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("default")
            })
        case let .themeFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .headerVisuals(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .customFont(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.selectFont()
            })
        case let .customPhone(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.editCustomPhone()
            })
        case let .hidePhone(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHidePhone(val)
            })
        case let .headerChats(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .secondsInMessages(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSeconds(val)
            })
        case let .quickTranslate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleTranslate(val)
            })
        case let .hideRecording(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideRecording(val)
            })
        case let .rearCam(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleRearCam(val)
            })
        case let .compactChatList(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactChatList(val)
            })
        case let .compactPreview(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactPreview(val)
            })
        case let .foldersAtBottom(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFoldersAtBottom(val)
            })
        case let .wideTabBar(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleWideTabBar(val)
            })
        case let .disableSnap(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSnap(val)
            })
        }
    }
}

private final class BurmalgramCustomizationArguments {
    let toggleFakePremium: (Bool) -> Void
    let applyTheme: (String) -> Void
    let selectFont: () -> Void
    let editCustomPhone: () -> Void
    let toggleHidePhone: (Bool) -> Void
    let toggleSeconds: (Bool) -> Void
    let toggleTranslate: (Bool) -> Void
    let toggleHideRecording: (Bool) -> Void
    let toggleRearCam: (Bool) -> Void
    let toggleCompactChatList: (Bool) -> Void
    let toggleCompactPreview: (Bool) -> Void
    let toggleFoldersAtBottom: (Bool) -> Void
    let toggleWideTabBar: (Bool) -> Void
    let toggleDisableSnap: (Bool) -> Void
    
    init(
        toggleFakePremium: @escaping (Bool) -> Void,
        applyTheme: @escaping (String) -> Void,
        selectFont: @escaping () -> Void,
        editCustomPhone: @escaping () -> Void,
        toggleHidePhone: @escaping (Bool) -> Void,
        toggleSeconds: @escaping (Bool) -> Void,
        toggleTranslate: @escaping (Bool) -> Void,
        toggleHideRecording: @escaping (Bool) -> Void,
        toggleRearCam: @escaping (Bool) -> Void,
        toggleCompactChatList: @escaping (Bool) -> Void,
        toggleCompactPreview: @escaping (Bool) -> Void,
        toggleFoldersAtBottom: @escaping (Bool) -> Void,
        toggleWideTabBar: @escaping (Bool) -> Void,
        toggleDisableSnap: @escaping (Bool) -> Void
    ) {
        self.toggleFakePremium = toggleFakePremium
        self.applyTheme = applyTheme
        self.selectFont = selectFont
        self.editCustomPhone = editCustomPhone
        self.toggleHidePhone = toggleHidePhone
        self.toggleSeconds = toggleSeconds
        self.toggleTranslate = toggleTranslate
        self.toggleHideRecording = toggleHideRecording
        self.toggleRearCam = toggleRearCam
        self.toggleCompactChatList = toggleCompactChatList
        self.toggleCompactPreview = toggleCompactPreview
        self.toggleFoldersAtBottom = toggleFoldersAtBottom
        self.toggleWideTabBar = toggleWideTabBar
        self.toggleDisableSnap = toggleDisableSnap
    }
}

public func burmalgramCustomizationController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramCustomizationArguments(
        toggleFakePremium: { val in
            SGSimpleSettings.shared.fakePremium = val
            reloadPromise.set(true)
        },
        applyTheme: { themeKey in
            applyBurmalgramTheme(context: context, themeKey: themeKey)
            reloadPromise.set(true)
        },
        selectFont: {
            presentBurmalgramFontPicker(context: context, onSelect: { _ in
                reloadPromise.set(true)
            })
        },
        editCustomPhone: {
            presentBurmalgramPhoneEditor(context: context, onComplete: {
                reloadPromise.set(true)
            })
        },
        toggleHidePhone: { val in
            SGSimpleSettings.shared.hidePhoneInSettings = val
            reloadPromise.set(true)
        },
        toggleSeconds: { val in
            SGSimpleSettings.shared.secondsInMessages = val
            reloadPromise.set(true)
        },
        toggleTranslate: { val in
            SGSimpleSettings.shared.quickTranslateButton = val
            reloadPromise.set(true)
        },
        toggleHideRecording: { val in
            SGSimpleSettings.shared.hideRecordingButton = val
            reloadPromise.set(true)
        },
        toggleRearCam: { val in
            SGSimpleSettings.shared.startTelescopeWithRearCam = val
            reloadPromise.set(true)
        },
        toggleCompactChatList: { val in
            SGSimpleSettings.shared.compactChatList = val
            reloadPromise.set(true)
        },
        toggleCompactPreview: { val in
            SGSimpleSettings.shared.chatListLines = val ? SGSimpleSettings.ChatListLines.one.rawValue : SGSimpleSettings.ChatListLines.three.rawValue
            reloadPromise.set(true)
        },
        toggleFoldersAtBottom: { val in
            let _ = updateExperimentalUISettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.foldersTabAtBottom = val
                return settings
            }).start()
            reloadPromise.set(true)
        },
        toggleWideTabBar: { val in
            SGSimpleSettings.shared.wideTabBar = val
            reloadPromise.set(true)
        },
        toggleDisableSnap: { val in
            SGSimpleSettings.shared.disableSnapDeletionEffect = val
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings]),
        reloadPromise.get()
    )
    |> map { presentationData, sharedData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let expSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        var entries: [BurmalgramCustomizationEntry] = []
        
        entries.append(.headerPremium(presentationData.theme, "ЛОКАЛЬНЫЙ TELEGRAM PREMIUM"))
        entries.append(.fakePremium(presentationData.theme, "Локальный Telegram Premium", SGSimpleSettings.shared.fakePremium))
        entries.append(.fakePremiumInfo(presentationData.theme, "100% локальный режим: значок Premium в профиле, смену цветов профиля и имени без сетевых ошибок, доступ ко всем премиум-иконкам, расширенные лимиты, распознавание речи и премиум-реакции."))
        
        let currentTheme = SGSimpleSettings.shared.burmalgramTheme
        entries.append(.headerThemes(presentationData.theme, "ЭКСКЛЮЗИВНЫЕ ТЕМЫ BURMALGRAM"))
        entries.append(.themeMidnight(presentationData.theme, "🌌 Тёмная (Midnight Black)", currentTheme == "midnight" ? "Активна" : ""))
        entries.append(.themeSparkling(presentationData.theme, "✨ Сверкающая (Sparkling Star)", currentTheme == "sparkling" ? "Активна" : ""))
        entries.append(.themeNeon(presentationData.theme, "⚡ Неон (Neon Blue)", currentTheme == "neon" ? "Активна" : ""))
        entries.append(.themeTitanium(presentationData.theme, "🛡️ Титан (Titanium Metal)", currentTheme == "titanium" ? "Активна" : ""))
        entries.append(.themeReset(presentationData.theme, "🔄 Сбросить тему (По умолчанию)", ""))
        entries.append(.themeFooter(presentationData.theme, "Эксклюзивные стили, вдохновлённые иконками приложения: стилизованные фоны, баблы сообщений и акценты."))
        
        entries.append(.headerVisuals(presentationData.theme, "ШРИФТ И ПРОФИЛЬ"))
        entries.append(.customFont(presentationData.theme, "Шрифт интерфейса", burmalgramFontDisplayName(SGSimpleSettings.shared.customFont)))
        let phoneText = SGSimpleSettings.shared.customPhoneNumber.isEmpty ? "Не задан" : SGSimpleSettings.shared.customPhoneNumber
        entries.append(.customPhone(presentationData.theme, "Кастомный номер (визуальный)", phoneText))
        entries.append(.hidePhone(presentationData.theme, "Скрыть номер в настройках", SGSimpleSettings.shared.hidePhoneInSettings))
        
        entries.append(.headerChats(presentationData.theme, "ИНТЕРФЕЙС И ЧАТЫ"))
        entries.append(.secondsInMessages(presentationData.theme, "Секунды в сообщениях", SGSimpleSettings.shared.secondsInMessages))
        entries.append(.quickTranslate(presentationData.theme, "Кнопка быстрого перевода", SGSimpleSettings.shared.quickTranslateButton))
        entries.append(.hideRecording(presentationData.theme, "Скрыть кнопку записи (микрофон)", SGSimpleSettings.shared.hideRecordingButton))
        entries.append(.rearCam(presentationData.theme, "Видеокружки с задней камеры", SGSimpleSettings.shared.startTelescopeWithRearCam))
        entries.append(.compactChatList(presentationData.theme, "Компактный список чатов", SGSimpleSettings.shared.compactChatList))
        entries.append(.compactPreview(presentationData.theme, "Однострочный предпросмотр сообщений", SGSimpleSettings.shared.chatListLines != SGSimpleSettings.ChatListLines.three.rawValue))
        entries.append(.foldersAtBottom(presentationData.theme, "Вкладки папок снизу", expSettings.foldersTabAtBottom))
        entries.append(.wideTabBar(presentationData.theme, "Широкая панель вкладок", SGSimpleSettings.shared.wideTabBar))
        entries.append(.disableSnap(presentationData.theme, "Отключить эффект сгорания (Snap)", SGSimpleSettings.shared.disableSnapDeletionEffect))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Кастомизация"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}

// MARK: - 3. Sub-Menu: BurmalgramPrivacyController

private enum BurmalgramPrivacySection: Int32 {
    case ghost
    case messages
    case stories
    case calls
}

private enum BurmalgramPrivacyEntry: ItemListNodeEntry {
    case headerGhost(PresentationTheme, String)
    case ghostMode(PresentationTheme, String, Bool)
    case dontRead(PresentationTheme, String, Bool)
    case dontOnline(PresentationTheme, String, Bool)
    case dontTyping(PresentationTheme, String, Bool)
    case anonStories(PresentationTheme, String, Bool)
    case ghostDetails(PresentationTheme, String, String)
    
    case headerMessages(PresentationTheme, String)
    case antiDelete(PresentationTheme, String, Bool)
    case antiDeleteMedia(PresentationTheme, String, Bool)
    case deletedHistory(PresentationTheme, String, String)
    
    case headerStories(PresentationTheme, String)
    case hideStories(PresentationTheme, String, Bool)
    case warnStories(PresentationTheme, String, Bool)
    
    case headerCalls(PresentationTheme, String)
    case bypassCopy(PresentationTheme, String, Bool)
    case confirmCalls(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .headerGhost, .ghostMode, .dontRead, .dontOnline, .dontTyping, .anonStories, .ghostDetails:
            return BurmalgramPrivacySection.ghost.rawValue
        case .headerMessages, .antiDelete, .antiDeleteMedia, .deletedHistory:
            return BurmalgramPrivacySection.messages.rawValue
        case .headerStories, .hideStories, .warnStories:
            return BurmalgramPrivacySection.stories.rawValue
        case .headerCalls, .bypassCopy, .confirmCalls:
            return BurmalgramPrivacySection.calls.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerGhost: return 0
        case .ghostMode: return 1
        case .dontRead: return 2
        case .dontOnline: return 3
        case .dontTyping: return 4
        case .anonStories: return 5
        case .ghostDetails: return 6
        case .headerMessages: return 10
        case .antiDelete: return 11
        case .antiDeleteMedia: return 12
        case .deletedHistory: return 13
        case .headerStories: return 20
        case .hideStories: return 21
        case .warnStories: return 22
        case .headerCalls: return 30
        case .bypassCopy: return 31
        case .confirmCalls: return 32
        }
    }
    
    static func ==(lhs: BurmalgramPrivacyEntry, rhs: BurmalgramPrivacyEntry) -> Bool {
        switch lhs {
        case let .headerGhost(lhsTheme, lhsText):
            if case let .headerGhost(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .ghostMode(lhsTheme, lhsText, lhsValue):
            if case let .ghostMode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .dontRead(lhsTheme, lhsText, lhsValue):
            if case let .dontRead(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .dontOnline(lhsTheme, lhsText, lhsValue):
            if case let .dontOnline(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .dontTyping(lhsTheme, lhsText, lhsValue):
            if case let .dontTyping(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .anonStories(lhsTheme, lhsText, lhsValue):
            if case let .anonStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostDetails(lhsTheme, lhsText, lhsValue):
            if case let .ghostDetails(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerMessages(lhsTheme, lhsText):
            if case let .headerMessages(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .antiDelete(lhsTheme, lhsText, lhsValue):
            if case let .antiDelete(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .antiDeleteMedia(lhsTheme, lhsText, lhsValue):
            if case let .antiDeleteMedia(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .deletedHistory(lhsTheme, lhsText, lhsValue):
            if case let .deletedHistory(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerStories(lhsTheme, lhsText):
            if case let .headerStories(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .hideStories(lhsTheme, lhsText, lhsValue):
            if case let .hideStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .warnStories(lhsTheme, lhsText, lhsValue):
            if case let .warnStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerCalls(lhsTheme, lhsText):
            if case let .headerCalls(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .bypassCopy(lhsTheme, lhsText, lhsValue):
            if case let .bypassCopy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .confirmCalls(lhsTheme, lhsText, lhsValue):
            if case let .confirmCalls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramPrivacyEntry, rhs: BurmalgramPrivacyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramPrivacyArguments
        switch self {
        case let .headerGhost(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .ghostMode(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostMode(val)
            })
        case let .dontRead(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDontRead(val)
            })
        case let .dontOnline(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDontOnline(val)
            })
        case let .dontTyping(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDontTyping(val)
            })
        case let .anonStories(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAnonStories(val)
            })
        case let .ghostDetails(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.appearance, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openGhostDetails()
            })
        case let .headerMessages(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .antiDelete(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDelete(val)
            })
        case let .antiDeleteMedia(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDeleteMedia(val)
            })
        case let .deletedHistory(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.messages, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openDeletedHistory()
            })
        case let .headerStories(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .hideStories(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideStories(val)
            })
        case let .warnStories(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleWarnStories(val)
            })
        case let .headerCalls(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .bypassCopy(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleBypassCopy(val)
            })
        case let .confirmCalls(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleConfirmCalls(val)
            })
        }
    }
}

private final class BurmalgramPrivacyArguments {
    let toggleGhostMode: (Bool) -> Void
    let toggleDontRead: (Bool) -> Void
    let toggleDontOnline: (Bool) -> Void
    let toggleDontTyping: (Bool) -> Void
    let toggleAnonStories: (Bool) -> Void
    let openGhostDetails: () -> Void
    let toggleAntiDelete: (Bool) -> Void
    let toggleAntiDeleteMedia: (Bool) -> Void
    let openDeletedHistory: () -> Void
    let toggleHideStories: (Bool) -> Void
    let toggleWarnStories: (Bool) -> Void
    let toggleBypassCopy: (Bool) -> Void
    let toggleConfirmCalls: (Bool) -> Void
    
    init(
        toggleGhostMode: @escaping (Bool) -> Void,
        toggleDontRead: @escaping (Bool) -> Void,
        toggleDontOnline: @escaping (Bool) -> Void,
        toggleDontTyping: @escaping (Bool) -> Void,
        toggleAnonStories: @escaping (Bool) -> Void,
        openGhostDetails: @escaping () -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleAntiDeleteMedia: @escaping (Bool) -> Void,
        openDeletedHistory: @escaping () -> Void,
        toggleHideStories: @escaping (Bool) -> Void,
        toggleWarnStories: @escaping (Bool) -> Void,
        toggleBypassCopy: @escaping (Bool) -> Void,
        toggleConfirmCalls: @escaping (Bool) -> Void
    ) {
        self.toggleGhostMode = toggleGhostMode
        self.toggleDontRead = toggleDontRead
        self.toggleDontOnline = toggleDontOnline
        self.toggleDontTyping = toggleDontTyping
        self.toggleAnonStories = toggleAnonStories
        self.openGhostDetails = openGhostDetails
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleAntiDeleteMedia = toggleAntiDeleteMedia
        self.openDeletedHistory = openDeletedHistory
        self.toggleHideStories = toggleHideStories
        self.toggleWarnStories = toggleWarnStories
        self.toggleBypassCopy = toggleBypassCopy
        self.toggleConfirmCalls = toggleConfirmCalls
    }
}

public func burmalgramPrivacyController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramPrivacyArguments(
        toggleGhostMode: { val in
            GhostModeManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        toggleDontRead: { val in
            GhostModeManager.shared.hideReadReceipts = val
            reloadPromise.set(true)
        },
        toggleDontOnline: { val in
            GhostModeManager.shared.hideOnlineStatus = val
            reloadPromise.set(true)
        },
        toggleDontTyping: { val in
            GhostModeManager.shared.hideTypingIndicator = val
            reloadPromise.set(true)
        },
        toggleAnonStories: { val in
            GhostModeManager.shared.hideStoryViews = val
            reloadPromise.set(true)
        },
        openGhostDetails: {
            pushControllerImpl?(ghostModeController(context: context))
        },
        toggleAntiDelete: { val in
            AntiDeleteManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        toggleAntiDeleteMedia: { val in
            AntiDeleteManager.shared.archiveMedia = val
            reloadPromise.set(true)
        },
        openDeletedHistory: {
            pushControllerImpl?(deletedMessagesController(context: context))
        },
        toggleHideStories: { val in
            SGSimpleSettings.shared.hideStories = val
            reloadPromise.set(true)
        },
        toggleWarnStories: { val in
            SGSimpleSettings.shared.warnOnStoriesOpen = val
            reloadPromise.set(true)
        },
        toggleBypassCopy: { val in
            SGSimpleSettings.shared.disableForwardRestriction = val
            reloadPromise.set(true)
        },
        toggleConfirmCalls: { val in
            SGSimpleSettings.shared.confirmCalls = val
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramPrivacyEntry] = []
        
        entries.append(.headerGhost(presentationData.theme, "РЕЖИМ ПРИЗРАКА (GHOST MODE)"))
        entries.append(.ghostMode(presentationData.theme, "Включить Режим призрака", GhostModeManager.shared.isEnabled))
        entries.append(.dontRead(presentationData.theme, "Не читать входящие сообщения", GhostModeManager.shared.hideReadReceipts))
        entries.append(.dontOnline(presentationData.theme, "Скрыть статус «В сети»", GhostModeManager.shared.hideOnlineStatus))
        entries.append(.dontTyping(presentationData.theme, "Скрыть статус набора текста", GhostModeManager.shared.hideTypingIndicator))
        entries.append(.anonStories(presentationData.theme, "Анонимный просмотр историй", GhostModeManager.shared.hideStoryViews))
        entries.append(.ghostDetails(presentationData.theme, "Все настройки Ghost Mode", "\(GhostModeManager.shared.activeFeatureCount)/5"))
        
        entries.append(.headerMessages(presentationData.theme, "СОХРАНЕНИЕ СООБЩЕНИЙ (ANTI-DELETE)"))
        entries.append(.antiDelete(presentationData.theme, "Сохранять удалённые сообщения", AntiDeleteManager.shared.isEnabled))
        entries.append(.antiDeleteMedia(presentationData.theme, "Сохранять удалённые медиа", AntiDeleteManager.shared.archiveMedia))
        entries.append(.deletedHistory(presentationData.theme, "Журнал удалённых сообщений", "Открыть"))
        
        entries.append(.headerStories(presentationData.theme, "ИСТОРИИ"))
        entries.append(.hideStories(presentationData.theme, "Скрыть истории", SGSimpleSettings.shared.hideStories))
        entries.append(.warnStories(presentationData.theme, "Предупреждать при открытии историй", SGSimpleSettings.shared.warnOnStoriesOpen))
        
        entries.append(.headerCalls(presentationData.theme, "ЗАЩИТА КОНТЕНТА И ЗВОНКИ"))
        entries.append(.bypassCopy(presentationData.theme, "Запрет копирования (обход No-Save)", SGSimpleSettings.shared.disableForwardRestriction))
        entries.append(.confirmCalls(presentationData.theme, "Подтверждение перед звонком", SGSimpleSettings.shared.confirmCalls))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Конфиденциальность"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

// MARK: - 4. Sub-Menu: BurmalgramToolsController

private enum BurmalgramToolsSection: Int32 {
    case spoofing
    case network
    case system
}

private enum BurmalgramToolsEntry: ItemListNodeEntry {
    case headerSpoofing(PresentationTheme, String)
    case deviceSpoof(PresentationTheme, String, String)
    case geoSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    
    case headerNetwork(PresentationTheme, String)
    case downloadSpeed(PresentationTheme, String, String)
    case uploadSpeed(PresentationTheme, String, Bool)
    case sendLargePhotos(PresentationTheme, String, Bool)
    case blockAds(PresentationTheme, String, Bool)
    
    case headerSystem(PresentationTheme, String)
    case filePickerFix(PresentationTheme, String, Bool)
    case clearCache(PresentationTheme, String, String)
    case resetSettings(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerSpoofing, .deviceSpoof, .geoSpoof, .voiceMorpher, .sendDelay:
            return BurmalgramToolsSection.spoofing.rawValue
        case .headerNetwork, .downloadSpeed, .uploadSpeed, .sendLargePhotos, .blockAds:
            return BurmalgramToolsSection.network.rawValue
        case .headerSystem, .filePickerFix, .clearCache, .resetSettings:
            return BurmalgramToolsSection.system.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerSpoofing: return 0
        case .deviceSpoof: return 1
        case .geoSpoof: return 2
        case .voiceMorpher: return 3
        case .sendDelay: return 4
        case .headerNetwork: return 10
        case .downloadSpeed: return 11
        case .uploadSpeed: return 12
        case .sendLargePhotos: return 13
        case .blockAds: return 14
        case .headerSystem: return 20
        case .filePickerFix: return 21
        case .clearCache: return 22
        case .resetSettings: return 23
        }
    }
    
    static func ==(lhs: BurmalgramToolsEntry, rhs: BurmalgramToolsEntry) -> Bool {
        switch lhs {
        case let .headerSpoofing(lhsTheme, lhsText):
            if case let .headerSpoofing(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
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
        case let .headerNetwork(lhsTheme, lhsText):
            if case let .headerNetwork(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .downloadSpeed(lhsTheme, lhsText, lhsValue):
            if case let .downloadSpeed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .uploadSpeed(lhsTheme, lhsText, lhsValue):
            if case let .uploadSpeed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .sendLargePhotos(lhsTheme, lhsText, lhsValue):
            if case let .sendLargePhotos(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .blockAds(lhsTheme, lhsText, lhsValue):
            if case let .blockAds(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerSystem(lhsTheme, lhsText):
            if case let .headerSystem(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .filePickerFix(lhsTheme, lhsText, lhsValue):
            if case let .filePickerFix(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .clearCache(lhsTheme, lhsText, lhsValue):
            if case let .clearCache(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .resetSettings(lhsTheme, lhsText, lhsValue):
            if case let .resetSettings(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramToolsEntry, rhs: BurmalgramToolsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramToolsArguments
        switch self {
        case let .headerSpoofing(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .deviceSpoof(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.devices, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openDeviceSpoof()
            })
        case let .geoSpoof(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.location, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openGeoSpoof()
            })
        case let .voiceMorpher(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.voices, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openVoiceMorpher()
            })
        case let .sendDelay(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.recentActions, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openSendDelay()
            })
        case let .headerNetwork(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .downloadSpeed(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.cycleDownloadSpeed()
            })
        case let .uploadSpeed(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleUploadSpeed(val)
            })
        case let .sendLargePhotos(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSendLargePhotos(val)
            })
        case let .blockAds(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleBlockAds(val)
            })
        case let .headerSystem(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .filePickerFix(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFilePickerFix(val)
            })
        case let .clearCache(_, text, _):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.clearCache()
            })
        case let .resetSettings(_, text, _):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.resetSettings()
            })
        }
    }
}

private final class BurmalgramToolsArguments {
    let openDeviceSpoof: () -> Void
    let openGeoSpoof: () -> Void
    let openVoiceMorpher: () -> Void
    let openSendDelay: () -> Void
    let cycleDownloadSpeed: () -> Void
    let toggleUploadSpeed: (Bool) -> Void
    let toggleSendLargePhotos: (Bool) -> Void
    let toggleBlockAds: (Bool) -> Void
    let toggleFilePickerFix: (Bool) -> Void
    let clearCache: () -> Void
    let resetSettings: () -> Void
    
    init(
        openDeviceSpoof: @escaping () -> Void,
        openGeoSpoof: @escaping () -> Void,
        openVoiceMorpher: @escaping () -> Void,
        openSendDelay: @escaping () -> Void,
        cycleDownloadSpeed: @escaping () -> Void,
        toggleUploadSpeed: @escaping (Bool) -> Void,
        toggleSendLargePhotos: @escaping (Bool) -> Void,
        toggleBlockAds: @escaping (Bool) -> Void,
        toggleFilePickerFix: @escaping (Bool) -> Void,
        clearCache: @escaping () -> Void,
        resetSettings: @escaping () -> Void
    ) {
        self.openDeviceSpoof = openDeviceSpoof
        self.openGeoSpoof = openGeoSpoof
        self.openVoiceMorpher = openVoiceMorpher
        self.openSendDelay = openSendDelay
        self.cycleDownloadSpeed = cycleDownloadSpeed
        self.toggleUploadSpeed = toggleUploadSpeed
        self.toggleSendLargePhotos = toggleSendLargePhotos
        self.toggleBlockAds = toggleBlockAds
        self.toggleFilePickerFix = toggleFilePickerFix
        self.clearCache = clearCache
        self.resetSettings = resetSettings
    }
}

public func burmalgramToolsController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramToolsArguments(
        openDeviceSpoof: {
            pushControllerImpl?(deviceSpoofController(context: context))
        },
        openGeoSpoof: {
            pushControllerImpl?(geoSpoofController(context: context))
        },
        openVoiceMorpher: {
            pushControllerImpl?(voiceMorpherController(context: context))
        },
        openSendDelay: {
            pushControllerImpl?(sendDelayController(context: context))
        },
        cycleDownloadSpeed: {
            let current = SGSimpleSettings.shared.downloadSpeedBoost
            let next: String
            switch current {
            case SGSimpleSettings.DownloadSpeedBoostValues.none.rawValue:
                next = SGSimpleSettings.DownloadSpeedBoostValues.medium.rawValue
            case SGSimpleSettings.DownloadSpeedBoostValues.medium.rawValue:
                next = SGSimpleSettings.DownloadSpeedBoostValues.maximum.rawValue
            default:
                next = SGSimpleSettings.DownloadSpeedBoostValues.none.rawValue
            }
            SGSimpleSettings.shared.downloadSpeedBoost = next
            reloadPromise.set(true)
        },
        toggleUploadSpeed: { val in
            SGSimpleSettings.shared.uploadSpeedBoost = val
            reloadPromise.set(true)
        },
        toggleSendLargePhotos: { val in
            SGSimpleSettings.shared.sendLargePhotos = val
            reloadPromise.set(true)
        },
        toggleBlockAds: { val in
            MiscSettingsManager.shared.blockAds = val
            MiscSettingsManager.shared.isEnabled = true
            reloadPromise.set(true)
        },
        toggleFilePickerFix: { val in
            SGSimpleSettings.shared.fixFilePicker = val
            reloadPromise.set(true)
        },
        clearCache: {
            let fileManager = FileManager.default
            let tmpDir = NSTemporaryDirectory()
            if let files = try? fileManager.contentsOfDirectory(atPath: tmpDir) {
                for file in files {
                    try? fileManager.removeItem(atPath: (tmpDir as NSString).appendingPathComponent(file))
                }
            }
            let alert = UIAlertController(title: "Кэш очищен", message: "Временные файлы и кэш успешно удалены.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(alert, animated: true, completion: nil)
            }
        },
        resetSettings: {
            let alert = UIAlertController(title: "Сброс настроек", message: "Вы уверены, что хотите сбросить все настройки Burmalgram на значения по умолчанию?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { _ in
                SGSimpleSettings.shared.fakePremium = false
                SGSimpleSettings.shared.customFont = "default"
                SGSimpleSettings.shared.customPhoneNumber = ""
                SGSimpleSettings.shared.burmalgramTheme = "default"
                SGSimpleSettings.shared.disableForwardRestriction = false
                SGSimpleSettings.shared.fixFilePicker = false
                SGSimpleSettings.shared.secondsInMessages = false
                SGSimpleSettings.shared.quickTranslateButton = false
                SGSimpleSettings.shared.hideRecordingButton = false
                SGSimpleSettings.shared.startTelescopeWithRearCam = false
                SGSimpleSettings.shared.compactChatList = false
                SGSimpleSettings.shared.wideTabBar = false
                SGSimpleSettings.shared.disableSnapDeletionEffect = false
                SGSimpleSettings.shared.downloadSpeedBoost = SGSimpleSettings.DownloadSpeedBoostValues.none.rawValue
                SGSimpleSettings.shared.uploadSpeedBoost = false
                SGSimpleSettings.shared.sendLargePhotos = false
                MiscSettingsManager.shared.blockAds = false
                GhostModeManager.shared.isEnabled = false
                AntiDeleteManager.shared.isEnabled = false
                DeviceSpoofManager.shared.isEnabled = false
                GeoSpoofManager.shared.isEnabled = false
                reloadPromise.set(true)
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(alert, animated: true, completion: nil)
            }
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramToolsEntry] = []
        
        entries.append(.headerSpoofing(presentationData.theme, "ПОДМЕНА ДАННЫХ"))
        entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства", DeviceSpoofManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.geoSpoof(presentationData.theme, "Фейковая геолокация (GPS)", GeoSpoofManager.shared.isEnabled ? GeoSpoofManager.shared.presetName : "Выкл"))
        entries.append(.voiceMorpher(presentationData.theme, "Голосовой морфер", VoiceMorpherManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.sendDelay(presentationData.theme, "Задержка отправки сообщений", SendDelayManager.shared.isEnabled ? "Вкл" : "Выкл"))
        
        entries.append(.headerNetwork(presentationData.theme, "СЕТЬ И ОПТИМИЗАЦИЯ"))
        let dlText: String
        switch SGSimpleSettings.shared.downloadSpeedBoost {
        case SGSimpleSettings.DownloadSpeedBoostValues.medium.rawValue:
            dlText = "Среднее"
        case SGSimpleSettings.DownloadSpeedBoostValues.maximum.rawValue:
            dlText = "Максимум"
        default:
            dlText = "Выкл"
        }
        entries.append(.downloadSpeed(presentationData.theme, "Ускорение загрузки", dlText))
        entries.append(.uploadSpeed(presentationData.theme, "Ускорение отдачи", SGSimpleSettings.shared.uploadSpeedBoost))
        entries.append(.sendLargePhotos(presentationData.theme, "Большие фото без сжатия (2560px)", SGSimpleSettings.shared.sendLargePhotos))
        entries.append(.blockAds(presentationData.theme, "Блокировка рекламы и промо-постов", MiscSettingsManager.shared.blockAds))
        
        entries.append(.headerSystem(presentationData.theme, "СИСТЕМА"))
        entries.append(.filePickerFix(presentationData.theme, "Исправление выбора файлов", SGSimpleSettings.shared.fixFilePicker))
        entries.append(.clearCache(presentationData.theme, "Очистить кэш базы данных и медиа", ""))
        entries.append(.resetSettings(presentationData.theme, "Сбросить настройки мода", ""))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Инструменты"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
