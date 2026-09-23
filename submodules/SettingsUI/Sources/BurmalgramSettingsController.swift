import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SGSimpleSettings
import SGSettingsUI
import TelegramUIPreferences
import UndoUI

// MARK: - Font Utilities & Selection Screen

public let burmalgramFontOptions: [(String, String)] = [
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

public func burmalgramFontDisplayName(_ key: String) -> String {
    for (fontKey, title) in burmalgramFontOptions {
        if fontKey == key {
            return title
        }
    }
    return "По умолчанию"
}

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
            let previewFont = Font.fontForCustomFontKey(key, size: presentationData.fontSize.itemListBaseFontSize)
            return ItemListCheckboxItem(presentationData: presentationData, title: title, titleFont: previewFont, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
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

// MARK: - UI Helpers

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

private func presentChoiceSheet(
    title: String?,
    options: [(String, String)],
    current: String,
    onSelect: @escaping (String) -> Void
) {
    let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
    for (key, label) in options {
        let isSelected = (key == current)
        let actionTitle = isSelected ? "✓ \(label)" : label
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { _ in
            onSelect(key)
        }))
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
       let rootVC = window.rootViewController {
        if let popover = alert.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        rootVC.present(alert, animated: true, completion: nil)
    }
}

private func showBurmalgramToast(text: String, in controller: ViewController, context: AccountContext) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    controller.present(UndoOverlayController(
        presentationData: presentationData,
        content: .info(title: nil, text: text, timeout: nil, customUndoText: nil),
        elevatedLayout: false,
        action: { _ in return false }
    ), in: .current)
}

// MARK: - 1. Главный экран: BurmalgramSettingsController

private enum BurmalgramMainSection: Int32 {
    case categories
    case info
}

private enum BurmalgramMainEntry: ItemListNodeEntry {
    case headerCategories(PresentationTheme, String)
    case appearance(PresentationTheme, String, String)
    case privacy(PresentationTheme, String, String)
    case fakePremium(PresentationTheme, String, String)
    case chats(PresentationTheme, String, String)
    case media(PresentationTheme, String, String)
    case tdata(PresentationTheme, String, String)
    case network(PresentationTheme, String, String)
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerCategories, .appearance, .privacy, .fakePremium, .chats, .media, .tdata, .network:
            return BurmalgramMainSection.categories.rawValue
        case .info:
            return BurmalgramMainSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerCategories: return 0
        case .appearance: return 1
        case .privacy: return 2
        case .fakePremium: return 3
        case .chats: return 4
        case .media: return 5
        case .tdata: return 6
        case .network: return 7
        case .info: return 10
        }
    }
    
    static func ==(lhs: BurmalgramMainEntry, rhs: BurmalgramMainEntry) -> Bool {
        switch lhs {
        case let .headerCategories(lhsTheme, lhsText):
            if case let .headerCategories(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .appearance(lhsTheme, lhsText, lhsValue):
            if case let .appearance(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .privacy(lhsTheme, lhsText, lhsValue):
            if case let .privacy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .fakePremium(lhsTheme, lhsText, lhsValue):
            if case let .fakePremium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .chats(lhsTheme, lhsText, lhsValue):
            if case let .chats(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .media(lhsTheme, lhsText, lhsValue):
            if case let .media(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .tdata(lhsTheme, lhsText, lhsValue):
            if case let .tdata(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .network(lhsTheme, lhsText, lhsValue):
            if case let .network(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
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
        case let .appearance(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.appearance, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openAppearance()
            })
        case let .privacy(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.security, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openPrivacy()
            })
        case let .fakePremium(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.premium, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openFakePremium()
            })
        case let .chats(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.savedMessages, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openChats()
            })
        case let .media(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.videos, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openMedia()
            })
        case let .tdata(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.passkeys, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openTData()
            })
        case let .network(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.proxy, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openNetwork()
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class BurmalgramMainArguments {
    let openAppearance: () -> Void
    let openPrivacy: () -> Void
    let openFakePremium: () -> Void
    let openChats: () -> Void
    let openMedia: () -> Void
    let openTData: () -> Void
    let openNetwork: () -> Void
    
    init(
        openAppearance: @escaping () -> Void,
        openPrivacy: @escaping () -> Void,
        openFakePremium: @escaping () -> Void,
        openChats: @escaping () -> Void,
        openMedia: @escaping () -> Void,
        openTData: @escaping () -> Void,
        openNetwork: @escaping () -> Void
    ) {
        self.openAppearance = openAppearance
        self.openPrivacy = openPrivacy
        self.openFakePremium = openFakePremium
        self.openChats = openChats
        self.openMedia = openMedia
        self.openTData = openTData
        self.openNetwork = openNetwork
    }
}

public func burmalgramSettingsController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramMainArguments(
        openAppearance: {
            pushControllerImpl?(burmalgramAppearanceController(context: context))
        },
        openPrivacy: {
            pushControllerImpl?(burmalgramPrivacyController(context: context))
        },
        openFakePremium: {
            pushControllerImpl?(burmalgramFakePremiumController(context: context))
        },
        openChats: {
            pushControllerImpl?(burmalgramChatsController(context: context))
        },
        openMedia: {
            pushControllerImpl?(burmalgramMediaController(context: context))
        },
        openTData: {
            pushControllerImpl?(burmalgramTDataController(context: context))
        },
        openNetwork: {
            pushControllerImpl?(burmalgramNetworkController(context: context))
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramMainEntry] = []
        
        entries.append(.headerCategories(presentationData.theme, "КАТЕГОРИИ НАСТРОЕК EXTERAGRAM"))
        entries.append(.appearance(presentationData.theme, "Внешний вид", "Стиль, Pill Stack, Аватары"))
        entries.append(.privacy(presentationData.theme, "Конфиденциальность", "Ghost Mode, Анти-удаление"))
        entries.append(.fakePremium(presentationData.theme, "Fake Premium", SGSimpleSettings.shared.fakePremium ? "Включен" : "Выключен"))
        entries.append(.chats(presentationData.theme, "Чаты и сообщения", "Clean URLs, Перевод"))
        entries.append(.media(presentationData.theme, "Медиа и камера", "Качество, Камера, PIP"))
        entries.append(.tdata(presentationData.theme, "Сессии и TData", "Экспорт и импорт"))
        entries.append(.network(presentationData.theme, "Сеть и Спуфинг", "Ускорение, GPS, Девайс"))
        
        entries.append(.info(presentationData.theme, "Burmalgram • Стиль и архитектура exteraGram\nВсе настройки кастомизируются индивидуально без готовых тем."))
        
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

// MARK: - 2. Раздел: Внешний вид (BurmalgramAppearanceController)

private enum BurmalgramAppearanceSection: Int32 {
    case style
    case pillStack
    case messages
    case avatars
    case dividers
    case glass
    case navigation
    case hiddenElements
}

private enum BurmalgramAppearanceEntry: ItemListNodeEntry {
    case headerStyle(PresentationTheme, String)
    case exteraStyle(PresentationTheme, String, Bool)
    case fontSelection(PresentationTheme, String, String)
    case footerStyle(PresentationTheme, String)
    
    case headerPillStack(PresentationTheme, String)
    case pillStackToggle(PresentationTheme, String, Bool)
    case pillStackWeather(PresentationTheme, String, Bool)
    case pillStackCrypto(PresentationTheme, String, Bool)
    case pillStackCache(PresentationTheme, String, Bool)
    case pillStackProxy(PresentationTheme, String, Bool)
    case pillStackInfinite(PresentationTheme, String, Bool)
    case footerPillStack(PresentationTheme, String)
    
    case headerMessages(PresentationTheme, String)
    case removeMessageTail(PresentationTheme, String, Bool)
    case footerMessages(PresentationTheme, String)
    
    case headerAvatars(PresentationTheme, String)
    case avatarCorners(PresentationTheme, String, String)
    case footerAvatars(PresentationTheme, String)
    
    case headerDividers(PresentationTheme, String)
    case dividerStyle(PresentationTheme, String, String)
    case footerDividers(PresentationTheme, String)
    
    case headerGlass(PresentationTheme, String)
    case forceBlur(PresentationTheme, String, Bool)
    case glassOutlineStyle(PresentationTheme, String, String)
    case springAnimations(PresentationTheme, String, Bool)
    case footerGlass(PresentationTheme, String)
    
    case headerNavigation(PresentationTheme, String)
    case centerTitle(PresentationTheme, String, Bool)
    case compactFolderNames(PresentationTheme, String, Bool)
    case rememberLastFolder(PresentationTheme, String, Bool)
    case tabBarSearch(PresentationTheme, String, Bool)
    case footerNavigation(PresentationTheme, String)
    
    case headerHidden(PresentationTheme, String)
    case hideStories(PresentationTheme, String, Bool)
    case hideSearchBar(PresentationTheme, String, Bool)
    case allChatsHidden(PresentationTheme, String, Bool)
    case hideTabBar(PresentationTheme, String, Bool)
    case compactChatList(PresentationTheme, String, Bool)
    case hideReactions(PresentationTheme, String, Bool)
    case wideChannelPosts(PresentationTheme, String, Bool)
    case footerHidden(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerStyle, .exteraStyle, .fontSelection, .footerStyle:
            return BurmalgramAppearanceSection.style.rawValue
        case .headerPillStack, .pillStackToggle, .pillStackWeather, .pillStackCrypto, .pillStackCache, .pillStackProxy, .pillStackInfinite, .footerPillStack:
            return BurmalgramAppearanceSection.pillStack.rawValue
        case .headerMessages, .removeMessageTail, .footerMessages:
            return BurmalgramAppearanceSection.messages.rawValue
        case .headerAvatars, .avatarCorners, .footerAvatars:
            return BurmalgramAppearanceSection.avatars.rawValue
        case .headerDividers, .dividerStyle, .footerDividers:
            return BurmalgramAppearanceSection.dividers.rawValue
        case .headerGlass, .forceBlur, .glassOutlineStyle, .springAnimations, .footerGlass:
            return BurmalgramAppearanceSection.glass.rawValue
        case .headerNavigation, .centerTitle, .compactFolderNames, .rememberLastFolder, .tabBarSearch, .footerNavigation:
            return BurmalgramAppearanceSection.navigation.rawValue
        case .headerHidden, .hideStories, .hideSearchBar, .allChatsHidden, .hideTabBar, .compactChatList, .hideReactions, .wideChannelPosts, .footerHidden:
            return BurmalgramAppearanceSection.hiddenElements.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerStyle: return 0
        case .exteraStyle: return 1
        case .fontSelection: return 2
        case .footerStyle: return 3
            
        case .headerPillStack: return 10
        case .pillStackToggle: return 11
        case .pillStackWeather: return 12
        case .pillStackCrypto: return 13
        case .pillStackCache: return 14
        case .pillStackProxy: return 15
        case .pillStackInfinite: return 16
        case .footerPillStack: return 17
            
        case .headerMessages: return 20
        case .removeMessageTail: return 21
        case .footerMessages: return 22
            
        case .headerAvatars: return 30
        case .avatarCorners: return 31
        case .footerAvatars: return 32
            
        case .headerDividers: return 40
        case .dividerStyle: return 41
        case .footerDividers: return 42
            
        case .headerGlass: return 50
        case .forceBlur: return 51
        case .glassOutlineStyle: return 52
        case .springAnimations: return 53
        case .footerGlass: return 54
            
        case .headerNavigation: return 60
        case .centerTitle: return 61
        case .compactFolderNames: return 62
        case .rememberLastFolder: return 63
        case .tabBarSearch: return 64
        case .footerNavigation: return 65
            
        case .headerHidden: return 70
        case .hideStories: return 71
        case .hideSearchBar: return 72
        case .allChatsHidden: return 73
        case .hideTabBar: return 74
        case .compactChatList: return 75
        case .hideReactions: return 76
        case .wideChannelPosts: return 77
        case .footerHidden: return 78
        }
    }
    
    static func ==(lhs: BurmalgramAppearanceEntry, rhs: BurmalgramAppearanceEntry) -> Bool {
        switch lhs {
        case let .headerStyle(lhsTheme, lhsText):
            if case let .headerStyle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .exteraStyle(lhsTheme, lhsText, lhsValue):
            if case let .exteraStyle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .fontSelection(lhsTheme, lhsText, lhsValue):
            if case let .fontSelection(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerStyle(lhsTheme, lhsText):
            if case let .footerStyle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerPillStack(lhsTheme, lhsText):
            if case let .headerPillStack(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .pillStackToggle(lhsTheme, lhsText, lhsValue):
            if case let .pillStackToggle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pillStackWeather(lhsTheme, lhsText, lhsValue):
            if case let .pillStackWeather(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pillStackCrypto(lhsTheme, lhsText, lhsValue):
            if case let .pillStackCrypto(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pillStackCache(lhsTheme, lhsText, lhsValue):
            if case let .pillStackCache(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pillStackProxy(lhsTheme, lhsText, lhsValue):
            if case let .pillStackProxy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .pillStackInfinite(lhsTheme, lhsText, lhsValue):
            if case let .pillStackInfinite(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerPillStack(lhsTheme, lhsText):
            if case let .footerPillStack(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerMessages(lhsTheme, lhsText):
            if case let .headerMessages(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .removeMessageTail(lhsTheme, lhsText, lhsValue):
            if case let .removeMessageTail(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerMessages(lhsTheme, lhsText):
            if case let .footerMessages(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerAvatars(lhsTheme, lhsText):
            if case let .headerAvatars(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .avatarCorners(lhsTheme, lhsText, lhsValue):
            if case let .avatarCorners(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerAvatars(lhsTheme, lhsText):
            if case let .footerAvatars(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerDividers(lhsTheme, lhsText):
            if case let .headerDividers(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .dividerStyle(lhsTheme, lhsText, lhsValue):
            if case let .dividerStyle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerDividers(lhsTheme, lhsText):
            if case let .footerDividers(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerGlass(lhsTheme, lhsText):
            if case let .headerGlass(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .forceBlur(lhsTheme, lhsText, lhsValue):
            if case let .forceBlur(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .glassOutlineStyle(lhsTheme, lhsText, lhsValue):
            if case let .glassOutlineStyle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .springAnimations(lhsTheme, lhsText, lhsValue):
            if case let .springAnimations(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerGlass(lhsTheme, lhsText):
            if case let .footerGlass(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerNavigation(lhsTheme, lhsText):
            if case let .headerNavigation(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .centerTitle(lhsTheme, lhsText, lhsValue):
            if case let .centerTitle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactFolderNames(lhsTheme, lhsText, lhsValue):
            if case let .compactFolderNames(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .rememberLastFolder(lhsTheme, lhsText, lhsValue):
            if case let .rememberLastFolder(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .tabBarSearch(lhsTheme, lhsText, lhsValue):
            if case let .tabBarSearch(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerNavigation(lhsTheme, lhsText):
            if case let .footerNavigation(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerHidden(lhsTheme, lhsText):
            if case let .headerHidden(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .hideStories(lhsTheme, lhsText, lhsValue):
            if case let .hideStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideSearchBar(lhsTheme, lhsText, lhsValue):
            if case let .hideSearchBar(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .allChatsHidden(lhsTheme, lhsText, lhsValue):
            if case let .allChatsHidden(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideTabBar(lhsTheme, lhsText, lhsValue):
            if case let .hideTabBar(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .compactChatList(lhsTheme, lhsText, lhsValue):
            if case let .compactChatList(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideReactions(lhsTheme, lhsText, lhsValue):
            if case let .hideReactions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .wideChannelPosts(lhsTheme, lhsText, lhsValue):
            if case let .wideChannelPosts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerHidden(lhsTheme, lhsText):
            if case let .footerHidden(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramAppearanceEntry, rhs: BurmalgramAppearanceEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramAppearanceArguments
        switch self {
        case let .headerStyle(_, text), let .headerPillStack(_, text), let .headerMessages(_, text),
             let .headerAvatars(_, text), let .headerDividers(_, text), let .headerGlass(_, text),
             let .headerNavigation(_, text), let .headerHidden(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .exteraStyle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleExteraStyle(val)
            })
        case let .fontSelection(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openFontSelection()
            })
        case let .footerStyle(_, text), let .footerPillStack(_, text), let .footerMessages(_, text),
             let .footerAvatars(_, text), let .footerDividers(_, text), let .footerGlass(_, text),
             let .footerNavigation(_, text), let .footerHidden(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .pillStackToggle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStack(val)
            })
        case let .pillStackWeather(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStackWeather(val)
            })
        case let .pillStackCrypto(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStackCrypto(val)
            })
        case let .pillStackCache(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStackCache(val)
            })
        case let .pillStackProxy(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStackProxy(val)
            })
        case let .pillStackInfinite(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.togglePillStackInfinite(val)
            })
            
        case let .removeMessageTail(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleRemoveMessageTail(val)
            })
            
        case let .avatarCorners(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.selectAvatarCorners()
            })
            
        case let .dividerStyle(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.selectDividerStyle()
            })
            
        case let .forceBlur(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleForceBlur(val)
            })
        case let .glassOutlineStyle(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.selectGlassOutlineStyle()
            })
        case let .springAnimations(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSpringAnimations(val)
            })
            
        case let .centerTitle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCenterTitle(val)
            })
        case let .compactFolderNames(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactFolderNames(val)
            })
        case let .rememberLastFolder(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleRememberLastFolder(val)
            })
        case let .tabBarSearch(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleTabBarSearch(val)
            })
            
        case let .hideStories(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideStories(val)
            })
        case let .hideSearchBar(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideSearchBar(val)
            })
        case let .allChatsHidden(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAllChatsHidden(val)
            })
        case let .hideTabBar(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideTabBar(val)
            })
        case let .compactChatList(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCompactChatList(val)
            })
        case let .hideReactions(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideReactions(val)
            })
        case let .wideChannelPosts(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleWideChannelPosts(val)
            })
        }
    }
}

private final class BurmalgramAppearanceArguments {
    let toggleExteraStyle: (Bool) -> Void
    let openFontSelection: () -> Void
    let togglePillStack: (Bool) -> Void
    let togglePillStackWeather: (Bool) -> Void
    let togglePillStackCrypto: (Bool) -> Void
    let togglePillStackCache: (Bool) -> Void
    let togglePillStackProxy: (Bool) -> Void
    let togglePillStackInfinite: (Bool) -> Void
    let toggleRemoveMessageTail: (Bool) -> Void
    let selectAvatarCorners: () -> Void
    let selectDividerStyle: () -> Void
    let toggleForceBlur: (Bool) -> Void
    let selectGlassOutlineStyle: () -> Void
    let toggleSpringAnimations: (Bool) -> Void
    let toggleCenterTitle: (Bool) -> Void
    let toggleCompactFolderNames: (Bool) -> Void
    let toggleRememberLastFolder: (Bool) -> Void
    let toggleTabBarSearch: (Bool) -> Void
    let toggleHideStories: (Bool) -> Void
    let toggleHideSearchBar: (Bool) -> Void
    let toggleAllChatsHidden: (Bool) -> Void
    let toggleHideTabBar: (Bool) -> Void
    let toggleCompactChatList: (Bool) -> Void
    let toggleHideReactions: (Bool) -> Void
    let toggleWideChannelPosts: (Bool) -> Void
    
    init(
        toggleExteraStyle: @escaping (Bool) -> Void,
        openFontSelection: @escaping () -> Void,
        togglePillStack: @escaping (Bool) -> Void,
        togglePillStackWeather: @escaping (Bool) -> Void,
        togglePillStackCrypto: @escaping (Bool) -> Void,
        togglePillStackCache: @escaping (Bool) -> Void,
        togglePillStackProxy: @escaping (Bool) -> Void,
        togglePillStackInfinite: @escaping (Bool) -> Void,
        toggleRemoveMessageTail: @escaping (Bool) -> Void,
        selectAvatarCorners: @escaping () -> Void,
        selectDividerStyle: @escaping () -> Void,
        toggleForceBlur: @escaping (Bool) -> Void,
        selectGlassOutlineStyle: @escaping () -> Void,
        toggleSpringAnimations: @escaping (Bool) -> Void,
        toggleCenterTitle: @escaping (Bool) -> Void,
        toggleCompactFolderNames: @escaping (Bool) -> Void,
        toggleRememberLastFolder: @escaping (Bool) -> Void,
        toggleTabBarSearch: @escaping (Bool) -> Void,
        toggleHideStories: @escaping (Bool) -> Void,
        toggleHideSearchBar: @escaping (Bool) -> Void,
        toggleAllChatsHidden: @escaping (Bool) -> Void,
        toggleHideTabBar: @escaping (Bool) -> Void,
        toggleCompactChatList: @escaping (Bool) -> Void,
        toggleHideReactions: @escaping (Bool) -> Void,
        toggleWideChannelPosts: @escaping (Bool) -> Void
    ) {
        self.toggleExteraStyle = toggleExteraStyle
        self.openFontSelection = openFontSelection
        self.togglePillStack = togglePillStack
        self.togglePillStackWeather = togglePillStackWeather
        self.togglePillStackCrypto = togglePillStackCrypto
        self.togglePillStackCache = togglePillStackCache
        self.togglePillStackProxy = togglePillStackProxy
        self.togglePillStackInfinite = togglePillStackInfinite
        self.toggleRemoveMessageTail = toggleRemoveMessageTail
        self.selectAvatarCorners = selectAvatarCorners
        self.selectDividerStyle = selectDividerStyle
        self.toggleForceBlur = toggleForceBlur
        self.selectGlassOutlineStyle = selectGlassOutlineStyle
        self.toggleSpringAnimations = toggleSpringAnimations
        self.toggleCenterTitle = toggleCenterTitle
        self.toggleCompactFolderNames = toggleCompactFolderNames
        self.toggleRememberLastFolder = toggleRememberLastFolder
        self.toggleTabBarSearch = toggleTabBarSearch
        self.toggleHideStories = toggleHideStories
        self.toggleHideSearchBar = toggleHideSearchBar
        self.toggleAllChatsHidden = toggleAllChatsHidden
        self.toggleHideTabBar = toggleHideTabBar
        self.toggleCompactChatList = toggleCompactChatList
        self.toggleHideReactions = toggleHideReactions
        self.toggleWideChannelPosts = toggleWideChannelPosts
    }
}

public func burmalgramAppearanceController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = BurmalgramAppearanceArguments(
        toggleExteraStyle: { val in
            SGSimpleSettings.shared.exteraUiStyle = val ? "extera" : "ios"
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
            reloadPromise.set(true)
        },
        openFontSelection: {
            pushControllerImpl?(burmalgramFontSelectionController(context: context))
        },
        togglePillStack: { val in
            SGSimpleSettings.shared.pillStackEnabled = val
            reloadPromise.set(true)
        },
        togglePillStackWeather: { val in
            SGSimpleSettings.shared.pillStackShowWeather = val
            reloadPromise.set(true)
        },
        togglePillStackCrypto: { val in
            SGSimpleSettings.shared.pillStackShowCrypto = val
            reloadPromise.set(true)
        },
        togglePillStackCache: { val in
            SGSimpleSettings.shared.pillStackShowCache = val
            reloadPromise.set(true)
        },
        togglePillStackProxy: { val in
            SGSimpleSettings.shared.pillStackShowProxy = val
            reloadPromise.set(true)
        },
        togglePillStackInfinite: { val in
            SGSimpleSettings.shared.pillStackInfiniteScroll = val
            reloadPromise.set(true)
        },
        toggleRemoveMessageTail: { val in
            SGSimpleSettings.shared.removeMessageTail = val
            reloadPromise.set(true)
        },
        selectAvatarCorners: {
            let options = [
                ("squircle", "Сквиркл (exteraGram)"),
                ("circle", "Круглые (Классика)"),
                ("rounded", "Скругленные квадраты")
            ]
            presentChoiceSheet(
                title: "Форма аватаров",
                options: options,
                current: SGSimpleSettings.shared.avatarCorners,
                onSelect: { selected in
                    SGSimpleSettings.shared.avatarCorners = selected
                    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
                    reloadPromise.set(true)
                }
            )
        },
        selectDividerStyle: {
            let options = [
                ("hidden", "Скрыты (Минимализм)"),
                ("full", "Сплошная линия"),
                ("segmented", "Сегментированные")
            ]
            presentChoiceSheet(
                title: "Стиль разделителей",
                options: options,
                current: SGSimpleSettings.shared.dividerStyle,
                onSelect: { selected in
                    SGSimpleSettings.shared.dividerStyle = selected
                    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
                    reloadPromise.set(true)
                }
            )
        },
        toggleForceBlur: { val in
            SGSimpleSettings.shared.forceBlur = val
            reloadPromise.set(true)
        },
        selectGlassOutlineStyle: {
            let options = [
                ("glare", "Блики (Glare)"),
                ("sharp", "Четкая линия"),
                ("hidden", "Скрыта")
            ]
            presentChoiceSheet(
                title: "Стиль обводки стекла",
                options: options,
                current: SGSimpleSettings.shared.glassOutlineStyle,
                onSelect: { selected in
                    SGSimpleSettings.shared.glassOutlineStyle = selected
                    let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
                    reloadPromise.set(true)
                }
            )
        },
        toggleSpringAnimations: { val in
            SGSimpleSettings.shared.springAnimations = val
            reloadPromise.set(true)
        },
        toggleCenterTitle: { val in
            SGSimpleSettings.shared.centerTitle = val
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
        toggleTabBarSearch: { val in
            SGSimpleSettings.shared.tabBarSearchEnabled = val
            reloadPromise.set(true)
        },
        toggleHideStories: { val in
            SGSimpleSettings.shared.hideStories = val
            reloadPromise.set(true)
        },
        toggleHideSearchBar: { val in
            SGSimpleSettings.shared.hideDialogsSearchBar = val
            reloadPromise.set(true)
        },
        toggleAllChatsHidden: { val in
            SGSimpleSettings.shared.allChatsHidden = val
            reloadPromise.set(true)
        },
        toggleHideTabBar: { val in
            SGSimpleSettings.shared.hideTabBar = val
            reloadPromise.set(true)
        },
        toggleCompactChatList: { val in
            SGSimpleSettings.shared.compactChatList = val
            reloadPromise.set(true)
        },
        toggleHideReactions: { val in
            SGSimpleSettings.shared.hideReactions = val
            reloadPromise.set(true)
        },
        toggleWideChannelPosts: { val in
            SGSimpleSettings.shared.wideChannelPosts = val
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramAppearanceEntry] = []
        
        entries.append(.headerStyle(presentationData.theme, "СТИЛЬ ОФОРМЛЕНИЯ"))
        entries.append(.exteraStyle(presentationData.theme, "Минимализм exteraGram", SGSimpleSettings.shared.exteraUiStyle == "extera"))
        entries.append(.fontSelection(presentationData.theme, "Шрифт интерфейса", burmalgramFontDisplayName(SGSimpleSettings.shared.customFont)))
        entries.append(.footerStyle(presentationData.theme, "Фирменный стиль оформления exteraGram с плавными анимациями и современным расположением элементов."))
        
        entries.append(.headerPillStack(presentationData.theme, "ПАНЕЛЬ PILL STACK"))
        entries.append(.pillStackToggle(presentationData.theme, "Включить Pill Stack", SGSimpleSettings.shared.pillStackEnabled))
        if SGSimpleSettings.shared.pillStackEnabled {
            entries.append(.pillStackWeather(presentationData.theme, "Виджет Погоды", SGSimpleSettings.shared.pillStackShowWeather))
            entries.append(.pillStackCrypto(presentationData.theme, "Виджет Криптовалют (BTC/TON/USD)", SGSimpleSettings.shared.pillStackShowCrypto))
            entries.append(.pillStackCache(presentationData.theme, "Виджет очистки кэша", SGSimpleSettings.shared.pillStackShowCache))
            entries.append(.pillStackProxy(presentationData.theme, "Виджет прокси и пинга", SGSimpleSettings.shared.pillStackShowProxy))
            entries.append(.pillStackInfinite(presentationData.theme, "Бесконечная прокрутка", SGSimpleSettings.shared.pillStackInfiniteScroll))
        }
        entries.append(.footerPillStack(presentationData.theme, "Интерактивная панель виджетов над списком диалогов в стиле exteraGram."))
        
        entries.append(.headerMessages(presentationData.theme, "СООБЩЕНИЯ"))
        entries.append(.removeMessageTail(presentationData.theme, "Убрать хвостики сообщений", SGSimpleSettings.shared.removeMessageTail))
        entries.append(.footerMessages(presentationData.theme, "Отключает треугольные хвостики у пузырей сообщений."))
        
        entries.append(.headerAvatars(presentationData.theme, "ФОРМА АВАТАРОВ"))
        let avatarCornerTitle: String
        switch SGSimpleSettings.shared.avatarCorners {
        case "circle": avatarCornerTitle = "Круглые"
        case "rounded": avatarCornerTitle = "Скругленные квадраты"
        default: avatarCornerTitle = "Сквиркл"
        }
        entries.append(.avatarCorners(presentationData.theme, "Форма аватаров", avatarCornerTitle))
        entries.append(.footerAvatars(presentationData.theme, "Форма аватаров в диалогах, чатах и карточках профилей."))
        
        entries.append(.headerDividers(presentationData.theme, "РАЗДЕЛИТЕЛИ ЧАТОВ"))
        let dividerTitle: String
        switch SGSimpleSettings.shared.dividerStyle {
        case "full": dividerTitle = "Сплошная линия"
        case "segmented": dividerTitle = "Сегментированные"
        default: dividerTitle = "Скрыты"
        }
        entries.append(.dividerStyle(presentationData.theme, "Стиль разделителей", dividerTitle))
        entries.append(.footerDividers(presentationData.theme, "Отображение линий-разделителей между строками диалогов."))
        
        entries.append(.headerGlass(presentationData.theme, "СТЕКЛО И РАЗМЫТИЕ"))
        entries.append(.forceBlur(presentationData.theme, "Принудительное размытие (Force Blur)", SGSimpleSettings.shared.forceBlur))
        let glassTitle: String
        switch SGSimpleSettings.shared.glassOutlineStyle {
        case "sharp": glassTitle = "Четкая линия"
        case "hidden": glassTitle = "Скрыта"
        default: glassTitle = "Блики"
        }
        entries.append(.glassOutlineStyle(presentationData.theme, "Стиль обводки стекла", glassTitle))
        entries.append(.springAnimations(presentationData.theme, "Пружинные анимации", SGSimpleSettings.shared.springAnimations))
        entries.append(.footerGlass(presentationData.theme, "Эффекты матового стекла Liquid Glass и динамические пружинные переходы."))
        
        entries.append(.headerNavigation(presentationData.theme, "НАВИГАЦИЯ И ШАПКА"))
        entries.append(.centerTitle(presentationData.theme, "Заголовок по центру", SGSimpleSettings.shared.centerTitle))
        entries.append(.compactFolderNames(presentationData.theme, "Компактные имена папок", SGSimpleSettings.shared.compactFolderNames))
        entries.append(.rememberLastFolder(presentationData.theme, "Запоминать последнюю папку", SGSimpleSettings.shared.rememberLastFolder))
        entries.append(.tabBarSearch(presentationData.theme, "Поиск в таббаре", SGSimpleSettings.shared.tabBarSearchEnabled))
        entries.append(.footerNavigation(presentationData.theme, "Расположение и поведение вкладок чатов и навигационной панели."))
        
        entries.append(.headerHidden(presentationData.theme, "СКРЫТИЕ ЭЛЕМЕНТОВ"))
        entries.append(.hideStories(presentationData.theme, "Скрыть Истории сверху", SGSimpleSettings.shared.hideStories))
        entries.append(.hideSearchBar(presentationData.theme, "Скрыть строку поиска диалогов", SGSimpleSettings.shared.hideDialogsSearchBar))
        entries.append(.allChatsHidden(presentationData.theme, "Скрыть вкладку «Все чаты»", SGSimpleSettings.shared.allChatsHidden))
        entries.append(.hideTabBar(presentationData.theme, "Скрыть таббар", SGSimpleSettings.shared.hideTabBar))
        entries.append(.compactChatList(presentationData.theme, "Компактный список чатов", SGSimpleSettings.shared.compactChatList))
        entries.append(.hideReactions(presentationData.theme, "Скрыть реакции", SGSimpleSettings.shared.hideReactions))
        entries.append(.wideChannelPosts(presentationData.theme, "Посты на всю ширину каналов", SGSimpleSettings.shared.wideChannelPosts))
        entries.append(.footerHidden(presentationData.theme, "Индивидуальное скрытие ненужных визуальных блоков."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Внешний вид"),
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

// MARK: - 3. Раздел: Конфиденциальность (BurmalgramPrivacyController)

private enum BurmalgramPrivacySection: Int32 {
    case ghost
    case antiDelete
    case security
}

private enum BurmalgramPrivacyEntry: ItemListNodeEntry {
    case headerGhost(PresentationTheme, String)
    case ghostMaster(PresentationTheme, String, Bool)
    case ghostReadReceipts(PresentationTheme, String, Bool)
    case ghostOnline(PresentationTheme, String, Bool)
    case ghostOffline(PresentationTheme, String, Bool)
    case ghostTyping(PresentationTheme, String, Bool)
    case ghostStories(PresentationTheme, String, Bool)
    case footerGhost(PresentationTheme, String)
    
    case headerAntiDelete(PresentationTheme, String)
    case antiDeleteToggle(PresentationTheme, String, Bool)
    case antiDeleteMedia(PresentationTheme, String, Bool)
    case antiDeleteOwn(PresentationTheme, String, Bool)
    case footerAntiDelete(PresentationTheme, String)
    
    case headerSecurity(PresentationTheme, String)
    case disableForwardRestriction(PresentationTheme, String, Bool)
    case hidePhoneInSettings(PresentationTheme, String, Bool)
    case customPhone(PresentationTheme, String, String)
    case footerSecurity(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerGhost, .ghostMaster, .ghostReadReceipts, .ghostOnline, .ghostOffline, .ghostTyping, .ghostStories, .footerGhost:
            return BurmalgramPrivacySection.ghost.rawValue
        case .headerAntiDelete, .antiDeleteToggle, .antiDeleteMedia, .antiDeleteOwn, .footerAntiDelete:
            return BurmalgramPrivacySection.antiDelete.rawValue
        case .headerSecurity, .disableForwardRestriction, .hidePhoneInSettings, .customPhone, .footerSecurity:
            return BurmalgramPrivacySection.security.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerGhost: return 0
        case .ghostMaster: return 1
        case .ghostReadReceipts: return 2
        case .ghostOnline: return 3
        case .ghostOffline: return 4
        case .ghostTyping: return 5
        case .ghostStories: return 6
        case .footerGhost: return 7
            
        case .headerAntiDelete: return 10
        case .antiDeleteToggle: return 11
        case .antiDeleteMedia: return 12
        case .antiDeleteOwn: return 13
        case .footerAntiDelete: return 14
            
        case .headerSecurity: return 20
        case .disableForwardRestriction: return 21
        case .hidePhoneInSettings: return 22
        case .customPhone: return 23
        case .footerSecurity: return 24
        }
    }
    
    static func ==(lhs: BurmalgramPrivacyEntry, rhs: BurmalgramPrivacyEntry) -> Bool {
        switch lhs {
        case let .headerGhost(lhsTheme, lhsText):
            if case let .headerGhost(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .ghostMaster(lhsTheme, lhsText, lhsValue):
            if case let .ghostMaster(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostReadReceipts(lhsTheme, lhsText, lhsValue):
            if case let .ghostReadReceipts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostOnline(lhsTheme, lhsText, lhsValue):
            if case let .ghostOnline(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostOffline(lhsTheme, lhsText, lhsValue):
            if case let .ghostOffline(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostTyping(lhsTheme, lhsText, lhsValue):
            if case let .ghostTyping(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .ghostStories(lhsTheme, lhsText, lhsValue):
            if case let .ghostStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerGhost(lhsTheme, lhsText):
            if case let .footerGhost(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerAntiDelete(lhsTheme, lhsText):
            if case let .headerAntiDelete(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .antiDeleteToggle(lhsTheme, lhsText, lhsValue):
            if case let .antiDeleteToggle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .antiDeleteMedia(lhsTheme, lhsText, lhsValue):
            if case let .antiDeleteMedia(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .antiDeleteOwn(lhsTheme, lhsText, lhsValue):
            if case let .antiDeleteOwn(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerAntiDelete(lhsTheme, lhsText):
            if case let .footerAntiDelete(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerSecurity(lhsTheme, lhsText):
            if case let .headerSecurity(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .disableForwardRestriction(lhsTheme, lhsText, lhsValue):
            if case let .disableForwardRestriction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hidePhoneInSettings(lhsTheme, lhsText, lhsValue):
            if case let .hidePhoneInSettings(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .customPhone(lhsTheme, lhsText, lhsValue):
            if case let .customPhone(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerSecurity(lhsTheme, lhsText):
            if case let .footerSecurity(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramPrivacyEntry, rhs: BurmalgramPrivacyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramPrivacyArguments
        switch self {
        case let .headerGhost(_, text), let .headerAntiDelete(_, text), let .headerSecurity(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .ghostMaster(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostMaster(val)
            })
        case let .ghostReadReceipts(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostReadReceipts(val)
            })
        case let .ghostOnline(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostOnline(val)
            })
        case let .ghostOffline(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostOffline(val)
            })
        case let .ghostTyping(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostTyping(val)
            })
        case let .ghostStories(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleGhostStories(val)
            })
        case let .footerGhost(_, text), let .footerAntiDelete(_, text), let .footerSecurity(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .antiDeleteToggle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDelete(val)
            })
        case let .antiDeleteMedia(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDeleteMedia(val)
            })
        case let .antiDeleteOwn(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleAntiDeleteOwn(val)
            })
            
        case let .disableForwardRestriction(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableForwardRestriction(val)
            })
        case let .hidePhoneInSettings(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHidePhoneInSettings(val)
            })
        case let .customPhone(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.editCustomPhone()
            })
        }
    }
}

private final class BurmalgramPrivacyArguments {
    let toggleGhostMaster: (Bool) -> Void
    let toggleGhostReadReceipts: (Bool) -> Void
    let toggleGhostOnline: (Bool) -> Void
    let toggleGhostOffline: (Bool) -> Void
    let toggleGhostTyping: (Bool) -> Void
    let toggleGhostStories: (Bool) -> Void
    let toggleAntiDelete: (Bool) -> Void
    let toggleAntiDeleteMedia: (Bool) -> Void
    let toggleAntiDeleteOwn: (Bool) -> Void
    let toggleDisableForwardRestriction: (Bool) -> Void
    let toggleHidePhoneInSettings: (Bool) -> Void
    let editCustomPhone: () -> Void
    
    init(
        toggleGhostMaster: @escaping (Bool) -> Void,
        toggleGhostReadReceipts: @escaping (Bool) -> Void,
        toggleGhostOnline: @escaping (Bool) -> Void,
        toggleGhostOffline: @escaping (Bool) -> Void,
        toggleGhostTyping: @escaping (Bool) -> Void,
        toggleGhostStories: @escaping (Bool) -> Void,
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleAntiDeleteMedia: @escaping (Bool) -> Void,
        toggleAntiDeleteOwn: @escaping (Bool) -> Void,
        toggleDisableForwardRestriction: @escaping (Bool) -> Void,
        toggleHidePhoneInSettings: @escaping (Bool) -> Void,
        editCustomPhone: @escaping () -> Void
    ) {
        self.toggleGhostMaster = toggleGhostMaster
        self.toggleGhostReadReceipts = toggleGhostReadReceipts
        self.toggleGhostOnline = toggleGhostOnline
        self.toggleGhostOffline = toggleGhostOffline
        self.toggleGhostTyping = toggleGhostTyping
        self.toggleGhostStories = toggleGhostStories
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleAntiDeleteMedia = toggleAntiDeleteMedia
        self.toggleAntiDeleteOwn = toggleAntiDeleteOwn
        self.toggleDisableForwardRestriction = toggleDisableForwardRestriction
        self.toggleHidePhoneInSettings = toggleHidePhoneInSettings
        self.editCustomPhone = editCustomPhone
    }
}

public func burmalgramPrivacyController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramPrivacyArguments(
        toggleGhostMaster: { val in
            GhostModeManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        toggleGhostReadReceipts: { val in
            GhostModeManager.shared.hideReadReceipts = val
            reloadPromise.set(true)
        },
        toggleGhostOnline: { val in
            GhostModeManager.shared.hideOnlineStatus = val
            reloadPromise.set(true)
        },
        toggleGhostOffline: { val in
            GhostModeManager.shared.forceOffline = val
            reloadPromise.set(true)
        },
        toggleGhostTyping: { val in
            GhostModeManager.shared.hideTypingIndicator = val
            reloadPromise.set(true)
        },
        toggleGhostStories: { val in
            GhostModeManager.shared.hideStoryViews = val
            SGSimpleSettings.shared.storyStealthMode = val
            reloadPromise.set(true)
        },
        toggleAntiDelete: { val in
            AntiDeleteManager.shared.isEnabled = val
            reloadPromise.set(true)
        },
        toggleAntiDeleteMedia: { val in
            AntiDeleteManager.shared.archiveMedia = val
            reloadPromise.set(true)
        },
        toggleAntiDeleteOwn: { val in
            AntiDeleteManager.shared.showOwnDeletedMessages = val
            reloadPromise.set(true)
        },
        toggleDisableForwardRestriction: { val in
            SGSimpleSettings.shared.disableForwardRestriction = val
            reloadPromise.set(true)
        },
        toggleHidePhoneInSettings: { val in
            SGSimpleSettings.shared.hidePhoneInSettings = val
            reloadPromise.set(true)
        },
        editCustomPhone: {
            presentBurmalgramPhoneEditor(context: context, onComplete: {
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
        var entries: [BurmalgramPrivacyEntry] = []
        
        entries.append(.headerGhost(presentationData.theme, "GHOST MODE (НЕЧИТАЛКА)"))
        entries.append(.ghostMaster(presentationData.theme, "Ghost Mode (Мастер-переключатель)", GhostModeManager.shared.isEnabled))
        if GhostModeManager.shared.isEnabled {
            entries.append(.ghostReadReceipts(presentationData.theme, "Не отправлять отметку о прочтении", GhostModeManager.shared.hideReadReceipts))
            entries.append(.ghostOnline(presentationData.theme, "Скрыть статус «В сети»", GhostModeManager.shared.hideOnlineStatus))
            entries.append(.ghostOffline(presentationData.theme, "Всегда оффлайн (Force Offline)", GhostModeManager.shared.forceOffline))
            entries.append(.ghostTyping(presentationData.theme, "Скрыть статус набора текста", GhostModeManager.shared.hideTypingIndicator))
            entries.append(.ghostStories(presentationData.theme, "Скрытный просмотр историй", GhostModeManager.shared.hideStoryViews))
        }
        entries.append(.footerGhost(presentationData.theme, "Ghost Mode позволяет читать сообщения, смотреть истории и находиться онлайн полностью незаметно для других пользователей."))
        
        entries.append(.headerAntiDelete(presentationData.theme, "АНТИ-УДАЛЕНИЕ СООБЩЕНИЙ"))
        entries.append(.antiDeleteToggle(presentationData.theme, "Сохранять удалённые сообщения", AntiDeleteManager.shared.isEnabled))
        if AntiDeleteManager.shared.isEnabled {
            entries.append(.antiDeleteMedia(presentationData.theme, "Сохранять медиафайлы сообщений", AntiDeleteManager.shared.archiveMedia))
            entries.append(.antiDeleteOwn(presentationData.theme, "Показывать свои удалённые сообщения", AntiDeleteManager.shared.showOwnDeletedMessages))
        }
        entries.append(.footerAntiDelete(presentationData.theme, "Удалённые собеседником сообщения сохраняются в локальной базе и помечаются специальным значком корзины."))
        
        entries.append(.headerSecurity(presentationData.theme, "БЕЗОПАСНОСТЬ И КОНТЕНТ"))
        entries.append(.disableForwardRestriction(presentationData.theme, "Снять запрет на скриншоты и пересылку", SGSimpleSettings.shared.disableForwardRestriction))
        entries.append(.hidePhoneInSettings(presentationData.theme, "Скрыть номер телефона в настройках", SGSimpleSettings.shared.hidePhoneInSettings))
        let phoneText = SGSimpleSettings.shared.customPhoneNumber.isEmpty ? "Не задан" : SGSimpleSettings.shared.customPhoneNumber
        entries.append(.customPhone(presentationData.theme, "Кастомный номер телефона", phoneText))
        entries.append(.footerSecurity(presentationData.theme, "Обход ограничений защиты контента (noforwards) в защищенных каналах и секретных чатах."))
        
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
    return controller
}

// MARK: - 4. Раздел: Fake Premium (BurmalgramFakePremiumController)

private enum BurmalgramFakePremiumSection: Int32 {
    case master
    case features
}

private enum BurmalgramFakePremiumEntry: ItemListNodeEntry {
    case headerMaster(PresentationTheme, String)
    case masterToggle(PresentationTheme, String, Bool)
    case hideBadgeToggle(PresentationTheme, String, Bool)
    case footerMaster(PresentationTheme, String)
    
    case headerFeatures(PresentationTheme, String)
    case voiceToText(PresentationTheme, String, Bool)
    case premiumReactions(PresentationTheme, String, Bool)
    case premiumColors(PresentationTheme, String, Bool)
    case footerFeatures(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerMaster, .masterToggle, .hideBadgeToggle, .footerMaster:
            return BurmalgramFakePremiumSection.master.rawValue
        case .headerFeatures, .voiceToText, .premiumReactions, .premiumColors, .footerFeatures:
            return BurmalgramFakePremiumSection.features.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerMaster: return 0
        case .masterToggle: return 1
        case .hideBadgeToggle: return 2
        case .footerMaster: return 3
            
        case .headerFeatures: return 10
        case .voiceToText: return 11
        case .premiumReactions: return 12
        case .premiumColors: return 13
        case .footerFeatures: return 14
        }
    }
    
    static func ==(lhs: BurmalgramFakePremiumEntry, rhs: BurmalgramFakePremiumEntry) -> Bool {
        switch lhs {
        case let .headerMaster(lhsTheme, lhsText):
            if case let .headerMaster(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .masterToggle(lhsTheme, lhsText, lhsValue):
            if case let .masterToggle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .hideBadgeToggle(lhsTheme, lhsText, lhsValue):
            if case let .hideBadgeToggle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerMaster(lhsTheme, lhsText):
            if case let .footerMaster(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerFeatures(lhsTheme, lhsText):
            if case let .headerFeatures(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .voiceToText(lhsTheme, lhsText, lhsValue):
            if case let .voiceToText(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .premiumReactions(lhsTheme, lhsText, lhsValue):
            if case let .premiumReactions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .premiumColors(lhsTheme, lhsText, lhsValue):
            if case let .premiumColors(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerFeatures(lhsTheme, lhsText):
            if case let .footerFeatures(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramFakePremiumEntry, rhs: BurmalgramFakePremiumEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramFakePremiumArguments
        switch self {
        case let .headerMaster(_, text), let .headerFeatures(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .masterToggle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleMaster(val)
            })
        case let .hideBadgeToggle(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideBadge(val)
            })
        case let .footerMaster(_, text), let .footerFeatures(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .voiceToText(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleVoiceToText(val)
            })
        case let .premiumReactions(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleReactions(val)
            })
        case let .premiumColors(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleColors(val)
            })
        }
    }
}

private final class BurmalgramFakePremiumArguments {
    let toggleMaster: (Bool) -> Void
    let toggleHideBadge: (Bool) -> Void
    let toggleVoiceToText: (Bool) -> Void
    let toggleReactions: (Bool) -> Void
    let toggleColors: (Bool) -> Void
    
    init(
        toggleMaster: @escaping (Bool) -> Void,
        toggleHideBadge: @escaping (Bool) -> Void,
        toggleVoiceToText: @escaping (Bool) -> Void,
        toggleReactions: @escaping (Bool) -> Void,
        toggleColors: @escaping (Bool) -> Void
    ) {
        self.toggleMaster = toggleMaster
        self.toggleHideBadge = toggleHideBadge
        self.toggleVoiceToText = toggleVoiceToText
        self.toggleReactions = toggleReactions
        self.toggleColors = toggleColors
    }
}

public func burmalgramFakePremiumController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramFakePremiumArguments(
        toggleMaster: { val in
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
        toggleHideBadge: { val in
            SGSimpleSettings.shared.fakePremiumShowBadge = val
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
            reloadPromise.set(true)
        },
        toggleVoiceToText: { val in
            SGSimpleSettings.shared.fakePremiumVoiceToText = val
            reloadPromise.set(true)
        },
        toggleReactions: { val in
            SGSimpleSettings.shared.fakePremiumReactions = val
            reloadPromise.set(true)
        },
        toggleColors: { val in
            SGSimpleSettings.shared.fakePremiumColors = val
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramFakePremiumEntry] = []
        
        entries.append(.headerMaster(presentationData.theme, "FAKE PREMIUM"))
        entries.append(.masterToggle(presentationData.theme, "Fake Premium (Мастер-переключатель)", SGSimpleSettings.shared.fakePremium))
        entries.append(.hideBadgeToggle(presentationData.theme, "Скрыть значок звезды у ника", SGSimpleSettings.shared.fakePremiumShowBadge))
        entries.append(.footerMaster(presentationData.theme, "Тумблер «Скрыть значок звезды у ника» позволяет полностью убрать эмодзи или звезду около вашего имени в профиле и чатах, сохраняя все премиум-возможности активными."))
        
        entries.append(.headerFeatures(presentationData.theme, "ВОЗМОЖНОСТИ FAKE PREMIUM"))
        entries.append(.voiceToText(presentationData.theme, "Расшифровка голосовых (Voice-to-Text)", SGSimpleSettings.shared.fakePremiumVoiceToText))
        entries.append(.premiumReactions(presentationData.theme, "Премиум-реакции на сообщения", SGSimpleSettings.shared.fakePremiumReactions))
        entries.append(.premiumColors(presentationData.theme, "Кастомные цвета профиля и имени", SGSimpleSettings.shared.fakePremiumColors))
        entries.append(.footerFeatures(presentationData.theme, "Все премиум-функции активируются локально на вашем устройстве без необходимости покупки платной подписки."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Fake Premium"),
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

// MARK: - 5. Раздел: Чаты и сообщения (BurmalgramChatsController)

private enum BurmalgramChatsSection: Int32 {
    case links
    case messaging
    case userInfo
}

private enum BurmalgramChatsEntry: ItemListNodeEntry {
    case headerLinks(PresentationTheme, String)
    case cleanUrls(PresentationTheme, String, Bool)
    case zalgoFilter(PresentationTheme, String, Bool)
    case footerLinks(PresentationTheme, String)
    
    case headerMessaging(PresentationTheme, String)
    case hideForwardName(PresentationTheme, String, Bool)
    case quickTranslate(PresentationTheme, String, Bool)
    case secondsInMessages(PresentationTheme, String, Bool)
    case sendWithReturnKey(PresentationTheme, String, Bool)
    case doubleTapEdit(PresentationTheme, String, Bool)
    case disableScrollNext(PresentationTheme, String, Bool)
    case disableSendAs(PresentationTheme, String, Bool)
    case footerMessaging(PresentationTheme, String)
    
    case headerUserInfo(PresentationTheme, String)
    case showProfileId(PresentationTheme, String, Bool)
    case showRegDate(PresentationTheme, String, Bool)
    case showCreationDate(PresentationTheme, String, Bool)
    case footerUserInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerLinks, .cleanUrls, .zalgoFilter, .footerLinks:
            return BurmalgramChatsSection.links.rawValue
        case .headerMessaging, .hideForwardName, .quickTranslate, .secondsInMessages, .sendWithReturnKey, .doubleTapEdit, .disableScrollNext, .disableSendAs, .footerMessaging:
            return BurmalgramChatsSection.messaging.rawValue
        case .headerUserInfo, .showProfileId, .showRegDate, .showCreationDate, .footerUserInfo:
            return BurmalgramChatsSection.userInfo.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerLinks: return 0
        case .cleanUrls: return 1
        case .zalgoFilter: return 2
        case .footerLinks: return 3
            
        case .headerMessaging: return 10
        case .hideForwardName: return 11
        case .quickTranslate: return 12
        case .secondsInMessages: return 13
        case .sendWithReturnKey: return 14
        case .doubleTapEdit: return 15
        case .disableScrollNext: return 16
        case .disableSendAs: return 17
        case .footerMessaging: return 18
            
        case .headerUserInfo: return 20
        case .showProfileId: return 21
        case .showRegDate: return 22
        case .showCreationDate: return 23
        case .footerUserInfo: return 24
        }
    }
    
    static func ==(lhs: BurmalgramChatsEntry, rhs: BurmalgramChatsEntry) -> Bool {
        switch lhs {
        case let .headerLinks(lhsTheme, lhsText):
            if case let .headerLinks(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .cleanUrls(lhsTheme, lhsText, lhsValue):
            if case let .cleanUrls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .zalgoFilter(lhsTheme, lhsText, lhsValue):
            if case let .zalgoFilter(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerLinks(lhsTheme, lhsText):
            if case let .footerLinks(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerMessaging(lhsTheme, lhsText):
            if case let .headerMessaging(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .hideForwardName(lhsTheme, lhsText, lhsValue):
            if case let .hideForwardName(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .quickTranslate(lhsTheme, lhsText, lhsValue):
            if case let .quickTranslate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .secondsInMessages(lhsTheme, lhsText, lhsValue):
            if case let .secondsInMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .sendWithReturnKey(lhsTheme, lhsText, lhsValue):
            if case let .sendWithReturnKey(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .doubleTapEdit(lhsTheme, lhsText, lhsValue):
            if case let .doubleTapEdit(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableScrollNext(lhsTheme, lhsText, lhsValue):
            if case let .disableScrollNext(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableSendAs(lhsTheme, lhsText, lhsValue):
            if case let .disableSendAs(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerMessaging(lhsTheme, lhsText):
            if case let .footerMessaging(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerUserInfo(lhsTheme, lhsText):
            if case let .headerUserInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .showProfileId(lhsTheme, lhsText, lhsValue):
            if case let .showProfileId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showRegDate(lhsTheme, lhsText, lhsValue):
            if case let .showRegDate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .showCreationDate(lhsTheme, lhsText, lhsValue):
            if case let .showCreationDate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerUserInfo(lhsTheme, lhsText):
            if case let .footerUserInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramChatsEntry, rhs: BurmalgramChatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramChatsArguments
        switch self {
        case let .headerLinks(_, text), let .headerMessaging(_, text), let .headerUserInfo(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .cleanUrls(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleCleanUrls(val)
            })
        case let .zalgoFilter(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleZalgoFilter(val)
            })
        case let .footerLinks(_, text), let .footerMessaging(_, text), let .footerUserInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .hideForwardName(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleHideForwardName(val)
            })
        case let .quickTranslate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleQuickTranslate(val)
            })
        case let .secondsInMessages(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSecondsInMessages(val)
            })
        case let .sendWithReturnKey(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSendWithReturnKey(val)
            })
        case let .doubleTapEdit(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDoubleTapEdit(val)
            })
        case let .disableScrollNext(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableScrollNext(val)
            })
        case let .disableSendAs(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSendAs(val)
            })
            
        case let .showProfileId(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowProfileId(val)
            })
        case let .showRegDate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowRegDate(val)
            })
        case let .showCreationDate(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleShowCreationDate(val)
            })
        }
    }
}

private final class BurmalgramChatsArguments {
    let toggleCleanUrls: (Bool) -> Void
    let toggleZalgoFilter: (Bool) -> Void
    let toggleHideForwardName: (Bool) -> Void
    let toggleQuickTranslate: (Bool) -> Void
    let toggleSecondsInMessages: (Bool) -> Void
    let toggleSendWithReturnKey: (Bool) -> Void
    let toggleDoubleTapEdit: (Bool) -> Void
    let toggleDisableScrollNext: (Bool) -> Void
    let toggleDisableSendAs: (Bool) -> Void
    let toggleShowProfileId: (Bool) -> Void
    let toggleShowRegDate: (Bool) -> Void
    let toggleShowCreationDate: (Bool) -> Void
    
    init(
        toggleCleanUrls: @escaping (Bool) -> Void,
        toggleZalgoFilter: @escaping (Bool) -> Void,
        toggleHideForwardName: @escaping (Bool) -> Void,
        toggleQuickTranslate: @escaping (Bool) -> Void,
        toggleSecondsInMessages: @escaping (Bool) -> Void,
        toggleSendWithReturnKey: @escaping (Bool) -> Void,
        toggleDoubleTapEdit: @escaping (Bool) -> Void,
        toggleDisableScrollNext: @escaping (Bool) -> Void,
        toggleDisableSendAs: @escaping (Bool) -> Void,
        toggleShowProfileId: @escaping (Bool) -> Void,
        toggleShowRegDate: @escaping (Bool) -> Void,
        toggleShowCreationDate: @escaping (Bool) -> Void
    ) {
        self.toggleCleanUrls = toggleCleanUrls
        self.toggleZalgoFilter = toggleZalgoFilter
        self.toggleHideForwardName = toggleHideForwardName
        self.toggleQuickTranslate = toggleQuickTranslate
        self.toggleSecondsInMessages = toggleSecondsInMessages
        self.toggleSendWithReturnKey = toggleSendWithReturnKey
        self.toggleDoubleTapEdit = toggleDoubleTapEdit
        self.toggleDisableScrollNext = toggleDisableScrollNext
        self.toggleDisableSendAs = toggleDisableSendAs
        self.toggleShowProfileId = toggleShowProfileId
        self.toggleShowRegDate = toggleShowRegDate
        self.toggleShowCreationDate = toggleShowCreationDate
    }
}

public func burmalgramChatsController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramChatsArguments(
        toggleCleanUrls: { val in
            SGSimpleSettings.shared.cleanUrlsEnabled = val
            reloadPromise.set(true)
        },
        toggleZalgoFilter: { val in
            SGSimpleSettings.shared.zalgoFilterEnabled = val
            reloadPromise.set(true)
        },
        toggleHideForwardName: { val in
            SGSimpleSettings.shared.contextShowHideForwardName = val
            reloadPromise.set(true)
        },
        toggleQuickTranslate: { val in
            SGSimpleSettings.shared.quickTranslateButton = val
            reloadPromise.set(true)
        },
        toggleSecondsInMessages: { val in
            SGSimpleSettings.shared.secondsInMessages = val
            reloadPromise.set(true)
        },
        toggleSendWithReturnKey: { val in
            SGSimpleSettings.shared.sendWithReturnKey = val
            reloadPromise.set(true)
        },
        toggleDoubleTapEdit: { val in
            SGSimpleSettings.shared.messageDoubleTapActionOutgoing = val ? SGSimpleSettings.MessageDoubleTapAction.edit.rawValue : SGSimpleSettings.MessageDoubleTapAction.default.rawValue
            reloadPromise.set(true)
        },
        toggleDisableScrollNext: { val in
            SGSimpleSettings.shared.disableScrollToNextChannel = val
            reloadPromise.set(true)
        },
        toggleDisableSendAs: { val in
            SGSimpleSettings.shared.disableSendAsButton = val
            reloadPromise.set(true)
        },
        toggleShowProfileId: { val in
            SGSimpleSettings.shared.showProfileId = val
            reloadPromise.set(true)
        },
        toggleShowRegDate: { val in
            SGSimpleSettings.shared.showRegDate = val
            reloadPromise.set(true)
        },
        toggleShowCreationDate: { val in
            SGSimpleSettings.shared.showCreationDate = val
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramChatsEntry] = []
        
        entries.append(.headerLinks(presentationData.theme, "ССЫЛКИ И ТЕКСТ"))
        entries.append(.cleanUrls(presentationData.theme, "Очистка URL от трекеров (Clean URLs)", SGSimpleSettings.shared.cleanUrlsEnabled))
        entries.append(.zalgoFilter(presentationData.theme, "Фильтр искажений Zalgo", SGSimpleSettings.shared.zalgoFilterEnabled))
        entries.append(.footerLinks(presentationData.theme, "Автоматически очищает ссылки от utm_*, fbclid, yclid, gclid и защищает текст сообщений от ломающих верстку символов."))
        
        entries.append(.headerMessaging(presentationData.theme, "СООБЩЕНИЯ И ПЕРЕСЫЛКА"))
        entries.append(.hideForwardName(presentationData.theme, "Отправка без автора (Контекстное меню)", SGSimpleSettings.shared.contextShowHideForwardName))
        entries.append(.quickTranslate(presentationData.theme, "Кнопка быстрого перевода", SGSimpleSettings.shared.quickTranslateButton))
        entries.append(.secondsInMessages(presentationData.theme, "Секунды во времени сообщений", SGSimpleSettings.shared.secondsInMessages))
        entries.append(.sendWithReturnKey(presentationData.theme, "Отправка клавишей Return (Enter)", SGSimpleSettings.shared.sendWithReturnKey))
        entries.append(.doubleTapEdit(presentationData.theme, "Двойной тап: редактировать сообщение", SGSimpleSettings.shared.messageDoubleTapActionOutgoing == SGSimpleSettings.MessageDoubleTapAction.edit.rawValue))
        entries.append(.disableScrollNext(presentationData.theme, "Отключить переход к следующему каналу", SGSimpleSettings.shared.disableScrollToNextChannel))
        entries.append(.disableSendAs(presentationData.theme, "Отключить кнопку «Отправить как»", SGSimpleSettings.shared.disableSendAsButton))
        entries.append(.footerMessaging(presentationData.theme, "Удобные инструменты для общения, быстрого перевода и управления сообщениями."))
        
        entries.append(.headerUserInfo(presentationData.theme, "ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ"))
        entries.append(.showProfileId(presentationData.theme, "Отображать ID аккаунта в профиле", SGSimpleSettings.shared.showProfileId))
        entries.append(.showRegDate(presentationData.theme, "Отображать дату регистрации аккаунта", SGSimpleSettings.shared.showRegDate))
        entries.append(.showCreationDate(presentationData.theme, "Отображать точную дату создания чатов", SGSimpleSettings.shared.showCreationDate))
        entries.append(.footerUserInfo(presentationData.theme, "Вывод ID и регистрационных дат в информации о пользователях, группах и каналах."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Чаты и сообщения"),
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

// MARK: - 6. Раздел: Медиа и камера (BurmalgramMediaController)

private enum BurmalgramMediaSection: Int32 {
    case media
    case playback
}

private enum BurmalgramMediaEntry: ItemListNodeEntry {
    case headerMedia(PresentationTheme, String)
    case sendLargePhotos(PresentationTheme, String, Bool)
    case startTelescopeRear(PresentationTheme, String, Bool)
    case disableGalleryCamera(PresentationTheme, String, Bool)
    case disableSnapEffect(PresentationTheme, String, Bool)
    case footerMedia(PresentationTheme, String)
    
    case headerPlayback(PresentationTheme, String)
    case forceSystemSharing(PresentationTheme, String, Bool)
    case videoPIP(PresentationTheme, String, Bool)
    case footerPlayback(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerMedia, .sendLargePhotos, .startTelescopeRear, .disableGalleryCamera, .disableSnapEffect, .footerMedia:
            return BurmalgramMediaSection.media.rawValue
        case .headerPlayback, .forceSystemSharing, .videoPIP, .footerPlayback:
            return BurmalgramMediaSection.playback.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerMedia: return 0
        case .sendLargePhotos: return 1
        case .startTelescopeRear: return 2
        case .disableGalleryCamera: return 3
        case .disableSnapEffect: return 4
        case .footerMedia: return 5
            
        case .headerPlayback: return 10
        case .forceSystemSharing: return 11
        case .videoPIP: return 12
        case .footerPlayback: return 13
        }
    }
    
    static func ==(lhs: BurmalgramMediaEntry, rhs: BurmalgramMediaEntry) -> Bool {
        switch lhs {
        case let .headerMedia(lhsTheme, lhsText):
            if case let .headerMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .sendLargePhotos(lhsTheme, lhsText, lhsValue):
            if case let .sendLargePhotos(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .startTelescopeRear(lhsTheme, lhsText, lhsValue):
            if case let .startTelescopeRear(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableGalleryCamera(lhsTheme, lhsText, lhsValue):
            if case let .disableGalleryCamera(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .disableSnapEffect(lhsTheme, lhsText, lhsValue):
            if case let .disableSnapEffect(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerMedia(lhsTheme, lhsText):
            if case let .footerMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerPlayback(lhsTheme, lhsText):
            if case let .headerPlayback(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .forceSystemSharing(lhsTheme, lhsText, lhsValue):
            if case let .forceSystemSharing(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .videoPIP(lhsTheme, lhsText, lhsValue):
            if case let .videoPIP(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerPlayback(lhsTheme, lhsText):
            if case let .footerPlayback(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramMediaEntry, rhs: BurmalgramMediaEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramMediaArguments
        switch self {
        case let .headerMedia(_, text), let .headerPlayback(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .sendLargePhotos(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleSendLargePhotos(val)
            })
        case let .startTelescopeRear(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleStartTelescopeRear(val)
            })
        case let .disableGalleryCamera(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableGalleryCamera(val)
            })
        case let .disableSnapEffect(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleDisableSnapEffect(val)
            })
        case let .footerMedia(_, text), let .footerPlayback(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .forceSystemSharing(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleForceSystemSharing(val)
            })
        case let .videoPIP(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleVideoPIP(val)
            })
        }
    }
}

private final class BurmalgramMediaArguments {
    let toggleSendLargePhotos: (Bool) -> Void
    let toggleStartTelescopeRear: (Bool) -> Void
    let toggleDisableGalleryCamera: (Bool) -> Void
    let toggleDisableSnapEffect: (Bool) -> Void
    let toggleForceSystemSharing: (Bool) -> Void
    let toggleVideoPIP: (Bool) -> Void
    
    init(
        toggleSendLargePhotos: @escaping (Bool) -> Void,
        toggleStartTelescopeRear: @escaping (Bool) -> Void,
        toggleDisableGalleryCamera: @escaping (Bool) -> Void,
        toggleDisableSnapEffect: @escaping (Bool) -> Void,
        toggleForceSystemSharing: @escaping (Bool) -> Void,
        toggleVideoPIP: @escaping (Bool) -> Void
    ) {
        self.toggleSendLargePhotos = toggleSendLargePhotos
        self.toggleStartTelescopeRear = toggleStartTelescopeRear
        self.toggleDisableGalleryCamera = toggleDisableGalleryCamera
        self.toggleDisableSnapEffect = toggleDisableSnapEffect
        self.toggleForceSystemSharing = toggleForceSystemSharing
        self.toggleVideoPIP = toggleVideoPIP
    }
}

public func burmalgramMediaController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    
    let arguments = BurmalgramMediaArguments(
        toggleSendLargePhotos: { val in
            SGSimpleSettings.shared.sendLargePhotos = val
            reloadPromise.set(true)
        },
        toggleStartTelescopeRear: { val in
            SGSimpleSettings.shared.startTelescopeWithRearCam = val
            reloadPromise.set(true)
        },
        toggleDisableGalleryCamera: { val in
            SGSimpleSettings.shared.disableGalleryCamera = val
            reloadPromise.set(true)
        },
        toggleDisableSnapEffect: { val in
            SGSimpleSettings.shared.disableSnapDeletionEffect = val
            reloadPromise.set(true)
        },
        toggleForceSystemSharing: { val in
            SGSimpleSettings.shared.forceSystemSharing = val
            reloadPromise.set(true)
        },
        toggleVideoPIP: { val in
            SGSimpleSettings.shared.videoPIPSwipeDirection = val ? SGSimpleSettings.VideoPIPSwipeDirection.up.rawValue : SGSimpleSettings.VideoPIPSwipeDirection.none.rawValue
            reloadPromise.set(true)
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramMediaEntry] = []
        
        entries.append(.headerMedia(presentationData.theme, "ФОТО И ВИДЕО"))
        entries.append(.sendLargePhotos(presentationData.theme, "Отправка фото без сжатия (2560px HQ)", SGSimpleSettings.shared.sendLargePhotos))
        entries.append(.startTelescopeRear(presentationData.theme, "Кружочки с задней камеры по умолчанию", SGSimpleSettings.shared.startTelescopeWithRearCam))
        entries.append(.disableGalleryCamera(presentationData.theme, "Отключить камеру в панели галереи", SGSimpleSettings.shared.disableGalleryCamera))
        entries.append(.disableSnapEffect(presentationData.theme, "Отключить эффект сгорания (Snap)", SGSimpleSettings.shared.disableSnapDeletionEffect))
        entries.append(.footerMedia(presentationData.theme, "Высокое качество отправки медиафайлов и управление съемкой."))
        
        entries.append(.headerPlayback(presentationData.theme, "ВОСПРОИЗВЕДЕНИЕ И ПЛЕЕР"))
        entries.append(.forceSystemSharing(presentationData.theme, "Внешний плеер VLC / Infuse (Системный шеринг)", SGSimpleSettings.shared.forceSystemSharing))
        entries.append(.videoPIP(presentationData.theme, "Картинка в картинке (PIP) свайпом вверх", SGSimpleSettings.shared.videoPIPSwipeDirection == SGSimpleSettings.VideoPIPSwipeDirection.up.rawValue))
        entries.append(.footerPlayback(presentationData.theme, "Воспроизведение видео во внешних медиаплеерах и быстрое открытие режима PIP жестом свайпа вверх."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Медиа и камера"),
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

// MARK: - 7. Раздел: Сессии и TData (BurmalgramTDataController)

private enum BurmalgramTDataSection: Int32 {
    case info
    case actions
}

private enum BurmalgramTDataEntry: ItemListNodeEntry {
    case headerInfo(PresentationTheme, String)
    case dcId(PresentationTheme, String, String)
    case apiId(PresentationTheme, String, String)
    case userId(PresentationTheme, String, String)
    case footerInfo(PresentationTheme, String)
    
    case headerActions(PresentationTheme, String)
    case exportTData(PresentationTheme, String)
    case importTData(PresentationTheme, String)
    case footerActions(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerInfo, .dcId, .apiId, .userId, .footerInfo:
            return BurmalgramTDataSection.info.rawValue
        case .headerActions, .exportTData, .importTData, .footerActions:
            return BurmalgramTDataSection.actions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerInfo: return 0
        case .dcId: return 1
        case .apiId: return 2
        case .userId: return 3
        case .footerInfo: return 4
            
        case .headerActions: return 10
        case .exportTData: return 11
        case .importTData: return 12
        case .footerActions: return 13
        }
    }
    
    static func ==(lhs: BurmalgramTDataEntry, rhs: BurmalgramTDataEntry) -> Bool {
        switch lhs {
        case let .headerInfo(lhsTheme, lhsText):
            if case let .headerInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .dcId(lhsTheme, lhsText, lhsValue):
            if case let .dcId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .apiId(lhsTheme, lhsText, lhsValue):
            if case let .apiId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .userId(lhsTheme, lhsText, lhsValue):
            if case let .userId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerInfo(lhsTheme, lhsText):
            if case let .footerInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerActions(lhsTheme, lhsText):
            if case let .headerActions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .exportTData(lhsTheme, lhsText):
            if case let .exportTData(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .importTData(lhsTheme, lhsText):
            if case let .importTData(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .footerActions(lhsTheme, lhsText):
            if case let .footerActions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramTDataEntry, rhs: BurmalgramTDataEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramTDataArguments
        switch self {
        case let .headerInfo(_, text), let .headerActions(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .dcId(_, text, value), let .apiId(_, text, value), let .userId(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: nil)
            
        case let .footerInfo(_, text), let .footerActions(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .exportTData(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.exportTData()
            })
        case let .importTData(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.importTData()
            })
        }
    }
}

private final class BurmalgramTDataArguments {
    let exportTData: () -> Void
    let importTData: () -> Void
    
    init(exportTData: @escaping () -> Void, importTData: @escaping () -> Void) {
        self.exportTData = exportTData
        self.importTData = importTData
    }
}

public func burmalgramTDataController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var exportImpl: (() -> Void)?
    var importImpl: (() -> Void)?
    
    let arguments = BurmalgramTDataArguments(
        exportTData: {
            exportImpl?()
        },
        importTData: {
            importImpl?()
        }
    )
    
    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        reloadPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [BurmalgramTDataEntry] = []
        
        entries.append(.headerInfo(presentationData.theme, "ТЕКУЩАЯ СЕССИЯ"))
        entries.append(.dcId(presentationData.theme, "Дата-центр", "DC \(context.account.masterDatacenterId)"))
        entries.append(.apiId(presentationData.theme, "API ID сессии", "2040 (Telegram Desktop)"))
        entries.append(.userId(presentationData.theme, "Telegram User ID", "\(context.account.peerId.id._internalGetInt64Value())"))
        entries.append(.footerInfo(presentationData.theme, "Сведения о текущей активной авторизованной сессии клиента."))
        
        entries.append(.headerActions(presentationData.theme, "РЕЗЕРВНОЕ КОПИРОВАНИЕ TDATA"))
        entries.append(.exportTData(presentationData.theme, "Экспортировать сессию в TData (.zip)"))
        entries.append(.importTData(presentationData.theme, "Импортировать TData (.zip)"))
        entries.append(.footerActions(presentationData.theme, "Формат TData позволяет мгновенно открывать авторизованную сессию в Telegram Desktop на ПК без ввода SMS-кода, либо импортировать готовый архив TData."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Сессии и TData"),
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
    exportImpl = { [weak controller] in
        guard let controller = controller else { return }
        TDataBridge.exportTData(context: context, fromViewController: controller)
    }
    importImpl = { [weak controller] in
        guard let controller = controller else { return }
        TDataBridge.importTData(context: context, fromViewController: controller)
    }
    return controller
}

// MARK: - 8. Раздел: Сеть и Спуфинг (BurmalgramNetworkController)

private enum BurmalgramNetworkSection: Int32 {
    case speed
    case spoofing
    case system
}

private enum BurmalgramNetworkEntry: ItemListNodeEntry {
    case headerSpeed(PresentationTheme, String)
    case downloadSpeed(PresentationTheme, String, String)
    case uploadSpeed(PresentationTheme, String, Bool)
    case localDNS(PresentationTheme, String, Bool)
    case footerSpeed(PresentationTheme, String)
    
    case headerSpoofing(PresentationTheme, String)
    case geoSpoof(PresentationTheme, String, String)
    case deviceSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    case footerSpoofing(PresentationTheme, String)
    
    case headerSystem(PresentationTheme, String)
    case filePickerFix(PresentationTheme, String, Bool)
    case clearCache(PresentationTheme, String)
    case resetSettings(PresentationTheme, String)
    case footerSystem(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .headerSpeed, .downloadSpeed, .uploadSpeed, .localDNS, .footerSpeed:
            return BurmalgramNetworkSection.speed.rawValue
        case .headerSpoofing, .geoSpoof, .deviceSpoof, .voiceMorpher, .sendDelay, .footerSpoofing:
            return BurmalgramNetworkSection.spoofing.rawValue
        case .headerSystem, .filePickerFix, .clearCache, .resetSettings, .footerSystem:
            return BurmalgramNetworkSection.system.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .headerSpeed: return 0
        case .downloadSpeed: return 1
        case .uploadSpeed: return 2
        case .localDNS: return 3
        case .footerSpeed: return 4
            
        case .headerSpoofing: return 10
        case .geoSpoof: return 11
        case .deviceSpoof: return 12
        case .voiceMorpher: return 13
        case .sendDelay: return 14
        case .footerSpoofing: return 15
            
        case .headerSystem: return 20
        case .filePickerFix: return 21
        case .clearCache: return 22
        case .resetSettings: return 23
        case .footerSystem: return 24
        }
    }
    
    static func ==(lhs: BurmalgramNetworkEntry, rhs: BurmalgramNetworkEntry) -> Bool {
        switch lhs {
        case let .headerSpeed(lhsTheme, lhsText):
            if case let .headerSpeed(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .downloadSpeed(lhsTheme, lhsText, lhsValue):
            if case let .downloadSpeed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .uploadSpeed(lhsTheme, lhsText, lhsValue):
            if case let .uploadSpeed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .localDNS(lhsTheme, lhsText, lhsValue):
            if case let .localDNS(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerSpeed(lhsTheme, lhsText):
            if case let .footerSpeed(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerSpoofing(lhsTheme, lhsText):
            if case let .headerSpoofing(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .geoSpoof(lhsTheme, lhsText, lhsValue):
            if case let .geoSpoof(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .deviceSpoof(lhsTheme, lhsText, lhsValue):
            if case let .deviceSpoof(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .voiceMorpher(lhsTheme, lhsText, lhsValue):
            if case let .voiceMorpher(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .sendDelay(lhsTheme, lhsText, lhsValue):
            if case let .sendDelay(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .footerSpoofing(lhsTheme, lhsText):
            if case let .footerSpoofing(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
            
        case let .headerSystem(lhsTheme, lhsText):
            if case let .headerSystem(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .filePickerFix(lhsTheme, lhsText, lhsValue):
            if case let .filePickerFix(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true }
            return false
        case let .clearCache(lhsTheme, lhsText):
            if case let .clearCache(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .resetSettings(lhsTheme, lhsText):
            if case let .resetSettings(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .footerSystem(lhsTheme, lhsText):
            if case let .footerSystem(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: BurmalgramNetworkEntry, rhs: BurmalgramNetworkEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! BurmalgramNetworkArguments
        switch self {
        case let .headerSpeed(_, text), let .headerSpoofing(_, text), let .headerSystem(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            
        case let .downloadSpeed(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.cycleDownloadSpeed()
            })
        case let .uploadSpeed(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleUploadSpeed(val)
            })
        case let .localDNS(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleLocalDNS(val)
            })
        case let .footerSpeed(_, text), let .footerSpoofing(_, text), let .footerSystem(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            
        case let .geoSpoof(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openGeoSpoof()
            })
        case let .deviceSpoof(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openDeviceSpoof()
            })
        case let .voiceMorpher(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openVoiceMorpher()
            })
        case let .sendDelay(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                args.openSendDelay()
            })
            
        case let .filePickerFix(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.toggleFilePickerFix(val)
            })
        case let .clearCache(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.clearCache()
            })
        case let .resetSettings(_, text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                args.resetSettings()
            })
        }
    }
}

private final class BurmalgramNetworkArguments {
    let cycleDownloadSpeed: () -> Void
    let toggleUploadSpeed: (Bool) -> Void
    let toggleLocalDNS: (Bool) -> Void
    let openGeoSpoof: () -> Void
    let openDeviceSpoof: () -> Void
    let openVoiceMorpher: () -> Void
    let openSendDelay: () -> Void
    let toggleFilePickerFix: (Bool) -> Void
    let clearCache: () -> Void
    let resetSettings: () -> Void
    
    init(
        cycleDownloadSpeed: @escaping () -> Void,
        toggleUploadSpeed: @escaping () -> Void,
        toggleLocalDNS: @escaping () -> Void,
        openGeoSpoof: @escaping () -> Void,
        openDeviceSpoof: @escaping () -> Void,
        openVoiceMorpher: @escaping () -> Void,
        openSendDelay: @escaping () -> Void,
        toggleFilePickerFix: @escaping (Bool) -> Void,
        clearCache: @escaping () -> Void,
        resetSettings: @escaping () -> Void
    ) {
        self.cycleDownloadSpeed = cycleDownloadSpeed
        self.toggleUploadSpeed = toggleUploadSpeed
        self.toggleLocalDNS = toggleLocalDNS
        self.openGeoSpoof = openGeoSpoof
        self.openDeviceSpoof = openDeviceSpoof
        self.openVoiceMorpher = openVoiceMorpher
        self.openSendDelay = openSendDelay
        self.toggleFilePickerFix = toggleFilePickerFix
        self.clearCache = clearCache
        self.resetSettings = resetSettings
    }
}

public func burmalgramNetworkController(context: AccountContext) -> ViewController {
    let reloadPromise = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    var showToastImpl: ((String) -> Void)?
    
    let arguments = BurmalgramNetworkArguments(
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
        toggleLocalDNS: { val in
            SGSimpleSettings.shared.localDNSForProxyHost = val
            reloadPromise.set(true)
        },
        openGeoSpoof: {
            pushControllerImpl?(geoSpoofController(context: context))
        },
        openDeviceSpoof: {
            pushControllerImpl?(deviceSpoofController(context: context))
        },
        openVoiceMorpher: {
            pushControllerImpl?(voiceMorpherController(context: context))
        },
        openSendDelay: {
            pushControllerImpl?(sendDelayController(context: context))
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
            showToastImpl?("Кэш и временные файлы успешно очищены")
        },
        resetSettings: {
            let alert = UIAlertController(title: "Сброс настроек", message: "Вы уверены, что хотите сбросить все настройки Burmalgram на значения по умолчанию?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { _ in
                SGSimpleSettings.shared.fakePremium = false
                SGSimpleSettings.shared.fakePremiumShowBadge = false
                SGSimpleSettings.shared.customFont = "default"
                SGSimpleSettings.shared.customPhoneNumber = ""
                SGSimpleSettings.shared.exteraUiStyle = "extera"
                SGSimpleSettings.shared.pillStackEnabled = true
                SGSimpleSettings.shared.pillStackShowWeather = true
                SGSimpleSettings.shared.pillStackShowCrypto = true
                SGSimpleSettings.shared.pillStackShowCache = true
                SGSimpleSettings.shared.pillStackShowProxy = true
                SGSimpleSettings.shared.pillStackInfiniteScroll = false
                SGSimpleSettings.shared.removeMessageTail = true
                SGSimpleSettings.shared.avatarCorners = "squircle"
                SGSimpleSettings.shared.dividerStyle = "hidden"
                SGSimpleSettings.shared.forceBlur = true
                SGSimpleSettings.shared.glassOutlineStyle = "glare"
                SGSimpleSettings.shared.springAnimations = true
                SGSimpleSettings.shared.centerTitle = false
                SGSimpleSettings.shared.hideDialogsSearchBar = false
                SGSimpleSettings.shared.cleanUrlsEnabled = true
                SGSimpleSettings.shared.zalgoFilterEnabled = true
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
                
                GhostModeManager.shared.isEnabled = false
                AntiDeleteManager.shared.isEnabled = false
                DeviceSpoofManager.shared.isEnabled = false
                GeoSpoofManager.shared.isEnabled = false
                VoiceMorpherManager.shared.isEnabled = false
                SendDelayManager.shared.isEnabled = false
                
                let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0 }).start()
                reloadPromise.set(true)
                showToastImpl?("Все настройки сброшены на значения по умолчанию")
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
        var entries: [BurmalgramNetworkEntry] = []
        
        entries.append(.headerSpeed(presentationData.theme, "УСКОРЕНИЕ СЕТИ"))
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
        entries.append(.uploadSpeed(presentationData.theme, "Ускорение отдачи (Upload Speed Boost)", SGSimpleSettings.shared.uploadSpeedBoost))
        entries.append(.localDNS(presentationData.theme, "Локальный DNS для хоста прокси", SGSimpleSettings.shared.localDNSForProxyHost))
        entries.append(.footerSpeed(presentationData.theme, "Многопоточная передача данных для максимальной скорости загрузки и отдачи."))
        
        entries.append(.headerSpoofing(presentationData.theme, "ПОДМЕНА ДАННЫХ (СПУФИНГ)"))
        entries.append(.geoSpoof(presentationData.theme, "Фейковая геолокация (GPS)", GeoSpoofManager.shared.isEnabled ? GeoSpoofManager.shared.presetName : "Выкл"))
        entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства (Device Spoof)", DeviceSpoofManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.voiceMorpher(presentationData.theme, "Голосовой морфер (Voice Morpher)", VoiceMorpherManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.sendDelay(presentationData.theme, "Задержка отправки сообщений", SendDelayManager.shared.isEnabled ? "Вкл" : "Выкл"))
        entries.append(.footerSpoofing(presentationData.theme, "Инструменты подмены параметров устройства, геолокации, голоса и искусственной задержки сообщений."))
        
        entries.append(.headerSystem(presentationData.theme, "СИСТЕМНЫЕ ДЕЙСТВИЯ"))
        entries.append(.filePickerFix(presentationData.theme, "Исправление выбора файлов", SGSimpleSettings.shared.fixFilePicker))
        entries.append(.clearCache(presentationData.theme, "Очистить кэш базы данных и медиа"))
        entries.append(.resetSettings(presentationData.theme, "Сбросить настройки мода"))
        entries.append(.footerSystem(presentationData.theme, "Служебные функции обслуживания приложения."))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Сеть и Спуфинг"),
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
    showToastImpl = { [weak controller] text in
        guard let controller = controller else { return }
        showBurmalgramToast(text: text, in: controller, context: context)
    }
    return controller
}

// MARK: - Legacy Aliases for Seamless Backward Compatibility

public func burmalgramCustomizationController(context: AccountContext) -> ViewController {
    return burmalgramAppearanceController(context: context)
}

public func burmalgramToolsController(context: AccountContext) -> ViewController {
    return burmalgramChatsController(context: context)
}

public func burmaldaToolsSettingsController(context: AccountContext) -> ViewController {
    return burmalgramSettingsController(context: context)
}

public func burmalgramCustomThemeController(context: AccountContext) -> ViewController {
    return burmalgramAppearanceController(context: context)
}
