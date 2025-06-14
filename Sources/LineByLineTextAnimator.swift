import CoreImage
import CoreText
import ObjectiveC
import UIKit

// MARK: - LineByLineTextAnimator

enum LineByLineTextAnimator {

  static func animateIn(
    label: UILabel,
    totalDuration: TimeInterval = 0.56,
    cascadeFraction: Double = 0.45,
    completion: (() -> Void)? = nil
  ) {
    if let ctx = context(for: label) {
      ctx.animator.pauseAnimation()
      ctx.animator.isReversed = false
      ctx.direction = .in
      ctx.animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
    } else {
      runAnimation(
        label: label,
        totalDuration: totalDuration,
        cascadeFraction: cascadeFraction,
        direction: .in,
        completion: completion
      )
    }
  }

  static func animateOut(
    label: UILabel,
    totalDuration: TimeInterval = 0.56,
    cascadeFraction: Double = 0.45,
    completion: (() -> Void)? = nil
  ) {
    if let ctx = context(for: label) {
      ctx.animator.pauseAnimation()
      ctx.animator.isReversed = true
      ctx.direction = .out
      ctx.animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
    } else {
      runAnimation(
        label: label,
        totalDuration: totalDuration,
        cascadeFraction: cascadeFraction,
        direction: .out,
        completion: completion
      )
    }
  }

  private enum Direction {
    case `in`
    case out
  }

  private final class AnimationContext: NSObject {
    let container: UIView
    let animator: UIViewPropertyAnimator
    var direction: Direction

    init(container: UIView, animator: UIViewPropertyAnimator, direction: Direction) {
      self.container = container
      self.animator = animator
      self.direction = direction
    }
  }

  private static var contextKey: UInt8 = 0

  private static func setContext(_ context: AnimationContext?, for label: UILabel) {
    objc_setAssociatedObject(label, &contextKey, context, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }

  private static func context(for label: UILabel) -> AnimationContext? {
    objc_getAssociatedObject(label, &contextKey) as? AnimationContext
  }

  private static func runAnimation(
    label: UILabel,
    totalDuration: TimeInterval,
    cascadeFraction: Double,
    direction: Direction,
    completion: (() -> Void)? = nil
  ) {
    if let existing = context(for: label) {
      existing.animator.stopAnimation(true)
      existing.container.removeFromSuperview()
      setContext(nil, for: label)
    }

    guard let host = label.superview else {
      completion?()
      return
    }
    let lines = label.visualLinesCached()
    guard !lines.isEmpty else {
      completion?()
      return
    }

    if direction == .out {
      label.isHidden = true
    }

    let container = UIView(frame: label.frame)
    container.isUserInteractionEnabled = false
    host.addSubview(container)

    let perLineDelay =
      lines.count > 1
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

      let lineLabel = UILabel(frame: wrapper.bounds)
      lineLabel.attributedText = attr
      lineLabel.numberOfLines = 1
      lineLabel.lineBreakMode = .byWordWrapping
      lineLabel.textAlignment = label.textAlignment
      lineLabel.backgroundColor = .clear
      wrapper.addSubview(lineLabel)

      if #available(iOS 17.0, *) {
        let startRadius: CGFloat = direction == .in ? 8 : 0
        let endRadius: CGFloat = direction == .in ? 0 : 8

        guard let blur = CIFilter(name: "CIGaussianBlur") else {
          addFallbackBlur(
            to: wrapper, direction: direction, lineDuration: lineDuration,
            delay: perLineDelay * Double(idx))
          container.addSubview(wrapper)
          wrappers.append(wrapper)
          continue
        }
        blur.setValue(startRadius, forKey: kCIInputRadiusKey)
        lineLabel.layer.filters = [blur]

        let blurAnim = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
        blurAnim.fromValue = startRadius
        blurAnim.toValue = endRadius
        blurAnim.duration = lineDuration
        blurAnim.beginTime = CACurrentMediaTime() + perLineDelay * Double(idx)
        blurAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLabel.layer.add(blurAnim, forKey: "blur")
      } else {
        addFallbackBlur(
          to: wrapper, direction: direction, lineDuration: lineDuration,
          delay: perLineDelay * Double(idx))
      }

      container.addSubview(wrapper)
      wrappers.append(wrapper)
    }

    func addFallbackBlur(
      to wrapper: UIView, direction: Direction, lineDuration: TimeInterval, delay: TimeInterval
    ) {
      let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
      blurView.frame = wrapper.bounds
      blurView.alpha = direction == .in ? 1 : 0
      wrapper.addSubview(blurView)

      UIView.animate(
        withDuration: lineDuration,
        delay: delay,
        options: [.curveEaseOut]
      ) {
        blurView.alpha = direction == .in ? 0 : 1
      }
    }

    let animator = UIViewPropertyAnimator(duration: lineDuration, timingParameters: timing)
    for (idx, wrapper) in wrappers.enumerated() {
      let delayFactor = (perLineDelay * Double(idx)) / totalDuration
      animator.addAnimations(
        {
          if direction == .in {
            wrapper.alpha = 1
            wrapper.transform = .identity
          } else {
            wrapper.alpha = 0
            wrapper.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.96, y: 0.96)
          }
        }, delayFactor: CGFloat(delayFactor))
    }

    animator.addCompletion { _ in
      container.removeFromSuperview()
      if direction == .in {
        label.isHidden = false
      }
      setContext(nil, for: label)
      completion?()
    }
    let ctx = AnimationContext(container: container, animator: animator, direction: direction)
    setContext(ctx, for: label)
    animator.startAnimation()
  }
}

// MARK: – Caching & TextKit helpers ----------------------------------------

private struct LineCacheKey: Hashable {
  let text: String
  let fontName: String
  let fontSize: CGFloat
  let width: CGFloat
  let alignment: NSTextAlignment
  let lineHeight: CGFloat?
  let textColor: UIColor?
}

extension UILabel {

  fileprivate func visualLinesCached() -> [(NSAttributedString, CGRect)] {
    var effectiveLineHeight: CGFloat?
    if let attributedText = self.attributedText, attributedText.length > 0,
      let paragraphStyle = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
        as? NSParagraphStyle
    {
      if paragraphStyle.minimumLineHeight > 0
        && paragraphStyle.minimumLineHeight == paragraphStyle.maximumLineHeight
      {
        effectiveLineHeight = paragraphStyle.minimumLineHeight
      }
    }

    let key = LineCacheKey(
      text: self.attributedText?.string ?? self.text ?? "",
      fontName: self.font?.fontName ?? UIFont.systemFont(ofSize: 17).fontName,
      fontSize: self.font?.pointSize ?? 17,
      width: self.bounds.width.rounded(),
      alignment: self.textAlignment,
      lineHeight: effectiveLineHeight,
      textColor: self.textColor
    )

    if let cached = Self._cache[key] {
      return cached
    }

    let attributedStringToUse = self.createAttributedString()
    let res = self.makeVisualLineInfo(using: attributedStringToUse)
    Self._cache[key] = res
    return res
  }

  fileprivate func createAttributedString() -> NSAttributedString {
    let sourceText = self.attributedText?.string ?? self.text ?? ""
    guard !sourceText.isEmpty else {
      return NSAttributedString()
    }

    var attributes: [NSAttributedString.Key: Any] = [:]
    attributes[.font] = self.font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
    attributes[.foregroundColor] = self.textColor ?? UIColor.black

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = self.textAlignment
    paragraphStyle.lineBreakMode = self.lineBreakMode

    if let existingAttributedText = self.attributedText, existingAttributedText.length > 0,
      let existingParagraphStyle = existingAttributedText.attribute(
        .paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    {
      if existingParagraphStyle.minimumLineHeight > 0
        && existingParagraphStyle.minimumLineHeight == existingParagraphStyle.maximumLineHeight
      {
        paragraphStyle.minimumLineHeight = existingParagraphStyle.minimumLineHeight
        paragraphStyle.maximumLineHeight = existingParagraphStyle.maximumLineHeight
      }
    }
    attributes[.paragraphStyle] = paragraphStyle

    if let existingAttributedText = self.attributedText, existingAttributedText.length > 0 {
      let mutableAttributedString = NSMutableAttributedString(string: sourceText)
      existingAttributedText.enumerateAttributes(
        in: NSRange(location: 0, length: existingAttributedText.length)
      ) { (attrs, range, _) in
        mutableAttributedString.addAttributes(attrs, range: range)
      }
      mutableAttributedString.addAttributes(
        attributes, range: NSRange(location: 0, length: mutableAttributedString.length))
      return mutableAttributedString
    } else {
      return NSAttributedString(string: sourceText, attributes: attributes)
    }
  }

  fileprivate func makeVisualLineInfo(using attr: NSAttributedString) -> [(
    NSAttributedString, CGRect
  )] {
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
    var glyphIndex = 0
    while glyphIndex < layout.numberOfGlyphs {
      var lineRange = NSRange()
      let lineRect = layout.lineFragmentUsedRect(
        forGlyphAt: glyphIndex,
        effectiveRange: &lineRange
      )
      if lineRange.length == 0 {
        break
      }
      let charRange = layout.characterRange(
        forGlyphRange: lineRange,
        actualGlyphRange: nil
      )
      result.append((attr.attributedSubstring(from: charRange), lineRect))
      glyphIndex = NSMaxRange(lineRange)
    }
    return result
  }

  private static var _cache: [LineCacheKey: [(NSAttributedString, CGRect)]] = [:]

}
