//
//  LegalTexts.swift
//  NebenkostenApp — Common
//
//  Platzhalter-Texte für Datenschutzerklärung und AVV. In Phase 1 durch
//  juristisch geprüfte Fassung ersetzen.
//

import Foundation

enum LegalTexts {

    static let datenschutzPlatzhalter: String = """
    Hinweis: Dieser Text ist ein Platzhalter. Die finale \
    Datenschutzerklärung wird in Phase 1 durch eine juristisch geprüfte \
    Fassung ersetzt.

    1. Verantwortlicher

    Verantwortlicher im Sinne der DSGVO für die in dieser App \
    verarbeiteten Daten sind Sie als App-Nutzerin bzw. App-Nutzer. Die \
    NebenkostenApp arbeitet auf Ihrem Gerät und synchronisiert die Daten \
    ausschließlich in Ihren privaten iCloud-Container. Wir als Anbieter \
    der App haben keinen Zugriff auf Inhalte, die Sie erfassen \
    (Mieterdaten, Rechnungen, Zählerstände).

    2. Datenarten

    Wenn Sie die App verwenden, verarbeiten Sie personenbezogene Daten \
    Ihrer Mieter (Name, Anschrift, E-Mail, ggf. Einzugs-/Auszugsdatum, \
    Personenzahl, Bankverbindung bei Vorauszahlungen). Für diese Daten \
    sind Sie gegenüber Ihren Mietern verantwortlich.

    3. Rechtsgrundlage

    Rechtsgrundlage für die Verarbeitung ist Art. 6 Abs. 1 lit. b DSGVO \
    (Erfüllung des Mietverhältnisses) sowie §§ 556 ff. BGB \
    (Betriebskostenabrechnung).

    4. Speicherdauer

    Abgeschlossene Abrechnungen sind nach § 257 HGB zehn Jahre \
    aufzubewahren. Die App pseudonymisiert Mieterdaten nach expliziter \
    Aufforderung, erhält aber den historischen Abrechnungsbezug.

    5. Ihre Rechte

    Sie können jederzeit in den Einstellungen der App:
    • alle Ihre Daten exportieren (Art. 20 DSGVO — Datenübertragbarkeit),
    • Ihren gesamten iCloud-Container löschen (Art. 17 DSGVO — Löschung),
    • einzelne Mieter pseudonymisieren.

    Mit der Nutzung der App bestätigen Sie, dass Sie die vorstehenden \
    Hinweise zur Kenntnis genommen haben.
    """

    static let avvPlatzhalter: String = """
    Hinweis: Dieser Text ist ein Platzhalter. Der finale \
    Auftragsverarbeitungsvertrag (AVV) wird in Phase 1 durch eine \
    juristisch geprüfte Fassung ersetzt.

    1. Gegenstand

    Dieser Vertrag regelt die Auftragsverarbeitung gemäß Art. 28 DSGVO \
    zwischen Ihnen (Verantwortlicher) und dem Anbieter der \
    NebenkostenApp (Auftragsverarbeiter).

    2. Art der Verarbeitung

    Der Auftragsverarbeiter stellt die App-Software bereit. Die \
    tatsächliche Verarbeitung Ihrer Daten findet ausschließlich auf \
    Ihrem Apple-Gerät und in Ihrem privaten iCloud-Container statt. Der \
    Auftragsverarbeiter hat keinen technischen Zugriff auf Ihre Daten.

    3. Unterauftragsverarbeiter

    Als einzigen Unterauftragsverarbeiter setzen Sie Apple Inc. ein, \
    indem Sie iCloud verwenden. Apple verarbeitet die Daten DSGVO-konform \
    gemäß seinen Datenschutzrichtlinien.

    4. Dauer

    Der Vertrag läuft, solange Sie die App verwenden. Nach Deinstallation \
    und Löschen des iCloud-Containers werden keine personenbezogenen \
    Daten mehr vom Auftragsverarbeiter verarbeitet.

    Mit der Zustimmung akzeptieren Sie diesen AVV.
    """
}
