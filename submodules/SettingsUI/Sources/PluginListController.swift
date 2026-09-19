import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

private enum PluginListSection: Int32 {
    case info
    case plugins
    case actions
}

private enum PluginListEntry: ItemListNodeEntry {
    case info(PresentationTheme, String)
    case pluginItem(PresentationTheme, String, String, Bool, String) // theme, title, subtitle, isEnabled, id
    case createNew(PresentationTheme, String)
    case docs(PresentationTheme, String)
    case reset(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .info:
            return PluginListSection.info.rawValue
        case .pluginItem:
            return PluginListSection.plugins.rawValue
        case .createNew, .docs, .reset:
            return PluginListSection.actions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .info:
            return 0
        case let .pluginItem(_, _, _, _, id):
            return Int32(abs(id.hashValue % 100000) + 10)
        case .createNew:
            return 200000
        case .docs:
            return 200001
        case .reset:
            return 200002
        }
    }
    
    static func ==(lhs: PluginListEntry, rhs: PluginListEntry) -> Bool {
        switch lhs {
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .pluginItem(lhsTheme, lhsTitle, lhsSubtitle, lhsEnabled, lhsId):
            if case let .pluginItem(rhsTheme, rhsTitle, rhsSubtitle, rhsEnabled, rhsId) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsEnabled == rhsEnabled, lhsId == rhsId {
                return true
            }
            return false
        case let .createNew(lhsTheme, lhsText):
            if case let .createNew(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .docs(lhsTheme, lhsText):
            if case let .docs(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .reset(lhsTheme, lhsText):
            if case let .reset(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: PluginListEntry, rhs: PluginListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PluginListControllerArguments
        switch self {
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .pluginItem(_, title, subtitle, isEnabled, id):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: title,
                value: isEnabled,
                type: .regular,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.togglePlugin(id, value)
                },
                action: {
                    arguments.openPlugin(id)
                }
            )
        case let .createNew(_, text):
            return ItemListActionItem(
                presentationData: presentationData,
                title: text,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.createNewPlugin()
                }
            )
        case let .docs(_, text):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: "v4.1.0",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openDocs()
                }
            )
        case let .reset(_, text):
            return ItemListActionItem(
                presentationData: presentationData,
                title: text,
                kind: .destructive,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.resetDefaults()
                }
            )
        }
    }
}

private final class PluginListControllerArguments {
    let togglePlugin: (String, Bool) -> Void
    let openPlugin: (String) -> Void
    let createNewPlugin: () -> Void
    let openDocs: () -> Void
    let resetDefaults: () -> Void
    
    init(
        togglePlugin: @escaping (String, Bool) -> Void,
        openPlugin: @escaping (String) -> Void,
        createNewPlugin: @escaping () -> Void,
        openDocs: @escaping () -> Void,
        resetDefaults: @escaping () -> Void
    ) {
        self.togglePlugin = togglePlugin
        self.openPlugin = openPlugin
        self.createNewPlugin = createNewPlugin
        self.openDocs = openDocs
        self.resetDefaults = resetDefaults
    }
}

public func pluginListController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController, Bool) -> Void)?
    let statePromise = ValuePromise<[GGPlugin]>(GGPluginManager.shared.getPlugins(), ignoreRepeated: false)
    
    let arguments = PluginListControllerArguments(
        togglePlugin: { id, enabled in
            GGPluginManager.shared.setEnabled(id: id, enabled: enabled)
            statePromise.set(GGPluginManager.shared.getPlugins())
        },
        openPlugin: { id in
            if let plugin = GGPluginManager.shared.plugin(for: id) {
                let editor = GGPluginEditorController(context: context, plugin: plugin)
                pushControllerImpl?(editor, true)
            }
        },
        createNewPlugin: {
            let newPlugin = GGPlugin(
                id: UUID().uuidString,
                name: "Новый плагин",
                author: "User",
                version: "1.0.0",
                description: "Пользовательский скрипт GGPlugin",
                code: """
                // @name Новый плагин
                // @author User
                // @version 1.0.0
                // @description Описание плагина
                // @api 2
                // @permissions ui,events

                GGAPI.log("Привет из нового плагина!");
                GGAPI.toast("Плагин запущен!");
                """,
                isEnabled: true,
                isBuiltin: false
            )
            GGPluginManager.shared.savePlugin(newPlugin)
            statePromise.set(GGPluginManager.shared.getPlugins())
            let editor = GGPluginEditorController(context: context, plugin: newPlugin)
            pushControllerImpl?(editor, true)
        },
        openDocs: {
            let docs = pluginAPIDocsController(context: context)
            pushControllerImpl?(docs, true)
        },
        resetDefaults: {
            GGPluginManager.shared.resetToDefaults()
            statePromise.set(GGPluginManager.shared.getPlugins())
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, plugins -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [PluginListEntry] = []
        entries.append(.info(presentationData.theme, "Плагины Ghostgram (GGPlugin) позволяют модифицировать поведение клиента с помощью JavaScript-скриптов. Нажмите на плагин для редактирования в IDE."))
        
        for plugin in plugins {
            let isRunning = GGPluginManager.shared.isRunning(id: plugin.id)
            let status = isRunning ? "Активен" : "Выключен"
            let subtitle = "\(plugin.description) · \(status)"
            entries.append(.pluginItem(presentationData.theme, plugin.name, subtitle, plugin.isEnabled, plugin.id))
        }
        
        entries.append(.createNew(presentationData.theme, "+ Создать новый плагин"))
        entries.append(.docs(presentationData.theme, "Документация GGAPI"))
        entries.append(.reset(presentationData.theme, "Сбросить к исходным плагинам"))
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Плагины GGPlugin"),
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
        statePromise.set(GGPluginManager.shared.getPlugins())
    }
    
    pushControllerImpl = { [weak controller] c, animated in
        controller?.push(c)
    }
    return controller
}
