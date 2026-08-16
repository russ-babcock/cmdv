import Testing
@testable import CmdV

@Suite struct PinKeyTests {
    @Test func acceptsDigitsAndLetters() {
        #expect(PinKey.isValid("1"))
        #expect(PinKey.isValid("9"))
        #expect(PinKey.isValid("A"))
        #expect(PinKey.isValid("z"))
    }

    @Test func rejectsZeroMultiCharacterAndSymbols() {
        #expect(!PinKey.isValid("0"))
        #expect(!PinKey.isValid("AB"))
        #expect(!PinKey.isValid("!"))
        #expect(!PinKey.isValid(""))
    }

    @Test func normalizeUppercasesLetters() {
        #expect(PinKey.normalize("a") == "A")
        #expect(PinKey.normalize("5") == "5")
        #expect(PinKey.normalize("0") == nil)
    }
}
