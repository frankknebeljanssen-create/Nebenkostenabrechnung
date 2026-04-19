//
//  Mustache.swift
//  NebenkostenApp — Common
//
//  Minimaler Mustache-Renderer für HTML-Templates (PDF-Generierung).
//  Unterstützt:
//    - {{key}}                     einfache Variable
//    - {{obj.prop}}                Dot-Notation
//    - {{#array}}...{{/array}}     Iteration über [[String: Any]]
//    - {{#flag}}...{{/flag}}       Conditional Section (truthy → rendern)
//
//  Escaping von HTML-Sonderzeichen wird NICHT gemacht — Template-Autor
//  ist verantwortlich für korrekte Feldwerte.
//

import Foundation

enum Mustache {

    static func render(_ template: String, with context: [String: Any]) -> String {
        let nachSections = aufloeseSections(template, context: context)
        return aufloeseVariablen(nachSections, context: context)
    }

    // MARK: - Sections

    /// Findet {{#key}}...{{/key}}-Blöcke und rendert sie.
    /// Unterstützt Iteration (Arrays) und Conditional-Sections (Bool/Truthy).
    private static func aufloeseSections(
        _ template: String,
        context: [String: Any]
    ) -> String {
        let regex = try! NSRegularExpression(
            pattern: #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#,
            options: [.dotMatchesLineSeparators]
        )

        var result = template
        while true {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: range) else {
                break
            }
            let keyRange = Range(match.range(at: 1), in: result)!
            let bodyRange = Range(match.range(at: 2), in: result)!
            let fullRange = Range(match.range(at: 0), in: result)!

            let key = String(result[keyRange])
            let body = String(result[bodyRange])
            let wert = schlage(key: key, in: context)

            let ersatz = rendereSection(body: body, wert: wert, context: context)
            result.replaceSubrange(fullRange, with: ersatz)
        }
        return result
    }

    private static func rendereSection(
        body: String,
        wert: Any?,
        context: [String: Any]
    ) -> String {
        if let array = wert as? [[String: Any]] {
            // Array-Iteration: jedes Item wird zum scope für den Body.
            return array.map { item in
                var scope = context
                for (k, v) in item { scope[k] = v }
                return aufloeseSections(body, context: scope)
                    .let { aufloeseVariablen($0, context: scope) }
            }.joined()
        }
        if let bool = wert as? Bool, bool == false {
            return ""
        }
        if wert == nil {
            return ""
        }
        // Truthy non-bool, non-array: Block wird mit current context gerendert.
        return aufloeseVariablen(body, context: context)
    }

    // MARK: - Variablen

    private static func aufloeseVariablen(
        _ template: String,
        context: [String: Any]
    ) -> String {
        let regex = try! NSRegularExpression(pattern: #"\{\{([\w.]+)\}\}"#)

        var result = template
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = regex.matches(in: result, options: [], range: range).reversed()

        for match in matches {
            let keyRange = Range(match.range(at: 1), in: result)!
            let fullRange = Range(match.range(at: 0), in: result)!
            let key = String(result[keyRange])

            let wert = schlage(key: key, in: context)
            let text = formatte(wert)
            result.replaceSubrange(fullRange, with: text)
        }
        return result
    }

    private static func schlage(key: String, in context: [String: Any]) -> Any? {
        let teile = key.split(separator: ".").map(String.init)
        var current: Any? = context
        for teil in teile {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[teil]
        }
        return current
    }

    private static func formatte(_ wert: Any?) -> String {
        guard let wert else { return "" }
        if let dec = wert as? Decimal {
            return NSDecimalNumber(decimal: dec).stringValue
        }
        return "\(wert)"
    }
}

private extension String {
    /// Helper für Kette: "value.let { transform($0) }".
    func `let`<T>(_ transform: (String) -> T) -> T { transform(self) }
}
