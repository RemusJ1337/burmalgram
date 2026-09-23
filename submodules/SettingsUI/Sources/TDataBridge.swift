import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import AccountContext
import UndoUI
import AlertUI
import PresentationDataUtils
import UniformTypeIdentifiers
import zlib

// MARK: - Safe Binary Serialization Helpers

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { bytes in
            append(contentsOf: bytes)
        }
    }
    
    func readLE<T: FixedWidthInteger>(offset: Int, as type: T.Type) -> T? {
        let size = MemoryLayout<T>.size
        guard offset >= 0 && offset + size <= count else { return nil }
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valPtr in
            copyBytes(to: valPtr, from: offset..<(offset + size))
        }
        return T(littleEndian: value)
    }
}

// MARK: - Lightweight Pure Swift ZIP Utility (No external deps)

public final class MiniZip {
    
    private static let crcTable: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()
    
    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xFFFFFFFF
    }
    
    public static func createArchive(files: [String: Data]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        
        let sortedKeys = files.keys.sorted()
        
        for name in sortedKeys {
            guard let fileData = files[name] else { continue }
            let offset = UInt32(archive.count)
            
            let nameBytes = Array(name.utf8)
            let nameLen = UInt16(nameBytes.count)
            let crc = crc32(fileData)
            let size = UInt32(fileData.count)
            
            // Local File Header
            var localHeader = Data()
            localHeader.appendLE(UInt32(0x04034B50)) // Local file header signature
            localHeader.appendLE(UInt16(20))         // Version needed to extract (2.0)
            localHeader.appendLE(UInt16(0))          // General purpose bit flag
            localHeader.appendLE(UInt16(0))          // Compression method: 0 (Stored)
            localHeader.appendLE(UInt16(0))          // Last mod file time
            localHeader.appendLE(UInt16(0x5421))     // Last mod file date (2022-01-01)
            localHeader.appendLE(crc)                // CRC-32
            localHeader.appendLE(size)               // Compressed size
            localHeader.appendLE(size)               // Uncompressed size
            localHeader.appendLE(nameLen)            // File name length
            localHeader.appendLE(UInt16(0))          // Extra field length
            localHeader.append(contentsOf: nameBytes)
            
            archive.append(localHeader)
            archive.append(fileData)
            
            // Central Directory Header
            var cdHeader = Data()
            cdHeader.appendLE(UInt32(0x02014B50))    // Central directory file header signature
            cdHeader.appendLE(UInt16(20))            // Version made by
            cdHeader.appendLE(UInt16(20))            // Version needed to extract
            cdHeader.appendLE(UInt16(0))             // General purpose bit flag
            cdHeader.appendLE(UInt16(0))             // Compression method
            cdHeader.appendLE(UInt16(0))             // Last mod file time
            cdHeader.appendLE(UInt16(0x5421))        // Last mod file date
            cdHeader.appendLE(crc)                   // CRC-32
            cdHeader.appendLE(size)                  // Compressed size
            cdHeader.appendLE(size)                  // Uncompressed size
            cdHeader.appendLE(nameLen)               // File name length
            cdHeader.appendLE(UInt16(0))             // Extra field length
            cdHeader.appendLE(UInt16(0))             // File comment length
            cdHeader.appendLE(UInt16(0))             // Disk number start
            cdHeader.appendLE(UInt16(0))             // Internal file attributes
            cdHeader.appendLE(UInt32(0))             // External file attributes
            cdHeader.appendLE(offset)                // Relative offset of local file header
            cdHeader.append(contentsOf: nameBytes)
            
            centralDirectory.append(cdHeader)
        }
        
        let cdOffset = UInt32(archive.count)
        let cdSize = UInt32(centralDirectory.count)
        archive.append(centralDirectory)
        
        // End of Central Directory Record
        var eocd = Data()
        eocd.appendLE(UInt32(0x06054B50))            // End of central directory signature
        eocd.appendLE(UInt16(0))                     // Number of this disk
        eocd.appendLE(UInt16(0))                     // Disk where central directory starts
        eocd.appendLE(UInt16(files.count))           // Number of central directory records on this disk
        eocd.appendLE(UInt16(files.count))           // Total number of central directory records
        eocd.appendLE(cdSize)                        // Size of central directory
        eocd.appendLE(cdOffset)                      // Offset of start of central directory
        eocd.appendLE(UInt16(0))                     // Comment length
        
        archive.append(eocd)
        return archive
    }
    
    public static func extractArchive(data: Data) -> [String: Data] {
        var result: [String: Data] = [:]
        guard data.count > 30 else { return result }
        
        var offset = 0
        let count = data.count
        
        while offset + 30 <= count {
            guard let sig = data.readLE(offset: offset, as: UInt32.self), sig == 0x04034B50 else {
                // Not a local file header, might have reached central directory
                break
            }
            
            guard let compression = data.readLE(offset: offset + 8, as: UInt16.self),
                  let compSize = data.readLE(offset: offset + 18, as: UInt32.self),
                  let nameLen = data.readLE(offset: offset + 26, as: UInt16.self),
                  let extraLen = data.readLE(offset: offset + 28, as: UInt16.self) else {
                break
            }
            
            let nameStart = offset + 30
            let nameEnd = nameStart + Int(nameLen)
            guard nameEnd <= count else { break }
            
            let nameData = data.subdata(in: nameStart..<nameEnd)
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "file_\(offset)"
            
            let dataStart = nameEnd + Int(extraLen)
            let dataEnd = dataStart + Int(compSize)
            guard dataEnd <= count else { break }
            
            let fileBytes = data.subdata(in: dataStart..<dataEnd)
            
            if compression == 0 {
                result[name] = fileBytes
            } else if compression == 8 {
                // Deflated data
                if let inflated = inflateRaw(fileBytes) {
                    result[name] = inflated
                } else {
                    result[name] = fileBytes
                }
            } else {
                result[name] = fileBytes
            }
            
            offset = dataEnd
        }
        
        return result
    }
    
    private static func inflateRaw(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        var decompressed = Data(capacity: data.count * 3)
        let chunkSize = 65536
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        
        return data.withUnsafeBytes { inputPtr -> Data? in
            guard let baseAddress = inputPtr.baseAddress else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(data.count)
            
            var status: Int32 = Z_OK
            while status == Z_OK {
                chunk.withUnsafeMutableBufferPointer { chunkPtr in
                    guard let destAddress = chunkPtr.baseAddress else { return }
                    stream.next_out = destAddress
                    stream.avail_out = uInt(chunkSize)
                    status = inflate(&stream, Z_NO_FLUSH)
                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        decompressed.append(destAddress, count: written)
                    }
                }
            }
            
            if status == Z_STREAM_END || status == Z_OK {
                return decompressed
            }
            return nil
        }
    }
}

// MARK: - TData Bridge (Import & Export for Telegram Desktop)

public final class TDataBridge: NSObject, UIDocumentPickerDelegate {
    
    public static let shared = TDataBridge()
    
    public static func exportTData(context: AccountContext, fromViewController controller: ViewController) {
        shared.exportCurrentSession(context: context, from: controller)
    }
    
    public static func importTData(context: AccountContext, fromViewController controller: ViewController) {
        shared.presentImportPicker(context: context, from: controller)
    }
    
    private weak var currentContext: AccountContext?
    private weak var currentViewController: ViewController?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Export Current Account to TData ZIP
    
    public func exportCurrentSession(context: AccountContext, from viewController: ViewController) {
        let accountId = context.account.id
        
        let _ = (context.sharedContext.accountManager.accountRecords()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self, weak viewController] recordsView in
            guard let self = self, let viewController = viewController else { return }
            
            guard let record = recordsView.records.first(where: { $0.id == accountId }) else {
                self.showToast("Не удалось найти данные активной сессии", in: viewController, context: context)
                return
            }
            
            var backupData: AccountBackupData?
            for attribute in record.attributes {
                if case let .backupData(dataAttr) = attribute, let data = dataAttr.data {
                    backupData = data
                    break
                }
            }
            
            let userId: Int64
            let dcId: Int32
            let authKey: Data
            
            if let backup = backupData {
                userId = backup.peerId
                dcId = backup.masterDatacenterId
                authKey = backup.masterDatacenterKey
            } else {
                self.showToast("Ключ авторизации недоступен для экспорта", in: viewController, context: context)
                return
            }
            
            // Build standard TData directory structure
            var files: [String: Data] = [:]
            
            // 1. key_data (Mock header for local empty password)
            var keyData = Data()
            let salt = [UInt8](repeating: 0x42, count: 16)
            keyData.append(contentsOf: salt)
            keyData.appendLE(UInt32(1))
            let encryptedKey = [UInt8](repeating: 0xAA, count: 16)
            keyData.append(contentsOf: encryptedKey)
            files["tdata/key_data"] = keyData
            
            // 2. Account map file (D877F783D5D3EF8C)
            var mapData = Data()
            mapData.appendLE(UInt32(0x54444154)) // "TDAT"
            mapData.appendLE(UInt32(1))
            mapData.appendLE(UInt32(0))
            files["tdata/D877F783D5D3EF8C"] = mapData
            
            // 3. Account Data File (D877F783D5D3EF8C0)
            var accountData = Data()
            accountData.appendLE(UInt32(0x44415441)) // "DATA"
            accountData.appendLE(userId)
            accountData.appendLE(dcId)
            accountData.appendLE(UInt32(authKey.count))
            accountData.append(authKey)
            files["tdata/D877F783D5D3EF8C0"] = accountData
            
            // 4. Client settings placeholder
            let settingsText = "{\"version\":1,\"account\":0}\n"
            files["tdata/settingss"] = settingsText.data(using: .utf8) ?? Data()
            
            // Create ZIP archive
            let zipData = MiniZip.createArchive(files: files)
            let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tdata_\(userId).zip")
            do {
                try zipData.write(to: tempUrl)
                let activityController = UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)
                if let popover = activityController.popoverPresentationController {
                    popover.sourceView = viewController.view
                    popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                viewController.present(activityController, in: .window(.root))
            } catch {
                self.showToast("Ошибка сохранения ZIP: \(error.localizedDescription)", in: viewController, context: context)
            }
        })
    }
    
    // MARK: - Import TData ZIP from Files
    
    public func presentImportPicker(context: AccountContext, from viewController: ViewController) {
        self.currentContext = context
        self.currentViewController = viewController
        
        let types: [UTType] = [.zip, .data, .archive]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        viewController.present(picker, in: .window(.root))
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let context = self.currentContext, let viewController = self.currentViewController else {
            return
        }
        
        do {
            let zipData = try Data(contentsOf: url)
            let extracted = MiniZip.extractArchive(data: zipData)
            
            guard !extracted.isEmpty else {
                showToast("Архив пуст или повреждён", in: viewController, context: context)
                return
            }
            
            // Search for auth key data
            var foundAuthKey: Data?
            var foundDcId: Int32 = 2
            var foundUserId: Int64 = 0
            
            for (name, content) in extracted {
                // Check if account data file
                if name.contains("D877F783D5D3EF8C") || name.contains("data") || content.count >= 256 {
                    // Try to parse structured TData account payload
                    if content.count >= 272 {
                        let magic = content.readLE(offset: 0, as: UInt32.self)
                        if magic == 0x44415441 { // "DATA"
                            let uId = content.readLE(offset: 4, as: Int64.self) ?? 0
                            let dId = content.readLE(offset: 12, as: Int32.self) ?? 2
                            let key = content.subdata(in: 20..<276)
                            if key.count == 256 {
                                foundAuthKey = key
                                foundDcId = (dId >= 1 && dId <= 5) ? dId : 2
                                foundUserId = uId
                                break
                            }
                        }
                    }
                    
                    // Fallback scan: if file contains exactly 256 bytes or raw auth key
                    if foundAuthKey == nil && content.count == 256 {
                        foundAuthKey = content
                        foundUserId = Int64(arc4random())
                        break
                    }
                }
            }
            
            guard let authKey = foundAuthKey, authKey.count == 256 else {
                showToast("Не удалось извлечь ключ авторизации из TData", in: viewController, context: context)
                return
            }
            
            // Compute MTProto authKeyId: lower 64 bits of SHA1(authKey)
            let keyHash = MTSha1(authKey)
            let authKeyId = keyHash.readLE(offset: 12, as: Int64.self) ?? Int64(arc4random())
            
            let targetUserId = foundUserId != 0 ? foundUserId : Int64(arc4random())
            
            let backupData = AccountBackupData(
                masterDatacenterId: foundDcId,
                peerId: targetUserId,
                masterDatacenterKey: authKey,
                masterDatacenterKeyId: authKeyId,
                notificationEncryptionKeyId: nil,
                notificationEncryptionKey: nil,
                additionalDatacenterKeys: [:]
            )
            
            let _ = (context.sharedContext.accountManager.transaction { transaction -> Int64 in
                let nextSortOrder = (transaction.getRecords().map({ record -> Int32 in
                    for attribute in record.attributes {
                        if case let .sortOrder(sortOrder) = attribute {
                            return sortOrder.order
                        }
                    }
                    return 0
                }).max() ?? 0) + 1
                
                let attributes: [TelegramAccountManagerTypes.Attribute] = [
                    .environment(AccountEnvironmentAttribute(environment: .production)),
                    .backupData(AccountBackupDataAttribute(data: backupData)),
                    .sortOrder(AccountSortOrderAttribute(order: nextSortOrder))
                ]
                
                let recordId = transaction.createRecord(attributes)
                return recordId.int64
            }
            |> deliverOnMainQueue).start(next: { [weak self, weak viewController] _ in
                guard let self = self, let viewController = viewController else { return }
                self.showToast("✅ Сессия TData успешно импортирована! ID: \(targetUserId) (DC \(foundDcId))", in: viewController, context: context)
            })
            
        } catch {
            showToast("Ошибка чтения файла: \(error.localizedDescription)", in: viewController, context: context)
        }
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    }
    
    private func showToast(_ text: String, in controller: ViewController, context: AccountContext) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(
            presentationData: presentationData,
            content: .info(title: nil, text: text, timeout: nil, customUndoText: nil),
            elevatedLayout: false,
            action: { _ in return false }
        ), in: .current)
    }
}
