import Foundation

struct AnonymizationService {

    struct AnonymizationResult {
        let anonymizedText: String
        let mapping: [String: String]   // placeholder → original
        let stats: AnonymizationStats
    }

    struct AnonymizationStats {
        var namesReplaced: Int = 0
        var ibansReplaced: Int = 0
        var emailsReplaced: Int = 0
        var phonesReplaced: Int = 0
        var addressesReplaced: Int = 0
    }

    // MARK: - Public Entry

    static func anonymize(
        ocrText: String,
        mieterName: String,
        mieterAdresse: String,
        vermieterName: String?,
        vermieterAdresse: String?
    ) -> AnonymizationResult {
        var text = ocrText
        var mapping: [String: String] = [:]
        var stats = AnonymizationStats()

        // 1. NAMEN — case-insensitive, mit Umlaut-Normalisierung
        text = replaceName(
            in: text, name: mieterName, placeholder: "MIETER",
            mapping: &mapping, stats: &stats
        )
        if let vName = vermieterName, !vName.isEmpty {
            text = replaceName(
                in: text, name: vName, placeholder: "VERMIETER",
                mapping: &mapping, stats: &stats
            )
        }

        // 2. IBAN — Länderpräfix + 20 Ziffern, optionale Leerzeichen
        if let ibanRegex = try? NSRegularExpression(
            pattern: "[A-Z]{2}\\s?\\d{2}[\\s]?(?:\\d{4}[\\s]?){4}\\d{2}",
            options: []
        ) {
            text = replaceMatches(
                regex: ibanRegex, in: text, prefix: "IBAN",
                mapping: &mapping, counter: &stats.ibansReplaced
            )
        }

        // 3. BIC / SWIFT (deutsche Banken)
        if let bicRegex = try? NSRegularExpression(
            pattern: "[A-Z]{4}DE[A-Z0-9]{2}(?:[A-Z0-9]{3})?",
            options: []
        ) {
            text = replaceMatches(
                regex: bicRegex, in: text, prefix: "BIC",
                mapping: &mapping, counter: &stats.ibansReplaced
            )
        }

        // 4. EMAIL
        if let emailRegex = try? NSRegularExpression(
            pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            options: []
        ) {
            text = replaceMatches(
                regex: emailRegex, in: text, prefix: "EMAIL",
                mapping: &mapping, counter: &stats.emailsReplaced
            )
        }

        // 5. TELEFON — deutsche Formate
        let phonePatterns = [
            "\\+49\\s?[\\d\\s/\\-]{8,14}",           // +49 170 1234567
            "0\\d{2,4}[\\s/\\-]?\\d{4,8}",            // 030 12345678
            "\\(0\\d{2,4}\\)\\s?\\d{4,8}"             // (030) 12345678
        ]
        for pattern in phonePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                text = replaceMatches(
                    regex: regex, in: text, prefix: "TELEFON",
                    mapping: &mapping, counter: &stats.phonesReplaced
                )
            }
        }

        // 6. ADRESSEN — Mieter und Vermieter
        text = replaceAddress(
            in: text, address: mieterAdresse,
            placeholder: "MIETER_ADRESSE",
            mapping: &mapping, stats: &stats
        )
        if let vAdr = vermieterAdresse, !vAdr.isEmpty {
            text = replaceAddress(
                in: text, address: vAdr,
                placeholder: "VERMIETER_ADRESSE",
                mapping: &mapping, stats: &stats
            )
        }

        return AnonymizationResult(
            anonymizedText: text,
            mapping: mapping,
            stats: stats
        )
    }

    // MARK: - Name Replacement (fuzzy)

    private static func replaceName(
        in text: String,
        name: String,
        placeholder: String,
        mapping: inout [String: String],
        stats: inout AnonymizationStats
    ) -> String {
        var result = text
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        // Voller Name
        let ph = "§§\(placeholder)§§"
        let before = result
        result = replaceInsensitive(in: result, target: trimmed, replacement: ph)
        if result != before {
            mapping[ph] = trimmed
            stats.namesReplaced += 1
        }

        // Einzelne Namensbestandteile (> 2 Zeichen, ohne Füllwörter)
        let skipWords: Set<String> = ["von", "der", "die", "das", "und", "van", "de"]
        for teil in trimmed.split(separator: " ") {
            let t = String(teil)
            guard t.count > 2, !skipWords.contains(t.lowercased()) else { continue }
            let tph = "§§\(placeholder)_\(t.uppercased())§§"
            let beforeTeil = result
            result = replaceInsensitive(in: result, target: t, replacement: tph)
            if result != beforeTeil {
                mapping[tph] = t
                stats.namesReplaced += 1
            }
        }

        return result
    }

    /// Case-insensitive + Umlaut-tolerant ersetzen — ALLE Vorkommen.
    private static func replaceInsensitive(
        in text: String,
        target: String,
        replacement: String
    ) -> String {
        var result = text

        // 1. Case-insensitive, ALLE Vorkommen
        let before = result
        result = result.replacingOccurrences(
            of: target,
            with: replacement,
            options: .caseInsensitive
        )
        if result != before { return result }

        // 2. Umlaut → ASCII (Müller → Mueller)
        let normalized = umlautNormalized(target)
        if normalized != target {
            let before2 = result
            result = result.replacingOccurrences(
                of: normalized,
                with: replacement,
                options: .caseInsensitive
            )
            if result != before2 { return result }
        }

        // 3. ASCII → Umlaut (Mueller → Müller)
        let denormalized = umlautDenormalized(target)
        if denormalized != target {
            result = result.replacingOccurrences(
                of: denormalized,
                with: replacement,
                options: .caseInsensitive
            )
        }

        return result
    }

    private static func umlautNormalized(_ s: String) -> String {
        s.replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ä", with: "Ae")
    }

    private static func umlautDenormalized(_ s: String) -> String {
        s.replacingOccurrences(of: "ue", with: "ü")
            .replacingOccurrences(of: "oe", with: "ö")
            .replacingOccurrences(of: "ae", with: "ä")
            .replacingOccurrences(of: "ss", with: "ß")
            .replacingOccurrences(of: "Ue", with: "Ü")
            .replacingOccurrences(of: "Oe", with: "Ö")
            .replacingOccurrences(of: "Ae", with: "Ä")
    }

    // MARK: - Regex-Replacement (rückwärts iterieren für stabile Indices)

    private static func replaceMatches(
        regex: NSRegularExpression,
        in text: String,
        prefix: String,
        mapping: inout [String: String],
        counter: inout Int
    ) -> String {
        var result = text
        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, range: range)
        let total = matches.count

        // Rückwärts iterieren damit Range-Indices stabil bleiben
        for (i, match) in matches.reversed().enumerated() {
            if let r = Range(match.range, in: result) {
                let original = String(result[r])
                // Nummerierung im Lesefluss (links → rechts)
                let nummer = total - i
                let ph = "§§\(prefix)_\(nummer)§§"
                result = result.replacingCharacters(in: r, with: ph)
                mapping[ph] = original
                counter += 1
            }
        }
        return result
    }

    // MARK: - Address Replacement (zeilenweise)

    private static func replaceAddress(
        in text: String,
        address: String,
        placeholder: String,
        mapping: inout [String: String],
        stats: inout AnonymizationStats
    ) -> String {
        var result = text
        let trimmedAdr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAdr.isEmpty, trimmedAdr.count > 8 else { return result }

        for (i, zeile) in trimmedAdr.split(separator: "\n").enumerated() {
            let z = String(zeile).trimmingCharacters(in: .whitespaces)
            guard z.count > 4 else { continue }
            let ph = "§§\(placeholder)_\(i + 1)§§"
            let before = result
            result = replaceInsensitive(in: result, target: z, replacement: ph)
            if result != before {
                mapping[ph] = z
                stats.addressesReplaced += 1
            }
        }
        return result
    }

    // MARK: - De-Anonymization

    /// De-Anonymisiert einen Text — ersetzt Platzhalter durch Originale.
    /// Längere Platzhalter zuerst (verhindert Substring-Kollisionen).
    static func deanonymize(_ text: String, mapping: [String: String]) -> String {
        var result = text
        let sorted = mapping.sorted { $0.key.count > $1.key.count }
        for (placeholder, original) in sorted {
            result = result.replacingOccurrences(of: placeholder, with: original)
        }
        return result
    }
}
