import UIKit
import CoreText
import CoreImage

// MARK: - LineByLineTextAnimator

enum LineByLineTextAnimator {

    static func animateIn(
        label: UILabel,
        totalDuration: TimeInterval = 0.56,
        cascadeFraction: Double = 0.45
    ) {
        runAnimation(
            label: label,
            totalDuration: totalDuration,
            cascadeFraction: cascadeFraction,
            direction: .in
        )
    }

    static func animateOut(
        label: UILabel,
        totalDuration: TimeInterval = 0.56,
        cascadeFraction: Double = 0.45
    ) {
        runAnimation(
            label: label,
            totalDuration: totalDuration,
            cascadeFraction: cascadeFraction,
            direction: .out
        )
    }

    private enum Direction {
        case `in`
        case out
    }

    private static func runAnimation(
        label: UILabel,
        totalDuration: TimeInterval,
        cascadeFraction: Double,
        direction: Direction
    ) {
        guard let host = label.superview else {
            return
        }
        let lines = label.visualLinesCached()
        guard !lines.isEmpty else {
            return
        }

        if direction == .out {
            label.isHidden = true
        }

        let container = UIView(frame: label.frame)
        container.isUserInteractionEnabled = false
        host.addSubview(container)

        let perLineDelay = lines.count > 1
            ? (totalDuration * cascadeFraction) / Double(lines.count - 1)
            : 0
        let lineDuration = totalDuration * (1 - cascadeFraction)
        let timing = UISpringTimingParameters(
            mass: 1,
            stiffness: 180,
            damping: 18,
            initialVelocity: .zero
        )

        var wrappers: [UIView] = []

        for (idx, (attr, rect)) in lines.enumerated() {
            let wrapper = UIView(
                frame: CGRect(
                    x: 0,
                    y: rect.minY,
                    width: container.bounds.width,
                    height: rect.height
                )
            )

            if direction == .in {
                wrapper.alpha = 0
                wrapper.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.96, y: 0.96)
            }

            let textLayer = CATextLayer()
            textLayer.frame = wrapper.bounds
            textLayer.string = attr
            textLayer.contentsScale = UIScreen.main.scale
            wrapper.layer.addSublayer(textLayer)

            if #available(iOS 17.0, *) {
                let startRadius: CGFloat = direction == .in ? 8 : 0
                let endRadius: CGFloat = direction == .in ? 0 : 8
                let blur = CIFilter(
                    name: "CIGaussianBlur",
                    parameters: [kCIInputRadiusKey: startRadius]
                )!
                textLayer.filters = [blur]

                let blurAnim = CABasicAnimation(
                    keyPath: "filters.gaussianBlur.inputRadius"
                )
                blurAnim.fromValue = startRadius
                blurAnim.toValue = endRadius
                blurAnim.duration = lineDuration
                blurAnim.beginTime = CACurrentMediaTime() + perLineDelay * Double(idx)
                blurAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                textLayer.add(blurAnim, forKey: "blur")
            } else {
                let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                blurView.frame = wrapper.bounds
                blurView.alpha = direction == .in ? 1 : 0
                wrapper.addSubview(blurView)

                UIView.animate(
                    withDuration: lineDuration,
                    delay: perLineDelay * Double(idx),
                    options: [.curveEaseOut]
                ) {
                    blurView.alpha = direction == .in ? 0 : 1
                }
            }

            container.addSubview(wrapper)
            wrappers.append(wrapper)
        }

        let animator = UIViewPropertyAnimator(
            duration: lineDuration,
            timingParameters: timing
        )
        for (idx, wrapper) in wrappers.enumerated() {
            let delayFactor = (perLineDelay * Double(idx)) / totalDuration
            animator.addAnimations(
                {
                    if direction == .in {
                        wrapper.alpha = 1
                        wrapper.transform = .identity
                    } else {
                        wrapper.alpha = 0
                        wrapper.transform = CGAffineTransform(translationX: 0, y: 8)
                            .scaledBy(x: 0.96, y: 0.96)
                    }
                },
                delayFactor: CGFloat(delayFactor)
            )
        }

        animator.addCompletion { _ in
            container.removeFromSuperview()
            if direction == .in {
                label.isHidden = false
            }
        }
        animator.startAnimation()
    }
}

// MARK: – Caching & TextKit helpers ----------------------------------------

private struct LineCacheKey: Hashable {
    let text: String
    let font: UIFont
    let width: CGFloat
}

private extension UILabel {

    func visualLinesCached() -> [(NSAttributedString, CGRect)] {
        let key = LineCacheKey(
            text: text ?? attributedText?.string ?? "",
            font: font ?? .systemFont(ofSize: 17),
            width: bounds.width.rounded()
        )
        if let cached = Self._cache[key] {
            return cached
        }
        let res = makeVisualLineInfo(using: createAttributedString())
        Self._cache[key] = res
        return res
    }

    private static var _cache: [LineCacheKey: [(NSAttributedString, CGRect)]] = [:]

}

private extension UILabel {

    func createAttributedString() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = lineBreakMode
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font as Any,
            .paragraphStyle: paragraph,
            .foregroundColor: textColor as Any
        ]
        if let attr = attributedText, attr.length > 0 {
            let m = NSMutableAttributedString(attributedString: attr)
            m.addAttributes(baseAttrs, range: NSRange(location: 0, length: m.length))
            return m
        }
        return NSAttributedString(string: text ?? "", attributes: baseAttrs)
    }

    func makeVisualLineInfo(using attr: NSAttributedString) -> [(NSAttributedString, CGRect)] {
        guard attr.length > 0 else {
            return []
        }

        let storage = NSTextStorage(attributedString: attr)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        let container = NSTextContainer(size: bounds.size)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = numberOfLines == 0 ? .max : numberOfLines
        container.lineBreakMode = lineBreakMode
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)

        var result: [(NSAttributedString, CGRect)] = []
        var glyph = 0
        while glyph < layout.numberOfGlyphs {
            var range = NSRange()
            let rect = layout.lineFragmentUsedRect(
                forGlyphAt: glyph,
                effectiveRange: &range
            )
            if range.length == 0 {
                break
            }
            let charRange = layout.characterRange(
                forGlyphRange: range,
                actualGlyphRange: nil
            )
            result.append((attr.attributedSubstring(from: charRange), rect))
            glyph = NSMaxRange(range)
        }
        return result
    }

}
