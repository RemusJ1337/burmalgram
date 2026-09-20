import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGSimpleSettings
import UndoUI

public final class BurmaldaTools {
    
    // MARK: - State Cache
    
    private struct IncomingRecord {
        let messageId: MessageId
        let peerId: PeerId
        let authorId: PeerId
        let text: String
        let timestamp: Double
    }
    
    private static var recentIncomingRecords: [IncomingRecord] = []
    private static var activeSpamSignatures: [String: Double] = [:]
    private static var lastAutoanswerTimestamps: [PeerId: Double] = [:]
    private static let lock = NSLock()
    
    // MARK: - Toast Helper
    
    public static func showToast(_ text: String, controller: ViewController?, context: AccountContext) {
        if let controller = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .info(title: nil, text: text, timeout: nil, customUndoText: nil),
                elevatedLayout: false,
                action: { _ in return false }
            ), in: .current)
        }
    }
    
    // MARK: - Mute Store
    
    public static func isPeerMuted(_ peerId: PeerId) -> Bool {
        return SGSimpleSettings.shared.burmaldaMutedPeerIds.contains(String(peerId.toInt64()))
    }
    
    @discardableResult
    public static func toggleMute(peerId: PeerId) -> Bool {
        let idVal = String(peerId.toInt64())
        var list = SGSimpleSettings.shared.burmaldaMutedPeerIds
        let isNowMuted: Bool
        if list.contains(idVal) {
            list.removeAll(where: { $0 == idVal })
            isNowMuted = false
        } else {
            list.append(idVal)
            isNowMuted = true
        }
        SGSimpleSettings.shared.burmaldaMutedPeerIds = list
        return isNowMuted
    }
    
    // MARK: - Incoming Message Processor (Real-Time Auto-Antispam, Mute & Autoanswer)
    
    public static func handleIncomingMessage(message: Message, context: AccountContext) {
        guard SGSimpleSettings.shared.enableBurmaldaTools else { return }
        guard message.flags.contains(.Incoming) else { return }
        guard let author = message.author, author.id != context.account.peerId else { return }
        
        let isPM = message.id.peerId.namespace == Namespaces.Peer.CloudUser
        
        // 1. PM Mute logic (delete all new messages from the interlocutor immediately)
        if isPM && isPeerMuted(message.id.peerId) {
            let _ = context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forEveryone).startStandalone()
            return
        }
        
        // 2. Real-Time Auto-Antispam (if > 3 identical messages from same sender, delete repeats)
        if SGSimpleSettings.shared.burmaldaAntispamOn {
            let trimmedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                let now = Date().timeIntervalSince1970
                var idsToDelete: [MessageId] = []
                
                lock.lock()
                recentIncomingRecords.removeAll(where: { now - $0.timestamp > 180.0 })
                activeSpamSignatures = activeSpamSignatures.filter { now - $0.value < 300.0 }
                
                let spamKey = "\(message.id.peerId.toInt64()):\(author.id.toInt64()):\(trimmedText)"
                
                if activeSpamSignatures[spamKey] != nil {
                    // Already flagged as spam: delete this incoming duplicate immediately
                    activeSpamSignatures[spamKey] = now
                    idsToDelete.append(message.id)
                } else {
                    let matchingRecords = recentIncomingRecords.filter {
                        $0.peerId == message.id.peerId && $0.authorId == author.id && $0.text == trimmedText
                    }
                    
                    if !matchingRecords.isEmpty {
                        // Already exists a message with this exact text from this author:
                        // Delete this incoming duplicate immediately, leaving only 1 original message!
                        activeSpamSignatures[spamKey] = now
                        idsToDelete.append(message.id)
                    } else {
                        recentIncomingRecords.append(IncomingRecord(
                            messageId: message.id,
                            peerId: message.id.peerId,
                            authorId: author.id,
                            text: trimmedText,
                            timestamp: now
                        ))
                    }
                }
                lock.unlock()
                
                if !idsToDelete.isEmpty {
                    let _ = context.engine.messages.deleteMessagesInteractively(messageIds: idsToDelete, type: .forEveryone).startStandalone()
                    return
                }
            }
        }
        
        // 3. Offline Auto-Responder in PM
        if isPM && SGSimpleSettings.shared.burmaldaAutoanswerOn {
            if let user = author as? TelegramUser, user.botInfo == nil {
                let now = Date().timeIntervalSince1970
                let delay = Double(max(5, SGSimpleSettings.shared.burmaldaAutoanswerDelay))
                
                var canAnswer = false
                lock.lock()
                let lastTime = lastAutoanswerTimestamps[message.id.peerId] ?? 0.0
                if now - lastTime >= delay {
                    lastAutoanswerTimestamps[message.id.peerId] = now
                    canAnswer = true
                }
                lock.unlock()
                
                if canAnswer {
                    let autoText = SGSimpleSettings.shared.burmaldaAutoanswerText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !autoText.isEmpty {
                        sendMessage(account: context.account, peerId: message.id.peerId, threadId: nil, replyToMessageId: nil, text: autoText)
                    }
                }
            }
        }
    }
    
    // MARK: - Markdown & Spoiler Parser
    
    public static func parseSimpleEntities(_ input: String) -> (String, [MessageTextEntity]) {
        var resultText = ""
        var entities: [MessageTextEntity] = []
        
        var i = input.startIndex
        while i < input.endIndex {
            if input[i...].hasPrefix("||") {
                let contentStart = input.index(i, offsetBy: 2)
                if let closeRange = input[contentStart...].range(of: "||") {
                    let inside = String(input[contentStart..<closeRange.lowerBound])
                    let startUtf16 = (resultText as NSString).length
                    resultText += inside
                    let endUtf16 = (resultText as NSString).length
                    entities.append(MessageTextEntity(range: startUtf16 ..< endUtf16, type: .Spoiler))
                    i = closeRange.upperBound
                    continue
                }
            } else if input[i...].hasPrefix("`") {
                let contentStart = input.index(after: i)
                if let closeIdx = input[contentStart...].firstIndex(of: "`") {
                    let inside = String(input[contentStart..<closeIdx])
                    let startUtf16 = (resultText as NSString).length
                    resultText += inside
                    let endUtf16 = (resultText as NSString).length
                    entities.append(MessageTextEntity(range: startUtf16 ..< endUtf16, type: .Code))
                    i = input.index(after: closeIdx)
                    continue
                }
            } else if input[i...].hasPrefix("**") {
                let contentStart = input.index(i, offsetBy: 2)
                if let closeRange = input[contentStart...].range(of: "**") {
                    let inside = String(input[contentStart..<closeRange.lowerBound])
                    let startUtf16 = (resultText as NSString).length
                    resultText += inside
                    let endUtf16 = (resultText as NSString).length
                    entities.append(MessageTextEntity(range: startUtf16 ..< endUtf16, type: .Bold))
                    i = closeRange.upperBound
                    continue
                }
            }
            resultText.append(input[i])
            i = input.index(after: i)
        }
        return (resultText, entities)
    }
    
    // MARK: - Outgoing Message Sender
    
    public static func sendMessage(
        account: Account,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        text: String,
        entities: [MessageTextEntity] = [],
        correlationId: Int64? = nil,
        completion: ((MessageId?) -> Void)? = nil
    ) {
        var attributes: [MessageAttribute] = []
        if !entities.isEmpty {
            attributes.append(TextEntitiesMessageAttribute(entities: entities))
        }
        let enqueueMsg = EnqueueMessage.message(
            text: text,
            attributes: attributes,
            inlineStickers: [:],
            mediaReference: nil,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            replyToStoryId: nil,
            localGroupingKey: nil,
            correlationId: correlationId,
            bubbleUpEmojiOrStickersets: []
        )
        let _ = (enqueueMessages(account: account, peerId: peerId, messages: [enqueueMsg])
        |> deliverOnMainQueue).startStandalone(next: { messageIds in
            completion?(messageIds.first.flatMap { $0 })
        })
    }
    
    // MARK: - Cloud Message Resolver
    
    private static func resolveCloudMessageId(
        correlationId: Int64,
        context: AccountContext,
        attempt: Int = 0,
        completion: @escaping (MessageId?) -> Void
    ) {
        if let cloudId = context.engine.messages.synchronouslyLookupCorrelationId(correlationId: correlationId) {
            completion(cloudId)
            return
        }
        if attempt >= 20 {
            completion(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            resolveCloudMessageId(correlationId: correlationId, context: context, attempt: attempt + 1, completion: completion)
        }
    }
    
    // MARK: - Main Command Interceptor
    
    public static func handleCommand(
        text: String,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext,
        controller: ViewController?
    ) -> Bool {
        guard SGSimpleSettings.shared.enableBurmaldaTools else {
            return false
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCatSynonym = trimmed.lowercased() == "котость"
        guard trimmed.hasPrefix(".") || isCatSynonym else {
            return false
        }
        
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let firstWord = parts.first else {
            return false
        }
        
        let cmd = firstWord.lowercased()
        
        // Handle sending command to server if requested
        let sendRawToServerIfNeeded: () -> Void = {
            if SGSimpleSettings.shared.burmaldaSendCommandsToServer {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: text) { sentCmdId in
                    if SGSimpleSettings.shared.burmaldaDeleteCommands, let sentCmdId = sentCmdId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let _ = context.engine.messages.deleteMessagesInteractively(messageIds: [sentCmdId], type: .forEveryone).startStandalone()
                        }
                    }
                }
            }
        }
        
        // 1. .help / .хелп
        if cmd == ".help" || cmd == ".хелп" {
            sendRawToServerIfNeeded()
            let helpText = """
            🛠 **Burmalda Tools (Native):**

            • `.spam [число] [текст]` — Заспамить чат
            • `.text [текст]` — Анимация печати (машинка)
            • `.calc [пример]` — Калькулятор (или `.calculate`, `.калькулятор`)
            • `.coin` — Подбросить монетку (или `.монетка`)
            • `.dox` — Шуточный деанон со спойлерами (или `.докс`)
            • `.encrypt [текст]` — Зашифровать в Base64
            • `.decrypt` — Расшифровать (ответом на шифр)
            • `.cat` — Котики (или `.кот`, `котость`)
            • `.mute` — Мут в ЛС (удаляет сообщения собеседника)
            • `.antispam` — Очистить повторяющиеся сообщения
            • `.antispam-on` / `.antispam-off` — Авто-антиспам
            • `.help` — Справка по командам
            """
            let (parsedText, entities) = parseSimpleEntities(helpText)
            sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
            return true
        }
        
        // 2. .mute / .мут (логика мутов в лс - просто удаляет все новые сообщения собеседника)
        if cmd == ".mute" || cmd == ".мут" {
            guard SGSimpleSettings.shared.burmaldaToolMute else { return false }
            sendRawToServerIfNeeded()
            if peerId.namespace != Namespaces.Peer.CloudUser {
                showToast("❌ Мут работает только в личных сообщениях (ЛС)!", controller: controller, context: context)
                return true
            }
            let isMuted = toggleMute(peerId: peerId)
            if isMuted {
                showToast("🔇 Мут в ЛС включен!\nНовые сообщения собеседника будут сразу удаляться.", controller: controller, context: context)
            } else {
                showToast("🔊 Мут в ЛС снят!", controller: controller, context: context)
            }
            return true
        }
        
        // 3. .antispam / .антиспам (удалить повторяющиеся сообщения в лс или чатах если админ)
        if cmd == ".antispam" || cmd == ".антиспам" {
            guard SGSimpleSettings.shared.burmaldaToolAntispam else { return false }
            sendRawToServerIfNeeded()
            
            let _ = (context.account.postbox.transaction { transaction -> (canDeleteAll: Bool, duplicateIds: [MessageId], scanned: Int) in
                var canDeleteAll = false
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    canDeleteAll = true
                } else if let channel = transaction.getPeer(peerId) as? TelegramChannel {
                    if channel.hasPermission(.deleteAllMessages) || channel.flags.contains(.isCreator) {
                        canDeleteAll = true
                    }
                } else if let group = transaction.getPeer(peerId) as? TelegramGroup {
                    if case .creator = group.role {
                        canDeleteAll = true
                    } else if case .admin = group.role {
                        canDeleteAll = true
                    }
                }
                
                var seenKeys: Set<String> = []
                var duplicateIds: [MessageId] = []
                var count = 0
                
                transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: 150, { msg in
                    count += 1
                    let authorId = msg.author?.id.toInt64() ?? 0
                    let isOwn = (msg.author?.id == context.account.peerId)
                    
                    // If not admin in group, regular users can always delete their own duplicate messages
                    if !canDeleteAll && !isOwn {
                        return true
                    }
                    
                    let contentKey: String
                    let trimmed = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        contentKey = "t:\(trimmed)"
                    } else if let file = msg.media.first as? TelegramMediaFile {
                        contentKey = "f:\(file.fileId.id)"
                    } else {
                        return true
                    }
                    
                    let key = "\(authorId)_\(contentKey)"
                    if seenKeys.contains(key) {
                        duplicateIds.append(msg.id)
                    } else {
                        seenKeys.insert(key)
                    }
                    return true
                })
                
                return (canDeleteAll, duplicateIds, count)
            } |> deliverOnMainQueue).startStandalone(next: { result in
                if result.duplicateIds.isEmpty {
                    showToast("🧹 Повторяющихся сообщений не найдено (проверено: \(result.scanned))", controller: controller, context: context)
                } else {
                    let _ = context.engine.messages.deleteMessagesInteractively(messageIds: result.duplicateIds, type: .forEveryone).startStandalone()
                    showToast("🧹 Антиспам: удалено \(result.duplicateIds.count) повторных сообщений!", controller: controller, context: context)
                }
            })
            return true
        }
        
        // 4. .antispam-on / .antispam-off / .антиспам-вкл / .антиспам-выкл
        if cmd == ".antispam-on" || cmd == ".антиспам-вкл" {
            sendRawToServerIfNeeded()
            SGSimpleSettings.shared.burmaldaAntispamOn = true
            showToast("✅ Авто-антиспам включен!\n(При >3 одинаковых сообщений в ЛС повторки удаляются)", controller: controller, context: context)
            return true
        }
        if cmd == ".antispam-off" || cmd == ".антиспам-выкл" {
            sendRawToServerIfNeeded()
            SGSimpleSettings.shared.burmaldaAntispamOn = false
            showToast("❌ Авто-антиспам выключен", controller: controller, context: context)
            return true
        }
        
        // 5. .spam [count] [text] / .спам
        if cmd == ".spam" || cmd == ".спам" {
            guard SGSimpleSettings.shared.burmaldaToolSpam else { return false }
            sendRawToServerIfNeeded()
            
            let count: Int
            let spamText: String
            
            if parts.count >= 3 && Int(parts[1]) != nil {
                count = min(max(1, Int(parts[1]) ?? 10), 50)
                let dropCount = 2
                spamText = parts.dropFirst(dropCount).joined(separator: " ")
            } else if parts.count >= 2 {
                if let parsedNum = Int(parts[1]) {
                    count = min(max(1, parsedNum), 50)
                    spamText = "Спам!"
                } else {
                    count = 10
                    spamText = parts.dropFirst(1).joined(separator: " ")
                }
            } else {
                count = 10
                spamText = "Спам!"
            }
            
            for i in 0 ..< count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                    sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: spamText)
                }
            }
            return true
        }
        
        // 6. .text [text] / .текст
        if cmd == ".text" || cmd == ".текст" {
            guard SGSimpleSettings.shared.burmaldaToolText else { return false }
            sendRawToServerIfNeeded()
            let targetText = parts.dropFirst().joined(separator: " ")
            guard !targetText.isEmpty else {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Пример: .text Привет!")
                return true
            }
            handleTypeText(text: targetText, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 7. .calc [expression] / .calculate / .калькулятор
        if cmd == ".calc" || cmd == ".calculate" || cmd == ".калькулятор" {
            guard SGSimpleSettings.shared.burmaldaToolCalc else { return false }
            sendRawToServerIfNeeded()
            let expr = parts.dropFirst().joined(separator: " ")
            guard !expr.isEmpty else {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Пример: .calc 2 + 2 * 2")
                return true
            }
            if let result = evaluateMathExpression(expr) {
                let msg = "🧮 `\(expr) = \(result)`"
                let (parsedText, entities) = parseSimpleEntities(msg)
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
            } else {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Ошибка вычисления! Допускаются только цифры и знаки (+, -, *, /, .)")
            }
            return true
        }
        
        // 8. .coin / .монетка
        if cmd == ".coin" || cmd == ".монетка" {
            guard SGSimpleSettings.shared.burmaldaToolCoin else { return false }
            sendRawToServerIfNeeded()
            handleCoin(peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 9. .dox / .докс
        if cmd == ".dox" || cmd == ".докс" {
            guard SGSimpleSettings.shared.burmaldaToolDox else { return false }
            sendRawToServerIfNeeded()
            handleDox(peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }

        
        // 11. .encrypt [text] / .зашифровать / .зашыфровать
        if cmd == ".encrypt" || cmd == ".зашифровать" || cmd == ".зашыфровать" {
            guard SGSimpleSettings.shared.burmaldaToolEncrypt else { return false }
            sendRawToServerIfNeeded()
            let content = parts.dropFirst().joined(separator: " ")
            handleEncrypt(content: content, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 12. .decrypt / .расшифровать / .расшыфровать
        if cmd == ".decrypt" || cmd == ".расшифровать" || cmd == ".расшыфровать" {
            guard SGSimpleSettings.shared.burmaldaToolEncrypt else { return false }
            sendRawToServerIfNeeded()
            let arg = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil
            handleDecrypt(arg: arg, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 13. .cat / .кот / .котость / котость
        if cmd == ".cat" || cmd == ".кот" || cmd == ".котость" || isCatSynonym {
            guard SGSimpleSettings.shared.burmaldaToolCat else { return false }
            sendRawToServerIfNeeded()
            handleCat(peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        return false
    }
    
    // MARK: - Typewriter Animation
    
    private static func handleTypeText(
        text: String,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        guard !text.isEmpty else { return }
        
        let chars = Array(text)
        let firstChar = String(chars[0])
        let correlationId = Int64.random(in: 1...Int64.max)
        
        sendMessage(
            account: context.account,
            peerId: peerId,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            text: firstChar,
            correlationId: correlationId
        ) { _ in
            resolveCloudMessageId(correlationId: correlationId, context: context) { cloudMessageId in
                guard let messageId = cloudMessageId else { return }
                
                let totalChars = chars.count
                if totalChars <= 1 { return }
                
                var targetLengths: [Int] = []
                let steps = min(6, totalChars)
                if steps > 1 {
                    for s in 1...steps {
                        let len = max(1, Int(round(Double(totalChars) * Double(s) / Double(steps))))
                        if !targetLengths.contains(len) {
                            targetLengths.append(len)
                        }
                    }
                }
                if targetLengths.isEmpty || targetLengths.last != totalChars {
                    targetLengths.append(totalChars)
                }
                
                for (index, len) in targetLengths.enumerated() {
                    let delay = Double(index + 1) * 0.45
                    let partial = String(chars.prefix(len))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let _ = context.engine.messages.requestEditMessage(
                            messageId: messageId,
                            text: partial,
                            media: .keep,
                            entities: nil,
                            richText: nil,
                            inlineStickers: [:]
                        ).startStandalone()
                    }
                }
            }
        }
    }
    
    // MARK: - Coin Animation
    
    private static func handleCoin(
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        let correlationId = Int64.random(in: 1...Int64.max)
        sendMessage(
            account: context.account,
            peerId: peerId,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            text: "🪙 Подбрасываю монетку...",
            correlationId: correlationId
        ) { _ in
            resolveCloudMessageId(correlationId: correlationId, context: context) { cloudMessageId in
                guard let messageId = cloudMessageId else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let _ = context.engine.messages.requestEditMessage(
                        messageId: messageId,
                        text: "🔄 Крутится...",
                        media: .keep,
                        entities: nil,
                        richText: nil,
                        inlineStickers: [:]
                    ).startStandalone()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        let result = Bool.random() ? "🦅 Орёл!" : "👑 Решка!"
                        let _ = context.engine.messages.requestEditMessage(
                            messageId: messageId,
                            text: result,
                            media: .keep,
                            entities: nil,
                            richText: nil,
                            inlineStickers: [:]
                        ).startStandalone()
                    }
                }
            }
        }
    }
    
    // MARK: - Dox
    
    private static func handleDox(
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        let rawDox = """
        IP — ||67.228.52.1488||
        ФИО — ||Фогов Ч Бурмалдаевич||
        Адрес — ||г. Верхний Новгород, ул. Муренская, д. 67||
        Телефон — ||+7 (228) 1488-52-42||
        Паспорт — ||1488 228000||
        Банковская карта — ||Бурмалбанк (*1488)||
        Дата рождения — ||01.01.2001||
        Родственники — ||Друн||
        Место работы — ||Завод Производства Чекушки №5||
        Автомобиль — ||Lada Granta (с228во 67)||
        """
        let (parsedText, entities) = parseSimpleEntities(rawDox)
        sendMessage(
            account: context.account,
            peerId: peerId,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            text: parsedText,
            entities: entities
        )
    }
    
    // MARK: - Encryption / Decryption
    
    private static func handleEncrypt(
        content: String,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Пример: .encrypt Ваш текст")
            return
        }
        let b64 = Data(trimmed.utf8).base64EncodedString()
        let text = "🔐 **Зашифровано:**\n`\(b64)`\n\n[BURMALDA_ENC]"
        let (parsedText, entities) = parseSimpleEntities(text)
        sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
    }
    
    private static func handleDecrypt(
        arg: String?,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        if let replySubject = replyToMessageId {
            let _ = (context.account.postbox.transaction { transaction -> Message? in
                return transaction.getMessage(replySubject.messageId)
            } |> deliverOnMainQueue).startStandalone(next: { replyMsg in
                guard let replyText = replyMsg?.text else {
                    sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Ответьте на зашифрованное сообщение!")
                    return
                }
                guard replyText.contains("[BURMALDA_ENC]") else {
                    sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Это не шифровка Burmalda Tools!")
                    return
                }
                let cleaned = replyText.replacingOccurrences(of: "[BURMALDA_ENC]", with: "")
                    .replacingOccurrences(of: "🔐", with: "")
                    .replacingOccurrences(of: "Зашифровано:", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let data = Data(base64Encoded: cleaned), let decoded = String(data: data, encoding: .utf8) {
                    let msg = "🔓 **Расшифровано:**\n\(decoded)"
                    let (parsedText, entities) = parseSimpleEntities(msg)
                    sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
                } else {
                    sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Ошибка расшифровки! Код поврежден.")
                }
            })
            return
        }
        
        if let arg = arg, !arg.isEmpty {
            let cleaned = arg.replacingOccurrences(of: "[BURMALDA_ENC]", with: "")
                .replacingOccurrences(of: "`", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = Data(base64Encoded: cleaned), let decoded = String(data: data, encoding: .utf8) {
                let msg = "🔓 **Расшифровано:**\n\(decoded)"
                let (parsedText, entities) = parseSimpleEntities(msg)
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
            } else {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Ошибка расшифровки! Код поврежден.")
            }
        } else {
            sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Ответьте командой .decrypt на зашифрованное сообщение или введите: .decrypt <код>")
        }
    }
    
    // MARK: - Cat
    
    private static func handleCat(
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        let catQuotes = [
            "(=^･ω･^=) Мяу! Котик желает тебе прекрасного дня! 🐾",
            "/ᐠ｡ꞈ｡ᐟ\\ Мур-мур! Котость успешно доставлена.",
            "( ˶•ω•˶) Котик передает тебе тепло и мурчание! ✨",
            "ฅ(•ㅅ•❀)ฅ Бурмалдинский кот одобряет этот чат!",
            "/ᐠ. ｡.ᐟ\\ ᵐᵉᵒʷˎˊ˗ Ты лучший!",
            "(^・x・^) Котость зашкаливает! 🐱"
        ]
        let randomCat = catQuotes.randomElement() ?? "(=^･ω･^=) Мяу!"
        sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: randomCat)
    }
    
    // MARK: - Math Expression Evaluator
    
    private static func evaluateMathExpression(_ expr: String) -> String? {
        let cleaned = expr.replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: ":", with: "/")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let allowed = CharacterSet(charactersIn: "0123456789+-*/.() ")
        guard cleaned.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        
        let expression = NSExpression(format: cleaned)
        guard let value = expression.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }
        
        let dVal = value.doubleValue
        if dVal.isNaN || dVal.isInfinite {
            return nil
        }
        
        if dVal.truncatingRemainder(dividingBy: 1) == 0 && dVal < Double(Int64.max) && dVal > Double(Int64.min) {
            return "\(Int64(dVal))"
        } else {
            return String(format: "%.4f", dVal).replacingOccurrences(of: "0+$", with: "", options: .regularExpression).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        }
    }
}
