//
//  MustacheTests.swift
//  NebenkostenAppTests — CommonTests
//

import Foundation
import Testing
@testable import NebenkostenApp

struct MustacheTests {

    @Test("Einfache Variable {{name}} wird ersetzt")
    func einfacheVariable() {
        let result = Mustache.render("Hallo {{name}}", with: ["name": "Frank"])
        #expect(result == "Hallo Frank")
    }

    @Test("Dot-Notation {{obj.prop}}")
    func dotNotation() {
        let context: [String: Any] = [
            "mieter": ["name": "Pfaffenbach", "ort": "Berlin"]
        ]
        let result = Mustache.render("{{mieter.name}} in {{mieter.ort}}", with: context)
        #expect(result == "Pfaffenbach in Berlin")
    }

    @Test("Array-Iteration {{#items}}...{{/items}}")
    func arrayIteration() {
        let context: [String: Any] = [
            "items": [
                ["name": "Heizung", "betrag": "100 €"],
                ["name": "Wasser",  "betrag": "50 €"]
            ]
        ]
        let template = "{{#items}}{{name}}: {{betrag}}\n{{/items}}"
        let result = Mustache.render(template, with: context)
        #expect(result == "Heizung: 100 €\nWasser: 50 €\n")
    }

    @Test("Conditional-Section truthy → wird gerendert")
    func conditionalTruthy() {
        let context: [String: Any] = ["hatHinweis": true, "hinweis": "Achtung!"]
        let template = "{{#hatHinweis}}Hinweis: {{hinweis}}{{/hatHinweis}}"
        let result = Mustache.render(template, with: context)
        #expect(result == "Hinweis: Achtung!")
    }

    @Test("Conditional-Section falsy → leer")
    func conditionalFalsy() {
        let context: [String: Any] = ["hatHinweis": false]
        let template = "vor {{#hatHinweis}}Hinweis{{/hatHinweis}} nach"
        let result = Mustache.render(template, with: context)
        #expect(result == "vor  nach")
    }

    @Test("Fehlende Variable → leerer String")
    func fehlendeVariable() {
        let result = Mustache.render("Hallo {{name}}!", with: [:])
        #expect(result == "Hallo !")
    }

    @Test("Decimal wird sauber formatiert")
    func decimalFormatierung() {
        let context: [String: Any] = ["betrag": Decimal(string: "1234.56")!]
        let result = Mustache.render("{{betrag}} €", with: context)
        #expect(result == "1234.56 €")
    }

    @Test("Array-Iteration mit Zugriff auf outer context via dot-key")
    func iterationMitOuterContext() {
        let context: [String: Any] = [
            "vermieter": ["name": "Janßen"],
            "positionen": [
                ["kostenart": "Heizung"],
                ["kostenart": "Wasser"]
            ]
        ]
        let template = "{{#positionen}}- {{kostenart}} ({{vermieter.name}})\n{{/positionen}}"
        let result = Mustache.render(template, with: context)
        #expect(result == "- Heizung (Janßen)\n- Wasser (Janßen)\n")
    }

    @Test("Abrechnungs-Template Smoke: sektionen bleiben intakt")
    func abrechnungSmoke() {
        // Minimaler Satz aus abrechnung.html: Absender-Zeile + eine Position.
        let template = """
        <div>{{vermieter.name}}</div>
        <table>
        {{#positionen}}
        <tr><td>{{bezeichnung}}</td><td>{{mieteranteilEuro}} €</td></tr>
        {{/positionen}}
        </table>
        """
        let context: [String: Any] = [
            "vermieter": ["name": "Verena Janßen"],
            "positionen": [
                ["bezeichnung": "Heizung", "mieteranteilEuro": "1000,00"],
                ["bezeichnung": "Wasser",  "mieteranteilEuro": "346,53"]
            ]
        ]
        let result = Mustache.render(template, with: context)
        #expect(result.contains("<div>Verena Janßen</div>"))
        #expect(result.contains("<td>Heizung</td><td>1000,00 €</td>"))
        #expect(result.contains("<td>Wasser</td><td>346,53 €</td>"))
    }
}
