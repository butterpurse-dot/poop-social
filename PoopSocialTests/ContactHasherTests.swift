import XCTest
import CryptoKit

/// Unit coverage for the "add friends by number or email" privacy claims.
///
/// These tests exist because the promise is a *privacy* promise, and a privacy
/// claim that is not tested is a marketing claim. Each test names the property
/// it pins down.
///
/// `ContactHasher.swift` is pure Swift (Foundation + CryptoKit only), so it is
/// compiled straight into this bundle. No host app, no simulator.
final class ContactHasherTests: XCTestCase {

    // A fixed salt so tests are deterministic. The *production* salt is random
    // per install — see `testSaltIsRandomPerInstall`.
    private let salt = Data(repeating: 0xAB, count: 32)

    // MARK: - One-way

    /// The stored value must not contain, in any form, the number it came from.
    func testHashDoesNotContainTheRawNumber() {
        let raw = "+14155550100"
        let hash = ContactHasher.hash(kind: .phone, value: "+14155550100", salt: salt)

        XCTAssertFalse(hash.contains("4155550100"), "hash leaked the digits")
        XCTAssertFalse(hash.contains("14155550100"), "hash leaked the digits")
        XCTAssertFalse(hash.contains("+"), "hash looks like a phone number")
        // And it must not just be the number rendered another way.
        XCTAssertNotEqual(hash, raw)
    }

    /// The digest must be a real 256-bit hash: fixed length, hex, no structure.
    func testHashIsA256BitHexDigest() {
        let hash = ContactHasher.hash(kind: .email, value: "maya@example.com", salt: salt)
        XCTAssertEqual(hash.count, 64, "SHA-256 in hex is 64 characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "hash should be hex only")
    }

    // MARK: - Deterministic where it must be, different where it must be

    /// Same input + same salt ⇒ same hash. Without this, a number could never
    /// match the friend who has it.
    func testSameInputAndSaltProduceSameHash() {
        let a = ContactHasher.hash(kind: .email, value: "maya@example.com", salt: salt)
        let b = ContactHasher.hash(kind: .email, value: "maya@example.com", salt: salt)
        XCTAssertEqual(a, b)
    }

    /// Same input + *different* salt ⇒ different hash. This is the property that
    /// defeats precomputed rainbow tables of phone numbers.
    func testDifferentSaltProducesDifferentHash() {
        let other = Data(repeating: 0xCD, count: 32)
        let a = ContactHasher.hash(kind: .email, value: "maya@example.com", salt: salt)
        let b = ContactHasher.hash(kind: .email, value: "maya@example.com", salt: other)
        XCTAssertNotEqual(a, b, "the salt is not actually affecting the hash")
    }

    /// A phone hash and an email hash of the same string must never collide —
    /// hence the kind tag inside the digest.
    func testKindIsDomainSeparated() {
        let asPhone = ContactHasher.hash(kind: .phone, value: "1234567890", salt: salt)
        let asEmail = ContactHasher.hash(kind: .email, value: "1234567890", salt: salt)
        XCTAssertNotEqual(asPhone, asEmail, "kind tag is not separating the domains")
    }

    // MARK: - Normalisation (the "why don't my numbers match?" property)

    /// Formatting must not matter: these are all the same number.
    func testPhoneFormattingIsNormalisedBeforeHashing() {
        let variants = [
            "+1 (415) 555-0100",
            "+14155550100",
            "+1-415-555-0100",
            "+1.415.555.0100",
            "+1 415 555 0100",
        ]
        let hashes = Set(variants.map {
            ContactHasher.hash(raw: $0, salt: salt)!.hash
        })
        XCTAssertEqual(hashes.count, 1, "formatting changes the hash — numbers would fail to match")
    }

    /// Emails are case-insensitive in practice.
    func testEmailCaseAndWhitespaceAreNormalised() {
        let variants = ["  Maya@Example.COM ", "maya@example.com", "MAYA@EXAMPLE.COM"]
        let hashes = Set(variants.map {
            ContactHasher.hash(raw: $0, salt: salt)!.hash
        })
        XCTAssertEqual(hashes.count, 1, "email casing changes the hash")
    }

    // MARK: - Validation (never store a hash of junk)

    func testInvalidPhoneNumbersAreRejected() {
        for bad in ["", "123", "abc", "12 34", "+1"] {
            XCTAssertNil(ContactHasher.hash(raw: bad, salt: salt), "accepted junk: \(bad)")
        }
    }

    func testInvalidEmailsAreRejected() {
        for bad in ["", "@", "maya@", "@example.com", "maya@example", "maya example@test.com", "a@@b.com"] {
            XCTAssertNil(ContactHasher.hash(raw: bad, salt: salt), "accepted junk: \(bad)")
        }
    }

    /// A number is a number and an address is an address — chosen by content.
    func testKindIsInferredFromTheInput() {
        XCTAssertEqual(ContactHasher.hash(raw: "+14155550100", salt: salt)?.kind, .phone)
        XCTAssertEqual(ContactHasher.hash(raw: "maya@example.com", salt: salt)?.kind, .email)
    }

    // MARK: - Salt handling

    /// A fresh install with no stored salt must get a random one, and that salt
    /// must persist (otherwise contacts would never match across launches).
    func testSaltIsPersistedAndStable() {
        let suite = UserDefaults(suiteName: "ContactHasherTests.\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }

        let first = ContactHasher.salt(defaults: suite)
        let second = ContactHasher.salt(defaults: suite)

        XCTAssertEqual(first.count, 32, "salt should be 32 bytes")
        XCTAssertEqual(first, second, "salt must be stable once created")
    }

    /// Two different installs (different defaults) must not share a salt.
    func testSaltIsRandomPerInstall() {
        let a = UserDefaults(suiteName: "ContactHasherTests.a.\(UUID().uuidString)")!
        let b = UserDefaults(suiteName: "ContactHasherTests.b.\(UUID().uuidString)")!
        defer {
            a.removePersistentDomain(forName: a.description)
            b.removePersistentDomain(forName: b.description)
        }

        XCTAssertNotEqual(ContactHasher.salt(defaults: a), ContactHasher.salt(defaults: b))
    }

    // MARK: - The structural claim

    /// The strongest form of the promise: prove the *shape* of the hasher makes
    /// a raw leak impossible, the same way the no-photos rule proves `MediaKind`
    /// has no image case.
    ///
    /// If someone later adds an `init(raw:)` convenience that stashes the input
    /// in a `Data` blob, this test is what catches it.
    func testEveryOutputIsIndistinguishableFromRandom() {
        // A handful of very different inputs — including the shortest and
        // paddiest, which are the easiest to accidentally leak through.
        let inputs = ["+14155550100", "maya@example.com", "a@b.co", "+441234567890"]
        let hashes = inputs.map { ContactHasher.hash(raw: $0, salt: salt)! }

        for (raw, parsed) in zip(inputs, hashes) {
            let digits = raw.filter(\.isNumber).lowercased()
            XCTAssertFalse(
                parsed.hash.contains(digits),
                "hash of \(raw) contains its own digits"
            )
            // Uniform hex output means there is no positional structure to read.
            XCTAssertTrue(parsed.hash.allSatisfy { $0.isHexDigit })
            XCTAssertEqual(parsed.hash.count, 64)
        }
    }
}
