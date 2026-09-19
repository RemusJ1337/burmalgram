import Foundation
import UIKit
import WebKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class GGPluginEditorController: ViewController, WKScriptMessageHandler {
    private let context: AccountContext
    private var plugin: GGPlugin
    private var webView: WKWebView?
    private var isReady: Bool = false
    
    public init(context: AccountContext, plugin: GGPlugin) {
        self.context = context
        self.plugin = plugin
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
        self.title = plugin.name
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ViewControllerTracingNode()
        self.displayNode.backgroundColor = .black
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "ggplugin")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: self.view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.bounces = false
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        self.view.addSubview(webView)
        self.webView = webView
        
        loadIdeHtml()
    }
    
    private func findIdeHtmlUrl() -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "ide", withExtension: "html", subdirectory: "GGPlugin") {
            return url
        }
        if let url = bundle.url(forResource: "ide", withExtension: "html", subdirectory: "SettingsUIBundle.bundle") {
            return url
        }
        if let url = bundle.url(forResource: "ide", withExtension: "html") {
            return url
        }
        // Check Frameworks bundles
        let frameworksUrl = bundle.bundleURL.appendingPathComponent("Frameworks")
        if let enumerator = FileManager.default.enumerator(at: frameworksUrl, includingPropertiesForKeys: nil) {
            for case let fileUrl as URL in enumerator {
                if fileUrl.lastPathComponent == "ide.html" {
                    return fileUrl
                }
            }
        }
        return nil
    }
    
    private func loadSchemaJson() -> [String: Any]? {
        let bundle = Bundle.main
        var schemaUrl: URL? = bundle.url(forResource: "ggapi.schema", withExtension: "json", subdirectory: "GGPlugin")
        if schemaUrl == nil {
            schemaUrl = bundle.url(forResource: "ggapi.schema", withExtension: "json", subdirectory: "SettingsUIBundle.bundle")
        }
        if schemaUrl == nil {
            schemaUrl = bundle.url(forResource: "ggapi.schema", withExtension: "json")
        }
        if schemaUrl == nil {
            let frameworksUrl = bundle.bundleURL.appendingPathComponent("Frameworks")
            if let enumerator = FileManager.default.enumerator(at: frameworksUrl, includingPropertiesForKeys: nil) {
                for case let fileUrl as URL in enumerator {
                    if fileUrl.lastPathComponent == "ggapi.schema.json" {
                        schemaUrl = fileUrl
                        break
                    }
                }
            }
        }
        guard let url = schemaUrl, let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    private func loadIdeHtml() {
        if let htmlUrl = findIdeHtmlUrl() {
            webView?.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl.deletingLastPathComponent())
        } else {
            let fallbackHtml = """
            <!DOCTYPE html>
            <html>
            <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
            <body style="background:#1e1e1e;color:#fff;font-family:sans-serif;padding:20px;">
                <h2>GGPlugin IDE</h2>
                <p>Редактор встроенных плагинов Burmalgram.</p>
                <textarea id="editor" style="width:100%;height:300px;background:#2d2d2d;color:#fff;border:none;padding:10px;font-family:monospace;font-size:14px;border-radius:8px;">\(self.plugin.code)</textarea>
                <br><br>
                <button onclick="save()" style="padding:10px 20px;background:#007aff;color:#fff;border:none;border-radius:6px;font-size:16px;">Сохранить и Запустить</button>
                <script>
                    function save() {
                        const code = document.getElementById('editor').value;
                        window.webkit.messageHandlers.ggplugin.postMessage({ type: 'codeChanged', code: code });
                        window.webkit.messageHandlers.ggplugin.postMessage({ type: 'save' });
                        window.webkit.messageHandlers.ggplugin.postMessage({ type: 'run' });
                    }
                </script>
            </body>
            </html>
            """
            webView?.loadHTMLString(fallbackHtml, baseURL: nil)
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else {
            return
        }
        
        switch type {
        case "ready":
            self.isReady = true
            sendCurrentStateToWebView()
            
        case "codeChanged":
            if let code = body["code"] as? String {
                self.plugin.code = code
            }
            
        case "save":
            GGPluginManager.shared.savePlugin(self.plugin)
            if let updated = GGPluginManager.shared.plugin(for: self.plugin.id) {
                self.plugin = updated
                self.title = updated.name
            }
            sendCurrentStateToWebView()
            
        case "run":
            GGPluginManager.shared.savePlugin(self.plugin)
            let result = GGPluginManager.shared.runPlugin(id: self.plugin.id)
            if !result.success, let err = result.error {
                let alert = UIAlertController(title: "Ошибка запуска", message: err, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            sendCurrentStateToWebView()
            
        case "stop":
            GGPluginManager.shared.stopPlugin(id: self.plugin.id)
            sendCurrentStateToWebView()
            
        case "restart":
            GGPluginManager.shared.savePlugin(self.plugin)
            let _ = GGPluginManager.shared.runPlugin(id: self.plugin.id)
            sendCurrentStateToWebView()
            
        case "duplicate":
            var dup = self.plugin
            dup.id = UUID().uuidString
            dup.name = "\(self.plugin.name) (Копия)"
            dup.isBuiltin = false
            GGPluginManager.shared.savePlugin(dup)
            let editor = GGPluginEditorController(context: self.context, plugin: dup)
            self.push(editor)
            
        case "delete":
            let alert = UIAlertController(title: "Удалить плагин?", message: "Это действие нельзя отменить.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
                guard let self = self else { return }
                GGPluginManager.shared.deletePlugin(id: self.plugin.id)
                self.navigationController?.popViewController(animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            self.present(alert, animated: true)
            
        case "openDocs":
            let docs = pluginAPIDocsController(context: self.context)
            self.push(docs)
            
        default:
            break
        }
    }
    
    private func sendCurrentStateToWebView() {
        let isRunning = GGPluginManager.shared.isRunning(id: self.plugin.id)
        let lines = GGPluginConsole.shared.lines(pluginId: self.plugin.id).map { line -> [String: Any] in
            return [
                "level": line.level,
                "text": line.text,
                "timestamp": line.timestamp
            ]
        }
        
        var stateDict: [String: Any] = [
            "plugin": [
                "id": self.plugin.id,
                "name": self.plugin.name,
                "author": self.plugin.author,
                "version": self.plugin.version,
                "description": self.plugin.description,
                "code": self.plugin.code
            ],
            "runtime": [
                "state": isRunning ? "running" : "stopped"
            ],
            "console": lines
        ]
        
        if let schema = loadSchemaJson() {
            stateDict["schema"] = schema
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: stateDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let js = "if (window.GGPluginIDE && window.GGPluginIDE.setState) { window.GGPluginIDE.setState(\(jsonString)); }"
        self.webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}
