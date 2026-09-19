import Foundation
import UIKit
import SGSimpleSettings

public struct Font {
    public enum Design {
        case regular
        case serif
        case monospace
        case round
        case camera
        
        var key: String {
            switch self {
            case .regular:
                return "regular"
            case .serif:
                return "serif"
            case .monospace:
                return "monospace"
            case .round:
                return "round"
            case .camera:
                return "camera"
            }
        }
    }
    
    public struct Traits: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let italic = Traits(rawValue: 1 << 0)
        public static let monospacedNumbers = Traits(rawValue: 1 << 1)
    }
    
    public enum Width {
        case standard
        case condensed
        case compressed
        case expanded
        
        @available(iOS 16.0, *)
        var width: UIFont.Width {
            switch self {
            case .standard:
                return .standard
            case .condensed:
                return .condensed
            case .compressed:
                return .compressed
            case .expanded:
                return .expanded
            }
        }
        
        var key: String {
            switch self {
            case .standard:
                return "standard"
            case .condensed:
                return "condensed"
            case .compressed:
                return "compressed"
            case .expanded:
                return "expanded"
            }
        }
    }
    
    public enum Weight {
        case regular
        case thin
        case light
        case medium
        case semibold
        case bold
        case heavy
        
        var isBold: Bool {
            switch self {
                case .medium, .semibold, .bold, .heavy:
                    return true
                default:
                    return false
            }
        }
        
        var weight: UIFont.Weight {
            switch self {
                case .thin:
                    return .thin
                case .light:
                    return .light
                case .medium:
                    return .medium
                case .semibold:
                    return .semibold
                case .bold:
                    return .bold
                case .heavy:
                    return .heavy
                default:
                    return .regular
            }
        }
        
        var key: String {
            switch self {
            case .regular:
                return "regular"
            case .thin:
                return "thin"
            case .light:
                return "light"
            case .medium:
                return "medium"
            case .semibold:
                return "semibold"
            case .bold:
                return "bold"
            case .heavy:
                return "heavy"
            }
        }
    }
    
    private final class Cache {
        private var lock: pthread_rwlock_t
        private var fonts: [String: UIFont] = [:]
        
        init() {
            self.lock = pthread_rwlock_t()
            let status = pthread_rwlock_init(&self.lock, nil)
            assert(status == 0)
        }
        
        func get(_ key: String) -> UIFont? {
            let font: UIFont?
            pthread_rwlock_rdlock(&self.lock)
            font = self.fonts[key]
            pthread_rwlock_unlock(&self.lock)
            return font
        }
        
        func set(_ font: UIFont, key: String) {
            pthread_rwlock_wrlock(&self.lock)
            self.fonts[key] = font
            pthread_rwlock_unlock(&self.lock)
        }
    }

    private static let cache = Cache()
    
    public static func with(size: CGFloat, design: Design = .regular, weight: Weight = .regular, width: Width = .standard, traits: Traits = []) -> UIFont {
        let key = "\(size)_\(design.key)_\(weight.key)_\(width.key)_\(traits.rawValue)"
        
        if let cachedFont = self.cache.get(key) {
            return cachedFont
        }
        if #available(iOS 13.0, *), design != .camera {
            let descriptor: UIFontDescriptor
            if #available(iOS 14.0, *) {
                descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            } else {
                descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor
            }

            var symbolicTraits = descriptor.symbolicTraits
            if traits.contains(.italic) {
                symbolicTraits.insert(.traitItalic)
            }
            var updatedDescriptor: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolicTraits)
            if traits.contains(.monospacedNumbers) {
                updatedDescriptor = updatedDescriptor?.addingAttributes([
                UIFontDescriptor.AttributeName.featureSettings: [
                  [UIFontDescriptor.FeatureKey.featureIdentifier:
                   kNumberSpacingType,
                   UIFontDescriptor.FeatureKey.typeIdentifier:
                   kMonospacedNumbersSelector]
                ]])
            }
            switch design {
                case .serif:
                    updatedDescriptor = updatedDescriptor?.withDesign(.serif)
                case .monospace:
                    updatedDescriptor = updatedDescriptor?.withDesign(.monospaced)
                case .round:
                    updatedDescriptor = updatedDescriptor?.withDesign(.rounded)
                default:
                    updatedDescriptor = updatedDescriptor?.withDesign(.default)
            }
            if #available(iOS 14.0, *) {
                if weight != .regular {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight.weight]
                    ])
                }
            }
            if #available(iOS 16.0, *) {
                if width != .standard {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.width: width.width]
                    ])
                }
            }
            
            let font: UIFont
            if let updatedDescriptor = updatedDescriptor {
                font = UIFont(descriptor: updatedDescriptor, size: size)
            } else {
                font = UIFont(descriptor: descriptor, size: size)
            }
            
            self.cache.set(font, key: key)
            
            return font
        } else {
            let font: UIFont
            switch design {
                case .regular, .round:
                    if traits.contains(.italic) {
                        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor.withSymbolicTraits([.traitItalic]) {
                            font = UIFont(descriptor: descriptor, size: size)
                        } else {
                            font = UIFont.italicSystemFont(ofSize: size)
                        }
                    } else {
                        return UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
                case .serif:
                    if weight.isBold && traits.contains(.italic) {
                        font = UIFont(name: "Georgia-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        font = UIFont(name: "Georgia-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        font = UIFont(name: "Georgia-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        font = UIFont(name: "Georgia", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .monospace:
                    if weight.isBold && traits.contains(.italic) {
                        font = UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        font = UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        font = UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        font = UIFont(name: "Menlo", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .camera:
                    func encodeText(string: String, key: Int16) -> String {
                        let nsString = string as NSString
                        let result = NSMutableString()
                        for i in 0 ..< nsString.length {
                            var c: unichar = nsString.character(at: i)
                            c = unichar(Int16(c) + key)
                            result.append(NSString(characters: &c, length: 1) as String)
                        }
                        return result as String
                    }
                    if case .semibold = weight {
                        font = UIFont(name: encodeText(string: "TGDbnfsb.Tfnjcpme", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    } else {
                        font = UIFont(name: encodeText(string: "TGDbnfsb.Sfhvmbs", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
            }
            
            self.cache.set(font, key: key)
            
            return font
        }
    }
    
    private static func applyCustomFont(size: CGFloat, weight: Weight) -> UIFont {
        let fontPref = SGSimpleSettings.shared.customFont
        switch fontPref {
        case "round":
            return self.with(size: size, design: .round, weight: weight)
        case "serif":
            return self.with(size: size, design: .serif, weight: weight)
        case "monospace":
            return self.with(size: size, design: .monospace, weight: weight)
        case "avenir":
            let fontName: String
            switch weight {
            case .bold, .heavy:
                fontName = "AvenirNext-Bold"
            case .medium, .semibold:
                fontName = "AvenirNext-Medium"
            case .light, .thin:
                fontName = "AvenirNext-Light"
            default:
                fontName = "AvenirNext-Regular"
            }
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "georgia":
            let fontName = weight.isBold ? "Georgia-Bold" : "Georgia"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "trebuchet":
            let fontName = weight.isBold ? "TrebuchetMS-Bold" : "TrebuchetMS"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "helvetica":
            let fontName = weight.isBold ? "HelveticaNeue-Bold" : (weight == .medium || weight == .semibold ? "HelveticaNeue-Medium" : "HelveticaNeue")
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "futura":
            let fontName = weight.isBold ? "Futura-Bold" : "Futura-Medium"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "palatino":
            let fontName = weight.isBold ? "Palatino-Bold" : "Palatino-Roman"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "menlo":
            let fontName = weight.isBold ? "Menlo-Bold" : "Menlo-Regular"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "optima":
            let fontName = weight.isBold ? "Optima-Bold" : "Optima-Regular"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "baskerville":
            let fontName = weight.isBold ? "Baskerville-Bold" : "Baskerville"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "copperplate":
            let fontName = weight.isBold ? "Copperplate-Bold" : "Copperplate"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "gill":
            let fontName = weight.isBold ? "GillSans-Bold" : "GillSans"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "snell":
            let fontName = weight.isBold ? "SnellRoundhand-Bold" : "SnellRoundhand"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        case "markerfelt":
            let fontName = weight.isBold ? "MarkerFelt-Wide" : "MarkerFelt-Thin"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
        default:
            return UIFont.systemFont(ofSize: size, weight: weight.weight)
        }
    }
    
    public static func regular(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .regular)
        }
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .medium)
        }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.medium)
    }
    
    public static func semibold(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .semibold)
        }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.semibold)
    }
    
    public static func bold(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .bold)
        }
        if #available(iOS 8.2, *) {
            return UIFont.boldSystemFont(ofSize: size)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        }
    }
    
    public static func heavy(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .heavy)
        }
        return self.with(size: size, design: .regular, weight: .heavy, traits: [])
    }
    
    public static func light(_ size: CGFloat) -> UIFont {
        if SGSimpleSettings.shared.customFont != "default" {
            return applyCustomFont(size: size, weight: .light)
        }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.light)
    }
    
    public static func semiboldItalic(_ size: CGFloat) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.italicSystemFont(ofSize: size)
        }
    }
    
    public static func monospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Regular", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldItalicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont? = nil, textColor: UIColor = UIColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }
}
