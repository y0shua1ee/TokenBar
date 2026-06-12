import AppKit
import Foundation
import Testing
@testable import TokenBar

@MainActor
struct MouseLocationReaderTests {
    @Test
    func `mouse locations are coalesced to the latest pending point`() async {
        let view = MouseLocationReader.TrackingView()
        var delivered: [CGPoint?] = []
        view.onMoved = { delivered.append($0) }

        view.enqueueMouseLocationForTesting(CGPoint(x: 10, y: 10))
        view.enqueueMouseLocationForTesting(CGPoint(x: 11, y: 10.5))
        view.enqueueMouseLocationForTesting(CGPoint(x: 20, y: 20))

        try? await Task.sleep(nanoseconds: 50_000_000)

        let deliveredPoints = delivered.compactMap(\.self)
        #expect(deliveredPoints == [CGPoint(x: 20, y: 20)])
    }

    @Test
    func `mouse exit cancels pending delivery and clears selection immediately`() async {
        let view = MouseLocationReader.TrackingView()
        var delivered: [CGPoint?] = []
        view.onMoved = { delivered.append($0) }

        view.enqueueMouseLocationForTesting(CGPoint(x: 10, y: 10))
        view.enqueueMouseLocationForTesting(nil)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(delivered.count == 1)
        #expect(delivered[0] == nil)
    }
}
