import AppKit

extension StatusItemController {
    private static let mergedMenuVerticalClearance: CGFloat = 8

    @objc func showMergedMenu(_ sender: NSStatusBarButton) {
        guard self.shouldMergeIcons else { return }
        let menu = self.prepareMergedMenuForPresentation()

        let popupPoint = Self.autoAlignedMenuPopupPoint(
            statusButtonBounds: sender.bounds,
            statusButtonIsFlipped: sender.isFlipped,
            statusButtonScreenFrame: Self.statusButtonScreenFrame(for: sender),
            screenVisibleFrame: sender.window?.screen?.visibleFrame,
            menuWidth: self.renderedMenuWidth(for: menu))
        menu.popUp(positioning: nil, at: popupPoint, in: sender)
    }

    func scheduleOpenMergedMenuRealignmentIfNeeded(_ menu: NSMenu) {
        self.realignOpenMergedMenuWindowIfNeeded(menu)
        DispatchQueue.main.async { [weak self, weak menu] in
            guard let self, let menu else { return }
            self.realignOpenMergedMenuWindowIfNeeded(menu)
        }
    }

    private func realignOpenMergedMenuWindowIfNeeded(_ menu: NSMenu) {
        guard menu === self.mergedMenu else { return }
        guard self.openMenus[ObjectIdentifier(menu)] != nil else { return }
        guard let sender = self.statusItem.button else { return }
        guard let window = menu.items.lazy.compactMap({ $0.view?.window }).first else { return }
        guard window.frame.width > 0, window.frame.height > 0 else { return }

        let alignedFrame = Self.alignedMergedMenuWindowFrame(
            currentFrame: window.frame,
            statusButtonScreenFrame: Self.statusButtonScreenFrame(for: sender),
            screenVisibleFrame: sender.window?.screen?.visibleFrame ?? window.screen?.visibleFrame)
        guard !alignedFrame.equalTo(window.frame) else { return }
        window.setFrame(alignedFrame, display: true, animate: false)
    }

    func prepareMergedMenuForPresentation() -> NSMenu {
        let menu = self.mergedMenu ?? self.makeMenu()
        self.mergedMenu = menu
        let provider = self.resolvedMenuProvider()
        self.refreshMenuForOpenIfNeeded(menu, provider: provider)
        return menu
    }

    static func autoAlignedMenuPopupPoint(
        statusButtonBounds: NSRect,
        statusButtonIsFlipped: Bool,
        statusButtonScreenFrame: NSRect?,
        screenVisibleFrame: NSRect?,
        menuWidth: CGFloat)
        -> NSPoint
    {
        if self.mergedMenuHasRoomToOpenRight(
            statusButtonScreenFrame: statusButtonScreenFrame,
            screenVisibleFrame: screenVisibleFrame,
            menuWidth: ceil(menuWidth))
        {
            return self.rightAlignedMenuPopupPoint(
                statusButtonBounds: statusButtonBounds,
                statusButtonIsFlipped: statusButtonIsFlipped)
        }
        return self.trailingAlignedMenuPopupPoint(
            statusButtonBounds: statusButtonBounds,
            statusButtonIsFlipped: statusButtonIsFlipped,
            menuWidth: menuWidth)
    }

    static func trailingAlignedMenuPopupPoint(
        statusButtonBounds: NSRect,
        statusButtonIsFlipped: Bool,
        menuWidth: CGFloat)
        -> NSPoint
    {
        NSPoint(
            x: statusButtonBounds.maxX - ceil(menuWidth),
            y: self.mergedMenuPopupY(
                statusButtonBounds: statusButtonBounds,
                statusButtonIsFlipped: statusButtonIsFlipped))
    }

    private static func rightAlignedMenuPopupPoint(
        statusButtonBounds: NSRect,
        statusButtonIsFlipped: Bool)
        -> NSPoint
    {
        NSPoint(
            x: statusButtonBounds.maxX,
            y: self.mergedMenuPopupY(
                statusButtonBounds: statusButtonBounds,
                statusButtonIsFlipped: statusButtonIsFlipped))
    }

    private static func mergedMenuPopupY(
        statusButtonBounds: NSRect,
        statusButtonIsFlipped: Bool)
        -> CGFloat
    {
        if statusButtonIsFlipped {
            statusButtonBounds.maxY + self.mergedMenuVerticalClearance
        } else {
            statusButtonBounds.minY - self.mergedMenuVerticalClearance
        }
    }

    static func alignedMergedMenuWindowFrame(
        currentFrame: NSRect,
        statusButtonScreenFrame: NSRect?,
        screenVisibleFrame: NSRect?)
        -> NSRect
    {
        guard let statusButtonScreenFrame,
              currentFrame.width > 0,
              currentFrame.height > 0
        else {
            return currentFrame
        }

        var frame = currentFrame
        let opensRight = screenVisibleFrame.map {
            statusButtonScreenFrame.maxX + currentFrame.width <= $0.maxX
        } ?? false
        frame.origin.x = opensRight
            ? statusButtonScreenFrame.maxX
            : statusButtonScreenFrame.maxX - currentFrame.width

        let preferredTop = statusButtonScreenFrame.minY - self.mergedMenuVerticalClearance
        frame.origin.y = preferredTop - currentFrame.height

        if let screenVisibleFrame {
            if currentFrame.width <= screenVisibleFrame.width {
                frame.origin.x = min(
                    max(frame.origin.x, screenVisibleFrame.minX),
                    screenVisibleFrame.maxX - currentFrame.width)
            } else {
                frame.origin.x = screenVisibleFrame.minX
            }

            if currentFrame.height <= screenVisibleFrame.height {
                frame.origin.y = min(
                    max(frame.origin.y, screenVisibleFrame.minY),
                    screenVisibleFrame.maxY - currentFrame.height)
            } else {
                frame.origin.y = screenVisibleFrame.minY
            }
        }

        frame.origin.x = floor(frame.origin.x)
        frame.origin.y = floor(frame.origin.y)
        return frame
    }

    private static func statusButtonScreenFrame(for sender: NSStatusBarButton) -> NSRect? {
        guard let window = sender.window else { return nil }
        return window.convertToScreen(sender.convert(sender.bounds, to: nil))
    }

    private static func mergedMenuHasRoomToOpenRight(
        statusButtonScreenFrame: NSRect?,
        screenVisibleFrame: NSRect?,
        menuWidth: CGFloat)
        -> Bool
    {
        guard let statusButtonScreenFrame, let screenVisibleFrame else { return false }
        return statusButtonScreenFrame.maxX + menuWidth <= screenVisibleFrame.maxX
    }
}
