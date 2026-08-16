import AppKit
import Testing
@testable import CmdV

@Suite struct ConcealedDetectorTests {
    @Test func flagPresentIsConcealedRegardlessOfSource() {
        let concealed = ConcealedDetector.isConcealed(
            types: [.string, ConcealedDetector.concealedPasteboardType],
            sourceBundleID: "com.apple.TextEdit"
        )
        #expect(concealed)
    }

    @Test func knownPasswordManagerIsConcealedEvenWithoutFlag() {
        let concealed = ConcealedDetector.isConcealed(
            types: [.string],
            sourceBundleID: "com.1password.1password"
        )
        #expect(concealed)
    }

    @Test func ordinaryTextFromOrdinaryAppIsNotConcealed() {
        let concealed = ConcealedDetector.isConcealed(
            types: [.string],
            sourceBundleID: "com.apple.TextEdit"
        )
        #expect(!concealed)
    }

    @Test func noSourceBundleIDIsNotConcealedWithoutFlag() {
        let concealed = ConcealedDetector.isConcealed(types: [.string], sourceBundleID: nil)
        #expect(!concealed)
    }
}
