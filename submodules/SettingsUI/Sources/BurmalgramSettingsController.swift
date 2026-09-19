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

// MARK: - Font Selection Screen (Native Telegram Controller)

private enum BurmalgramFontSection: Int32 {
    case fonts
}

private enum BurmalgramFontEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
    case font(PresentationTheme, String, String, Bool)
    case footer(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return BurmalgramFontSection.fonts.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .font(_, key, _, _):
            for (i, opt) in burmalgramFontOptions.enumerated() {
                if opt.0 == key {
                    return Int32(1 + i)
                }
            }
            return 100
        case .footer:
            return 1000
        }
    }
    
    static func ==(lhs: BurmalgramFontEntry, rhs: BurmalgramFontEntry) -> Bool {
        switch lhs {
        case let .header(lhsTheme, lhsText):
            if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .font(lhsTheme, lhsKey, lhsTitle, lhsSelected):
            if case let .font(rhsTheme, rhsKey, rhsTitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsKey == rhsKey, lhsTitle == rhsTitle, lhsSelected == rhsSelected { return true }
            return false
        case let .footer(lhsTheme, lhsText):
            if case let .footer(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramFontEntry, rhs: BurmalgramFontEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramFontArguments
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .font(_, key, title, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                args.selectFont(key)
            })
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class BurmalgramFontArguments {
    let selectFont: (String) -> Void
    init(selectFont: @escaping (String) -> Void) {
        self.selectFont = selectFont
    }
}

public func burmalgramFontSelectionController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramFontArguments(
        selectFont: { key in
            SGSimpleSettings.shared.customFont = key
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current
            }).start()
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramFontEntry] = []
        entries.append(.header(presentationData.theme, "ВЫБЕРИТЕ ШРИФТ ИНТЕРФЕЙСА"))
        let currentFont = SGSimpleSettings.shared.customFont
        for (key, title) in burmalgramFontOptions {
            entries.append(.font(presentationData.theme, key, title, key == currentFont))
        }
        entries.append(.footer(presentationData.theme, "Выбранный шрифт применяется ко всему интерфейсу приложения мгновенно."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Шрифт интерфейса"),
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

// MARK: - Phone Editor Alert

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

// MARK: - Exclusive App Icon Themes

private func applyBurmalgramTheme(context: AccountContext, themeKey: String) {
    SGSimpleSettings.shared.burmalgramTheme = themeKey
    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
        var current = current
        
        let nightIndex = PresentationThemeReference.builtin(.night).index
        let nightAccentIndex = PresentationThemeReference.builtin(.nightAccent).index
        let dayIndex = PresentationThemeReference.builtin(.day).index
        let dayClassicIndex = PresentationThemeReference.builtin(.dayClassic).index
        
        var accents = current.themeSpecificAccentColors
        var wallpapers = current.themeSpecificChatWallpapers
        
        switch themeKey {
        case "neon": // ⚡ Cyber Neon (Неон) - neon.jpg
            let accentColor: UInt32 = 0x00B4FF
            let bubbleColors: [UInt32] = [0x006CE6, 0x0091FA, 0x00BCFF, 0x00E2FF]
            let wallpaper: TelegramWallpaper = .gradient(TelegramWallpaper.Gradient(
                id: nil,
                colors: [0x000F35, 0x00184D, 0x00246B, 0x001442],
                settings: WallpaperSettings(blur: false, motion: true, colors: [0x000F35, 0x00184D, 0x00246B, 0x001442], rotation: 45)
            ))
            SGSimpleSettings.shared.canUseNY = true
            SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.sparks.rawValue
            
            let accent = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            let coloredNightIndex = coloredThemeIndex(reference: .builtin(.night), accentColor: accent)
            let coloredNightAccentIndex = coloredThemeIndex(reference: .builtin(.nightAccent), accentColor: accent)
            accents[nightIndex] = accent
            accents[nightAccentIndex] = accent
            wallpapers[nightIndex] = wallpaper
            wallpapers[nightAccentIndex] = wallpaper
            wallpapers[coloredNightIndex] = wallpaper
            wallpapers[coloredNightAccentIndex] = wallpaper
            
            current.theme = .builtin(.night)
            var autoSwitch = current.automaticThemeSwitchSetting
            autoSwitch.theme = .builtin(.night)
            current.automaticThemeSwitchSetting = autoSwitch
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "titanium": // 🛡️ Titanium Metal (Титан) - titanium.jpg
            let accentColor: UInt32 = 0xD0D3DE
            let bubbleColors: [UInt32] = [0x5E6068, 0x7E808C, 0xA4A7B4, 0xD0D3DE]
            let wallpaper: TelegramWallpaper = .gradient(TelegramWallpaper.Gradient(
                id: nil,
                colors: [0x121214, 0x1A1B1F, 0x26282E, 0x151619],
                settings: WallpaperSettings(blur: false, motion: true, colors: [0x121214, 0x1A1B1F, 0x26282E, 0x151619], rotation: 90)
            ))
            SGSimpleSettings.shared.canUseNY = true
            SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.metal.rawValue
            
            let accent = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            let coloredNightIndex = coloredThemeIndex(reference: .builtin(.night), accentColor: accent)
            let coloredNightAccentIndex = coloredThemeIndex(reference: .builtin(.nightAccent), accentColor: accent)
            accents[nightIndex] = accent
            accents[nightAccentIndex] = accent
            wallpapers[nightIndex] = wallpaper
            wallpapers[nightAccentIndex] = wallpaper
            wallpapers[coloredNightIndex] = wallpaper
            wallpapers[coloredNightAccentIndex] = wallpaper
            
            current.theme = .builtin(.night)
            var autoSwitch = current.automaticThemeSwitchSetting
            autoSwitch.theme = .builtin(.night)
            current.automaticThemeSwitchSetting = autoSwitch
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "space", "midnight": // 🌌 Deep Space (Космос) - space.jpg
            let accentColor: UInt32 = 0x5B82B8
            let bubbleColors: [UInt32] = [0x223040, 0x2D3E52, 0x394E6B, 0x48648B]
            let wallpaper: TelegramWallpaper = .gradient(TelegramWallpaper.Gradient(
                id: nil,
                colors: [0x020716, 0x060B1C, 0x0C152B, 0x050917],
                settings: WallpaperSettings(blur: false, motion: true, colors: [0x020716, 0x060B1C, 0x0C152B, 0x050917], rotation: 120)
            ))
            SGSimpleSettings.shared.canUseNY = true
            SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.stars.rawValue
            
            let accent = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            let coloredNightIndex = coloredThemeIndex(reference: .builtin(.night), accentColor: accent)
            let coloredNightAccentIndex = coloredThemeIndex(reference: .builtin(.nightAccent), accentColor: accent)
            accents[nightIndex] = accent
            accents[nightAccentIndex] = accent
            wallpapers[nightIndex] = wallpaper
            wallpapers[nightAccentIndex] = wallpaper
            wallpapers[coloredNightIndex] = wallpaper
            wallpapers[coloredNightAccentIndex] = wallpaper
            
            current.theme = .builtin(.night)
            var autoSwitch = current.automaticThemeSwitchSetting
            autoSwitch.theme = .builtin(.night)
            current.automaticThemeSwitchSetting = autoSwitch
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        case "sparkling": // ✨ Sparkling Star (Сверкающая) - sparkling.jpg
            let accentColor: UInt32 = 0x0088FF
            let bubbleColors: [UInt32] = [0x0238FD, 0x0545FE, 0x0B94FE, 0x00D2FF]
            let wallpaper: TelegramWallpaper = .gradient(TelegramWallpaper.Gradient(
                id: nil,
                colors: [0x040514, 0x080A22, 0x0E1136, 0x050618],
                settings: WallpaperSettings(blur: false, motion: true, colors: [0x040514, 0x080A22, 0x0E1136, 0x050618], rotation: 60)
            ))
            SGSimpleSettings.shared.canUseNY = true
            SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.stars.rawValue
            
            let accent = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: accentColor, bubbleColors: bubbleColors, wallpaper: wallpaper)
            let coloredNightIndex = coloredThemeIndex(reference: .builtin(.night), accentColor: accent)
            let coloredNightAccentIndex = coloredThemeIndex(reference: .builtin(.nightAccent), accentColor: accent)
            accents[nightIndex] = accent
            accents[nightAccentIndex] = accent
            wallpapers[nightIndex] = wallpaper
            wallpapers[nightAccentIndex] = wallpaper
            wallpapers[coloredNightIndex] = wallpaper
            wallpapers[coloredNightAccentIndex] = wallpaper
            
            current.theme = .builtin(.night)
            var autoSwitch = current.automaticThemeSwitchSetting
            autoSwitch.theme = .builtin(.night)
            current.automaticThemeSwitchSetting = autoSwitch
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            
        default: // Reset to default Telegram
            SGSimpleSettings.shared.canUseNY = false
            SGSimpleSettings.shared.nyStyle = SGSimpleSettings.NYStyle.default.rawValue
            SGSimpleSettings.shared.burmalgramTheme = ""
            
            accents.removeValue(forKey: nightIndex)
            accents.removeValue(forKey: nightAccentIndex)
            accents.removeValue(forKey: dayIndex)
            accents.removeValue(forKey: dayClassicIndex)
            
            wallpapers.removeAll()
            
            current.themeSpecificAccentColors = accents
            current.themeSpecificChatWallpapers = wallpapers
            current.theme = .builtin(.nightAccent)
            var autoSwitch = current.automaticThemeSwitchSetting
            autoSwitch.theme = .builtin(.nightAccent)
            current.automaticThemeSwitchSetting = autoSwitch
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
    
    case headerQuick(PresentationTheme, String)
    case fakePremium(PresentationTheme, String, Bool)
    case ghostMode(PresentationTheme, String, Bool)
    case antiDelete(PresentationTheme, String, Bool)
    case customFont(PresentationTheme, String, String)
    
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerCategories, .customization, .privacy, .tools:
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
    let toggleFakePremium: (Bool) -> Void
    let toggleGhostMode: (Bool) -> Void
    let toggleAntiDelete: (Bool) -> Void
    let selectFont: () -> Void
    
    init(
        openCustomization: @escaping () -> Void,
        openPrivacy: @escaping () -> Void,
        openTools: @escaping () -> Void,
        toggleFakePremium: @escaping (Bool) -> Void,
        toggleGhostMode: @escaping (Bool) -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        selectFont: @escaping () -> Void
    ) {
        self.openCustomization = openCustomization
        self.openPrivacy = openPrivacy
        self.openTools = openTools
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
        toggleFakePremium: { val in
            SGSimpleSettings.shared.fakePremium = val
            let _ = context.account.postbox.transaction { transaction -> Void in
                if let peer = transaction.getPeer(context.account.peerId) as? TelegramUser {
                    var userFlags = peer.flags
                    if val {
                        userFlags.insert(.isPremium)
                    } else {
                        userFlags.remove(.isPremium)
                    }
                    updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedFlags(userFlags)], update: { _, updated in
                        return updated
                    })
                }
            }.start()
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
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
            pushControllerImpl?(burmalgramFontSelectionController(context: context))
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
        entries.append(.customization(presentationData.theme, "Кастомизация и оформление", "Темы, Шрифты, Premium, Папки"))
        entries.append(.privacy(presentationData.theme, "Конфиденциальность и Ghost", "Ghost Mode, Сообщения, Истории"))
        entries.append(.tools(presentationData.theme, "Инструменты и функции", "Спуфинг, Меню, Сеть, Система"))
        
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
    case tabsAndFolders
    case chatList
}

private enum BurmalgramCustomizationEntry: ItemListNodeEntry {
    case headerPremium(PresentationTheme, String)
    case fakePremium(PresentationTheme, String, Bool)
    case fakePremiumInfo(PresentationTheme, String)
    
    case headerThemes(PresentationTheme, String)
    case themeNeon(PresentationTheme, String, String)
    case themeTitanium(PresentationTheme, String, String)
    case themeSpace(PresentationTheme, String, String)
    case themeSparkling(PresentationTheme, String, String)
    case themeStandardPicker(PresentationTheme, String)
    case themeReset(PresentationTheme, String, String)
    case useDefaultThemeColors(PresentationTheme, String, Bool)
    case themeFooter(PresentationTheme, String)
    
    case headerVisuals(PresentationTheme, String)
    case customFont(PresentationTheme, String, String)
    case customPhone(PresentationTheme, String, String)
    case hidePhone(PresentationTheme, String, Bool)
    case showProfileId(PresentationTheme, String, Bool)
    case showDC(PresentationTheme, String, Bool)
    case showRegDate(PresentationTheme, String, Bool)
    case showCreationDate(PresentationTheme, String, Bool)
    
    case headerTabsAndFolders(PresentationTheme, String)
    case foldersAtBottom(PresentationTheme, String, Bool)
    case allChatsHidden(PresentationTheme, String, Bool)
    case compactFolderNames(PresentationTheme, String, Bool)
    case rememberLastFolder(PresentationTheme, String, Bool)
    case wideTabBar(PresentationTheme, String, Bool)
    case tabBarSearchEnabled(PresentationTheme, String, Bool)
    case hideTabBar(PresentationTheme, String, Bool)
    case showTabNames(PresentationTheme, String, Bool)
    
    case headerChatList(PresentationTheme, String)
    case compactChatList(PresentationTheme, String, Bool)
    case compactPreview(PresentationTheme, String, Bool)
    case disableChatSwipeOptions(PresentationTheme, String, Bool)
    case disableDeleteChatSwipeOption(PresentationTheme, String, Bool)
    case hideReactions(PresentationTheme, String, Bool)
    case wideChannelPosts(PresentationTheme, String, Bool)
    case hideChannelBottomButton(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .headerPremium, .fakePremium, .fakePremiumInfo:
            return BurmalgramCustomizationSection.premium.rawValue
        case .headerThemes, .themeNeon, .themeTitanium, .themeSpace, .themeSparkling, .themeStandardPicker, .themeReset, .useDefaultThemeColors, .themeFooter:
            return BurmalgramCustomizationSection.themes.rawValue
        case .headerVisuals, .customFont, .customPhone, .hidePhone, .showProfileId, .showDC, .showRegDate, .showCreationDate:
            return BurmalgramCustomizationSection.visuals.rawValue
        case .headerTabsAndFolders, .foldersAtBottom, .allChatsHidden, .compactFolderNames, .rememberLastFolder, .wideTabBar, .tabBarSearchEnabled, .hideTabBar, .showTabNames:
            return BurmalgramCustomizationSection.tabsAndFolders.rawValue
        case .headerChatList, .compactChatList, .compactPreview, .disableChatSwipeOptions, .disableDeleteChatSwipeOption, .hideReactions, .wideChannelPosts, .hideChannelBottomButton:
            return BurmalgramCustomizationSection.chatList.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerPremium: return 0
        case .fakePremium: return 1
        case .fakePremiumInfo: return 2
        
        case .headerThemes: return 10
        case .themeNeon: return 11
        case .themeTitanium: return 12
        case .themeSpace: return 13
        case .themeSparkling: return 14
        case .themeStandardPicker: return 15
        case .themeReset: return 16
        case .useDefaultThemeColors: return 17
        case .themeFooter: return 18
        
        case .headerVisuals: return 20
        case .customFont: return 21
        case .customPhone: return 22
        case .hidePhone: return 23
        case .showProfileId: return 24
        case .showDC: return 25
        case .showRegDate: return 26
        case .showCreationDate: return 27
        
        case .headerTabsAndFolders: return 30
        case .foldersAtBottom: return 31
        case .allChatsHidden: return 32
        case .compactFolderNames: return 33
        case .rememberLastFolder: return 34
        case .wideTabBar: return 35
        case .tabBarSearchEnabled: return 36
        case .hideTabBar: return 37
        case .showTabNames: return 38
        
        case .headerChatList: return 40
        case .compactChatList: return 41
        case .compactPreview: return 42
        case .disableChatSwipeOptions: return 43
        case .disableDeleteChatSwipeOption: return 44
        case .hideReactions: return 45
        case .wideChannelPosts: return 46
        case .hideChannelBottomButton: return 47
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
        case let .themeNeon(lhsTheme, lhsText, lhsValue):
            if case let .themeNeon(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeTitanium(lhsTheme, lhsText, lhsValue):
            if case let .themeTitanium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeSpace(lhsTheme, lhsText, lhsValue):
            if case let .themeSpace(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeSparkling(lhsTheme, lhsText, lhsValue):
            if case let .themeSparkling(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .themeStandardPicker(lhsTheme, lhsText):
            if case let .themeStandardPicker(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .themeReset(lhsTheme, lhsText, lhsValue):
            if case let .themeReset(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .useDefaultThemeColors(lhsTheme, lhsText, lhsValue):
            if case let .useDefaultThemeColors(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .showProfileId(lhsTheme, lhsText, lhsValue):
            if case let .showProfileId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showDC(lhsTheme, lhsText, lhsValue):
            if case let .showDC(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showRegDate(lhsTheme, lhsText, lhsValue):
            if case let .showRegDate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showCreationDate(lhsTheme, lhsText, lhsValue):
            if case let .showCreationDate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerTabsAndFolders(lhsTheme, lhsText):
            if case let .headerTabsAndFolders(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .foldersAtBottom(lhsTheme, lhsText, lhsValue):
            if case let .foldersAtBottom(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .allChatsHidden(lhsTheme, lhsText, lhsValue):
            if case let .allChatsHidden(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactFolderNames(lhsTheme, lhsText, lhsValue):
            if case let .compactFolderNames(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .rememberLastFolder(lhsTheme, lhsText, lhsValue):
            if case let .rememberLastFolder(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .wideTabBar(lhsTheme, lhsText, lhsValue):
            if case let .wideTabBar(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .tabBarSearchEnabled(lhsTheme, lhsText, lhsValue):
            if case let .tabBarSearchEnabled(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideTabBar(lhsTheme, lhsText, lhsValue):
            if case let .hideTabBar(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showTabNames(lhsTheme, lhsText, lhsValue):
            if case let .showTabNames(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerChatList(lhsTheme, lhsText):
            if case let .headerChatList(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .compactChatList(lhsTheme, lhsText, lhsValue):
            if case let .compactChatList(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactPreview(lhsTheme, lhsText, lhsValue):
            if case let .compactPreview(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableChatSwipeOptions(lhsTheme, lhsText, lhsValue):
            if case let .disableChatSwipeOptions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableDeleteChatSwipeOption(lhsTheme, lhsText, lhsValue):
            if case let .disableDeleteChatSwipeOption(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideReactions(lhsTheme, lhsText, lhsValue):
            if case let .hideReactions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .wideChannelPosts(lhsTheme, lhsText, lhsValue):
            if case let .wideChannelPosts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideChannelBottomButton(lhsTheme, lhsText, lhsValue):
            if case let .hideChannelBottomButton(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .themeNeon(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("neon")
            })
        case let .themeTitanium(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("titanium")
            })
        case let .themeSpace(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("space")
            })
        case let .themeSparkling(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("sparkling")
            })
        case let .themeStandardPicker(_, text):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.chatAppearance, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                args.openStandardThemes()
            })
        case let .themeReset(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.applyTheme("default")
            })
        case let .useDefaultThemeColors(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleUseDefaultThemeColors(val)
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
        case let .showProfileId(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowProfileId(val)
            })
        case let .showDC(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowDC(val)
            })
        case let .showRegDate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowRegDate(val)
            })
        case let .showCreationDate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowCreationDate(val)
            })
        case let .headerTabsAndFolders(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .foldersAtBottom(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFoldersAtBottom(val)
            })
        case let .allChatsHidden(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAllChatsHidden(val)
            })
        case let .compactFolderNames(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactFolderNames(val)
            })
        case let .rememberLastFolder(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleRememberLastFolder(val)
            })
        case let .wideTabBar(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleWideTabBar(val)
            })
        case let .tabBarSearchEnabled(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleTabBarSearchEnabled(val)
            })
        case let .hideTabBar(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideTabBar(val)
            })
        case let .showTabNames(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowTabNames(val)
            })
        case let .headerChatList(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .compactChatList(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactChatList(val)
            })
        case let .compactPreview(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactPreview(val)
            })
        case let .disableChatSwipeOptions(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableChatSwipeOptions(val)
            })
        case let .disableDeleteChatSwipeOption(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableDeleteChatSwipeOption(val)
            })
        case let .hideReactions(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideReactions(val)
            })
        case let .wideChannelPosts(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleWideChannelPosts(val)
            })
        case let .hideChannelBottomButton(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideChannelBottomButton(val)
            })
        }
    }
}

private final class BurmalgramCustomizationArguments {
    let toggleFakePremium: (Bool) -> Void
    let applyTheme: (String) -> Void
    let toggleUseDefaultThemeColors: (Bool) -> Void
    let openStandardThemes: () -> Void
    let selectFont: () -> Void
    let editCustomPhone: () -> Void
    let toggleHidePhone: (Bool) -> Void
    let toggleShowProfileId: (Bool) -> Void
    let toggleShowDC: (Bool) -> Void
    let toggleShowRegDate: (Bool) -> Void
    let toggleShowCreationDate: (Bool) -> Void
    let toggleFoldersAtBottom: (Bool) -> Void
    let toggleAllChatsHidden: (Bool) -> Void
    let toggleCompactFolderNames: (Bool) -> Void
    let toggleRememberLastFolder: (Bool) -> Void
    let toggleWideTabBar: (Bool) -> Void
    let toggleTabBarSearchEnabled: (Bool) -> Void
    let toggleHideTabBar: (Bool) -> Void
    let toggleShowTabNames: (Bool) -> Void
    let toggleCompactChatList: (Bool) -> Void
    let toggleCompactPreview: (Bool) -> Void
    let toggleDisableChatSwipeOptions: (Bool) -> Void
    let toggleDisableDeleteChatSwipeOption: (Bool) -> Void
    let toggleHideReactions: (Bool) -> Void
    let toggleWideChannelPosts: (Bool) -> Void
    let toggleHideChannelBottomButton: (Bool) -> Void
    
    init(
        toggleFakePremium: @escaping (Bool) -> Void,
        applyTheme: @escaping (String) -> Void,
        toggleUseDefaultThemeColors: @escaping (Bool) -> Void,
        openStandardThemes: @escaping () -> Void,
        selectFont: @escaping () -> Void,
        editCustomPhone: @escaping () -> Void,
        toggleHidePhone: @escaping (Bool) -> Void,
        toggleShowProfileId: @escaping (Bool) -> Void,
        toggleShowDC: @escaping (Bool) -> Void,
        toggleShowRegDate: @escaping (Bool) -> Void,
        toggleShowCreationDate: @escaping (Bool) -> Void,
        toggleFoldersAtBottom: @escaping (Bool) -> Void,
        toggleAllChatsHidden: @escaping (Bool) -> Void,
        toggleCompactFolderNames: @escaping (Bool) -> Void,
        toggleRememberLastFolder: @escaping (Bool) -> Void,
        toggleWideTabBar: @escaping (Bool) -> Void,
        toggleTabBarSearchEnabled: @escaping (Bool) -> Void,
        toggleHideTabBar: @escaping (Bool) -> Void,
        toggleShowTabNames: @escaping (Bool) -> Void,
        toggleCompactChatList: @escaping (Bool) -> Void,
        toggleCompactPreview: @escaping (Bool) -> Void,
        toggleDisableChatSwipeOptions: @escaping (Bool) -> Void,
        toggleDisableDeleteChatSwipeOption: @escaping (Bool) -> Void,
        toggleHideReactions: @escaping (Bool) -> Void,
        toggleWideChannelPosts: @escaping (Bool) -> Void,
        toggleHideChannelBottomButton: @escaping (Bool) -> Void
    ) {
        self.toggleFakePremium = toggleFakePremium
        self.applyTheme = applyTheme
        self.toggleUseDefaultThemeColors = toggleUseDefaultThemeColors
        self.openStandardThemes = openStandardThemes
        self.selectFont = selectFont
        self.editCustomPhone = editCustomPhone
        self.toggleHidePhone = toggleHidePhone
        self.toggleShowProfileId = toggleShowProfileId
        self.toggleShowDC = toggleShowDC
        self.toggleShowRegDate = toggleShowRegDate
        self.toggleShowCreationDate = toggleShowCreationDate
        self.toggleFoldersAtBottom = toggleFoldersAtBottom
        self.toggleAllChatsHidden = toggleAllChatsHidden
        self.toggleCompactFolderNames = toggleCompactFolderNames
        self.toggleRememberLastFolder = toggleRememberLastFolder
        self.toggleWideTabBar = toggleWideTabBar
        self.toggleTabBarSearchEnabled = toggleTabBarSearchEnabled
        self.toggleHideTabBar = toggleHideTabBar
        self.toggleShowTabNames = toggleShowTabNames
        self.toggleCompactChatList = toggleCompactChatList
        self.toggleCompactPreview = toggleCompactPreview
        self.toggleDisableChatSwipeOptions = toggleDisableChatSwipeOptions
        self.toggleDisableDeleteChatSwipeOption = toggleDisableDeleteChatSwipeOption
        self.toggleHideReactions = toggleHideReactions
        self.toggleWideChannelPosts = toggleWideChannelPosts
        self.toggleHideChannelBottomButton = toggleHideChannelBottomButton
    }
}

public func burmalgramCustomizationController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramCustomizationArguments(
        toggleFakePremium: { val in
            SGSimpleSettings.shared.fakePremium = val
            let _ = context.account.postbox.transaction { transaction -> Void in
                if let peer = transaction.getPeer(context.account.peerId) as? TelegramUser {
                    var userFlags = peer.flags
                    if val {
                        userFlags.insert(.isPremium)
                    } else {
                        userFlags.remove(.isPremium)
                    }
                    updatePeersCustom(transaction: transaction, peers: [peer.withUpdatedFlags(userFlags)], update: { _, updated in
                        return updated
                    })
                }
            }.start()
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
            reloadPromise.set(true)
        },
        applyTheme: { themeKey in
            applyBurmalgramTheme(context: context, themeKey: themeKey)
            reloadPromise.set(true)
        },
        toggleUseDefaultThemeColors: { val in
            SGSimpleSettings.shared.useDefaultThemeColors = val
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
            reloadPromise.set(true)
        },
        openStandardThemes: {
            pushControllerImpl?(themePickerController(context: context))
        },
        selectFont: {
            pushControllerImpl?(burmalgramFontSelectionController(context: context))
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
        toggleShowProfileId: { val in
            SGSimpleSettings.shared.showProfileId = val
            reloadPromise.set(true)
        },
        toggleShowDC: { val in
            SGSimpleSettings.shared.showDC = val
            reloadPromise.set(true)
        },
        toggleShowRegDate: { val in
            SGSimpleSettings.shared.showRegDate = val
            reloadPromise.set(true)
        },
        toggleShowCreationDate: { val in
            SGSimpleSettings.shared.showCreationDate = val
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
        toggleAllChatsHidden: { val in
            SGSimpleSettings.shared.allChatsHidden = val
            reloadPromise.set(true)
        },
        toggleCompactFolderNames: { val in
            SGSimpleSettings.shared.compactFolderNames = val
            reloadPromise.set(true)
        },
        toggleRememberLastFolder: { val in
            SGSimpleSettings.shared.rememberLastFolder = val
            reloadPromise.set(true)
        },
        toggleWideTabBar: { val in
            SGSimpleSettings.shared.wideTabBar = val
            reloadPromise.set(true)
        },
        toggleTabBarSearchEnabled: { val in
            SGSimpleSettings.shared.tabBarSearchEnabled = val
            reloadPromise.set(true)
        },
        toggleHideTabBar: { val in
            SGSimpleSettings.shared.hideTabBar = val
            reloadPromise.set(true)
        },
        toggleShowTabNames: { val in
            SGSimpleSettings.shared.showTabNames = val
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
        toggleDisableChatSwipeOptions: { val in
            SGSimpleSettings.shared.disableChatSwipeOptions = val
            reloadPromise.set(true)
        },
        toggleDisableDeleteChatSwipeOption: { val in
            SGSimpleSettings.shared.disableDeleteChatSwipeOption = val
            reloadPromise.set(true)
        },
        toggleHideReactions: { val in
            SGSimpleSettings.shared.hideReactions = val
            reloadPromise.set(true)
        },
        toggleWideChannelPosts: { val in
            SGSimpleSettings.shared.wideChannelPosts = val
            reloadPromise.set(true)
        },
        toggleHideChannelBottomButton: { val in
            SGSimpleSettings.shared.hideChannelBottomButton = val
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
        entries.append(.fakePremiumInfo(presentationData.theme, "100% локальный режим: значок Premium в профиле, цвета профиля и имени сохраняются локально без ошибок сервера, премиум-иконки, расширенные лимиты, распознавание речи и премиум-реакции."))
        
        let currentTheme = SGSimpleSettings.shared.burmalgramTheme
        entries.append(.headerThemes(presentationData.theme, "ЭКСКЛЮЗИВНЫЕ ТЕМЫ BURMALGRAM (ИЗ ДИЗАЙНА)"))
        entries.append(.themeNeon(presentationData.theme, "⚡ Неон (Cyber Neon)", currentTheme == "neon" ? "Активна" : ""))
        entries.append(.themeTitanium(presentationData.theme, "🛡️ Титан (Titanium Metal)", currentTheme == "titanium" ? "Активна" : ""))
        entries.append(.themeSpace(presentationData.theme, "🌌 Космос (Deep Space)", (currentTheme == "space" || currentTheme == "midnight") ? "Активна" : ""))
        entries.append(.themeSparkling(presentationData.theme, "✨ Сверкающая (Sparkling Star)", currentTheme == "sparkling" ? "Активна" : ""))
        entries.append(.themeStandardPicker(presentationData.theme, "🎨 Все стандартные темы Telegram..."))
        entries.append(.themeReset(presentationData.theme, "🔄 Сбросить тему (По умолчанию)", ""))
        entries.append(.useDefaultThemeColors(presentationData.theme, "Использовать цвета стандартных тем", SGSimpleSettings.shared.useDefaultThemeColors))
        entries.append(.themeFooter(presentationData.theme, "Анимированные частицы (мерцающие звезды, искры, переливы платины), гироскопный параллакс 3D и многоточечные градиенты сообщений и фона. При выключенном переключателе эксклюзивные темы принудительно заменяют стандартные цвета чатов Telegram."))
        
        entries.append(.headerVisuals(presentationData.theme, "ШРИФТ И ПРОФИЛЬ"))
        entries.append(.customFont(presentationData.theme, "Шрифт интерфейса", burmalgramFontDisplayName(SGSimpleSettings.shared.customFont)))
        let phoneText = SGSimpleSettings.shared.customPhoneNumber.isEmpty ? "Не задан" : SGSimpleSettings.shared.customPhoneNumber
        entries.append(.customPhone(presentationData.theme, "Кастомный номер (визуальный)", phoneText))
        entries.append(.hidePhone(presentationData.theme, "Скрыть номер в настройках", SGSimpleSettings.shared.hidePhoneInSettings))
        entries.append(.showProfileId(presentationData.theme, "Показывать ID в профиле", SGSimpleSettings.shared.showProfileId))
        entries.append(.showDC(presentationData.theme, "Показывать Дата-центр (DC)", SGSimpleSettings.shared.showDC))
        entries.append(.showRegDate(presentationData.theme, "Показывать дату регистрации", SGSimpleSettings.shared.showRegDate))
        entries.append(.showCreationDate(presentationData.theme, "Показывать дату создания аккаунта", SGSimpleSettings.shared.showCreationDate))
        
        entries.append(.headerTabsAndFolders(presentationData.theme, "ВКЛАДКИ И ПАПКИ"))
        entries.append(.foldersAtBottom(presentationData.theme, "Вкладки папок снизу", expSettings.foldersTabAtBottom))
        entries.append(.allChatsHidden(presentationData.theme, "Скрыть вкладку «Все чаты»", SGSimpleSettings.shared.allChatsHidden))
        entries.append(.compactFolderNames(presentationData.theme, "Компактные имена папок", SGSimpleSettings.shared.compactFolderNames))
        entries.append(.rememberLastFolder(presentationData.theme, "Запоминать последнюю папку", SGSimpleSettings.shared.rememberLastFolder))
        entries.append(.wideTabBar(presentationData.theme, "Широкая панель вкладок", SGSimpleSettings.shared.wideTabBar))
        entries.append(.tabBarSearchEnabled(presentationData.theme, "Кнопка поиска на панели вкладок", SGSimpleSettings.shared.tabBarSearchEnabled))
        entries.append(.hideTabBar(presentationData.theme, "Скрыть нижнюю панель вкладок", SGSimpleSettings.shared.hideTabBar))
        entries.append(.showTabNames(presentationData.theme, "Показывать подписи вкладок", SGSimpleSettings.shared.showTabNames))
        
        entries.append(.headerChatList(presentationData.theme, "СПИСОК ЧАТОВ И СООБЩЕНИЯ"))
        entries.append(.compactChatList(presentationData.theme, "Компактный список чатов", SGSimpleSettings.shared.compactChatList))
        entries.append(.compactPreview(presentationData.theme, "Однострочный предпросмотр сообщений", SGSimpleSettings.shared.chatListLines != SGSimpleSettings.ChatListLines.three.rawValue))
        entries.append(.disableChatSwipeOptions(presentationData.theme, "Отключить свайпы чатов", SGSimpleSettings.shared.disableChatSwipeOptions))
        entries.append(.disableDeleteChatSwipeOption(presentationData.theme, "Отключить свайп удаления чата", SGSimpleSettings.shared.disableDeleteChatSwipeOption))
        entries.append(.hideReactions(presentationData.theme, "Скрыть реакции под сообщениями", SGSimpleSettings.shared.hideReactions))
        entries.append(.wideChannelPosts(presentationData.theme, "Широкие посты в каналах", SGSimpleSettings.shared.wideChannelPosts))
        entries.append(.hideChannelBottomButton(presentationData.theme, "Скрыть кнопку перехода вниз канала", SGSimpleSettings.shared.hideChannelBottomButton))
        
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
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

// MARK: - 3. Sub-Menu: BurmalgramPrivacyController

private enum BurmalgramPrivacySection: Int32 {
    case ghost
    case messages
    case stories
    case callsAndSecurity
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
    case disableSwipeToRecordStory(PresentationTheme, String, Bool)
    case showRepostToStory(PresentationTheme, String, Bool)
    case storyStealthMode(PresentationTheme, String, Bool)
    
    case headerCallsAndSecurity(PresentationTheme, String)
    case bypassCopy(PresentationTheme, String, Bool)
    case confirmCalls(PresentationTheme, String, Bool)
    case enableVoipTcp(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .headerGhost, .ghostMode, .dontRead, .dontOnline, .dontTyping, .anonStories, .ghostDetails:
            return BurmalgramPrivacySection.ghost.rawValue
        case .headerMessages, .antiDelete, .antiDeleteMedia, .deletedHistory:
            return BurmalgramPrivacySection.messages.rawValue
        case .headerStories, .hideStories, .warnStories, .disableSwipeToRecordStory, .showRepostToStory, .storyStealthMode:
            return BurmalgramPrivacySection.stories.rawValue
        case .headerCallsAndSecurity, .bypassCopy, .confirmCalls, .enableVoipTcp:
            return BurmalgramPrivacySection.callsAndSecurity.rawValue
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
        case .disableSwipeToRecordStory: return 23
        case .showRepostToStory: return 24
        case .storyStealthMode: return 25
        
        case .headerCallsAndSecurity: return 30
        case .bypassCopy: return 31
        case .confirmCalls: return 32
        case .enableVoipTcp: return 33
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
        case let .disableSwipeToRecordStory(lhsTheme, lhsText, lhsValue):
            if case let .disableSwipeToRecordStory(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showRepostToStory(lhsTheme, lhsText, lhsValue):
            if case let .showRepostToStory(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .storyStealthMode(lhsTheme, lhsText, lhsValue):
            if case let .storyStealthMode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerCallsAndSecurity(lhsTheme, lhsText):
            if case let .headerCallsAndSecurity(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .bypassCopy(lhsTheme, lhsText, lhsValue):
            if case let .bypassCopy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .confirmCalls(lhsTheme, lhsText, lhsValue):
            if case let .confirmCalls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .enableVoipTcp(lhsTheme, lhsText, lhsValue):
            if case let .enableVoipTcp(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .disableSwipeToRecordStory(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSwipeToRecordStory(val)
            })
        case let .showRepostToStory(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowRepostToStory(val)
            })
        case let .storyStealthMode(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleStoryStealthMode(val)
            })
        case let .headerCallsAndSecurity(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .bypassCopy(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleBypassCopy(val)
            })
        case let .confirmCalls(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleConfirmCalls(val)
            })
        case let .enableVoipTcp(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleEnableVoipTcp(val)
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
    let toggleDisableSwipeToRecordStory: (Bool) -> Void
    let toggleShowRepostToStory: (Bool) -> Void
    let toggleStoryStealthMode: (Bool) -> Void
    let toggleBypassCopy: (Bool) -> Void
    let toggleConfirmCalls: (Bool) -> Void
    let toggleEnableVoipTcp: (Bool) -> Void
    
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
        toggleDisableSwipeToRecordStory: @escaping (Bool) -> Void,
        toggleShowRepostToStory: @escaping (Bool) -> Void,
        toggleStoryStealthMode: @escaping (Bool) -> Void,
        toggleBypassCopy: @escaping (Bool) -> Void,
        toggleConfirmCalls: @escaping (Bool) -> Void,
        toggleEnableVoipTcp: @escaping (Bool) -> Void
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
        self.toggleDisableSwipeToRecordStory = toggleDisableSwipeToRecordStory
        self.toggleShowRepostToStory = toggleShowRepostToStory
        self.toggleStoryStealthMode = toggleStoryStealthMode
        self.toggleBypassCopy = toggleBypassCopy
        self.toggleConfirmCalls = toggleConfirmCalls
        self.toggleEnableVoipTcp = toggleEnableVoipTcp
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
        toggleDisableSwipeToRecordStory: { val in
            SGSimpleSettings.shared.disableSwipeToRecordStory = val
            reloadPromise.set(true)
        },
        toggleShowRepostToStory: { val in
            SGSimpleSettings.shared.showRepostToStoryV2 = val
            reloadPromise.set(true)
        },
        toggleStoryStealthMode: { val in
            SGSimpleSettings.shared.storyStealthMode = val
            reloadPromise.set(true)
        },
        toggleBypassCopy: { val in
            SGSimpleSettings.shared.disableForwardRestriction = val
            reloadPromise.set(true)
        },
        toggleConfirmCalls: { val in
            SGSimpleSettings.shared.confirmCalls = val
            reloadPromise.set(true)
        },
        toggleEnableVoipTcp: { val in
            let _ = updateExperimentalUISettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.enableVoipTcp = val
                return settings
            }).start()
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
        
        entries.append(.headerStories(presentationData.theme, "ИСТОРИИ (STORIES)"))
        entries.append(.hideStories(presentationData.theme, "Скрыть истории", SGSimpleSettings.shared.hideStories))
        entries.append(.warnStories(presentationData.theme, "Предупреждать при открытии историй", SGSimpleSettings.shared.warnOnStoriesOpen))
        entries.append(.disableSwipeToRecordStory(presentationData.theme, "Запретить свайп для записи истории", SGSimpleSettings.shared.disableSwipeToRecordStory))
        entries.append(.showRepostToStory(presentationData.theme, "Кнопка «Репост в историю»", SGSimpleSettings.shared.showRepostToStoryV2))
        entries.append(.storyStealthMode(presentationData.theme, "Стелс-режим историй", SGSimpleSettings.shared.storyStealthMode))
        
        entries.append(.headerCallsAndSecurity(presentationData.theme, "ЗАЩИТА КОНТЕНТА И ЗВОНКИ"))
        entries.append(.bypassCopy(presentationData.theme, "Запрет копирования (обход No-Save)", SGSimpleSettings.shared.disableForwardRestriction))
        entries.append(.confirmCalls(presentationData.theme, "Подтверждение перед звонком", SGSimpleSettings.shared.confirmCalls))
        entries.append(.enableVoipTcp(presentationData.theme, "Принудительный TCP для звонков (VoIP TCP)", expSettings.enableVoipTcp))
        
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
    case messagingTools
    case contextMenu
    case network
    case system
}

private enum BurmalgramToolsEntry: ItemListNodeEntry {
    case headerSpoofing(PresentationTheme, String)
    case deviceSpoof(PresentationTheme, String, String)
    case geoSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    
    case headerMessagingTools(PresentationTheme, String)
    case secondsInMessages(PresentationTheme, String, Bool)
    case sendWithReturnKey(PresentationTheme, String, Bool)
    case messageDoubleTapAction(PresentationTheme, String, Bool)
    case defaultEmojisFirst(PresentationTheme, String, Bool)
    case forceEmojiTab(PresentationTheme, String, Bool)
    case quickTranslate(PresentationTheme, String, Bool)
    case hideRecording(PresentationTheme, String, Bool)
    case rearCam(PresentationTheme, String, Bool)
    case disableSnap(PresentationTheme, String, Bool)
    case disableSendAs(PresentationTheme, String, Bool)
    case disableScrollToNextChannel(PresentationTheme, String, Bool)
    case swipeForVideoPIP(PresentationTheme, String, Bool)
    
    case headerContextMenu(PresentationTheme, String)
    case contextShowSaveToCloud(PresentationTheme, String, Bool)
    case contextShowHideForwardName(PresentationTheme, String, Bool)
    case contextShowSelectFromUser(PresentationTheme, String, Bool)
    case contextShowRestrict(PresentationTheme, String, Bool)
    case contextShowReport(PresentationTheme, String, Bool)
    case contextShowReply(PresentationTheme, String, Bool)
    case contextShowPin(PresentationTheme, String, Bool)
    case contextShowSaveMedia(PresentationTheme, String, Bool)
    case contextShowMessageReplies(PresentationTheme, String, Bool)
    case contextShowJson(PresentationTheme, String, Bool)
    
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
        case .headerMessagingTools, .secondsInMessages, .sendWithReturnKey, .messageDoubleTapAction, .defaultEmojisFirst, .forceEmojiTab, .quickTranslate, .hideRecording, .rearCam, .disableSnap, .disableSendAs, .disableScrollToNextChannel, .swipeForVideoPIP:
            return BurmalgramToolsSection.messagingTools.rawValue
        case .headerContextMenu, .contextShowSaveToCloud, .contextShowHideForwardName, .contextShowSelectFromUser, .contextShowRestrict, .contextShowReport, .contextShowReply, .contextShowPin, .contextShowSaveMedia, .contextShowMessageReplies, .contextShowJson:
            return BurmalgramToolsSection.contextMenu.rawValue
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
        
        case .headerMessagingTools: return 10
        case .secondsInMessages: return 11
        case .sendWithReturnKey: return 12
        case .messageDoubleTapAction: return 13
        case .defaultEmojisFirst: return 14
        case .forceEmojiTab: return 15
        case .quickTranslate: return 16
        case .hideRecording: return 17
        case .rearCam: return 18
        case .disableSnap: return 19
        case .disableSendAs: return 20
        case .disableScrollToNextChannel: return 21
        case .swipeForVideoPIP: return 22
        
        case .headerContextMenu: return 30
        case .contextShowSaveToCloud: return 31
        case .contextShowHideForwardName: return 32
        case .contextShowSelectFromUser: return 33
        case .contextShowRestrict: return 34
        case .contextShowReport: return 35
        case .contextShowReply: return 36
        case .contextShowPin: return 37
        case .contextShowSaveMedia: return 38
        case .contextShowMessageReplies: return 39
        case .contextShowJson: return 40
        
        case .headerNetwork: return 50
        case .downloadSpeed: return 51
        case .uploadSpeed: return 52
        case .sendLargePhotos: return 53
        case .blockAds: return 54
        
        case .headerSystem: return 60
        case .filePickerFix: return 61
        case .clearCache: return 62
        case .resetSettings: return 63
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
        case let .headerMessagingTools(lhsTheme, lhsText):
            if case let .headerMessagingTools(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .secondsInMessages(lhsTheme, lhsText, lhsValue):
            if case let .secondsInMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .sendWithReturnKey(lhsTheme, lhsText, lhsValue):
            if case let .sendWithReturnKey(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .messageDoubleTapAction(lhsTheme, lhsText, lhsValue):
            if case let .messageDoubleTapAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .defaultEmojisFirst(lhsTheme, lhsText, lhsValue):
            if case let .defaultEmojisFirst(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .forceEmojiTab(lhsTheme, lhsText, lhsValue):
            if case let .forceEmojiTab(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .disableSnap(lhsTheme, lhsText, lhsValue):
            if case let .disableSnap(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableSendAs(lhsTheme, lhsText, lhsValue):
            if case let .disableSendAs(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableScrollToNextChannel(lhsTheme, lhsText, lhsValue):
            if case let .disableScrollToNextChannel(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .swipeForVideoPIP(lhsTheme, lhsText, lhsValue):
            if case let .swipeForVideoPIP(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .headerContextMenu(lhsTheme, lhsText):
            if case let .headerContextMenu(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .contextShowSaveToCloud(lhsTheme, lhsText, lhsValue):
            if case let .contextShowSaveToCloud(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowHideForwardName(lhsTheme, lhsText, lhsValue):
            if case let .contextShowHideForwardName(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowSelectFromUser(lhsTheme, lhsText, lhsValue):
            if case let .contextShowSelectFromUser(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowRestrict(lhsTheme, lhsText, lhsValue):
            if case let .contextShowRestrict(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowReport(lhsTheme, lhsText, lhsValue):
            if case let .contextShowReport(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowReply(lhsTheme, lhsText, lhsValue):
            if case let .contextShowReply(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowPin(lhsTheme, lhsText, lhsValue):
            if case let .contextShowPin(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowSaveMedia(lhsTheme, lhsText, lhsValue):
            if case let .contextShowSaveMedia(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowMessageReplies(lhsTheme, lhsText, lhsValue):
            if case let .contextShowMessageReplies(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .contextShowJson(lhsTheme, lhsText, lhsValue):
            if case let .contextShowJson(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .headerMessagingTools(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .secondsInMessages(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSeconds(val)
            })
        case let .sendWithReturnKey(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSendWithReturnKey(val)
            })
        case let .messageDoubleTapAction(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleMessageDoubleTapAction(val)
            })
        case let .defaultEmojisFirst(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDefaultEmojisFirst(val)
            })
        case let .forceEmojiTab(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleForceEmojiTab(val)
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
        case let .disableSnap(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSnap(val)
            })
        case let .disableSendAs(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSendAs(val)
            })
        case let .disableScrollToNextChannel(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableScrollToNextChannel(val)
            })
        case let .swipeForVideoPIP(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSwipeForVideoPIP(val)
            })
        case let .headerContextMenu(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .contextShowSaveToCloud(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextSaveToCloud(val)
            })
        case let .contextShowHideForwardName(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextHideForwardName(val)
            })
        case let .contextShowSelectFromUser(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextSelectFromUser(val)
            })
        case let .contextShowRestrict(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextRestrict(val)
            })
        case let .contextShowReport(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextReport(val)
            })
        case let .contextShowReply(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextReply(val)
            })
        case let .contextShowPin(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextPin(val)
            })
        case let .contextShowSaveMedia(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextSaveMedia(val)
            })
        case let .contextShowMessageReplies(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextMessageReplies(val)
            })
        case let .contextShowJson(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleContextJson(val)
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
    let toggleSeconds: (Bool) -> Void
    let toggleSendWithReturnKey: (Bool) -> Void
    let toggleMessageDoubleTapAction: (Bool) -> Void
    let toggleDefaultEmojisFirst: (Bool) -> Void
    let toggleForceEmojiTab: (Bool) -> Void
    let toggleTranslate: (Bool) -> Void
    let toggleHideRecording: (Bool) -> Void
    let toggleRearCam: (Bool) -> Void
    let toggleDisableSnap: (Bool) -> Void
    let toggleDisableSendAs: (Bool) -> Void
    let toggleDisableScrollToNextChannel: (Bool) -> Void
    let toggleSwipeForVideoPIP: (Bool) -> Void
    let toggleContextSaveToCloud: (Bool) -> Void
    let toggleContextHideForwardName: (Bool) -> Void
    let toggleContextSelectFromUser: (Bool) -> Void
    let toggleContextRestrict: (Bool) -> Void
    let toggleContextReport: (Bool) -> Void
    let toggleContextReply: (Bool) -> Void
    let toggleContextPin: (Bool) -> Void
    let toggleContextSaveMedia: (Bool) -> Void
    let toggleContextMessageReplies: (Bool) -> Void
    let toggleContextJson: (Bool) -> Void
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
        toggleSeconds: @escaping (Bool) -> Void,
        toggleSendWithReturnKey: @escaping (Bool) -> Void,
        toggleMessageDoubleTapAction: @escaping (Bool) -> Void,
        toggleDefaultEmojisFirst: @escaping (Bool) -> Void,
        toggleForceEmojiTab: @escaping (Bool) -> Void,
        toggleTranslate: @escaping (Bool) -> Void,
        toggleHideRecording: @escaping (Bool) -> Void,
        toggleRearCam: @escaping (Bool) -> Void,
        toggleDisableSnap: @escaping (Bool) -> Void,
        toggleDisableSendAs: @escaping (Bool) -> Void,
        toggleDisableScrollToNextChannel: @escaping (Bool) -> Void,
        toggleSwipeForVideoPIP: @escaping (Bool) -> Void,
        toggleContextSaveToCloud: @escaping (Bool) -> Void,
        toggleContextHideForwardName: @escaping (Bool) -> Void,
        toggleContextSelectFromUser: @escaping (Bool) -> Void,
        toggleContextRestrict: @escaping (Bool) -> Void,
        toggleContextReport: @escaping (Bool) -> Void,
        toggleContextReply: @escaping (Bool) -> Void,
        toggleContextPin: @escaping (Bool) -> Void,
        toggleContextSaveMedia: @escaping (Bool) -> Void,
        toggleContextMessageReplies: @escaping (Bool) -> Void,
        toggleContextJson: @escaping (Bool) -> Void,
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
        self.toggleSeconds = toggleSeconds
        self.toggleSendWithReturnKey = toggleSendWithReturnKey
        self.toggleMessageDoubleTapAction = toggleMessageDoubleTapAction
        self.toggleDefaultEmojisFirst = toggleDefaultEmojisFirst
        self.toggleForceEmojiTab = toggleForceEmojiTab
        self.toggleTranslate = toggleTranslate
        self.toggleHideRecording = toggleHideRecording
        self.toggleRearCam = toggleRearCam
        self.toggleDisableSnap = toggleDisableSnap
        self.toggleDisableSendAs = toggleDisableSendAs
        self.toggleDisableScrollToNextChannel = toggleDisableScrollToNextChannel
        self.toggleSwipeForVideoPIP = toggleSwipeForVideoPIP
        self.toggleContextSaveToCloud = toggleContextSaveToCloud
        self.toggleContextHideForwardName = toggleContextHideForwardName
        self.toggleContextSelectFromUser = toggleContextSelectFromUser
        self.toggleContextRestrict = toggleContextRestrict
        self.toggleContextReport = toggleContextReport
        self.toggleContextReply = toggleContextReply
        self.toggleContextPin = toggleContextPin
        self.toggleContextSaveMedia = toggleContextSaveMedia
        self.toggleContextMessageReplies = toggleContextMessageReplies
        self.toggleContextJson = toggleContextJson
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
        toggleSeconds: { val in
            SGSimpleSettings.shared.secondsInMessages = val
            reloadPromise.set(true)
        },
        toggleSendWithReturnKey: { val in
            SGSimpleSettings.shared.sendWithReturnKey = val
            reloadPromise.set(true)
        },
        toggleMessageDoubleTapAction: { val in
            SGSimpleSettings.shared.messageDoubleTapActionOutgoing = val ? SGSimpleSettings.MessageDoubleTapAction.edit.rawValue : SGSimpleSettings.MessageDoubleTapAction.default.rawValue
            reloadPromise.set(true)
        },
        toggleDefaultEmojisFirst: { val in
            SGSimpleSettings.shared.defaultEmojisFirst = val
            reloadPromise.set(true)
        },
        toggleForceEmojiTab: { val in
            SGSimpleSettings.shared.forceEmojiTab = val
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
        toggleDisableSnap: { val in
            SGSimpleSettings.shared.disableSnapDeletionEffect = val
            reloadPromise.set(true)
        },
        toggleDisableSendAs: { val in
            SGSimpleSettings.shared.disableSendAsButton = val
            reloadPromise.set(true)
        },
        toggleDisableScrollToNextChannel: { val in
            SGSimpleSettings.shared.disableScrollToNextChannel = val
            reloadPromise.set(true)
        },
        toggleSwipeForVideoPIP: { val in
            SGSimpleSettings.shared.videoPIPSwipeDirection = val ? SGSimpleSettings.VideoPIPSwipeDirection.up.rawValue : SGSimpleSettings.VideoPIPSwipeDirection.none.rawValue
            reloadPromise.set(true)
        },
        toggleContextSaveToCloud: { val in
            SGSimpleSettings.shared.contextShowSaveToCloud = val
            reloadPromise.set(true)
        },
        toggleContextHideForwardName: { val in
            SGSimpleSettings.shared.contextShowHideForwardName = val
            reloadPromise.set(true)
        },
        toggleContextSelectFromUser: { val in
            SGSimpleSettings.shared.contextShowSelectFromUser = val
            reloadPromise.set(true)
        },
        toggleContextRestrict: { val in
            SGSimpleSettings.shared.contextShowRestrict = val
            reloadPromise.set(true)
        },
        toggleContextReport: { val in
            SGSimpleSettings.shared.contextShowReport = val
            reloadPromise.set(true)
        },
        toggleContextReply: { val in
            SGSimpleSettings.shared.contextShowReply = val
            reloadPromise.set(true)
        },
        toggleContextPin: { val in
            SGSimpleSettings.shared.contextShowPin = val
            reloadPromise.set(true)
        },
        toggleContextSaveMedia: { val in
            SGSimpleSettings.shared.contextShowSaveMedia = val
            reloadPromise.set(true)
        },
        toggleContextMessageReplies: { val in
            SGSimpleSettings.shared.contextShowMessageReplies = val
            reloadPromise.set(true)
        },
        toggleContextJson: { val in
            SGSimpleSettings.shared.contextShowJson = val
            reloadPromise.set(true)
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
                let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
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
        
        entries.append(.headerSpoofing(presentationData.theme, "ПОДМЕНА ДАННЫХ (SPOOFING)"))
        entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства", DeviceSpoofManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.geoSpoof(presentationData.theme, "Фейковая геолокация (GPS)", GeoSpoofManager.shared.isEnabled ? GeoSpoofManager.shared.presetName : "Выкл"))
        entries.append(.voiceMorpher(presentationData.theme, "Голосовой морфер", VoiceMorpherManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.sendDelay(presentationData.theme, "Задержка отправки сообщений", SendDelayManager.shared.isEnabled ? "Вкл" : "Выкл"))
        
        entries.append(.headerMessagingTools(presentationData.theme, "СООБЩЕНИЯ И ВВОД"))
        entries.append(.secondsInMessages(presentationData.theme, "Секунды в сообщениях", SGSimpleSettings.shared.secondsInMessages))
        entries.append(.sendWithReturnKey(presentationData.theme, "Отправка по клавише Enter", SGSimpleSettings.shared.sendWithReturnKey))
        entries.append(.messageDoubleTapAction(presentationData.theme, "Двойной тап: редактировать сообщение", SGSimpleSettings.shared.messageDoubleTapActionOutgoing == SGSimpleSettings.MessageDoubleTapAction.edit.rawValue))
        entries.append(.defaultEmojisFirst(presentationData.theme, "Эмодзи первыми в панели", SGSimpleSettings.shared.defaultEmojisFirst))
        entries.append(.forceEmojiTab(presentationData.theme, "Принудительная вкладка эмодзи", SGSimpleSettings.shared.forceEmojiTab))
        entries.append(.quickTranslate(presentationData.theme, "Кнопка быстрого перевода", SGSimpleSettings.shared.quickTranslateButton))
        entries.append(.hideRecording(presentationData.theme, "Скрыть кнопку записи (микрофон)", SGSimpleSettings.shared.hideRecordingButton))
        entries.append(.rearCam(presentationData.theme, "Видеокружки с задней камеры", SGSimpleSettings.shared.startTelescopeWithRearCam))
        entries.append(.disableSnap(presentationData.theme, "Отключить эффект сгорания (Snap)", SGSimpleSettings.shared.disableSnapDeletionEffect))
        entries.append(.disableSendAs(presentationData.theme, "Отключить кнопку «Отправить как»", SGSimpleSettings.shared.disableSendAsButton))
        entries.append(.disableScrollToNextChannel(presentationData.theme, "Отключить переход к след. каналу", SGSimpleSettings.shared.disableScrollToNextChannel))
        entries.append(.swipeForVideoPIP(presentationData.theme, "PIP видео свайпом вверх", SGSimpleSettings.shared.videoPIPSwipeDirection == SGSimpleSettings.VideoPIPSwipeDirection.up.rawValue))
        
        entries.append(.headerContextMenu(presentationData.theme, "КОНТЕКСТНОЕ МЕНЮ СООБЩЕНИЙ"))
        entries.append(.contextShowSaveToCloud(presentationData.theme, "Сохранить в Избранное", SGSimpleSettings.shared.contextShowSaveToCloud))
        entries.append(.contextShowHideForwardName(presentationData.theme, "Переслать без имени автора", SGSimpleSettings.shared.contextShowHideForwardName))
        entries.append(.contextShowSelectFromUser(presentationData.theme, "Сообщения от пользователя", SGSimpleSettings.shared.contextShowSelectFromUser))
        entries.append(.contextShowRestrict(presentationData.theme, "Ограничить / Заблокировать", SGSimpleSettings.shared.contextShowRestrict))
        entries.append(.contextShowReport(presentationData.theme, "Пожаловаться", SGSimpleSettings.shared.contextShowReport))
        entries.append(.contextShowReply(presentationData.theme, "Ответить", SGSimpleSettings.shared.contextShowReply))
        entries.append(.contextShowPin(presentationData.theme, "Закрепить", SGSimpleSettings.shared.contextShowPin))
        entries.append(.contextShowSaveMedia(presentationData.theme, "Сохранить в файлы", SGSimpleSettings.shared.contextShowSaveMedia))
        entries.append(.contextShowMessageReplies(presentationData.theme, "Показать ветку комментариев", SGSimpleSettings.shared.contextShowMessageReplies))
        entries.append(.contextShowJson(presentationData.theme, "Показать JSON", SGSimpleSettings.shared.contextShowJson))
        
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
        entries.append(.downloadSpeed(presentationData.theme, "Ускорение загрузки файлов", dlText))
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
