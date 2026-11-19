import SwiftUI
import UIKit

// 系统可能折叠或隐藏 Tab；只有找到可见的训练模式项时才提供动画位置。
struct TrainingModeTabProbe: UIViewRepresentable {
    @Binding var anchor: CGRect?

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onFrame = { frame in
            if anchor != frame { anchor = frame }
        }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onFrame = { frame in
            if anchor != frame { anchor = frame }
        }
        view.scheduleLookup()
    }

    final class ProbeView: UIView {
        var onFrame: ((CGRect?) -> Void)?
        private var scheduled = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleLookup()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleLookup()
        }

        func scheduleLookup() {
            guard window != nil, !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scheduled = false
                guard let window = self.window else { return }
                let tabBar = self.findTabBar(in: window)
                let item = tabBar.flatMap { self.findItem(in: $0) }
                let frame = item.map { $0.convert($0.bounds, to: window) }
                self.onFrame?(frame)
            }
        }

        private func findTabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar, !bar.isHidden, bar.alpha > 0, bar.window != nil {
                return bar
            }
            for child in view.subviews.reversed() {
                if let bar = findTabBar(in: child) { return bar }
            }
            return nil
        }

        private func findItem(in view: UIView) -> UIView? {
            guard !view.isHidden, view.alpha > 0 else { return nil }
            if view.accessibilityLabel == "训练模式", !view.bounds.isEmpty { return view }
            for child in view.subviews {
                if let item = findItem(in: child) { return item }
            }
            return nil
        }
    }
}
