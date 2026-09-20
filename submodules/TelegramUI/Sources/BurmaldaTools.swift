import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGSimpleSettings

public final class BurmaldaTools {
    
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
    
    // MARK: - Message Sender Helper
    
    public static func sendMessage(
        account: Account,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        text: String,
        entities: [MessageTextEntity] = [],
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
            correlationId: nil,
            bubbleUpEmojiOrStickersets: []
        )
        let _ = (enqueueMessages(account: account, peerId: peerId, messages: [enqueueMsg])
        |> deliverOnMainQueue).startStandalone(next: { messageIds in
            completion?(messageIds.first.flatMap { $0 })
        })
    }
    
    // MARK: - Main Command Handler
    
    public static func handleCommand(
        text: String,
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) -> Bool {
        guard SGSimpleSettings.shared.enableBurmaldaTools else {
            return false
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(".") else {
            return false
        }
        
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let firstWord = parts.first else {
            return false
        }
        
        let cmd = firstWord.lowercased()
        
        // 1. .help / .хелп
        if cmd == ".help" || cmd == ".хелп" {
            let helpText = """
            🛠 **Burmalda Tools (Native):**

            • `.spam [число] [текст]` — Заспамить чат
            • `.text [текст]` — Анимация печати (машинка)
            • `.calc [пример]` — Калькулятор (или `.calculate`)
            • `.coin` — Подбросить монетку (или `.монетка`)
            • `.dox` — Шуточный деанон со спойлерами (или `.докс`)
            • `.send [валюта] [сумма]` — Фейк-чек CryptoBot
            • `.encrypt [текст]` — Зашифровать в Base64
            • `.decrypt` — Расшифровать (ответом на шифр)
            • `.cat` — Котики (или `.кот`)
            • `.help` — Справка по командам
            """
            let (parsedText, entities) = parseSimpleEntities(helpText)
            sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: parsedText, entities: entities)
            return true
        }
        
        // 2. .spam [count] [text] / .спам
        if cmd == ".spam" || cmd == ".спам" {
            guard SGSimpleSettings.shared.burmaldaToolSpam else { return false }
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
        
        // 3. .text [text] / .текст
        if cmd == ".text" || cmd == ".текст" {
            guard SGSimpleSettings.shared.burmaldaToolText else { return false }
            let targetText = parts.dropFirst().joined(separator: " ")
            guard !targetText.isEmpty else {
                sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Пример: .text Привет!")
                return true
            }
            handleTypeText(text: targetText, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 4. .calc [expression] / .calculate / .калькулятор
        if cmd == ".calc" || cmd == ".calculate" || cmd == ".калькулятор" {
            guard SGSimpleSettings.shared.burmaldaToolCalc else { return false }
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
        
        // 5. .coin / .монетка
        if cmd == ".coin" || cmd == ".монетка" {
            guard SGSimpleSettings.shared.burmaldaToolCoin else { return false }
            handleCoin(peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 6. .dox / .докс
        if cmd == ".dox" || cmd == ".докс" {
            guard SGSimpleSettings.shared.burmaldaToolDox else { return false }
            handleDox(peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 7. .send [currency] [amount] / .сенд
        if cmd == ".send" || cmd == ".сенд" {
            guard SGSimpleSettings.shared.burmaldaToolSend else { return false }
            handleSend(parts: parts, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 8. .encrypt [text] / .зашифровать
        if cmd == ".encrypt" || cmd == ".зашифровать" || cmd == ".зашыфровать" {
            guard SGSimpleSettings.shared.burmaldaToolEncrypt else { return false }
            let content = parts.dropFirst().joined(separator: " ")
            handleEncrypt(content: content, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 9. .decrypt / .расшифровать
        if cmd == ".decrypt" || cmd == ".расшифровать" || cmd == ".расшыфровать" {
            guard SGSimpleSettings.shared.burmaldaToolEncrypt else { return false }
            let arg = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil
            handleDecrypt(arg: arg, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, context: context)
            return true
        }
        
        // 10. .cat / .кот / котость
        if cmd == ".cat" || cmd == ".кот" || cmd == ".котость" {
            guard SGSimpleSettings.shared.burmaldaToolCat else { return false }
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
        
        sendMessage(
            account: context.account,
            peerId: peerId,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            text: firstChar
        ) { messageId in
            guard let messageId = messageId else { return }
            
            let totalChars = chars.count
            let step = max(1, totalChars / 25)
            
            var currentLength = 1
            var delay = 0.15
            
            while currentLength < totalChars {
                currentLength = min(currentLength + step, totalChars)
                let partial = String(chars.prefix(currentLength))
                
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
                delay += 0.15
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
        sendMessage(
            account: context.account,
            peerId: peerId,
            threadId: threadId,
            replyToMessageId: replyToMessageId,
            text: "🪙 Подбрасываю монетку..."
        ) { messageId in
            guard let messageId = messageId else { return }
            
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
    
    // MARK: - CryptoBot Cheque
    
    private static func handleSend(
        parts: [String],
        peerId: PeerId,
        threadId: Int64?,
        replyToMessageId: EngineMessageReplySubject?,
        context: AccountContext
    ) {
        guard parts.count >= 3 else {
            sendMessage(account: context.account, peerId: peerId, threadId: threadId, replyToMessageId: replyToMessageId, text: "❌ Пример: .send USDT 100")
            return
        }
        let curr = parts[1].uppercased()
        let amt = parts[2]
        let amtNum = Double(amt.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        let rubRate: Double
        switch curr {
        case "BTC": rubRate = 6_500_000.0
        case "ETH": rubRate = 350_000.0
        case "TON": rubRate = 650.0
        case "USDT", "USD": rubRate = 92.5
        default: rubRate = 90.0
        }
        
        let rubTotal = amtNum * rubRate
        let rubFormatted = String(format: "%.2f", rubTotal)
            .replacingOccurrences(of: "\\B(?=(\\d{3})+(?!\\d))", with: " ", options: .regularExpression)
        
        let text = "🦋 Чек на 🤑 **\(amt) \(curr)** (\(rubFormatted) RUB).\n👉 Получить: https://t.me/CryptoBot"
        let (parsedText, entities) = parseSimpleEntities(text)
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
