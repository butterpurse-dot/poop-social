import Foundation
import CryptoKit

/// Turns a phone number or email into a **one-way, salted hash**.
///
/// This is the whole privacy story for "add friends by number or email", so it
/// is deliberately a small, pure, dependency-light type that unit tests can
/// hammer.
///
/// The rules it exists to enforce:
///
/// 1. **Raw contact data is never persisted.** The app stores only the hash.
///    A phone number in a database is a permanent, cross-referenceable
///    identifier; a salted hash is not.
/// 2. **Hashing is one-way.** There is no `unhash`. Nothing in the app can turn
///    a stored hash back into a number or address, even if the store leaks.
/// 3. **The salt is per-install.** Without it, an attacker could hash every
///    possible phone number and match the table (a rainbow table) — phone
///    numbers are a tiny, enumerable space. A per-install random salt makes
///    that precomputation useless against *this* device's data.
/// 4. **Normalisation happens before hashing**, so `+1 (415) 555-0100` and
///    `14155550100` produce the same hash and actually match each other.
///
/// What this does **not** claim to do: it is not a substitute for a server-side
/// private set intersection. Two *devices* can only match if they agree on the
/// hash, which for a real product would mean a shared salt on a server. Here the
/// matching is local-only, which is the safest possible default and the honest
/// limitation to name.
enum ContactHasher {

    /// Why `SHA256` and not something weaker: we are not defending against
    /// brute force of a *single* secret (a password). We are defending against
    /// someone holding the store and trying to recover any of millions of
    /// short, guessable inputs. SHA-256 plus a secret per-install salt is the
    /// right shape for that, and has no dependencies beyond CryptoKit.
    private static let saltDefaultsKey = "com.poopsocial.contactSalt"

    /// The per-install salt. Generated once, random, and stored in `UserDefaults`
    /// (not in the SwiftData graph, so it is *not* included in any future
    /// export/backup of the user's content).
    ///
    /// It is deliberately read-through and created on first use so there is no
    /// "forgot to seed the salt" path where we accidentally hash unsalted.
    static func salt(defaults: UserDefaults = .standard) -> Data {
        if let existing = defaults.data(forKey: saltDefaultsKey), existing.count == 32 {
            return existing
        }
        // 32 random bytes. `SystemRandomNumberGenerator` is a CSPRNG.
        let fresh = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        defaults.set(fresh, forKey: saltDefaultsKey)
        return fresh
    }

    // MARK: - Normalisation

    /// Normalise a phone number to digits only, with a leading `+` kept if the
    /// caller supplied one. We intentionally do **not** try to fully canonicalise
    /// international numbers (that needs a real E.164 library); we just make the
    /// common cases agree: spaces, dashes, parens and dots all disappear.
    ///
    /// Returns `nil` when there is nothing usable, so callers never hash a
    /// degenerate empty string into a "valid" hash.
    static func normalisePhone(_ raw: String) -> String? {
        let hadPlus = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        let digits = raw.filter(\.isNumber)
        // 7 is the shortest thing that can be a real local number; anything
        // lower is almost certainly a typo or a partial paste.
        guard digits.count >= 7, digits.count <= 15 else { return nil }
        return hadPlus ? "+" + digits : digits
    }

    /// Normalise an email: trim, lowercase, and require exactly one `@` with
    /// something on both sides and a dot in the domain. Deliberately permissive
    /// (email is hard to validate perfectly) but strict enough to reject
    /// obvious junk so we do not store hashes of typos.
    static func normaliseEmail(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let (local, domain) = (parts[0], parts[1])
        guard !local.isEmpty, domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else {
            return nil
        }
        guard !trimmed.contains(" ") else { return nil }
        return trimmed
    }

    // MARK: - Hashing

    /// A tagged hash so a phone hash can never be confused with an email hash
    /// of the same string. The tag is prepended before hashing.
    static func hash(kind: ContactKind, value: String, salt: Data) -> String {
        var data = Data()
        data.append(contentsOf: Array("poopsocial:\(kind.rawValue):".utf8))
        data.append(salt)
        data.append(contentsOf: Array(value.utf8))

        let digest = SHA256.hash(data: data)
        // Hex, so it is safe to put in a predicate, a log line or a URL.
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The one call sites should use: normalise, then hash. Returns `nil` for
    /// input that is not a valid phone or email, so an invalid entry never
    /// produces a stored hash that could never match anything anyway.
    static func hash(raw: String, salt: Data, defaults: UserDefaults = .standard) -> (kind: ContactKind, hash: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A number or an address — decide which by what it contains, not by
        // asking the user to pick a mode first.
        if trimmed.contains("@") {
            guard let value = normaliseEmail(trimmed) else { return nil }
            return (.email, hash(kind: .email, value: value, salt: salt))
        }
        guard let value = normalisePhone(trimmed) else { return nil }
        return (.phone, hash(kind: .phone, value: value, salt: salt))
    }
}

/// What kind of contact identifier a hash came from. Persisted alongside the
/// hash purely so the UI can say "matched an email" vs "matched a number".
enum ContactKind: String, Codable, CaseIterable {
    case phone
    case email

    var label: String {
        switch self {
        case .phone: return "phone number"
        case .email: return "email address"
        }
    }

    var icon: String {
        switch self {
        case .phone: return "phone.fill"
        case .email: return "envelope.fill"
        }
    }
}
