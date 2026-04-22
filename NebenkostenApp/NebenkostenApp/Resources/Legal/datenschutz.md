# Datenschutzerklärung

_Entwurf — juristisch markierte Passagen (`[TODO (Anwalt): …]`) müssen vor Launch anwaltlich geprüft werden._

## 1. Verantwortlicher

Verantwortlich im Sinne von Art. 4 Nr. 7 DSGVO für die Datenverarbeitung in dieser App ist:

[TODO (Anwalt): Vollständige Anbieter-Angaben — Firma oder Name, Anschrift, Rechtsform, Vertretungsberechtigte:r, USt-IdNr., Handelsregister sofern zutreffend.]

**Kontakt für Datenschutzanfragen:** [TODO (Anwalt): Dedizierte E-Mail-Adresse, ggf. Postadresse.]

## 2. Rollenverteilung

Die App speichert zwei Arten personenbezogener Daten:

- **Eigene Nutzerdaten** (z. B. Vermieter-Stammdaten, Zählerstände). Für diese sind wir Verantwortlicher nach Art. 4 Nr. 7 DSGVO.
- **Mieter-Daten, die der Nutzer erfasst** (z. B. Name, Anschrift, E-Mail). Für diese ist der Nutzer selbst Verantwortlicher — wir sind Auftragsverarbeiter nach Art. 28 DSGVO.

Ein Auftragsverarbeitungsvertrag (AVV) zwischen Nutzer und Anbieter wird im Onboarding geschlossen.

[TODO (Anwalt): Prüfen, ob die Rollenverteilung inhaltlich korrekt ist. AVV-Entwurf separat anlegen.]

## 3. Rechtsgrundlagen

- Art. 6 Abs. 1 lit. b DSGVO — Erfüllung des Nutzungsvertrags (App-Betrieb, Abo).
- Art. 6 Abs. 1 lit. c DSGVO — gesetzliche Pflichten, insbesondere § 257 HGB (Aufbewahrung).
- Art. 6 Abs. 1 lit. a DSGVO — ausdrückliche Einwilligung, sofern optionale Funktionen (z. B. "Volle Dokumente an Claude" statt PII-Schwärzung) aktiviert werden.

## 4. Verarbeitete Datenkategorien

### 4.1 Vom Nutzer eingegebene Daten

- Immobilien-Stammdaten (Adresse, Gesamtfläche, Einheiten, Kostenarten, Umlageschlüssel).
- Mieter-Daten (Name, Anschrift, E-Mail, Vorauszahlung, Einzug/Auszug).
- Zählerstände (Ablesedatum, Wert, Quelle, optional Foto).
- Rechnungen und Belege (PDF / Bild, extrahierte Werte, §35a-Lohnanteil).
- Abrechnungen (berechnete Salden, §35a-Auswertung, generierte PDFs).

### 4.2 Technisch erhobene Daten

- Kamera-Zugriff beim Scan (siehe NSCameraUsageDescription). Bilder verlassen das Gerät nicht ohne ausdrückliche Nutzeraktion.
- Foto-Mediathek-Zugriff bei Import (siehe NSPhotoLibraryUsageDescription). Ausgewählte Fotos werden als PDF im App-Sandbox gespeichert.
- iCloud-Synchronisation (siehe Abschnitt 6).
- Keine Analyse-, Tracking- oder Werbe-SDKs. Keine IP-Adressen-Speicherung durch den Anbieter.

[TODO (Anwalt): Prüfen, ob zusätzliche technische Erhebungen (Crash-Logs via Apple, App-Store-Analytics) aufzuführen sind.]

## 5. KI-gestützte Extraktion

Rechnungen und Belege werden beim Scan in zwei Stufen verarbeitet:

1. **On-Device (Foundation Models + Vision).** Läuft komplett auf dem iPhone, keine Daten verlassen das Gerät.
2. **Claude API (Anthropic, USA) — nur bei Bedarf.** Wird nur angefragt, wenn das On-Device-Modell unsicher ist oder ein unbekanntes Dokumentformat vorliegt. Standardmäßig werden vor dem Versand Adressen, Namen, Telefonnummern, IBANs und E-Mail-Adressen geschwärzt (Modus "Geschwärzt"). Der Nutzer kann in den Einstellungen den Modus "Vollständig" aktivieren — dann wird das Dokument unbearbeitet übertragen. Jeder Aufruf im Modus "Vollständig" wird im Audit-Log protokolliert.

Der API-Zugriff erfolgt über einen Cloudflare-Worker-Proxy; der Anthropic-API-Schlüssel liegt nicht auf dem Gerät. Anthropic verarbeitet die übermittelten Daten gemäß eigener [Nutzungsbedingungen](https://www.anthropic.com/legal) ohne Training auf Input-Daten (Stand der Anthropic-Policy bei Drucklegung).

[TODO (Anwalt): Prüfen, ob die Claude-API-Nutzung ein Drittlandtransfer im Sinne von Art. 44 ff. DSGVO darstellt und welche Garantien (Standardvertragsklauseln, TIA) erforderlich sind. Anthropic-DPA muss separat abgeschlossen werden.]

## 6. Speicherort und Sync

Alle Daten werden lokal auf dem iPhone im App-Sandbox gespeichert (SwiftData-Datei + App-Documents-Ordner) und über **Apple iCloud** (CloudKit Private Database) in den persönlichen iCloud-Account des Nutzers synchronisiert. Apple fungiert als Sub-Auftragsverarbeiter.

- **Anbieter:** Apple Distribution International Ltd., Hollyhill Industrial Estate, Hollyhill, Cork, Irland.
- **Rechtsgrundlage:** Apples iCloud-DPA, akzeptiert im Rahmen der Apple-Developer-Anmeldung.
- Es existiert kein Server des App-Anbieters, auf dem Nutzerdaten liegen.

[TODO (Anwalt): Sub-Auftragsverarbeiter-Liste (Apple, Anthropic, Cloudflare) in AVV aufnehmen und nutzern vor Zustimmung offenlegen.]

## 7. Speicherdauer

- Eingegebene Daten bleiben solange erhalten, wie das App-Abo aktiv ist oder der Nutzer sie nicht löscht.
- § 257 HGB verpflichtet zur 10-jährigen Aufbewahrung von Handelsunterlagen. Gelöschte Mieter werden deshalb nicht vollständig entfernt, sondern in bestehenden Abrechnungen pseudonymisiert (Kontaktdaten gelöscht, Historie bleibt).
- Vollständige Löschung über _Einstellungen → Alle Daten löschen_ zerstört SwiftData-Store und den iCloud-Container.

## 8. Rechte der Betroffenen

Sie haben nach DSGVO das Recht auf:

- **Auskunft** (Art. 15) — _Einstellungen → Daten exportieren_ liefert alle gespeicherten Inhalte als JSON + PDF-Belege im ZIP-Format.
- **Berichtigung** (Art. 16) — direkt über die App-UI.
- **Löschung** (Art. 17) — _Einstellungen → Einzelnen Mieter löschen_ bzw. _Alle Daten löschen_.
- **Einschränkung** (Art. 18), **Widerspruch** (Art. 21), **Datenübertragbarkeit** (Art. 20).
- **Beschwerde** bei der zuständigen Aufsichtsbehörde. [TODO (Anwalt): Zuständige Landesdatenschutzbehörde nach Sitz des Anbieters angeben.]

## 9. Kontakt

Anfragen zum Datenschutz bitte an:

[TODO (Anwalt): E-Mail-Adresse für Datenschutzanfragen.]

## 10. Änderungen

Diese Datenschutzerklärung wird bei funktionalen Änderungen der App (z. B. neue Sub-Auftragsverarbeiter) aktualisiert. Die jeweils aktuelle Fassung ist in _Einstellungen → Rechtliches → Datenschutz_ abrufbar.

_Stand:_ [TODO (Anwalt): Datum der letzten Aktualisierung bei jedem Release aktualisieren.]
