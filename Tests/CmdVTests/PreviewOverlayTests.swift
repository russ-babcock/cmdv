import Foundation
import Testing
@testable import CmdV

@Suite struct PreviewOverlayTests {
    private let maxSize = CGSize(width: 800, height: 600)

    @Test func smallImageIsNotUpscaled() {
        let fitted = PreviewOverlayController.fitSize(
            natural: CGSize(width: 100, height: 80),
            max: maxSize
        )
        #expect(fitted == CGSize(width: 100, height: 80))
    }

    @Test func largeImageScalesDownPreservingAspectRatio() {
        let fitted = PreviewOverlayController.fitSize(
            natural: CGSize(width: 4000, height: 2000),
            max: maxSize
        )
        #expect(fitted.width == 800)
        #expect(fitted.height == 400)
    }

    @Test func tallImageScalesDownByHeight() {
        let fitted = PreviewOverlayController.fitSize(
            natural: CGSize(width: 1000, height: 4000),
            max: maxSize
        )
        #expect(fitted.height == 600)
        #expect(fitted.width == 150)
    }

    @Test func imageExactlyAtMaxSizeIsUnchanged() {
        let fitted = PreviewOverlayController.fitSize(natural: maxSize, max: maxSize)
        #expect(fitted == maxSize)
    }
}
