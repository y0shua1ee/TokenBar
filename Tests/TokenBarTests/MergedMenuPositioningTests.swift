import AppKit
import Testing
@testable import TokenBar

@MainActor
struct MergedMenuPositioningTests {
    @Test
    func `popup point anchors menu trailing edge to status item trailing edge`() {
        let menuWidth: CGFloat = 620
        let compact = NSRect(x: 0, y: 0, width: 44, height: 22)
        let expanded = NSRect(x: -92, y: 0, width: 136, height: 22)

        let compactPoint = StatusItemController.trailingAlignedMenuPopupPoint(
            statusButtonBounds: compact,
            statusButtonIsFlipped: true,
            menuWidth: menuWidth)
        let expandedPoint = StatusItemController.trailingAlignedMenuPopupPoint(
            statusButtonBounds: expanded,
            statusButtonIsFlipped: true,
            menuWidth: menuWidth)

        #expect(compactPoint.x == expandedPoint.x)
        #expect(compactPoint.x + ceil(menuWidth) == compact.maxX)
        #expect(expandedPoint.x + ceil(menuWidth) == expanded.maxX)
        #expect(compactPoint.y == compact.maxY + 8)
        #expect(expandedPoint.y == expanded.maxY + 8)
    }

    @Test
    func `popup point clears status item in non-flipped coordinates`() {
        let point = StatusItemController.trailingAlignedMenuPopupPoint(
            statusButtonBounds: NSRect(x: 0, y: 0, width: 44, height: 22),
            statusButtonIsFlipped: false,
            menuWidth: 620)

        #expect(point.y == -8)
    }

    @Test
    func `auto popup point opens to the right when space is available`() {
        let point = StatusItemController.autoAlignedMenuPopupPoint(
            statusButtonBounds: NSRect(x: 0, y: 0, width: 24, height: 22),
            statusButtonIsFlipped: true,
            statusButtonScreenFrame: NSRect(x: 700, y: 870, width: 24, height: 22),
            screenVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 900),
            menuWidth: 320)

        #expect(point.x == 24)
        #expect(point.y == 30)
    }

    @Test
    func `auto popup point falls back to trailing alignment near the screen edge`() {
        let point = StatusItemController.autoAlignedMenuPopupPoint(
            statusButtonBounds: NSRect(x: 0, y: 0, width: 24, height: 22),
            statusButtonIsFlipped: false,
            statusButtonScreenFrame: NSRect(x: 1000, y: 870, width: 24, height: 22),
            screenVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 900),
            menuWidth: 320.4)

        #expect(point.x == -297)
        #expect(point.y == -8)
    }

    @Test
    func `auto popup point uses trailing alignment when screen geometry is unavailable`() {
        let point = StatusItemController.autoAlignedMenuPopupPoint(
            statusButtonBounds: NSRect(x: 0, y: 0, width: 24, height: 22),
            statusButtonIsFlipped: true,
            statusButtonScreenFrame: nil,
            screenVisibleFrame: nil,
            menuWidth: 320)

        #expect(point.x == -296)
        #expect(point.y == 30)
    }

    @Test
    func `realigned menu window returns to status item anchor after drifting down`() {
        let frame = StatusItemController.alignedMergedMenuWindowFrame(
            currentFrame: NSRect(x: 460, y: 10, width: 620, height: 740),
            statusButtonScreenFrame: NSRect(x: 1080, y: 878, width: 44, height: 22),
            screenVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 872))

        #expect(frame.origin.x == 504)
        #expect(frame.origin.y == 130)
        #expect(frame.maxX == 1124)
        #expect(frame.maxY == 870)
    }

    @Test
    func `realigned menu window opens right when status item has room`() {
        let frame = StatusItemController.alignedMergedMenuWindowFrame(
            currentFrame: NSRect(x: 0, y: 0, width: 320, height: 420),
            statusButtonScreenFrame: NSRect(x: 700, y: 878, width: 24, height: 22),
            screenVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 872))

        #expect(frame.origin.x == 724)
        #expect(frame.origin.y == 450)
        #expect(frame.maxY == 870)
    }

    @Test
    func `realigned menu window clamps inside visible screen`() {
        let frame = StatusItemController.alignedMergedMenuWindowFrame(
            currentFrame: NSRect(x: 0, y: 0, width: 1300, height: 1000),
            statusButtonScreenFrame: NSRect(x: 1180, y: 878, width: 20, height: 22),
            screenVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 872))

        #expect(frame.origin.x == 0)
        #expect(frame.origin.y == 0)
    }
}
