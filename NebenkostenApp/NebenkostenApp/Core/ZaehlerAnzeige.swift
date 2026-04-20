//
//  ZaehlerAnzeige.swift
//  NebenkostenApp — Core
//
//  Computed-Properties auf Zaehler, die die UI-Anzeige-Namen
//  liefern. Die View-Schicht darf keine JSON-IDs oder Roh-Slugs
//  mehr zeigen — alle User-sichtbaren Texte kommen aus diesen
//  Properties.
//
//  Regeln (UI-Fix-1 · 4):
//    - Eigener Name (`bezeichnung` nicht leer) hat immer Priorität.
//    - Hauptzähler (kein `wohneinheit`) → "<Medium>-Hauptzähler".
//    - Einheit-Zähler → "<Medium>zähler <Einheit>".
//    - Zwischenzähler (typ=.zwischen) → "<Zwischen-Semantik> <Einheit>"
//      — aktuell nur Wasser → "Gartenzähler <Einheit>".
//    - anzeigetyp ist der reine Medium-Name (Strom, Gas, Wärmemenge, …).
//    - anzeigeort liefert den menschenlesbaren Ort, wenn bekannt,
//      sonst leer. In der View wird er nur gezeigt wenn non-empty.
//

import Foundation

extension Zaehler {

    /// Menschenlesbarer Gesamtname für List-Rows und Titel.
    /// Vorrang: user-eingegebene `bezeichnung` → Heuristik aus Medium
    /// + Typ + Einheit.
    var anzeigename: String {
        let eigen = bezeichnung.trimmingCharacters(in: .whitespaces)
        if !eigen.isEmpty { return eigen }

        let einheitName = (wohneinheit?.bezeichnung ?? "").trimmingCharacters(in: .whitespaces)
        let medium = anzeigetyp

        // Zwischenzähler — aktuell hauptsächlich Garten-/Poolwasser.
        if typ == .zwischen {
            switch self.medium {
            case .kaltwasser, .warmwasser:
                return einheitName.isEmpty ? "Gartenzähler" : "Gartenzähler \(einheitName)"
            case .strom:
                return einheitName.isEmpty ? "Zwischen-Stromzähler" : "Zwischen-Stromzähler \(einheitName)"
            default:
                return einheitName.isEmpty ? "\(medium)-Zwischenzähler" : "\(medium)-Zwischenzähler \(einheitName)"
            }
        }

        // Hauptzähler: keine Einheit-Zuordnung.
        if einheitName.isEmpty {
            return "\(medium)-Hauptzähler"
        }

        // Einheit-Zähler: "Stromzähler OG", "Kaltwasserzähler EG".
        return "\(medium)zähler \(einheitName)"
    }

    /// Reiner Medium-Name für Typ-Chips und Section-Header.
    var anzeigetyp: String {
        switch self.medium {
        case .strom:         return "Strom"
        case .gas:           return "Gas"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemenge"
        case .oel:           return "Öl"
        }
    }

    /// Ortsangabe (Raum, Einheit, o.ä.). Wird im UI nur angezeigt,
    /// wenn non-empty. Phase-0 hat kein dediziertes Raum-Feld —
    /// deshalb Fallback auf die Einheit-Bezeichnung für Wohnungs-
    /// zähler und leer für Hauptzähler. Ein dediziertes Feld
    /// kommt in einem späteren Task.
    var anzeigeort: String {
        let einheitName = (wohneinheit?.bezeichnung ?? "").trimmingCharacters(in: .whitespaces)
        if !einheitName.isEmpty { return einheitName }
        return ""
    }
}
