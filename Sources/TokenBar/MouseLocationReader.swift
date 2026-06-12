import AppKit
import SwiftUI

/// Lightweight NSView-based mouse tracking with local coordinates.
///
/// Why: SwiftUI's `onHover` doesn't provide location, but we want "hover a bar to see values" on macOS.
@MainActor
struct MouseLocationReader: NSViewRepresentable {
    let onMoved: (CGPoint?) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMoved = self.onMoved
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onMoved = self.onMoved
    }

    final class TrackingView: NSView {
        private static let minimumDeliveryInterval: TimeInterval = 1.0 / 60.0
        private static let minimumMovementDistanceSquared: CGFloat = 2.25

        var onMoved: ((CGPoint?) -> Void)?
        private var trackingArea: NSTrackingArea?
        private var pendingLocation: CGPoint?
        private var deliveryWorkItem: DispatchWorkItem?
        private var lastDeliveredLocation: CGPoint?
        private var lastDeliveredAt: TimeInterval = 0

        override var isFlipped: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.window?.acceptsMouseMovedEvents = true
            self.updateTrackingAreas()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                self.removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                // NSMenu popups aren't "key windows", so `.activeInKeyWindow` would drop events and cause hover
                // state to flicker. `.activeAlways` keeps tracking stable while the menu is open.
                .activeAlways,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved,
            ]
            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            self.addTrackingArea(area)
            self.trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            self.enqueueMouseLocation(self.convert(event.locationInWindow, from: nil))
        }

        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            self.enqueueMouseLocation(self.convert(event.locationInWindow, from: nil))
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            self.enqueueMouseLocation(nil)
        }

        private func enqueueMouseLocation(_ location: CGPoint?) {
            guard let location else {
                guard self.pendingLocation != nil || self.lastDeliveredLocation != nil else { return }
                self.pendingLocation = nil
                self.deliveryWorkItem?.cancel()
                self.deliveryWorkItem = nil
                self.deliverMouseLocation(nil)
                return
            }

            if self.shouldDropSmallMove(to: location) { return }
            self.pendingLocation = location
            self.scheduleMouseDeliveryIfNeeded()
        }

        private func scheduleMouseDeliveryIfNeeded() {
            guard self.deliveryWorkItem == nil else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let delay = max(0, Self.minimumDeliveryInterval - (now - self.lastDeliveredAt))
            let workItem = DispatchWorkItem { [weak self] in
                self?.flushPendingMouseLocation()
            }
            self.deliveryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func flushPendingMouseLocation() {
            self.deliveryWorkItem = nil
            guard let location = self.pendingLocation else { return }
            self.pendingLocation = nil
            self.deliverMouseLocation(location)
        }

        private func deliverMouseLocation(_ location: CGPoint?) {
            self.lastDeliveredAt = ProcessInfo.processInfo.systemUptime
            self.lastDeliveredLocation = location
            self.onMoved?(location)
        }

        private func shouldDropSmallMove(to location: CGPoint) -> Bool {
            guard let reference = self.pendingLocation ?? self.lastDeliveredLocation else { return false }
            let dx = location.x - reference.x
            let dy = location.y - reference.y
            return dx * dx + dy * dy < Self.minimumMovementDistanceSquared
        }

        #if DEBUG
        func enqueueMouseLocationForTesting(_ location: CGPoint?) {
            self.enqueueMouseLocation(location)
        }
        #endif
    }
}
