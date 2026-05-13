import Foundation

struct GlossarEintrag: Identifiable {
    let id: String
    let begriff: String
    let erklaerung: String
    let kategorie: GlossarKategorie
}

enum GlossarKategorie: String, CaseIterable {
    case kostenarten = "Kostenarten"
    case verteilung = "Verteilung & Berechnung"
    case gesetze = "Gesetze & Normen"
    case recht = "Rechtliches"
    case fehlertypen = "Häufige Fehler"
    case abrechnung = "Abrechnung"
    case verwaltung = "Hausverwaltung"
    case technik = "Zähler & Technik"
}

struct NKGlossary {

    static let eintraege: [String: GlossarEintrag] = [

        // ═══════════════════════════════════════
        // KOSTENARTEN (BetrKV § 2 Nr. 1–17)
        // ═══════════════════════════════════════

        "grundsteuer": GlossarEintrag(
            id: "grundsteuer",
            begriff: "Grundsteuer",
            erklaerung: "Steuer die der Eigentümer an die Gemeinde zahlt (BetrKV § 2 Nr. 1). Darf auf Mieter umgelegt werden. Die Höhe hängt vom Einheitswert des Grundstücks und dem Hebesatz der Gemeinde ab.",
            kategorie: .kostenarten
        ),
        "entwaesserung": GlossarEintrag(
            id: "entwaesserung",
            begriff: "Wasserversorgung / Entwässerung",
            erklaerung: "Kosten für Frischwasser (BetrKV § 2 Nr. 2) und Abwasser (Nr. 3). Beinhaltet Wasserverbrauch, Grundgebühren, Zählermiete und Kanalgebühren. Wird meist nach Verbrauch oder Wohnfläche verteilt.",
            kategorie: .kostenarten
        ),
        "heizung": GlossarEintrag(
            id: "heizung",
            begriff: "Heizkosten",
            erklaerung: "Kosten für Heizung (BetrKV § 2 Nr. 4a). Beinhaltet Brennstoff, Wartung, Schornsteinfeger, Betriebsstrom der Heizanlage. Müssen laut Heizkostenverordnung zu 50–70% nach Verbrauch und 30–50% nach Wohnfläche verteilt werden.",
            kategorie: .kostenarten
        ),
        "warmwasser": GlossarEintrag(
            id: "warmwasser",
            begriff: "Warmwasserkosten",
            erklaerung: "Kosten für die Warmwasserbereitung (BetrKV § 2 Nr. 5a). Wie Heizkosten: 50–70% nach Verbrauch, Rest nach Wohnfläche. Bei zentraler Heizung werden Heiz- und Warmwasserkosten oft zusammen abgerechnet.",
            kategorie: .kostenarten
        ),
        "aufzug": GlossarEintrag(
            id: "aufzug",
            begriff: "Aufzugskosten",
            erklaerung: "Betriebskosten des Aufzugs (BetrKV § 2 Nr. 7): Strom, Wartung, TÜV-Prüfung, Notrufsystem. Auch Erdgeschoss-Mieter müssen zahlen, es sei denn der Mietvertrag schließt das aus. Reparaturen sind NICHT umlagefähig.",
            kategorie: .kostenarten
        ),
        "strassenreinigung": GlossarEintrag(
            id: "strassenreinigung",
            begriff: "Straßenreinigung / Winterdienst",
            erklaerung: "Kosten für öffentliche Straßenreinigung und Winterdienst (BetrKV § 2 Nr. 8). Beinhaltet auch Streumaterial und Räumgeräte. Wenn der Vermieter einen Winterdienst beauftragt, sind das ebenfalls umlagefähige Kosten.",
            kategorie: .kostenarten
        ),
        "muellabfuhr": GlossarEintrag(
            id: "muellabfuhr",
            begriff: "Müllabfuhr",
            erklaerung: "Gebühren für Müllentsorgung (BetrKV § 2 Nr. 8). Beinhaltet Restmüll, Biotonne, Gelbe Tonne/Gelber Sack und Sperrmüll. Die Gebühren werden von der Kommune festgelegt.",
            kategorie: .kostenarten
        ),
        "gebaeudereinigung": GlossarEintrag(
            id: "gebaeudereinigung",
            begriff: "Gebäudereinigung",
            erklaerung: "Kosten für die Reinigung von Gemeinschaftsflächen (BetrKV § 2 Nr. 9): Treppenhaus, Flure, Waschküche, Kellerflure. Wenn Mieter die Reinigung selbst übernehmen (Kehrwoche), darf der Vermieter keine Reinigungsfirma umlegen.",
            kategorie: .kostenarten
        ),
        "gartenpflege": GlossarEintrag(
            id: "gartenpflege",
            begriff: "Gartenpflege",
            erklaerung: "Kosten für die Pflege von Grünflächen und Gärten (BetrKV § 2 Nr. 10). Beinhaltet Rasenmähen, Heckenschnitt, Baumpflege, Blumen, Dünger. Neuanlage eines Gartens ist NICHT umlagefähig — nur die laufende Pflege.",
            kategorie: .kostenarten
        ),
        "beleuchtung": GlossarEintrag(
            id: "beleuchtung",
            begriff: "Allgemeinstrom / Beleuchtung",
            erklaerung: "Stromkosten für Gemeinschaftsflächen (BetrKV § 2 Nr. 11): Treppenhausbeleuchtung, Außenbeleuchtung, Kellerflure, Tiefgarage. Strom für den Aufzug wird separat unter Aufzugskosten erfasst.",
            kategorie: .kostenarten
        ),
        "schornsteinfeger": GlossarEintrag(
            id: "schornsteinfeger",
            begriff: "Schornsteinfeger",
            erklaerung: "Kosten für den Schornsteinfeger (BetrKV § 2 Nr. 12): Feuerstättenschau, Kehr- und Überprüfungsarbeiten, Emissionsmessung. Seit 2013 können Eigentümer den Schornsteinfeger frei wählen (außer für hoheitliche Aufgaben).",
            kategorie: .kostenarten
        ),
        "versicherung": GlossarEintrag(
            id: "versicherung",
            begriff: "Sach- und Haftpflichtversicherung",
            erklaerung: "Gebäudeversicherung gegen Feuer, Sturm, Wasser, Elementarschäden (BetrKV § 2 Nr. 13). Auch Haus- und Grundbesitzerhaftpflicht. Mietausfallversicherung und Rechtsschutz des Vermieters sind NICHT umlagefähig.",
            kategorie: .kostenarten
        ),
        "hausmeister": GlossarEintrag(
            id: "hausmeister",
            begriff: "Hausmeisterkosten",
            erklaerung: "Kosten für den Hauswart (BetrKV § 2 Nr. 14): Gehalt, Sozialabgaben, Arbeitsmaterial. ABER: Anteile für Verwaltung, Reparaturen oder Instandhaltung müssen herausgerechnet werden — die sind nicht umlagefähig. Typisch: 10–20% Abzug.",
            kategorie: .kostenarten
        ),
        "gemeinschaftsantenne": GlossarEintrag(
            id: "gemeinschaftsantenne",
            begriff: "Antennenanlage / Kabelfernsehen",
            erklaerung: "Kosten für Gemeinschaftsantenne oder Kabelanschluss (BetrKV § 2 Nr. 15). Seit Juli 2024 dürfen Kabelkosten nicht mehr über die Nebenkosten umgelegt werden (Nebenkostenprivileg abgeschafft). Nur noch Antennenanlagen-Betrieb.",
            kategorie: .kostenarten
        ),
        "wascheinrichtung": GlossarEintrag(
            id: "wascheinrichtung",
            begriff: "Gemeinschafts-Waschmaschine",
            erklaerung: "Kosten für gemeinschaftliche Waschmaschinen und Trockner (BetrKV § 2 Nr. 16): Strom, Wasser, Wartung. Nicht zu verwechseln mit deiner eigenen Waschmaschine in der Wohnung.",
            kategorie: .kostenarten
        ),
        "sonstige": GlossarEintrag(
            id: "sonstige",
            begriff: "Sonstige Betriebskosten",
            erklaerung: "Auffangposition (BetrKV § 2 Nr. 17). Nur umlagefähig wenn im Mietvertrag konkret benannt — z.B. Dachrinnenreinigung, Wartung Feuerlöscher, Spielplatzpflege, Schwimmbad. Eine pauschale Angabe 'sonstige Kosten' reicht NICHT.",
            kategorie: .kostenarten
        ),
        "verwaltungskosten": GlossarEintrag(
            id: "verwaltungskosten",
            begriff: "Verwaltungskosten",
            erklaerung: "Kosten der Hausverwaltung: Verwaltergebühr, Buchhaltung, Mahnwesen. Sind NICHT umlagefähig! Wenn sie trotzdem in deiner Abrechnung auftauchen, ist das ein Fehler den du widersprechen solltest.",
            kategorie: .kostenarten
        ),
        "instandhaltung": GlossarEintrag(
            id: "instandhaltung",
            begriff: "Instandhaltung / Reparaturen",
            erklaerung: "Kosten für Reparaturen und Instandhaltung des Gebäudes. Sind NICHT umlagefähig! Das ist Vermietersache. Werden manchmal versteckt unter 'Hausmeisterkosten' oder 'sonstige Kosten' umgelegt — ein häufiger Abrechnungsfehler.",
            kategorie: .kostenarten
        ),

        // ═══════════════════════════════════════
        // VERTEILUNG & BERECHNUNG
        // ═══════════════════════════════════════

        "verteilerschluessel": GlossarEintrag(
            id: "verteilerschluessel",
            begriff: "Verteilerschlüssel / Umlageschlüssel",
            erklaerung: "Bestimmt, wie die Gesamtkosten auf die Mieter verteilt werden. Übliche Schlüssel: nach Wohnfläche (m²), nach Verbrauch (Zähler), nach Personenzahl, nach Wohneinheiten, oder nach Miteigentumsanteilen. Der Schlüssel muss im Mietvertrag stehen oder der Vermieter wählt einen 'billigen' Schlüssel.",
            kategorie: .verteilung
        ),
        "wohnflaeche": GlossarEintrag(
            id: "wohnflaeche",
            begriff: "Wohnfläche (m²)",
            erklaerung: "Die anrechenbare Fläche deiner Wohnung. Wird nach der Wohnflächenverordnung (WoFlV) berechnet. Balkone zählen zu 25–50%, Dachschrägen unter 1m Höhe gar nicht, 1–2m zu 50%. Weicht die tatsächliche Fläche um mehr als 10% ab, kannst du widersprechen.",
            kategorie: .verteilung
        ),
        "personenzahl": GlossarEintrag(
            id: "personenzahl",
            begriff: "Personenzahl / Personenschlüssel",
            erklaerung: "Verteilung der Kosten nach Anzahl der im Haushalt lebenden Personen. Wird oft für Wasser und Müll verwendet. Problematisch: Die Personenzahl ändert sich (Geburt, Auszug) — der Vermieter muss das zeitanteilig berücksichtigen.",
            kategorie: .verteilung
        ),
        "miteigentumsanteil": GlossarEintrag(
            id: "miteigentumsanteil",
            begriff: "Miteigentumsanteil (MEA)",
            erklaerung: "Anteil eines Eigentümers am Gemeinschaftseigentum einer WEG (Wohnungseigentümergemeinschaft). Wird in der Teilungserklärung festgelegt und oft als Verteilerschlüssel verwendet. Als Mieter siehst du das manchmal in der Abrechnung — es ist ein Verteilerschlüssel wie Wohnfläche.",
            kategorie: .verteilung
        ),
        "heizkv": GlossarEintrag(
            id: "heizkv",
            begriff: "Heizkostenverordnung (HeizKV)",
            erklaerung: "Regelt wie Heiz- und Warmwasserkosten verteilt werden müssen. Mindestens 50% nach Verbrauch, maximal 70%. Der Rest nach Wohnfläche. Der Vermieter kann den Anteil wählen, muss aber die Grenzen einhalten. Verstößt er dagegen, kannst du 15% kürzen.",
            kategorie: .verteilung
        ),
        "verbrauchsabrechnung": GlossarEintrag(
            id: "verbrauchsabrechnung",
            begriff: "Verbrauchsabhängige Abrechnung",
            erklaerung: "Kosten werden nach individuellem Verbrauch verteilt (Zählerstand). Gilt verpflichtend für Heizung und Warmwasser. Für Kaltwasser freiwillig, aber immer häufiger. Voraussetzung: geeichte Zähler in jeder Wohnung.",
            kategorie: .verteilung
        ),
        "vorabzug": GlossarEintrag(
            id: "vorabzug",
            begriff: "Vorabzug / Vorwegabzug",
            erklaerung: "Kosten die VOR der Verteilung auf die Mieter von den Gesamtkosten abgezogen werden. Typisch: Kosten für Gewerbeeinheiten (die mehr Müll, Wasser etc. verbrauchen) werden vorweg abgezogen, damit Wohnungsmieter nicht draufzahlen.",
            kategorie: .verteilung
        ),
        "nutzerwechsel": GlossarEintrag(
            id: "nutzerwechsel",
            begriff: "Nutzerwechsel / Mieterwechsel",
            erklaerung: "Wenn du mitten im Abrechnungszeitraum ein- oder ausgezogen bist. Die Kosten müssen zeitanteilig (tagesgenau) aufgeteilt werden. Verbrauchsabhängige Kosten werden nach Zwischenablesung oder Gradtagszahlen aufgeteilt.",
            kategorie: .verteilung
        ),
        "gradtagszahl": GlossarEintrag(
            id: "gradtagszahl",
            begriff: "Gradtagszahlen",
            erklaerung: "Mathematisches Verfahren zur Aufteilung von Heizkosten bei Mieterwechsel, wenn keine Zwischenablesung möglich ist. Berücksichtigt dass im Winter mehr geheizt wird als im Sommer. Januar = 17%, Juli = 2% der Jahresheizkosten.",
            kategorie: .verteilung
        ),

        // ═══════════════════════════════════════
        // RECHTLICHES
        // ═══════════════════════════════════════

        "betrkv": GlossarEintrag(
            id: "betrkv",
            begriff: "Betriebskostenverordnung (BetrKV)",
            erklaerung: "Bundesverordnung die regelt, welche Nebenkosten der Vermieter auf Mieter umlegen darf. Enthält 17 Kostenarten (§ 2 Nr. 1–17). Kosten die nicht in der BetrKV stehen oder nicht im Mietvertrag vereinbart sind, dürfen nicht umgelegt werden.",
            kategorie: .recht
        ),
        "belegeinsicht": GlossarEintrag(
            id: "belegeinsicht",
            begriff: "Belegeinsicht / Belegprüfung",
            erklaerung: "Dein Recht als Mieter, die Originalrechnungen und Belege einzusehen, auf denen die Abrechnung basiert (§ 259 BGB). Der Vermieter muss dir Einsicht gewähren — meistens vor Ort in seinem Büro. Du darfst Kopien anfertigen. Bei Verweigerung musst du nicht zahlen.",
            kategorie: .recht
        ),
        "widerspruchsfrist": GlossarEintrag(
            id: "widerspruchsfrist",
            begriff: "Widerspruchsfrist",
            erklaerung: "Du hast 12 Monate nach Zugang der Abrechnung Zeit, Einwendungen zu erheben (§ 556 Abs. 3 S. 5 BGB). Danach verfällt dein Recht — außer du hast die Verspätung nicht zu vertreten. Wir empfehlen: innerhalb von 14 Tagen reagieren.",
            kategorie: .recht
        ),
        "abrechnungsfrist": GlossarEintrag(
            id: "abrechnungsfrist",
            begriff: "Abrechnungsfrist",
            erklaerung: "Der Vermieter muss die Abrechnung innerhalb von 12 Monaten nach Ende des Abrechnungszeitraums zustellen (§ 556 Abs. 3 S. 2 BGB). Kommt die Abrechnung zu spät, musst du Nachzahlungen NICHT leisten — Guthaben steht dir trotzdem zu.",
            kategorie: .recht
        ),
        "umlagefaehig": GlossarEintrag(
            id: "umlagefaehig",
            begriff: "Umlagefähige Kosten",
            erklaerung: "Kosten die der Vermieter auf Mieter umlegen darf — definiert in der BetrKV. NICHT umlagefähig sind: Verwaltungskosten, Reparaturen, Instandhaltung, Bankgebühren, Mietausfallversicherung. Ein häufiger Fehler in Abrechnungen.",
            kategorie: .recht
        ),
        "wirtschaftlichkeit": GlossarEintrag(
            id: "wirtschaftlichkeit",
            begriff: "Wirtschaftlichkeitsgebot",
            erklaerung: "Der Vermieter muss bei Betriebskosten wirtschaftlich handeln (§ 556 Abs. 3 BGB). Er darf nicht den teuersten Anbieter wählen wenn günstigere verfügbar sind. Sind Kosten unverhältnismäßig hoch, kannst du den Verstoß gegen das Wirtschaftlichkeitsgebot rügen.",
            kategorie: .recht
        ),
        "rdg": GlossarEintrag(
            id: "rdg",
            begriff: "Rechtsdienstleistungsgesetz (RDG)",
            erklaerung: "Regelt wer Rechtsberatung anbieten darf. Diese App bietet KEINE Rechtsberatung im Sinne des RDG. Die Analyse-Ergebnisse sind automatisch generiert. Für verbindliche rechtliche Einschätzungen wende dich an deinen Mieterverein oder einen Fachanwalt.",
            kategorie: .recht
        ),

        // ═══════════════════════════════════════
        // ABRECHNUNG
        // ═══════════════════════════════════════

        "vorauszahlung": GlossarEintrag(
            id: "vorauszahlung",
            begriff: "Vorauszahlung",
            erklaerung: "Monatlicher Betrag den du zusammen mit der Kaltmiete für Nebenkosten zahlst. Am Jahresende wird abgerechnet. Hast du mehr gezahlt als verbraucht, bekommst du ein Guthaben zurück. Hast du weniger gezahlt, kommt eine Nachzahlung.",
            kategorie: .abrechnung
        ),
        "pauschale": GlossarEintrag(
            id: "pauschale",
            begriff: "Betriebskostenpauschale",
            erklaerung: "Ein fester monatlicher Betrag für Nebenkosten, der NICHT abgerechnet wird. Bei einer Pauschale gibt es keine Nachzahlung und kein Guthaben. Der Vermieter darf die Pauschale nur erhöhen wenn die tatsächlichen Kosten gestiegen sind. Wird oft mit Vorauszahlung verwechselt.",
            kategorie: .abrechnung
        ),
        "nachzahlung": GlossarEintrag(
            id: "nachzahlung",
            begriff: "Nachzahlung",
            erklaerung: "Wenn deine Vorauszahlungen niedriger waren als die tatsächlichen Kosten. Du musst die Differenz nachzahlen — normalerweise mit der nächsten Miete. Tipp: Prüfe ob der Vermieter gleichzeitig die Vorauszahlung anpasst.",
            kategorie: .abrechnung
        ),
        "guthaben": GlossarEintrag(
            id: "guthaben",
            begriff: "Guthaben",
            erklaerung: "Wenn deine Vorauszahlungen höher waren als die tatsächlichen Kosten. Der Vermieter muss das Guthaben zeitnah auszahlen oder mit der nächsten Miete verrechnen. Viele Vermieter passen auch die Vorauszahlung nach unten an.",
            kategorie: .abrechnung
        ),
        "abrechnungszeitraum": GlossarEintrag(
            id: "abrechnungszeitraum",
            begriff: "Abrechnungszeitraum",
            erklaerung: "Der Zeitraum über den abgerechnet wird — immer genau 12 Monate. Muss nicht dem Kalenderjahr entsprechen. Ein Abrechnungszeitraum von mehr als 12 Monaten ist unzulässig und macht die gesamte Abrechnung anfechtbar.",
            kategorie: .abrechnung
        ),
        "gesamtkosten": GlossarEintrag(
            id: "gesamtkosten",
            begriff: "Gesamtkosten",
            erklaerung: "Die Summe aller Kosten einer Kostenart für das gesamte Gebäude. Davon wird dein Anteil berechnet (über den Verteilerschlüssel). Du hast das Recht, die Gesamtkosten zu erfahren und die Belege einzusehen.",
            kategorie: .abrechnung
        ),
        "mieteranteil": GlossarEintrag(
            id: "mieteranteil",
            begriff: "Mieteranteil / Dein Anteil",
            erklaerung: "Dein Anteil an den Gesamtkosten, berechnet über den Verteilerschlüssel. Beispiel: Gesamtkosten Wasser 4.000 €, deine Wohnfläche 80 m² von 400 m² gesamt → dein Anteil = 800 € (20%).",
            kategorie: .abrechnung
        ),
        "haushaltsnahe": GlossarEintrag(
            id: "haushaltsnahe",
            begriff: "Haushaltsnahe Dienstleistungen",
            erklaerung: "Tätigkeiten die normalerweise ein Haushaltsmitglied erledigen könnte: Treppenhausreinigung, Gartenpflege, Winterdienst, Hausmeister (Reinigungsanteil), Schädlingsbekämpfung. 20% absetzbar, maximal 4.000 € Steuerermäßigung pro Jahr (§ 35a Abs. 2 EStG). Nur der Arbeitsanteil zählt, nicht Material.",
            kategorie: .abrechnung
        ),
        "handwerkerleistungen": GlossarEintrag(
            id: "handwerkerleistungen",
            begriff: "Handwerkerleistungen (§ 35a Abs. 3 EStG)",
            erklaerung: "Handwerkerarbeiten im/am Gebäude: Wartung Heizung, Aufzugswartung, Schornsteinfeger, Reparatur Gemeinschaftsanlagen. 20% absetzbar, maximal 1.200 € Steuerermäßigung pro Jahr. Nur Arbeits- und Fahrtkosten, KEIN Material. Der Vermieter muss diese Kosten in der Abrechnung oder einer separaten Bescheinigung ausweisen.",
            kategorie: .abrechnung
        ),
        "bescheinigung35a": GlossarEintrag(
            id: "bescheinigung35a",
            begriff: "Steuerbescheinigung (§ 35a)",
            erklaerung: "Der Vermieter muss dir auf Verlangen eine Bescheinigung ausstellen, die den auf deine Wohnung entfallenden Anteil an haushaltsnahen Dienstleistungen und Handwerkerleistungen aufschlüsselt. Viele Vermieter fügen das der Abrechnung bei — wenn nicht, schriftlich anfordern.",
            kategorie: .abrechnung
        ),

        // ═══════════════════════════════════════
        // HAUSVERWALTUNG
        // ═══════════════════════════════════════

        "wirtschaftseinheit": GlossarEintrag(
            id: "wirtschaftseinheit",
            begriff: "Wirtschaftseinheit",
            erklaerung: "Zusammenfassung mehrerer Gebäude zu einer Abrechnungseinheit. Hausverwaltungen nutzen das oft um Kosten über mehrere Häuser zu verteilen. Kann für dich günstiger oder teurer sein. Du kannst verlangen, dass nur dein Gebäude abgerechnet wird, wenn die Wirtschaftseinheit nicht im Mietvertrag steht.",
            kategorie: .verwaltung
        ),
        "weg": GlossarEintrag(
            id: "weg",
            begriff: "WEG / Eigentümergemeinschaft",
            erklaerung: "Wohnungseigentümergemeinschaft — wenn das Haus mehrere Eigentümer hat. Die WEG beschließt in Eigentümerversammlungen über Kosten und Verteilung. Als Mieter bekommst du die WEG-Abrechnung nicht direkt — dein Vermieter rechnet auf Basis der WEG-Abrechnung mit dir ab.",
            kategorie: .verwaltung
        ),
        "hausgeld": GlossarEintrag(
            id: "hausgeld",
            begriff: "Hausgeld / Wohngeld",
            erklaerung: "Monatliche Zahlung eines Wohnungseigentümers an die WEG. Enthält umlagefähige Betriebskosten PLUS nicht-umlagefähige Kosten (Verwaltung, Instandhaltungsrücklage). Nur der umlagefähige Anteil darf an Mieter weitergegeben werden.",
            kategorie: .verwaltung
        ),
        "instandhaltungsruecklage": GlossarEintrag(
            id: "instandhaltungsruecklage",
            begriff: "Instandhaltungsrücklage",
            erklaerung: "Geld das die WEG für zukünftige Reparaturen und Sanierungen anspart. Ist NICHT umlagefähig! Wenn sie in deiner Nebenkostenabrechnung auftaucht, ist das ein Fehler. Wird manchmal als 'Rücklage' oder 'Erhaltungsrücklage' bezeichnet.",
            kategorie: .verwaltung
        ),
        "verwaltergebuehr": GlossarEintrag(
            id: "verwaltergebuehr",
            begriff: "Verwaltergebühr / Verwaltungskosten",
            erklaerung: "Gebühr für die Hausverwaltung. NICHT umlagefähig auf Mieter! Manche Hausverwaltungen verstecken die Gebühr in anderen Positionen oder listen sie als 'sonstige Kosten' auf — ein häufiger Fehler.",
            kategorie: .verwaltung
        ),
        "sonderumlage": GlossarEintrag(
            id: "sonderumlage",
            begriff: "Sonderumlage",
            erklaerung: "Einmalige Zahlung der WEG-Eigentümer für größere Maßnahmen (Dachsanierung, Fassade). NICHT umlagefähig auf Mieter! Wenn sie in deiner Abrechnung auftaucht, sofort widersprechen.",
            kategorie: .verwaltung
        ),
        "abrechnungsspitze": GlossarEintrag(
            id: "abrechnungsspitze",
            begriff: "Abrechnungsspitze",
            erklaerung: "Differenz zwischen den Kosten die der Vermieter an die WEG zahlt und den Kosten die er auf dich umlegt. Entsteht durch nicht-umlagefähige Anteile (Verwaltung, Rücklage). Der Vermieter muss diese Spitze korrekt herausrechnen.",
            kategorie: .verwaltung
        ),
        "leerstandskosten": GlossarEintrag(
            id: "leerstandskosten",
            begriff: "Leerstandskosten",
            erklaerung: "Kosten für leerstehende Wohnungen. Der Vermieter trägt diese selbst — sie dürfen NICHT auf die übrigen Mieter verteilt werden. Ein typischer Fehler: Der Gesamtflächenschlüssel wird nicht um die Leerstandsfläche bereinigt.",
            kategorie: .verwaltung
        ),
        "hauswart": GlossarEintrag(
            id: "hauswart",
            begriff: "Hauswart / Facility Management",
            erklaerung: "Professioneller Hausmeisterdienst, oft über eine Facility-Management-Firma. Umlagefähig sind nur die Betriebskosten-Anteile (Reinigung, Gartenpflege, Winterdienst). Verwaltungs- und Reparaturanteile müssen herausgerechnet werden.",
            kategorie: .verwaltung
        ),
        "messdienstleister": GlossarEintrag(
            id: "messdienstleister",
            begriff: "Messdienstleister / Ablesung",
            erklaerung: "Firma die Heizungs- und Wasserzähler abliest und die Heizkostenabrechnung erstellt (z.B. Techem, ista, Brunata). Die Kosten für Ablesung und Abrechnung sind umlagefähig. Die Miete der Messgeräte (Heizkostenverteiler, Wasserzähler) ebenfalls.",
            kategorie: .verwaltung
        ),
        "eigenleistung": GlossarEintrag(
            id: "eigenleistung",
            begriff: "Eigenleistung des Vermieters",
            erklaerung: "Wenn der Vermieter Arbeiten selbst erledigt (z.B. Gartenpflege, Hausmeister). Er darf dafür einen angemessenen Betrag ansetzen — aber nur für die reine Arbeitsleistung, nicht mehr als eine Fachfirma kosten würde.",
            kategorie: .verwaltung
        ),

        // ═══════════════════════════════════════
        // GESETZE & NORMEN
        // ═══════════════════════════════════════

        "bgb535": GlossarEintrag(
            id: "bgb535",
            begriff: "§ 535 BGB — Mietvertrag",
            erklaerung: "Grundnorm des Mietrechts. Regelt die Pflichten von Vermieter (Wohnung überlassen und instand halten) und Mieter (Miete zahlen). Nebenkosten müssen im Mietvertrag vereinbart sein, damit sie umgelegt werden dürfen.",
            kategorie: .gesetze
        ),
        "bgb556": GlossarEintrag(
            id: "bgb556",
            begriff: "§ 556 BGB — Betriebskosten",
            erklaerung: "Zentralnorm für Nebenkosten. Absatz 1: Umlage muss vereinbart sein. Absatz 2: Abrechnung bei Vorauszahlungen. Absatz 3: Abrechnungsfrist 12 Monate, Einwendungsfrist 12 Monate. Absatz 4: Zu Lasten des Mieters abweichende Vereinbarungen sind unwirksam.",
            kategorie: .gesetze
        ),
        "bgb556a": GlossarEintrag(
            id: "bgb556a",
            begriff: "§ 556a BGB — Abrechnungsmaßstab",
            erklaerung: "Wenn im Mietvertrag kein Verteilerschlüssel vereinbart ist, wird nach Wohnfläche verteilt. Verbrauchsabhängige Kosten (Heizung, Wasser) dürfen nach Verbrauch abgerechnet werden, auch wenn der Mietvertrag Wohnfläche vorsieht.",
            kategorie: .gesetze
        ),
        "bgb259": GlossarEintrag(
            id: "bgb259",
            begriff: "§ 259 BGB — Belegeinsicht",
            erklaerung: "Gibt dem Mieter das Recht, die Belege und Rechnungen einzusehen, die der Abrechnung zugrunde liegen. Der Vermieter muss Einsicht gewähren, Kopien erlauben. Verweigert er die Einsicht, musst du die Nachzahlung nicht leisten bis du die Belege gesehen hast.",
            kategorie: .gesetze
        ),
        "bgb273": GlossarEintrag(
            id: "bgb273",
            begriff: "§ 273 BGB — Zurückbehaltungsrecht",
            erklaerung: "Du darfst die Nachzahlung teilweise zurückbehalten, wenn du berechtigte Einwendungen gegen die Abrechnung hast oder der Vermieter dir keine Belegeinsicht gewährt. Wichtig: Nicht die komplette Zahlung verweigern, nur den strittigen Teil.",
            kategorie: .gesetze
        ),
        "bgb195": GlossarEintrag(
            id: "bgb195",
            begriff: "§ 195 BGB — Verjährung (3 Jahre)",
            erklaerung: "Nachzahlungsansprüche des Vermieters und Guthabenansprüche des Mieters verjähren nach 3 Jahren (ab Jahresende der Abrechnung). Beispiel: Abrechnung kommt im Juni 2025 → Verjährung am 31.12.2028.",
            kategorie: .gesetze
        ),
        "betrkv_gesetz": GlossarEintrag(
            id: "betrkv_gesetz",
            begriff: "Betriebskostenverordnung (BetrKV)",
            erklaerung: "Bundesverordnung vom 25.11.2003. Definiert in § 1 was Betriebskosten sind und listet in § 2 Nr. 1–17 die 17 umlagefähigen Kostenarten abschließend auf. Kosten die nicht in der BetrKV stehen, dürfen NICHT umgelegt werden (es sei denn als 'sonstige' im Mietvertrag benannt).",
            kategorie: .gesetze
        ),
        "heizkv_gesetz": GlossarEintrag(
            id: "heizkv_gesetz",
            begriff: "Heizkostenverordnung (HeizKV)",
            erklaerung: "Regelt die verbrauchsabhängige Abrechnung von Heiz- und Warmwasserkosten. § 6: Mindestens 50%, maximal 70% nach Verbrauch. § 7: Aufteilung Heizung/Warmwasser. § 9a: Kürzungsrecht von 15% bei Verstoß. § 12: Pflicht zur Installation fernablesbarer Zähler seit 2027.",
            kategorie: .gesetze
        ),
        "heizkv9a": GlossarEintrag(
            id: "heizkv9a",
            begriff: "§ 9a HeizKV — Kürzungsrecht 15%",
            erklaerung: "Wenn der Vermieter Heizkosten nicht verbrauchsabhängig abrechnet obwohl er muss, darfst du deinen Anteil um 15% kürzen. Auch wenn keine geeichten Zähler vorhanden sind oder die Ablesung nicht erfolgt ist. Ein starkes Druckmittel.",
            kategorie: .gesetze
        ),
        "woflv": GlossarEintrag(
            id: "woflv",
            begriff: "Wohnflächenverordnung (WoFlV)",
            erklaerung: "Regelt wie die Wohnfläche korrekt berechnet wird. Balkone/Terrassen: 25–50%. Dachschrägen unter 1m: 0%, zwischen 1–2m: 50%. Kellerräume, Garagen, Heizungsräume zählen NICHT. Weicht die reale Fläche um mehr als 10% von der im Mietvertrag ab, kannst du die Abrechnung anfechten.",
            kategorie: .gesetze
        ),
        "co2kostenauftg": GlossarEintrag(
            id: "co2kostenauftg",
            begriff: "CO\u{2082}-Kostenaufteilungsgesetz (CO2KostAufG)",
            erklaerung: "Seit 01.01.2023 müssen Vermieter einen Teil der CO\u{2082}-Kosten (Brennstoff) selbst tragen. Die Aufteilung hängt vom energetischen Zustand des Gebäudes ab (Stufenmodell). Schlechte Energiebilanz = mehr Vermieteranteil (bis zu 95%). Muss in der Heizkostenabrechnung ausgewiesen werden.",
            kategorie: .gesetze
        ),
        "eeg": GlossarEintrag(
            id: "eeg",
            begriff: "EEG-Umlage / Energierecht",
            erklaerung: "Die EEG-Umlage (Erneuerbare-Energien-Gesetz) wurde zum 01.07.2022 auf null gesetzt und zum 01.01.2023 abgeschafft. Sie darf in Abrechnungen ab 2023 NICHT mehr auftauchen. Falls doch, ist das ein Fehler.",
            kategorie: .gesetze
        ),
        "bgb560": GlossarEintrag(
            id: "bgb560",
            begriff: "§ 560 BGB — Veränderung der Betriebskosten",
            erklaerung: "Regelt die Anpassung von Vorauszahlungen und Pauschalen. Nach einer Abrechnung darf der Vermieter die Vorauszahlungen auf eine angemessene Höhe anpassen. Bei Pauschalen: Erhöhung nur bei gestiegenen Kosten, mit Erklärung.",
            kategorie: .gesetze
        ),
        "bgb543": GlossarEintrag(
            id: "bgb543",
            begriff: "§ 543 BGB — Außerordentliche Kündigung",
            erklaerung: "Relevant bei Nebenkosten: Wenn der Mieter mit Nachzahlungen in Verzug gerät (2 Monate Miete Rückstand), kann der Vermieter fristlos kündigen. Umgekehrt: Überhöhte Nebenkostenforderungen können KEIN Kündigungsgrund sein, wenn du dagegen Einwendungen erhebst.",
            kategorie: .gesetze
        ),
        "bgb242": GlossarEintrag(
            id: "bgb242",
            begriff: "§ 242 BGB — Treu und Glauben",
            erklaerung: "Generalnorm die auch im Nebenkostenrecht gilt. Der Vermieter muss die Abrechnung verständlich und nachvollziehbar gestalten. Eine Abrechnung die so undurchsichtig ist, dass ein durchschnittlicher Mieter sie nicht prüfen kann, kann unter § 242 anfechtbar sein.",
            kategorie: .gesetze
        ),
        "bimschv": GlossarEintrag(
            id: "bimschv",
            begriff: "Bundes-Immissionsschutzverordnung (BImSchV)",
            erklaerung: "Die 1. BImSchV (Kleinfeuerungsanlagen) regelt Emissionsgrenzwerte für Heizungen. Die Kosten für die vorgeschriebene Emissionsmessung durch den Schornsteinfeger sind umlagefähig als Teil der Schornsteinfegerkosten.",
            kategorie: .gesetze
        ),
        "trinkwv": GlossarEintrag(
            id: "trinkwv",
            begriff: "Trinkwasserverordnung (TrinkwV)",
            erklaerung: "Schreibt regelmäßige Legionellenprüfungen in Mehrfamilienhäusern vor (ab 3 Wohnungen mit zentraler Warmwasserbereitung). Die Prüfkosten sind als Betriebskosten umlagefähig. Wird die Prüfung nicht durchgeführt, ist das ein Verstoß des Vermieters.",
            kategorie: .gesetze
        ),
        "dsgvo_nk": GlossarEintrag(
            id: "dsgvo_nk",
            begriff: "DSGVO / Datenschutz bei Abrechnungen",
            erklaerung: "Die Nebenkostenabrechnung enthält personenbezogene Daten (Name, Adresse, Verbrauch). Der Vermieter muss diese gemäß DSGVO schützen. Verbrauchsdaten einzelner Mieter dürfen nicht für andere Mieter sichtbar sein. Relevant auch für diese App: Deine Daten werden anonymisiert verarbeitet.",
            kategorie: .gesetze
        ),
        "gwb": GlossarEintrag(
            id: "gwb",
            begriff: "Grundsteuerreform 2025",
            erklaerung: "Seit 01.01.2025 gilt die neue Grundsteuer auf Basis aktualisierter Grundstückswerte. Die Grundsteuer in Nebenkostenabrechnungen ab 2025 kann deutlich höher oder niedriger sein als vorher. Vergleiche mit dem Vorjahr sind daher nur eingeschränkt möglich.",
            kategorie: .gesetze
        ),
        "wegg": GlossarEintrag(
            id: "wegg",
            begriff: "Wohnungseigentumsgesetz (WEG)",
            erklaerung: "Regelt das Zusammenleben in Eigentümergemeinschaften. Für Mieter relevant: Die WEG-Abrechnung ist die Basis für deine Nebenkostenabrechnung. Der Vermieter muss die nicht-umlagefähigen WEG-Kosten (Verwaltung, Rücklage) herausrechnen bevor er auf dich umlegt.",
            kategorie: .gesetze
        ),
        "mietpreisbremse": GlossarEintrag(
            id: "mietpreisbremse",
            begriff: "Mietpreisbremse (§§ 556d–556g BGB)",
            erklaerung: "Gilt in angespannten Wohnungsmärkten: Die Miete bei Neuvermietung darf max. 10% über der ortsüblichen Vergleichsmiete liegen. Betrifft nicht direkt die Nebenkosten, aber: Wenn die Kaltmiete durch die Bremse gedeckelt ist, versuchen manche Vermieter über erhöhte Nebenkosten Ausgleich zu schaffen.",
            kategorie: .gesetze
        ),
        "enev_geg": GlossarEintrag(
            id: "enev_geg",
            begriff: "Gebäudeenergiegesetz (GEG)",
            erklaerung: "Seit 01.01.2024 ersetzt das GEG die alte Energieeinsparverordnung (EnEV). Relevant für Nebenkosten: Die Energieeffizienz des Gebäudes beeinflusst die CO\u{2082}-Kostenaufteilung und kann bei der Plausibilitätsprüfung von Heizkosten herangezogen werden.",
            kategorie: .gesetze
        ),
        "estg35a": GlossarEintrag(
            id: "estg35a",
            begriff: "§ 35a EStG — Steuerermäßigung",
            erklaerung: "Du kannst 20% der Kosten für haushaltsnahe Dienstleistungen und Handwerkerleistungen von der Steuer absetzen. Der Vermieter MUSS dir eine Bescheinigung ausstellen, welche Nebenkosten unter § 35a fallen. Fehlt die Bescheinigung, fordere sie ein — das ist dein Recht.",
            kategorie: .gesetze
        ),

        // ═══════════════════════════════════════
        // KOSTENARTEN — Ergänzungen (v4-18c)
        // ═══════════════════════════════════════

        "niederschlagswasser": GlossarEintrag(
            id: "niederschlagswasser",
            begriff: "Niederschlagswassergebühr",
            erklaerung: "Gebühr für die Ableitung von Regenwasser in die Kanalisation. Wird nach versiegelter Fläche berechnet (Dach, Parkplatz), nicht nach Wohnfläche. Umlagefähig als Teil der Entwässerungskosten (BetrKV § 2 Nr. 3). Viele Kommunen erheben sie separat vom Schmutzwasser.",
            kategorie: .kostenarten
        ),
        "heiznebenkosten": GlossarEintrag(
            id: "heiznebenkosten",
            begriff: "Heiznebenkosten",
            erklaerung: "Alle Kosten rund um die Heizung AUSSER dem Brennstoff: Wartung, Schornsteinfeger, Betriebsstrom, Emissionsmessung, Immissionsmessung, Tankeinigung, Bedienung. Werden wie Brennstoff auf Verbrauch und Fläche aufgeteilt (HeizKV).",
            kategorie: .kostenarten
        ),
        "betriebsstrom_heizung": GlossarEintrag(
            id: "betriebsstrom_heizung",
            begriff: "Betriebsstrom Heizung",
            erklaerung: "Strom den die Heizanlage verbraucht (Umwälzpumpe, Brenner, Regelung). Wird als Teil der Heizkosten umgelegt. Wenn kein separater Zähler vorhanden: Schätzung mit 3–5% der Brennstoffkosten ist üblich und zulässig.",
            kategorie: .kostenarten
        ),
        "rauchmelder": GlossarEintrag(
            id: "rauchmelder",
            begriff: "Rauchmelder / Rauchwarnmelder",
            erklaerung: "Wartungskosten für Rauchmelder (jährliche Funktionsprüfung) sind umlagefähig als 'sonstige Betriebskosten' — aber NUR wenn im Mietvertrag vereinbart. Die Anschaffung und Installation sind NICHT umlagefähig. Mietkosten für Rauchmelder: umstritten, viele Gerichte sagen ja.",
            kategorie: .kostenarten
        ),
        "ungezieferbekaempfung": GlossarEintrag(
            id: "ungezieferbekaempfung",
            begriff: "Schädlingsbekämpfung / Ungeziefer",
            erklaerung: "Regelmäßige, vorbeugende Schädlingsbekämpfung (z.B. Rattenköder im Keller) ist umlagefähig als 'sonstige Betriebskosten' wenn im Mietvertrag genannt. Einmalige Bekämpfung bei akutem Befall ist KEINE Betriebskosten — das ist Instandhaltung.",
            kategorie: .kostenarten
        ),
        "dachrinnenreinigung": GlossarEintrag(
            id: "dachrinnenreinigung",
            begriff: "Dachrinnenreinigung",
            erklaerung: "Regelmäßige Reinigung der Dachrinnen und Fallrohre. Umlagefähig als 'sonstige Betriebskosten' (BetrKV § 2 Nr. 17) wenn im Mietvertrag vereinbart. Ohne Vereinbarung: nicht umlagefähig. Bei verstopfter Rinne wegen mangelnder Reinigung: Vermieter haftet.",
            kategorie: .kostenarten
        ),
        "spielplatzwartung": GlossarEintrag(
            id: "spielplatzwartung",
            begriff: "Spielplatzwartung / -pflege",
            erklaerung: "Kosten für Pflege, Reinigung und TÜV-Prüfung des Spielplatzes. Umlagefähig als 'sonstige Betriebskosten' wenn im Mietvertrag genannt. Reparaturen und Neuanschaffung von Spielgeräten sind NICHT umlagefähig.",
            kategorie: .kostenarten
        ),
        "feuerloescher": GlossarEintrag(
            id: "feuerloescher",
            begriff: "Feuerlöscher-Wartung",
            erklaerung: "Die regelmäßige Prüfung und Wartung von Feuerlöschern ist umlagefähig als 'sonstige Betriebskosten' wenn im Mietvertrag vereinbart. Neuanschaffung und Austausch sind NICHT umlagefähig — das ist Instandhaltung.",
            kategorie: .kostenarten
        ),

        // ═══════════════════════════════════════
        // ABRECHNUNG — Ergänzungen (v4-18c)
        // ═══════════════════════════════════════

        "kaltmiete": GlossarEintrag(
            id: "kaltmiete",
            begriff: "Kaltmiete / Nettomiete",
            erklaerung: "Die reine Miete ohne Nebenkosten. Wenn du 800 € Kaltmiete + 250 € Nebenkosten-Vorauszahlung zahlst, ist die Kaltmiete 800 €. Die Kaltmiete ist die Basis für Mieterhöhungen und Mietpreisbremse. Nicht verwechseln mit Warmmiete.",
            kategorie: .abrechnung
        ),
        "warmmiete": GlossarEintrag(
            id: "warmmiete",
            begriff: "Warmmiete / Bruttomiete",
            erklaerung: "Kaltmiete PLUS alle Nebenkosten-Vorauszahlungen. Wenn du monatlich 1.050 € überweist (800 € Kalt + 250 € NK), ist 1.050 € deine Warmmiete. In Wohnungsanzeigen ist manchmal 'Warmmiete' angegeben — prüfe immer was enthalten ist.",
            kategorie: .abrechnung
        ),
        "betriebskostenspiegel": GlossarEintrag(
            id: "betriebskostenspiegel",
            begriff: "Betriebskostenspiegel",
            erklaerung: "Jährliche Auswertung des Deutschen Mieterbundes über durchschnittliche Nebenkosten in Deutschland. Aktuell ca. 2,28 €/m²/Monat. Damit kannst du prüfen ob deine Kosten im Rahmen liegen. Starke Abweichungen nach oben sind ein Warnsignal. Kostenlos online einsehbar.",
            kategorie: .abrechnung
        ),
        "heizspiegel": GlossarEintrag(
            id: "heizspiegel",
            begriff: "Heizspiegel / Heizkosten-Check",
            erklaerung: "Bundesweiter Vergleichswert für Heizkosten, herausgegeben von co2online. Zeigt ob dein Heizenergieverbrauch niedrig, mittel, hoch oder zu hoch ist. Getrennt nach Gebäudetyp, Energieträger und Region. Gutes Werkzeug um überhöhte Heizkosten zu erkennen.",
            kategorie: .abrechnung
        ),
        "einzelabrechnung": GlossarEintrag(
            id: "einzelabrechnung",
            begriff: "Einzelabrechnung",
            erklaerung: "Die Abrechnung die DU als Mieter bekommst — dein persönlicher Anteil an den Gesamtkosten. Muss enthalten: Gesamtkosten je Position, Verteilerschlüssel, dein Anteil, deine Vorauszahlungen, Ergebnis (Guthaben/Nachzahlung). Fehlt eins davon, ist die Abrechnung formell fehlerhaft.",
            kategorie: .abrechnung
        ),
        "gesamtabrechnung": GlossarEintrag(
            id: "gesamtabrechnung",
            begriff: "Gesamtabrechnung",
            erklaerung: "Die Zusammenstellung aller Kosten für das gesamte Gebäude. Basis für die Einzelabrechnungen der Mieter. Du hast das Recht die Gesamtabrechnung und die Belege einzusehen. Oft identisch mit der WEG-Jahresabrechnung bei Eigentumswohnungen.",
            kategorie: .abrechnung
        ),
        "nutzungsgebuehr": GlossarEintrag(
            id: "nutzungsgebuehr",
            begriff: "Nutzungsgebühr (Genossenschaft)",
            erklaerung: "In Wohnungsgenossenschaften zahlst du keine 'Miete' sondern eine 'Nutzungsgebühr'. Rechtlich ist der Unterschied gering — die Regeln für Betriebskosten gelten genauso. Die Genossenschaft muss jährlich abrechnen wie jeder andere Vermieter.",
            kategorie: .abrechnung
        ),
        "wirtschaftsplan": GlossarEintrag(
            id: "wirtschaftsplan",
            begriff: "Wirtschaftsplan",
            erklaerung: "Jährliche Vorausschau der erwarteten Einnahmen und Ausgaben einer WEG. Basis für das monatliche Hausgeld der Eigentümer. Für Mieter indirekt relevant: Die Vorauszahlungen sollten sich am Wirtschaftsplan orientieren, nicht an veralteten Werten.",
            kategorie: .abrechnung
        ),

        // ═══════════════════════════════════════
        // HÄUFIGE FEHLER (v4-18c, neue Kategorie)
        // ═══════════════════════════════════════

        "formeller_fehler": GlossarEintrag(
            id: "formeller_fehler",
            begriff: "Formeller Fehler",
            erklaerung: "Ein Fehler in der Darstellung oder Struktur der Abrechnung — unabhängig davon ob die Zahlen stimmen. Beispiele: Abrechnungszeitraum > 12 Monate, fehlende Gesamtkosten, fehlender Verteilerschlüssel, nicht nachvollziehbare Berechnung. Ein formell fehlerhafte Abrechnung ist wie KEINE Abrechnung — du musst nicht zahlen bis der Fehler korrigiert ist.",
            kategorie: .fehlertypen
        ),
        "materieller_fehler": GlossarEintrag(
            id: "materieller_fehler",
            begriff: "Materieller / Inhaltlicher Fehler",
            erklaerung: "Ein Fehler in den Zahlen selbst: falsche Gesamtkosten, falscher Verteilerschlüssel angewendet, Rechenfehler, nicht umlagefähige Kosten enthalten. Im Gegensatz zum formellen Fehler ist die Abrechnung gültig — du musst aber nur den korrekten Betrag zahlen.",
            kategorie: .fehlertypen
        ),
        "ausschlussfrist": GlossarEintrag(
            id: "ausschlussfrist",
            begriff: "Ausschlussfrist / Abrechnungsfrist",
            erklaerung: "Der Vermieter hat 12 Monate nach Ende des Abrechnungszeitraums Zeit, die Abrechnung zuzustellen (§ 556 Abs. 3 BGB). Verpasst er die Frist: Du musst eine Nachzahlung NICHT leisten. Guthaben steht dir trotzdem zu. Die Frist ist HART — auch eine Verzögerung um einen Tag reicht.",
            kategorie: .fehlertypen
        ),
        "doppelberechnung": GlossarEintrag(
            id: "doppelberechnung",
            begriff: "Doppelberechnung / doppelte Umlage",
            erklaerung: "Ein häufiger Fehler: Kosten werden zweimal umgelegt. Beispiel: Hausmeisterkosten UND separate Gebäudereinigung, obwohl der Hausmeister die Reinigung erledigt. Oder: Gartenpflege als eigene Position UND im Hausmeister-Posten enthalten.",
            kategorie: .fehlertypen
        ),
        "falsche_flaeche": GlossarEintrag(
            id: "falsche_flaeche",
            begriff: "Falsche Wohnfläche",
            erklaerung: "Wenn in der Abrechnung eine andere Wohnfläche steht als im Mietvertrag oder als tatsächlich vorhanden. Bei Abweichung > 10%: Die Abrechnung MUSS mit der korrekten Fläche neu berechnet werden. Betrifft alle Positionen die nach Wohnfläche verteilt werden.",
            kategorie: .fehlertypen
        ),
        "nicht_umlagefaehig": GlossarEintrag(
            id: "nicht_umlagefaehig",
            begriff: "Nicht umlagefähige Kosten enthalten",
            erklaerung: "Der häufigste Fehler überhaupt. Kosten die NICHT auf Mieter umgelegt werden dürfen: Verwaltungskosten, Instandhaltungsrücklage, Reparaturen, Bankgebühren, Mietausfallversicherung, Rechtsschutz des Vermieters, Leerstandskosten. Prüfe jede Position ob sie in der BetrKV steht.",
            kategorie: .fehlertypen
        ),
        "falscher_schluessel": GlossarEintrag(
            id: "falscher_schluessel",
            begriff: "Falscher Verteilerschlüssel",
            erklaerung: "Wenn ein anderer Verteilerschlüssel angewendet wird als im Mietvertrag vereinbart — z.B. nach Wohneinheiten statt nach Wohnfläche. Oder: Heizkosten werden komplett nach Fläche statt mindestens 50% nach Verbrauch verteilt (Verstoß gegen HeizKV).",
            kategorie: .fehlertypen
        ),
        "fehlende_angaben": GlossarEintrag(
            id: "fehlende_angaben",
            begriff: "Fehlende Pflichtangaben",
            erklaerung: "Eine formal korrekte Abrechnung MUSS enthalten: (1) Gesamtkosten je Position, (2) Verteilerschlüssel, (3) Berechnung deines Anteils, (4) Abzug deiner Vorauszahlungen, (5) Ergebnis. Fehlt eins davon = formeller Fehler, Abrechnung unwirksam.",
            kategorie: .fehlertypen
        ),
        "kostensteigerung": GlossarEintrag(
            id: "kostensteigerung",
            begriff: "Unerklärte Kostensteigerung",
            erklaerung: "Wenn eine Kostenposition ohne erkennbaren Grund deutlich steigt (>20% zum Vorjahr), kann das auf einen Fehler oder einen Verstoß gegen das Wirtschaftlichkeitsgebot hindeuten. Du hast das Recht, die Belege einzusehen und eine Erklärung zu verlangen.",
            kategorie: .fehlertypen
        ),
        "gewerbeumlage": GlossarEintrag(
            id: "gewerbeumlage",
            begriff: "Gewerbe-Kosten auf Wohnmieter",
            erklaerung: "Wenn im Haus Gewerbeeinheiten sind (Laden, Büro, Restaurant), verbrauchen diese oft mehr Wasser, Strom, Müll. Diese Mehrkosten müssen per Vorabzug herausgerechnet werden, BEVOR die Restkosten auf Wohnmieter verteilt werden. Fehlt der Vorabzug, zahlst du zu viel.",
            kategorie: .fehlertypen
        ),

        // ═══════════════════════════════════════
        // ZÄHLER & TECHNIK (v4-18c, neue Kategorie)
        // ═══════════════════════════════════════

        "heizkostenverteiler": GlossarEintrag(
            id: "heizkostenverteiler",
            begriff: "Heizkostenverteiler (HKV)",
            erklaerung: "Kleines Gerät am Heizkörper das den Wärmeverbrauch erfasst. Misst keine kWh, sondern 'Einheiten' die proportional zum Verbrauch sind. Es gibt Verdunstungs-HKV (Röhrchen mit Flüssigkeit) und elektronische HKV. Seit 2027 müssen alle fernablesbar sein.",
            kategorie: .technik
        ),
        "waermemengenzaehler": GlossarEintrag(
            id: "waermemengenzaehler",
            begriff: "Wärmemengenzähler (WMZ)",
            erklaerung: "Misst den tatsächlichen Wärmeverbrauch in kWh — genauer als Heizkostenverteiler. Wird in die Heizungsrohre eingebaut und misst Durchfluss + Temperatur. Muss alle 6 Jahre geeicht werden. Die Mietkosten für den Zähler sind umlagefähig.",
            kategorie: .technik
        ),
        "kaltwasserzaehler": GlossarEintrag(
            id: "kaltwasserzaehler",
            begriff: "Kaltwasserzähler",
            erklaerung: "Zähler in deiner Wohnung der den Kaltwasserverbrauch in Kubikmetern (m³) misst. Eichfrist: 6 Jahre. Wenn kein Zähler vorhanden: Verteilung nach Wohnfläche oder Personenzahl. Ein nicht geeichter Zähler ist ungültig — du kannst die verbrauchsabhängige Abrechnung anfechten.",
            kategorie: .technik
        ),
        "warmwasserzaehler": GlossarEintrag(
            id: "warmwasserzaehler",
            begriff: "Warmwasserzähler",
            erklaerung: "Zähler für den Warmwasserverbrauch. Eichfrist: 5 Jahre (kürzer als Kaltwasser wegen thermischer Belastung). Die Kosten werden nach HeizKV zu 50–70% nach Verbrauch und Rest nach Fläche verteilt.",
            kategorie: .technik
        ),
        "eichfrist": GlossarEintrag(
            id: "eichfrist",
            begriff: "Eichfrist / Eichgültigkeit",
            erklaerung: "Zähler müssen regelmäßig geeicht werden: Kaltwasser alle 6 Jahre, Warmwasser alle 5 Jahre, Wärmezähler alle 5 Jahre, Heizkostenverteiler: keine Eichpflicht (aber Batterie-Laufzeit beachten). Abgelesene Werte eines abgelaufenen Zählers sind rechtlich anfechtbar.",
            kategorie: .technik
        ),
        "funkablesung": GlossarEintrag(
            id: "funkablesung",
            begriff: "Funkablesung / Fernablesung",
            erklaerung: "Moderne Zähler senden ihre Werte per Funk — der Ableser muss nicht mehr in die Wohnung. Ab 2027 Pflicht für alle Zähler (§ 6 HeizKV). Vorteil: genauere Ablesung, monatliche Verbrauchsinformation. Die Umrüstungskosten trägt der Vermieter, die laufenden Kosten sind umlagefähig.",
            kategorie: .technik
        ),
        "schaetzwerte": GlossarEintrag(
            id: "schaetzwerte",
            begriff: "Schätzwerte / geschätzter Verbrauch",
            erklaerung: "Wenn ein Zähler defekt ist oder nicht abgelesen werden konnte, darf der Verbrauch geschätzt werden. Üblich: Durchschnitt der Nachbarwohnungen oder des Vorjahresverbrauchs. Eine Schätzung muss immer begründet werden. Dauerhaft geschätzte Werte kannst du anfechten.",
            kategorie: .technik
        ),
        "zwischenablesung": GlossarEintrag(
            id: "zwischenablesung",
            begriff: "Zwischenablesung",
            erklaerung: "Ablesung der Zähler bei Mieterwechsel mitten im Abrechnungszeitraum. Damit die Kosten fair zwischen altem und neuem Mieter aufgeteilt werden. Kosten der Zwischenablesung: umlagefähig. Wenn keine Zwischenablesung möglich: Aufteilung nach Gradtagszahlen oder zeitanteilig.",
            kategorie: .technik
        ),
        "verbrauchsinformation": GlossarEintrag(
            id: "verbrauchsinformation",
            begriff: "Monatliche Verbrauchsinformation",
            erklaerung: "Seit 2022 muss der Vermieter dir monatlich deinen Heizverbrauch mitteilen, wenn fernablesbare Zähler installiert sind (§ 6a HeizKV). Enthält: aktueller Verbrauch, Vergleich mit Vormonat, Vergleich mit Durchschnittsnutzer. Fehlt die Info, kannst du deine Heizkosten um 3% kürzen.",
            kategorie: .technik
        ),

        // ═══════════════════════════════════════
        // HAUSVERWALTUNG — Ergänzungen (v4-18c)
        // ═══════════════════════════════════════

        "gemeinschaftseigentum": GlossarEintrag(
            id: "gemeinschaftseigentum",
            begriff: "Gemeinschaftseigentum",
            erklaerung: "Alles was allen Eigentümern einer WEG gemeinsam gehört: Treppenhaus, Dach, Fassade, Aufzug, Heizanlage, Grundstück. Die Kosten dafür werden auf alle Eigentümer verteilt. Als Mieter zahlst du den Betriebskosten-Anteil über die Nebenkosten.",
            kategorie: .verwaltung
        ),
        "sondereigentum": GlossarEintrag(
            id: "sondereigentum",
            begriff: "Sondereigentum",
            erklaerung: "Deine Wohnung selbst — gehört einem einzelnen Eigentümer. Alles innerhalb der Wohnungswände: Bodenbeläge, Innentüren, Sanitär. Kosten für Reparaturen im Sondereigentum sind Sache des Eigentümers und NICHT über Nebenkosten umlagefähig.",
            kategorie: .verwaltung
        ),
        "teilungserklaerung": GlossarEintrag(
            id: "teilungserklaerung",
            begriff: "Teilungserklärung",
            erklaerung: "Notarielle Urkunde die festlegt, welche Teile eines Gebäudes Sondereigentum und welche Gemeinschaftseigentum sind. Enthält auch die Miteigentumsanteile (wichtig für den Verteilerschlüssel). Als Mieter musst du sie nicht kennen — aber bei Streit über den Verteilerschlüssel kann ein Blick helfen.",
            kategorie: .verwaltung
        ),
        "eigentuemerversammlung": GlossarEintrag(
            id: "eigentuemerversammlung",
            begriff: "Eigentümerversammlung",
            erklaerung: "Jährliche Versammlung aller Wohnungseigentümer einer WEG. Dort werden Wirtschaftsplan, Jahresabrechnung und Sonderumlagen beschlossen. Die Beschlüsse beeinflussen deine Nebenkosten — aber als Mieter hast du kein Stimmrecht und wirst nicht eingeladen.",
            kategorie: .verwaltung
        ),
        "mietverwaltung": GlossarEintrag(
            id: "mietverwaltung",
            begriff: "Mietverwaltung / Sondereigentumsverwaltung (SEV)",
            erklaerung: "Verwaltung, die der Eigentümer speziell für seine vermietete Wohnung beauftragt: Mieterkommunikation, Nebenkostenabrechnung, Reparaturkoordination. Die Kosten dafür sind NICHT umlagefähig — das sind Verwaltungskosten die der Vermieter selbst trägt.",
            kategorie: .verwaltung
        ),
        "genossenschaft": GlossarEintrag(
            id: "genossenschaft",
            begriff: "Wohnungsgenossenschaft",
            erklaerung: "Genossenschaftsmitglieder sind Miteigentümer und Nutzer zugleich. Du zahlst eine 'Nutzungsgebühr' statt Miete und Genossenschaftsanteile. Die Betriebskostenabrechnung funktioniert wie bei normalen Mietern. Vorteil: oft günstiger, kein Eigenbedarf möglich. Nachteil: Genossenschaftsanteile sind gebunden.",
            kategorie: .verwaltung
        ),

        // ═══════════════════════════════════════
        // RECHTLICHES — Ergänzungen (v4-18c)
        // ═══════════════════════════════════════

        "einwendungsfrist": GlossarEintrag(
            id: "einwendungsfrist",
            begriff: "Einwendungsfrist (12 Monate)",
            erklaerung: "Nach Zugang der Abrechnung hast du 12 Monate Zeit, Einwendungen zu erheben (§ 556 Abs. 3 S. 5 BGB). Danach kannst du Fehler nicht mehr rügen — selbst wenn die Abrechnung offensichtlich falsch ist. Ausnahme: Du hast die Verspätung nicht zu vertreten (z.B. Krankheit).",
            kategorie: .recht
        ),
        "zugang_abrechnung": GlossarEintrag(
            id: "zugang_abrechnung",
            begriff: "Zugang der Abrechnung",
            erklaerung: "Der Tag an dem die Abrechnung in deinem Briefkasten liegt — nicht der Tag an dem sie abgeschickt wurde. Ab diesem Tag laufen alle Fristen. Der Vermieter muss den Zugang beweisen können. Tipp: Notiere das Empfangsdatum auf der Abrechnung.",
            kategorie: .recht
        ),
        "belegpflicht": GlossarEintrag(
            id: "belegpflicht",
            begriff: "Belegpflicht / Belegvorhaltung",
            erklaerung: "Der Vermieter muss alle Belege (Rechnungen, Verträge, Gebührenbescheide) aufbewahren und dir auf Verlangen zur Einsicht vorlegen. Die Aufbewahrungsfrist beträgt mindestens bis zum Ablauf der Einwendungsfrist + Verjährungsfrist. Keine Belege = keine wirksame Abrechnung.",
            kategorie: .recht
        ),
        "mietminderung": GlossarEintrag(
            id: "mietminderung",
            begriff: "Mietminderung",
            erklaerung: "Wenn deine Wohnung Mängel hat (Schimmel, Heizungsausfall, Lärm), darfst du die Miete kürzen. Die Minderung betrifft die Warmmiete INKLUSIVE Nebenkosten. Wichtig: Erst Vermieter informieren, dann mindern. Höhe hängt vom Mangel ab (z.B. Heizungsausfall im Winter: bis 100%).",
            kategorie: .recht
        ),
        "saldoklage": GlossarEintrag(
            id: "saldoklage",
            begriff: "Saldoklage / Zahlungsklage",
            erklaerung: "Wenn du die Nachzahlung nicht leistest, kann der Vermieter klagen. Umgekehrt: Zahlt der Vermieter dein Guthaben nicht aus, kannst du klagen. Vor Gericht wird die gesamte Abrechnung geprüft — nicht nur der strittige Punkt. Kosten: ab ca. 300 € (Amtsgericht).",
            kategorie: .recht
        ),
        "staffelmiete": GlossarEintrag(
            id: "staffelmiete",
            begriff: "Staffelmiete (§ 557a BGB)",
            erklaerung: "Mietvertrag mit im Voraus festgelegten Mieterhöhungen zu bestimmten Zeitpunkten. Die Betriebskosten-Vorauszahlung kann trotzdem jährlich angepasst werden — die Staffelung betrifft nur die Kaltmiete.",
            kategorie: .recht
        ),
        "indexmiete": GlossarEintrag(
            id: "indexmiete",
            begriff: "Indexmiete (§ 557b BGB)",
            erklaerung: "Die Kaltmiete ist an den Verbraucherpreisindex gekoppelt und steigt/fällt automatisch mit der Inflation. Bei Indexmiete darf der Vermieter Betriebskosten trotzdem gesondert abrechnen. Die Index-Anpassung betrifft nur die Kaltmiete, nicht die Vorauszahlungen.",
            kategorie: .recht
        ),
        "kaution": GlossarEintrag(
            id: "kaution",
            begriff: "Kaution / Mietkaution (§ 551 BGB)",
            erklaerung: "Sicherheitsleistung von max. 3 Monats-Kaltmieten. Darf NICHT für offene Nebenkostennachzahlungen einbehalten werden solange das Mietverhältnis besteht. Nach Auszug: Der Vermieter darf einen angemessenen Teil zurückhalten bis die letzte Nebenkostenabrechnung erstellt ist (max. 6–12 Monate).",
            kategorie: .recht
        ),

        // ═══════════════════════════════════════
        // VERTEILUNG — Ergänzungen (v4-18c)
        // ═══════════════════════════════════════

        "wohneinheiten": GlossarEintrag(
            id: "wohneinheiten",
            begriff: "Verteilung nach Wohneinheiten",
            erklaerung: "Jede Wohnung zahlt den gleichen Anteil, unabhängig von Größe oder Personenzahl. Wird manchmal für Grundsteuer, Müll oder Versicherung verwendet. Benachteiligt kleine Wohnungen — eine 40-m²-Wohnung zahlt gleich viel wie eine 120-m²-Wohnung.",
            kategorie: .verteilung
        ),
        "kubikmeter": GlossarEintrag(
            id: "kubikmeter",
            begriff: "Kubikmeter (m³) Wasser",
            erklaerung: "1 Kubikmeter = 1.000 Liter Wasser. Eine Person verbraucht durchschnittlich ca. 120 Liter/Tag = ca. 44 m³/Jahr. Dein Zähler zeigt den Verbrauch in m³. Preis variiert stark nach Kommune: 1,50 – 5,00 €/m³ inkl. Abwasser.",
            kategorie: .verteilung
        ),
        "umrechnungsfaktor": GlossarEintrag(
            id: "umrechnungsfaktor",
            begriff: "Umrechnungsfaktor (Heizkostenverteiler)",
            erklaerung: "Heizkostenverteiler zeigen 'Einheiten' an, keine kWh. Je nach Heizkörper-Typ und -Größe wird ein Umrechnungsfaktor (KC/KQ-Wert) angewendet. Ein großer Heizkörper mit 100 Einheiten verbraucht mehr als ein kleiner mit 100 Einheiten. Der Messdienstleister berechnet das.",
            kategorie: .verteilung
        )
    ]

    /// Alle Einträge sortiert nach Kategorie
    static var nachKategorie: [(kategorie: GlossarKategorie, eintraege: [GlossarEintrag])] {
        GlossarKategorie.allCases.map { kat in
            (kategorie: kat,
             eintraege: eintraege.values
                .filter { $0.kategorie == kat }
                .sorted { $0.begriff < $1.begriff })
        }.filter { !$0.eintraege.isEmpty }
    }

    /// Suche im Glossar
    static func suche(_ query: String) -> [GlossarEintrag] {
        let q = query.lowercased()
        return eintraege.values.filter {
            $0.begriff.lowercased().contains(q) ||
            $0.erklaerung.lowercased().contains(q)
        }.sorted { $0.begriff < $1.begriff }
    }
}
