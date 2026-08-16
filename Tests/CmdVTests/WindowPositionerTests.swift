import Foundation
import Testing
@testable import CmdV

@Suite struct WindowPositionerTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func clampKeepsWindowFullyInsideFrameWhenAlreadyInside() {
        let origin = WindowPositioner.clamp(
            origin: CGPoint(x: 100, y: 100),
            size: CGSize(width: 400, height: 300),
            in: screen
        )
        #expect(origin == CGPoint(x: 100, y: 100))
    }

    @Test func clampPullsBackFromRightEdge() {
        let origin = WindowPositioner.clamp(
            origin: CGPoint(x: 1400, y: 100),
            size: CGSize(width: 400, height: 300),
            in: screen
        )
        #expect(origin.x == screen.maxX - 400)
    }

    @Test func clampPullsBackFromTopEdge() {
        let origin = WindowPositioner.clamp(
            origin: CGPoint(x: 100, y: 850),
            size: CGSize(width: 400, height: 300),
            in: screen
        )
        #expect(origin.y == screen.maxY - 300)
    }

    @Test func clampPullsBackFromNegativeOrigin() {
        let origin = WindowPositioner.clamp(
            origin: CGPoint(x: -50, y: -50),
            size: CGSize(width: 400, height: 300),
            in: screen
        )
        #expect(origin == CGPoint(x: 0, y: 0))
    }

    @Test func clampHandlesWindowLargerThanScreenByPinningToOrigin() {
        let origin = WindowPositioner.clamp(
            origin: CGPoint(x: 50, y: 50),
            size: CGSize(width: 2000, height: 1200),
            in: screen
        )
        #expect(origin == CGPoint(x: 0, y: 0))
    }

    @Test func centeredModeCentersWithinScreen() {
        let origin = WindowPositioner.origin(
            for: CGSize(width: 400, height: 300),
            mode: .centered,
            mouseLocation: CGPoint(x: 700, y: 450),
            screens: []
        )
        // Falls back to the default 1440x900 frame when no real screens are passed.
        #expect(origin == CGPoint(x: 520, y: 300))
    }
}
