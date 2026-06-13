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
