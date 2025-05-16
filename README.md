# LineByLineTextAnimator 🎬✨

WWDC‑style per‑line text reveal & hide animation for `UILabel` 🚀

## 🎯 Features

* 🔠 **Line‑by‑line** staggered animation (cascade)
* ↕️ **Opacity** 0 → 1 and **Y‑offset** 8pt → 0
* 📐 **Scale** 0.96 → 1.0 (anchor at bottom)
* 🌫️ **Blur** 8 → 0 (iOS 17+ GPU via `CIFilter`; fallback on iOS 16 to `UIVisualEffectView`)
* ▶️ **Animate In** (`animateIn`) and ⏹️ **Animate Out** (`animateOut`)
* 🪄 Triggers only when the label’s superview exists
* ⚡️ **Caching** of TextKit line layout for performance

## 📋 Requirements

* iOS 16.4+
* Swift 5.7+
* UIKit

> ℹ️ **Important:** The original `UILabel` being animated **must** have:
>
> * `lineBreakMode = .byWordWrapping`
> * **Initially** `isHidden = true`

## 🚀 Installation

1. Copy `LineByLineTextAnimator.swift` into your project.
2. Ensure you import:

   ```swift
   import UIKit
   import CoreText
   import CoreImage
   ```

## 🔧 Usage

### Reveal (Animate In) ▶️

```swift
// Ensure label.frame is final and label.layoutIfNeeded() has been called
label.isHidden = true  // initial state
LineByLineTextAnimator.animateIn(
    label: label,           // your multiline UILabel
    totalDuration: 0.56,    // optional, default 0.56s
    cascadeFraction: 0.45   // optional, default 0.45
)
```

### Hide (Animate Out) ⏹️

```swift
// Hide immediately and play reverse animation
label.isHidden = true
LineByLineTextAnimator.animateOut(
    label: label,
    totalDuration: 0.56,
    cascadeFraction: 0.45
)
```

## 📦 Example

In your view controller:

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Reveal once
    label.isHidden = true
    LineByLineTextAnimator.animateIn(label: label)
}

@IBAction func didTapHide(_ sender: UIButton) {
    // Hide on demand
    label.isHidden = true
    LineByLineTextAnimator.animateOut(label: label)
}
```

## 🔄 Customization

* **Timing:** adjust `totalDuration` & `cascadeFraction`.
* **Spring physics:** tweak `UISpringTimingParameters(mass:stiffness:damping:initialVelocity:)` in the code.
* **Blur radius:** modify values in the `CIFilter` or fallback animation.

## ⚡️ Performance Tips

* Call `label.layoutIfNeeded()` before animation.
* Reuse UILabels to benefit from line‑layout caching.

## 📜 License

MIT — free to use and modify.
