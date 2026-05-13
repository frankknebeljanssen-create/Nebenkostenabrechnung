import SwiftUI

/// Lokaler Hilfe-Artikel — alle Inhalte sind statisch im Bundle,
/// kein Netzwerk-Request.
struct HilfeArtikel: Identifiable {
    let id = UUID()
    let titel: String
    let keywords: [String]
    let section: String
    let inhalt: [HilfeBlock]

    /// Case-insensitive Match über Titel + Keywords.
    func passtZu(suchText: String) -> Bool {
        let q = suchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if titel.lowercased().contains(q) { return true }
        return keywords.contains { $0.lowercased().contains(q) }
    }
}

/// Inhalts-Bausteine eines Hilfe-Artikels.
///
/// - `text`:      Freitext-Absatz (14 pt)
/// - `schritt`:   Nummerierter Schritt mit kurzem Beschreibungstext
/// - `farbBlock`: Farb-akzentuierter Block (Border-Farbe + Titel bold + Text)
/// - `hinweis`:   Hervorgehobener Hinweis-Kasten (NKCard + info.circle)
enum HilfeBlock {
    case text(String)
    case schritt(Int, String)
    case farbBlock(Color, String, String)
    case hinweis(String)
}

// MARK: - Statischer Artikel-Katalog

enum HilfeKatalog {
    /// Wird in `HilfeView` als Datenquelle verwendet.
    static let alle: [HilfeArtikel] = [

        // MARK: Section „Erste Schritte"

        HilfeArtikel(
            titel: "So funktioniert die App",
            keywords: ["anleitung", "start", "fotografieren", "kamera", "prüfung"],
            section: "Erste Schritte",
            inhalt: [
                .text("In drei Schritten zu deinem geprüften Widerspruch:"),
                .schritt(1, "Fotografiere deine Nebenkostenabrechnung mit der Kamera. Die Abrechnung wird automatisch erkannt und gelesen."),
                .schritt(2, "Unsere KI-Agenten prüfen die Abrechnung — sie rechnen nach, vergleichen mit dem Gesetz und decken Fehler auf."),
                .schritt(3, "Du bekommst einen Bericht mit allen Ergebnissen und kannst direkt einen Widerspruch erstellen."),
                .hinweis("Die App ersetzt keine Rechtsberatung. Bei Unstimmigkeiten empfehlen wir einen Mieterverein.")
            ]
        ),

        HilfeArtikel(
            titel: "Was kostet die App?",
            keywords: ["preis", "kosten", "abo", "kostenlos", "gratis"],
            section: "Erste Schritte",
            inhalt: [
                .text("Die App selbst ist kostenlos. Du brauchst aber einen Zugangsschlüssel von Anthropic (dem Unternehmen hinter der KI Claude), damit deine Abrechnung geprüft werden kann."),
                .text("Anthropic rechnet die Prüfungen direkt mit dir ab — typischerweise wenige Cents pro Abrechnung."),
                .hinweis("Den Zugangsschlüssel hinterlegst du unter \u{201E}Mehr → Zugangsschlüssel\u{201C}. Er wird verschlüsselt in der iOS Keychain gespeichert.")
            ]
        ),

        // MARK: Section „Sicherheit & Datenschutz"

        HilfeArtikel(
            titel: "Datensicherheit",
            keywords: ["daten", "sicherheit", "verschlüsselung", "schutz"],
            section: "Sicherheit & Datenschutz",
            inhalt: [
                .text("So gehen wir mit deinen Daten um:"),
                .farbBlock(Color.green, "Lokale Speicherung",
                           "Profil, Wohnungen und alle Prüfberichte liegen ausschließlich auf deinem iPhone. Niemand sonst kann sie sehen."),
                .farbBlock(Color.blue, "Anonymisierung",
                           "Bevor etwas an die KI gesendet wird, werden Namen, IBANs, E-Mails und Telefonnummern automatisch ersetzt. Die KI sieht nie deine echten Daten."),
                .farbBlock(Color.orange, "Keine KI-Schulung",
                           "Anthropic verwendet die gesendeten Daten gemäß API-Nutzungsbedingungen NICHT für das Training neuer KI-Modelle. Daten werden nach 7 Tagen gelöscht.")
            ]
        ),

        HilfeArtikel(
            titel: "Datenschutz-Zustimmung",
            keywords: ["dsgvo", "consent", "zustimmung", "einwilligung"],
            section: "Sicherheit & Datenschutz",
            inhalt: [
                .text("Bevor die App das erste Mal Daten an die KI sendet, brauchen wir deine Zustimmung — das ist gesetzlich vorgeschrieben (DSGVO)."),
                .text("Die Zustimmung kannst du jederzeit unter \u{201E}Mehr → Datenschutz\u{201C} widerrufen. Ohne Zustimmung funktionieren nur lokale Funktionen — keine KI-Prüfung."),
                .hinweis("Die Zustimmung gilt nur für die Übertragung an die KI — Profil und Prüfberichte bleiben unabhängig davon auf deinem Gerät.")
            ]
        ),

        // MARK: Section „Häufige Fragen"

        HilfeArtikel(
            titel: "Wer prüft meine Abrechnung?",
            keywords: ["ki", "claude", "anthropic", "agent", "prüfung"],
            section: "Häufige Fragen",
            inhalt: [
                .text("Wir nutzen die KI Claude von Anthropic. Statt einer einzigen Anfrage arbeitet bei uns ein Team aus 7 spezialisierten KI-Agenten:"),
                .schritt(1, "Der Leser zieht alle Zahlen, Daten und Posten aus deiner Abrechnung."),
                .schritt(2, "Der Gegenprüfer kontrolliert, ob die gelesenen Daten wirklich in der Abrechnung stehen."),
                .schritt(3, "Der Rechner prüft jede Summe und jede Anteilsberechnung neu."),
                .schritt(4, "Der Jurist bewertet, ob jede Kostenart laut Mietrecht überhaupt umlegbar ist."),
                .schritt(5, "Der Kritiker hinterfragt jedes Ergebnis kritisch — wie ein Anwalt der Gegenseite."),
                .schritt(6, "Der Berichterstatter formuliert das Ergebnis verständlich für dich."),
                .schritt(7, "Der Auditor gibt die finale Freigabe — oder schickt das Ergebnis zur Korrektur zurück."),
                .hinweis("Jeder Agent arbeitet unabhängig. Erst wenn alle einverstanden sind, siehst du das Ergebnis.")
            ]
        ),

        HilfeArtikel(
            titel: "Brauche ich Internet?",
            keywords: ["internet", "offline", "wlan", "verbindung"],
            section: "Häufige Fragen",
            inhalt: [
                .text("Für die KI-Prüfung selbst brauchst du eine Internet-Verbindung — die Agenten laufen auf den Servern von Anthropic."),
                .text("Alles andere funktioniert offline:"),
                .schritt(1, "Fotografieren und OCR (Texterkennung) laufen lokal auf deinem iPhone."),
                .schritt(2, "Alle gespeicherten Prüfberichte und Wohnungs-Daten kannst du auch ohne Netz ansehen."),
                .schritt(3, "Widerspruchs-Briefe können offline gelesen, bearbeitet und als PDF gespeichert werden.")
            ]
        ),

        HilfeArtikel(
            titel: "Was bedeutet der Vertrauenswert?",
            keywords: ["vertrauen", "score", "prozent", "bewertung"],
            section: "Häufige Fragen",
            inhalt: [
                .text("Der Vertrauenswert zeigt, wie sicher ein Ergebnis ist — auf einer Skala von 0 bis 100 %."),
                .text("Er setzt sich aus 5 Validierungs-Schichten zusammen (je 20 %):"),
                .farbBlock(Color.green, "Struktur",
                           "Die ausgelesenen Daten sind vollständig und plausibel."),
                .farbBlock(Color.green, "Cross-Check",
                           "Die Summe der Einzelposten passt zur Gesamtsumme."),
                .farbBlock(Color.green, "Quelltreue",
                           "Jede Zahl steht so im Original-Dokument — nichts ist erfunden."),
                .farbBlock(Color.green, "Debatte",
                           "Der kritische Gutachter hat dem Ergebnis nicht widersprochen."),
                .farbBlock(Color.green, "Audit",
                           "Der finale Prüfer hat das Ergebnis freigegeben."),
                .hinweis("Ergebnisse mit über 80 % gelten als sicher. Unter 60 % solltest du das Ergebnis selbst kritisch prüfen.")
            ]
        ),

        HilfeArtikel(
            titel: "Wie versende ich den Widerspruch?",
            keywords: ["widerspruch", "versenden", "einschreiben", "email", "whatsapp"],
            section: "Häufige Fragen",
            inhalt: [
                .text("Für einen offiziellen Widerspruch empfehlen wir den Postweg — am besten per Einschreiben mit Rückschein."),
                .schritt(1, "Tippe in der Bericht-Ansicht auf \u{201E}Widerspruch erstellen\u{201C}. Der Brief wird automatisch formuliert."),
                .schritt(2, "Wähle \u{201E}PDF herunterladen\u{201C}. Du bekommst eine fertige A4-Datei, die du beim nächsten Druckdienst oder zu Hause drucken kannst."),
                .schritt(3, "Verschicke das Schreiben per Einschreiben mit Rückschein. So hast du einen Nachweis."),
                .farbBlock(Color.blue, "E-Mail als Alternative",
                           "Wenn du die E-Mail-Adresse deines Vermieters hast, kannst du den Brief auch per E-Mail senden. Aktiviere die Lesebestätigung."),
                .farbBlock(Color.orange, "WhatsApp nur als Hinweis",
                           "Eine WhatsApp-Nachricht ist KEIN offizieller Widerspruch — nur ein kurzer Hinweis. Der formelle Widerspruch muss schriftlich erfolgen.")
            ]
        )
    ]

    /// Sektionen in stabiler Reihenfolge (für die UI-Gruppierung).
    static var sektionen: [String] {
        ["Erste Schritte", "Sicherheit & Datenschutz", "Häufige Fragen"]
    }
}
