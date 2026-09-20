import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SGSimpleSettings

private func colorFromRgb(_ rgb: UInt32, alpha: CGFloat = 1.0) -> UIColor {
    return UIColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
        green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
        blue: CGFloat(rgb & 0xFF) / 255.0,
        alpha: alpha
    )
}

private func generateStarParticleImage() -> UIImage {
    let size = CGSize(width: 32.0, height: 32.0)
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
    
    // Soft outer glow
    ctx.setFillColor(UIColor(white: 1.0, alpha: 0.25).cgColor)
    ctx.fillEllipse(in: CGRect(x: 4.0, y: 4.0, width: 24.0, height: 24.0))
    
    // Bright center core
    ctx.setFillColor(UIColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 8.0, height: 8.0))
    
    // 4-point flare
    ctx.setStrokeColor(UIColor(white: 1.0, alpha: 0.9).cgColor)
    ctx.setLineWidth(1.5)
    ctx.move(to: CGPoint(x: 16.0, y: 2.0))
    ctx.addLine(to: CGPoint(x: 16.0, y: 30.0))
    ctx.move(to: CGPoint(x: 2.0, y: 16.0))
    ctx.addLine(to: CGPoint(x: 30.0, y: 16.0))
    ctx.strokePath()
    
    // Diagonal soft rays
    ctx.setStrokeColor(UIColor(white: 1.0, alpha: 0.45).cgColor)
    ctx.setLineWidth(1.0)
    ctx.move(to: CGPoint(x: 7.0, y: 7.0))
    ctx.addLine(to: CGPoint(x: 25.0, y: 25.0))
    ctx.move(to: CGPoint(x: 25.0, y: 7.0))
    ctx.addLine(to: CGPoint(x: 7.0, y: 25.0))
    ctx.strokePath()
    
    let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return result
}

private func generateSparkParticleImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 24.0, height: 24.0)
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
    
    // Outer cyan halo
    ctx.setFillColor(color.withAlphaComponent(0.35).cgColor)
    ctx.fillEllipse(in: CGRect(x: 2.0, y: 2.0, width: 20.0, height: 20.0))
    
    // Mid glow
    ctx.setFillColor(color.withAlphaComponent(0.75).cgColor)
    ctx.fillEllipse(in: CGRect(x: 6.0, y: 6.0, width: 12.0, height: 12.0))
    
    // Bright white core
    ctx.setFillColor(UIColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: 9.0, y: 9.0, width: 6.0, height: 6.0))
    
    let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return result
}

private func generateMetalParticleImage() -> UIImage {
    let size = CGSize(width: 20.0, height: 20.0)
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
    
    // Soft specular halo
    ctx.setFillColor(UIColor(white: 1.0, alpha: 0.25).cgColor)
    ctx.fillEllipse(in: CGRect(x: 2.0, y: 2.0, width: 16.0, height: 16.0))
    
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 10.0, y: 2.0))
    path.addLine(to: CGPoint(x: 18.0, y: 10.0))
    path.addLine(to: CGPoint(x: 10.0, y: 18.0))
    path.addLine(to: CGPoint(x: 2.0, y: 10.0))
    path.close()
    
    ctx.setFillColor(UIColor(white: 0.95, alpha: 0.85).cgColor)
    path.fill()
    
    ctx.setFillColor(UIColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: 8.0, y: 8.0, width: 4.0, height: 4.0))
    
    let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return result
}

class WallpaperNYNode: ASDisplayNode {
    private var emitterLayer: CAEmitterLayer?
    private var currentStyle: String?
    
    func updateLayout(size: CGSize) {
        var style = SGSimpleSettings.shared.nyStyle
        if SGSimpleSettings.shared.customThemeEnabled && SGSimpleSettings.shared.customThemeStarsEnabled {
            style = SGSimpleSettings.NYStyle.stars.rawValue
        }
        if !SGSimpleSettings.shared.isNYEnabled || style == SGSimpleSettings.NYStyle.default.rawValue {
            self.emitterLayer?.removeFromSuperlayer()
            self.emitterLayer = nil
            self.currentStyle = nil
            return
        }
        
        let customStarColor = SGSimpleSettings.shared.customThemeStarsColor
        let styleSignature = "\(style)_\(customStarColor)"
        
        if self.emitterLayer == nil || self.currentStyle != styleSignature {
            self.emitterLayer?.removeFromSuperlayer()
            
            let particlesLayer = CAEmitterLayer()
            self.emitterLayer = particlesLayer
            self.currentStyle = styleSignature

            self.layer.addSublayer(particlesLayer)
            self.layer.masksToBounds = true
            
            particlesLayer.backgroundColor = UIColor.clear.cgColor
            particlesLayer.renderMode = .oldestLast

            let cell1 = CAEmitterCell()
            switch style {
            case SGSimpleSettings.NYStyle.stars.rawValue:
                particlesLayer.emitterShape = .rectangle
                particlesLayer.emitterMode = .surface
                cell1.contents = generateStarParticleImage().cgImage
                cell1.name = "stars"
                cell1.scale = 0.09
                cell1.scaleRange = 0.14
                cell1.birthRate = 9.0
                cell1.lifetime = 14.0
                cell1.velocity = 2.0
                cell1.velocityRange = 3.0
                cell1.emissionRange = .pi * 2.0
                cell1.spin = 0.3
                cell1.spinRange = 0.6
                
                let starColorKey = customStarColor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let cleanHex = starColorKey.replacingOccurrences(of: "#", with: "")
                let starColor: UIColor
                if let hex = UInt32(cleanHex, radix: 16) {
                    starColor = colorFromRgb(hex, alpha: 0.95)
                } else {
                    switch starColorKey {
                    case "gold", "yellow":
                        starColor = colorFromRgb(0xFFD700, alpha: 0.95)
                    case "cyan", "blue":
                        starColor = colorFromRgb(0x00E5FF, alpha: 0.95)
                    case "pink":
                        starColor = colorFromRgb(0xFF4081, alpha: 0.95)
                    case "purple":
                        starColor = colorFromRgb(0xBD10E0, alpha: 0.95)
                    case "green":
                        starColor = colorFromRgb(0x00E676, alpha: 0.95)
                    case "red":
                        starColor = colorFromRgb(0xFF5252, alpha: 0.95)
                    default:
                        starColor = UIColor(white: 1.0, alpha: 0.9)
                    }
                }
                cell1.color = starColor.cgColor
                cell1.alphaSpeed = -0.06

            case SGSimpleSettings.NYStyle.sparks.rawValue:
                particlesLayer.emitterShape = .rectangle
                particlesLayer.emitterMode = .surface
                cell1.contents = generateSparkParticleImage(color: colorFromRgb(0x00E5FF)).cgImage
                cell1.name = "sparks"
                cell1.scale = 0.10
                cell1.scaleRange = 0.16
                cell1.birthRate = 12.0
                cell1.lifetime = 6.0
                cell1.velocity = 14.0
                cell1.velocityRange = 10.0
                cell1.xAcceleration = -1.0
                cell1.yAcceleration = -5.0
                cell1.emissionRange = .pi * 2.0
                cell1.color = colorFromRgb(0x00E5FF, alpha: 0.9).cgColor
                cell1.alphaSpeed = -0.12

            case SGSimpleSettings.NYStyle.metal.rawValue:
                particlesLayer.emitterShape = .rectangle
                particlesLayer.emitterMode = .surface
                cell1.contents = generateMetalParticleImage().cgImage
                cell1.name = "metal"
                cell1.scale = 0.08
                cell1.scaleRange = 0.12
                cell1.birthRate = 8.0
                cell1.lifetime = 9.0
                cell1.velocity = 4.0
                cell1.velocityRange = 5.0
                cell1.xAcceleration = 0.5
                cell1.yAcceleration = 1.2
                cell1.spin = 0.8
                cell1.spinRange = 1.5
                cell1.color = colorFromRgb(0xEBEBF0, alpha: 0.85).cgColor
                cell1.alphaSpeed = -0.07

            case SGSimpleSettings.NYStyle.lightning.rawValue:
                particlesLayer.emitterShape = .circle
                particlesLayer.emitterMode = .surface
                if let image = UIImage(bundleImageName: "SwiftgramContextMenu") {
                    cell1.contents = paintImage(image, to: UIColor.white.cgColor).cgImage
                }
                cell1.name = "lightning"
                cell1.scale = 0.15
                cell1.scaleRange = 0.25
                cell1.birthRate = 10.0
                cell1.lifetime = 55.0
                cell1.velocity = 1.0
                cell1.velocityRange = -1.5
                cell1.xAcceleration = 0.33
                cell1.yAcceleration = 1.0
                cell1.emissionRange = .pi
                cell1.spin = -28.6 * (.pi / 180.0)
                cell1.spinRange = 57.2 * (.pi / 180.0)
                cell1.color = UIColor.white.withAlphaComponent(0.58).cgColor

            default: // snow
                particlesLayer.emitterShape = .circle
                particlesLayer.emitterMode = .surface
                cell1.contents = UIImage(bundleImageName: "SGSnowflake")?.cgImage
                cell1.name = "snow"
                cell1.scale = 0.04
                cell1.scaleRange = 0.15
                cell1.birthRate = 10.0
                cell1.lifetime = 55.0
                cell1.velocity = 1.0
                cell1.velocityRange = -1.5
                cell1.xAcceleration = 0.33
                cell1.yAcceleration = 1.0
                cell1.emissionRange = .pi
                cell1.spin = -28.6 * (.pi / 180.0)
                cell1.spinRange = 57.2 * (.pi / 180.0)
                cell1.color = UIColor.white.withAlphaComponent(0.58).cgColor
            }
            
            if ProcessInfo.processInfo.isLowPowerModeEnabled || UIAccessibility.isReduceMotionEnabled {
                cell1.birthRate = cell1.birthRate / 3
            }
            particlesLayer.emitterCells = [cell1]
        }
        
        if let emitterLayer = self.emitterLayer {
            switch style {
            case SGSimpleSettings.NYStyle.stars.rawValue, SGSimpleSettings.NYStyle.sparks.rawValue, SGSimpleSettings.NYStyle.metal.rawValue:
                emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                emitterLayer.emitterSize = CGSize(width: size.width, height: size.height)
                emitterLayer.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
            default:
                var emitterWidthK: CGFloat = 1.5
                if style == SGSimpleSettings.NYStyle.lightning.rawValue {
                    emitterWidthK = 1.5
                }
                emitterLayer.emitterPosition = CGPoint(x: 0.0, y: -size.height / 8.0)
                emitterLayer.emitterSize = CGSize(width: size.width * emitterWidthK, height: size.height)
                emitterLayer.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
            }
        }
    }
}

func paintImage(_ image: UIImage, to: CGColor) -> UIImage {
    let rect = CGRect(origin: .zero, size: image.size)

    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    guard let ctx = UIGraphicsGetCurrentContext() else { return image }

    // Flip context
    ctx.translateBy(x: 0, y: image.size.height)
    ctx.scaleBy(x: 1, y: -1)

    // Draw alpha mask
    ctx.setBlendMode(.normal)
    ctx.clip(to: rect, mask: image.cgImage!)

    // Fill with white
    ctx.setFillColor(to)
    ctx.fill(rect)

    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return result ?? image
}
