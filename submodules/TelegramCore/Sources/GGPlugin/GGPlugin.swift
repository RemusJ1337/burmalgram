import Foundation
import JavaScriptCore

// MARK: - GGPlugin Model

public struct GGPlugin: Codable, Equatable {
    public var id: String
    public var name: String
    public var author: String
    public var version: String
    public var description: String
    public var code: String
    public var isEnabled: Bool
    public var isBuiltin: Bool
    
    public init(
        id: String,
        name: String,
        author: String,
        version: String,
        description: String,
        code: String,
        isEnabled: Bool,
        isBuiltin: Bool = false
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.code = code
        self.isEnabled = isEnabled
        self.isBuiltin = isBuiltin
    }
    
    public static func parseManifest(from code: String) -> (name: String?, author: String?, version: String?, description: String?) {
        var name: String?
        var author: String?
        var version: String?
        var description: String?
        
        for line in code.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("//") else {
                if !trimmed.isEmpty { break }
                continue
            }
            if let atRange = trimmed.range(of: "@") {
                let rest = String(trimmed[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { continue }
                let key = parts[0].lowercased()
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                switch key {
                case "name": name = value
                case "author": author = value
                case "version": version = value
                case "description": description = value
                default: break
                }
            }
        }
        return (name, author, version, description)
    }
}

// MARK: - GGPluginConsole

public final class GGPluginConsole {
    public struct Line: Codable, Equatable {
        public let level: String
        public let text: String
        public let timestamp: Double
        
        public init(level: String, text: String, timestamp: Double = Date().timeIntervalSince1970) {
            self.level = level
            self.text = text
            self.timestamp = timestamp
        }
    }
    
    public static let shared = GGPluginConsole()
    private var logs: [String: [Line]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    public func add(pluginId: String, level: String, text: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = Line(level: level, text: text)
        if logs[pluginId] == nil {
            logs[pluginId] = []
        }
        logs[pluginId]?.append(line)
        if (logs[pluginId]?.count ?? 0) > 200 {
            logs[pluginId]?.removeFirst(50)
        }
        NotificationCenter.default.post(name: NSNotification.Name("GGPluginConsoleUpdated"), object: pluginId)
    }
    
    public func lines(pluginId: String) -> [Line] {
        lock.lock()
        defer { lock.unlock() }
        return logs[pluginId] ?? []
    }
    
    public func clear(pluginId: String) {
        lock.lock()
        defer { lock.unlock() }
        logs[pluginId] = []
        NotificationCenter.default.post(name: NSNotification.Name("GGPluginConsoleUpdated"), object: pluginId)
    }
}

// MARK: - GGPluginManager

public final class GGPluginManager {
    public static let shared = GGPluginManager()
    
    public static let toastNotification = NSNotification.Name("GGPluginToastNotification")
    public static let alertNotification = NSNotification.Name("GGPluginAlertNotification")
    public static let openSettingsNotification = NSNotification.Name("GGPluginOpenSettingsNotification")
    public static let pluginsChangedNotification = NSNotification.Name("GGPluginPluginsChangedNotification")
    
    private let storageKey = "Burmalgram_GGPlugins_v1"
    private var activeContexts: [String: JSContext] = [:]
    private var beforeSendHandlers: [String: JSValue] = [:]
    private var eventListeners: [String: [JSValue]] = [:]
    private let lock = NSLock()
    
    private init() {
        if loadPlugins().isEmpty {
            savePlugins(defaultPlugins)
        }
        runAllEnabled()
    }
    
    // MARK: - Default Plugins
    
    private var defaultPlugins: [GGPlugin] {
        return [
            GGPlugin(
                id: "builtin_startup_toast",
                name: "Startup Toast",
                author: "Burmalgram",
                version: "1.0.0",
                description: "Приветственное уведомление при запуске плагина",
                code: """
                // @name Startup Toast
                // @author Burmalgram
                // @version 1.0.0
                // @description Приветственное уведомление при запуске плагина
                // @api 2
                // @permissions ui,events

                GGAPI.log("Плагин Startup Toast запущен!");
                GGAPI.toast("Burmalgram GGPlugin активен ✨");
                """,
                isEnabled: true,
                isBuiltin: true
            ),
            GGPlugin(
                id: "builtin_quick_actions",
                name: "Quick Storage Counter",
                author: "Burmalgram",
                version: "1.0.0",
                description: "Счётчик запусков с сохранением в локальное хранилище",
                code: """
                // @name Quick Storage Counter
                // @author Burmalgram
                // @version 1.0.0
                // @description Счётчик запусков с сохранением в локальное хранилище
                // @api 2
                // @permissions storage

                const runs = (GGAPI.storage.get("run_count") || 0) + 1;
                GGAPI.storage.set("run_count", runs);
                GGAPI.log("Количество запусков скрипта: " + runs);
                """,
                isEnabled: false,
                isBuiltin: true
            ),
            GGPlugin(
                id: "builtin_text_expander",
                name: "Text Expander",
                author: "Burmalgram",
                version: "1.0.0",
                description: "Замена :shrug:, :cat:, :fire: перед отправкой",
                code: """
                // @name Text Expander
                // @author Burmalgram
                // @version 1.0.0
                // @description Замена текстовых смайликов перед отправкой сообщения
                // @api 2
                // @permissions chat,messages

                GGAPI.chat.onBeforeSend(function(text) {
                  if (!text) return text;
                  return text.replace(/:shrug:/g, "¯\\\\_(ツ)_/¯")
                             .replace(/:cat:/g, "🐱")
                             .replace(/:fire:/g, "🔥");
                });
                GGAPI.log("Text Expander активен. Попробуйте ввести :shrug: или :cat:");
                """,
                isEnabled: false,
                isBuiltin: true
            )
        ]
    }
    
    // MARK: - CRUD
    
    public func getPlugins() -> [GGPlugin] {
        return loadPlugins()
    }
    
    public func plugin(for id: String) -> GGPlugin? {
        return getPlugins().first(where: { $0.id == id })
    }
    
    public func savePlugin(_ plugin: GGPlugin) {
        var list = loadPlugins()
        var updated = plugin
        let meta = GGPlugin.parseManifest(from: plugin.code)
        if let n = meta.name, !n.isEmpty { updated.name = n }
        if let a = meta.author, !a.isEmpty { updated.author = a }
        if let v = meta.version, !v.isEmpty { updated.version = v }
        if let d = meta.description, !d.isEmpty { updated.description = d }
        
        if let idx = list.firstIndex(where: { $0.id == updated.id }) {
            list[idx] = updated
        } else {
            list.append(updated)
        }
        savePlugins(list)
        if updated.isEnabled {
            let _ = runPlugin(id: updated.id)
        } else {
            stopPlugin(id: updated.id)
        }
        NotificationCenter.default.post(name: GGPluginManager.pluginsChangedNotification, object: nil)
    }
    
    public func deletePlugin(id: String) {
        stopPlugin(id: id)
        var list = loadPlugins()
        list.removeAll(where: { $0.id == id })
        savePlugins(list)
        NotificationCenter.default.post(name: GGPluginManager.pluginsChangedNotification, object: nil)
    }
    
    public func setEnabled(id: String, enabled: Bool) {
        var list = loadPlugins()
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].isEnabled = enabled
        savePlugins(list)
        if enabled {
            let _ = runPlugin(id: id)
        } else {
            stopPlugin(id: id)
        }
        NotificationCenter.default.post(name: GGPluginManager.pluginsChangedNotification, object: nil)
    }
    
    public func resetToDefaults() {
        stopAll()
        savePlugins(defaultPlugins)
        runAllEnabled()
        NotificationCenter.default.post(name: GGPluginManager.pluginsChangedNotification, object: nil)
    }
    
    // MARK: - Runtime
    
    public func isRunning(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeContexts[id] != nil
    }
    
    public func runAllEnabled() {
        for p in getPlugins() where p.isEnabled {
            let _ = runPlugin(id: p.id)
        }
    }
    
    public func stopAll() {
        lock.lock()
        let ids = Array(activeContexts.keys)
        lock.unlock()
        for id in ids {
            stopPlugin(id: id)
        }
    }
    
    public func stopPlugin(id: String) {
        lock.lock()
        activeContexts.removeValue(forKey: id)
        beforeSendHandlers.removeValue(forKey: id)
        lock.unlock()
        GGPluginConsole.shared.add(pluginId: id, level: "info", text: "Плагин остановлен.")
    }
    
    public func runPlugin(id: String) -> (success: Bool, error: String?) {
        guard let plugin = self.plugin(for: id) else {
            return (false, "Плагин не найден")
        }
        
        stopPlugin(id: id)
        
        guard let context = JSContext() else {
            return (false, "Не удалось создать JSContext")
        }
        
        context.exceptionHandler = { _, exception in
            let msg = exception?.toString() ?? "Неизвестная ошибка выполнения"
            GGPluginConsole.shared.add(pluginId: id, level: "error", text: msg)
        }
        
        setupBridge(context: context, pluginId: id)
        
        lock.lock()
        activeContexts[id] = context
        lock.unlock()
        
        GGPluginConsole.shared.add(pluginId: id, level: "info", text: "Запуск плагина \(plugin.name)...")
        
        let result = context.evaluateScript(plugin.code)
        if let exc = context.exception {
            let errStr = exc.toString() ?? "Ошибка выполнения скрипта"
            GGPluginConsole.shared.add(pluginId: id, level: "error", text: errStr)
            return (false, errStr)
        }
        
        GGPluginConsole.shared.add(pluginId: id, level: "info", text: "Плагин успешно запущен.")
        return (true, nil)
    }
    
    // MARK: - JS Bridge Setup
    
    private func setupBridge(context: JSContext, pluginId: String) {
        let ggapi = JSValue(newObjectIn: context)!
        
        // GGAPI.log(...)
        let logBlock: @convention(block) () -> Void = {
            guard let args = JSContext.currentArguments() else { return }
            let text = args.map { ($0 as? JSValue)?.toString() ?? "" }.joined(separator: " ")
            GGPluginConsole.shared.add(pluginId: pluginId, level: "log", text: text)
        }
        ggapi.setObject(logBlock, forKeyedSubscript: "log" as NSString)
        
        // GGAPI.toast(text)
        let toastBlock: @convention(block) (String) -> Void = { text in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: GGPluginManager.toastNotification, object: text)
            }
        }
        ggapi.setObject(toastBlock, forKeyedSubscript: "toast" as NSString)
        
        // GGAPI.app
        let app = JSValue(newObjectIn: context)!
        app.setObject(toastBlock, forKeyedSubscript: "toast" as NSString)
        
        let alertBlock: @convention(block) (String, String) -> Void = { title, message in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: GGPluginManager.alertNotification,
                    object: ["title": title, "message": message]
                )
            }
        }
        app.setObject(alertBlock, forKeyedSubscript: "alert" as NSString)
        
        let openSettingsBlock: @convention(block) () -> Void = {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: GGPluginManager.openSettingsNotification, object: nil)
            }
        }
        app.setObject(openSettingsBlock, forKeyedSubscript: "openSettings" as NSString)
        
        let clientInfoBlock: @convention(block) () -> [String: String] = {
            return [
                "name": "Burmalgram",
                "version": "12.9.2",
                "runtime": "GGAPI 4.1.0"
            ]
        }
        app.setObject(clientInfoBlock, forKeyedSubscript: "clientInfo" as NSString)
        ggapi.setObject(app, forKeyedSubscript: "app" as NSString)
        
        // GGAPI.storage
        let storage = JSValue(newObjectIn: context)!
        let storageGetBlock: @convention(block) (String) -> Any? = { key in
            return UserDefaults.standard.object(forKey: "GGPlugin_Storage_\(pluginId)_\(key)")
        }
        let storageSetBlock: @convention(block) (String, Any) -> Void = { key, val in
            UserDefaults.standard.set(val, forKey: "GGPlugin_Storage_\(pluginId)_\(key)")
        }
        storage.setObject(storageGetBlock, forKeyedSubscript: "get" as NSString)
        storage.setObject(storageSetBlock, forKeyedSubscript: "set" as NSString)
        ggapi.setObject(storage, forKeyedSubscript: "storage" as NSString)
        
        // GGAPI.chat
        let chat = JSValue(newObjectIn: context)!
        let onBeforeSendBlock: @convention(block) (JSValue) -> Void = { [weak self] handler in
            guard let self = self else { return }
            self.lock.lock()
            self.beforeSendHandlers[pluginId] = handler
            self.lock.unlock()
        }
        chat.setObject(onBeforeSendBlock, forKeyedSubscript: "onBeforeSend" as NSString)
        ggapi.setObject(chat, forKeyedSubscript: "chat" as NSString)
        
        // GGAPI.plugins
        let pluginsObj = JSValue(newObjectIn: context)!
        let emitBlock: @convention(block) (String, JSValue) -> Void = { [weak self] event, payload in
            guard let self = self else { return }
            self.lock.lock()
            let listeners = self.eventListeners[event] ?? []
            self.lock.unlock()
            for listener in listeners {
                listener.call(withArguments: [payload])
            }
        }
        let onBlock: @convention(block) (String, JSValue) -> Void = { [weak self] event, handler in
            guard let self = self else { return }
            self.lock.lock()
            if self.eventListeners[event] == nil {
                self.eventListeners[event] = []
            }
            self.eventListeners[event]?.append(handler)
            self.lock.unlock()
        }
        pluginsObj.setObject(emitBlock, forKeyedSubscript: "emit" as NSString)
        pluginsObj.setObject(onBlock, forKeyedSubscript: "on" as NSString)
        ggapi.setObject(pluginsObj, forKeyedSubscript: "plugins" as NSString)
        
        // Expose GGAPI and GG aliases globally
        context.setObject(ggapi, forKeyedSubscript: "GGAPI" as NSString)
        context.setObject(ggapi, forKeyedSubscript: "GG" as NSString)
    }
    
    // MARK: - Hooks
    
    public func transformBeforeSendText(_ text: String) -> String {
        lock.lock()
        let handlers = Array(beforeSendHandlers.values)
        lock.unlock()
        
        var current = text
        for handler in handlers {
            if let res = handler.call(withArguments: [current]), res.isString, let str = res.toString() {
                current = str
            }
        }
        return current
    }
    
    // MARK: - Persistence
    
    private func loadPlugins() -> [GGPlugin] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([GGPlugin].self, from: data) else {
            return []
        }
        return list
    }
    
    private func savePlugins(_ plugins: [GGPlugin]) {
        if let data = try? JSONEncoder().encode(plugins) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
