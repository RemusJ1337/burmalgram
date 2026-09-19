import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private enum PluginAPIDocsSection: Int32 {
    case info
    case namespaces
}

private enum PluginAPIDocsEntry: ItemListNodeEntry {
    case info(PresentationTheme, String)
    case method(PresentationTheme, String, String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .info:
            return PluginAPIDocsSection.info.rawValue
        case .method:
            return PluginAPIDocsSection.namespaces.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .info:
            return 0
        case let .method(_, sig, _, _):
            return Int32(abs(sig.hashValue % 100000) + 1)
        }
    }
    
    static func ==(lhs: PluginAPIDocsEntry, rhs: PluginAPIDocsEntry) -> Bool {
        switch lhs {
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .method(lhsTheme, lhsSig, lhsEx, lhsDesc):
            if case let .method(rhsTheme, rhsSig, rhsEx, rhsDesc) = rhs,
               lhsTheme === rhsTheme, lhsSig == rhsSig, lhsEx == rhsEx, lhsDesc == rhsDesc {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: PluginAPIDocsEntry, rhs: PluginAPIDocsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .method(_, sig, ex, desc):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: sig,
                label: desc,
                sectionId: self.section,
                style: .blocks,
                action: {
                    UIPasteboard.general.string = ex.isEmpty ? sig : ex
                }
            )
        }
    }
}

public func pluginAPIDocsController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let entries: [PluginAPIDocsEntry] = [
        .info(presentationData.theme, "GGAPI v4.1.0 — API среды выполнения пользовательских плагинов Burmalgram. Нажмите на метод, чтобы скопировать пример кода."),
        .method(presentationData.theme, "GGAPI.log(text)", "GGAPI.log(\"Hello world\");", "Вывод текста в консоль IDE"),
        .method(presentationData.theme, "GGAPI.toast(text)", "GGAPI.toast(\"Готово!\");", "Всплывающее уведомление"),
        .method(presentationData.theme, "GGAPI.app.alert(title, text)", "GGAPI.app.alert(\"Внимание\", \"Текст\");", "Системное диалоговое окно"),
        .method(presentationData.theme, "GGAPI.app.openSettings()", "GGAPI.app.openSettings();", "Открыть экран настроек"),
        .method(presentationData.theme, "GGAPI.app.clientInfo()", "const info = GGAPI.app.clientInfo();", "Информация о клиенте"),
        .method(presentationData.theme, "GGAPI.storage.get(key)", "const val = GGAPI.storage.get(\"key\");", "Чтение из хранилища"),
        .method(presentationData.theme, "GGAPI.storage.set(key, val)", "GGAPI.storage.set(\"key\", 123);", "Запись в хранилище"),
        .method(presentationData.theme, "GGAPI.chat.onBeforeSend(fn)", "GGAPI.chat.onBeforeSend((text) => text.toUpperCase());", "Модификация текста сообщений"),
        .method(presentationData.theme, "GGAPI.plugins.emit(event, data)", "GGAPI.plugins.emit(\"test\", { a: 1 });", "Шина событий"),
        .method(presentationData.theme, "GGAPI.plugins.on(event, fn)", "GGAPI.plugins.on(\"test\", (d) => {});", "Подписка на события")
    ]
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        .single(entries)
    )
    |> map { presentationData, entries -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("GGAPI Docs"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, ()))
    }
    
    return ItemListController(context: context, state: signal)
}
