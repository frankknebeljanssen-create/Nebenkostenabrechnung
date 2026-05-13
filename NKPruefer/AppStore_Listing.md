# App Store Listing — Nebenkosten-Prüfer

## App Name
Nebenkosten-Prüfer

## Untertitel (max. 30 Zeichen)
Abrechnung prüfen per Foto

## Bundle-ID
`com.knebeljanssen.NKPruefer`

## Version / Build
- `CFBundleShortVersionString`: 1.0.0
- `CFBundleVersion`: 1

## Kategorien
- **Primary**: Finanzen
- **Secondary**: Nachschlagewerke

---

## Beschreibung (max. 4 000 Zeichen)

Stimmt deine Nebenkostenabrechnung? Finde es in 3 Minuten heraus.

Jede zweite Nebenkostenabrechnung in Deutschland enthält Fehler — aber die wenigsten Mieter widersprechen. Der Nebenkosten-Prüfer ändert das: Fotografiere deine Abrechnung, und die App prüft automatisch alle Kostenpositionen, Verteilerschlüssel und Berechnungen.

**SO FUNKTIONIERT'S**

1. Fotografiere deine Nebenkostenabrechnung (oder wähle Fotos aus deiner Galerie)
2. Die App liest und prüft automatisch alle Positionen
3. Du bekommst einen detaillierten Prüfbericht mit konkreten Ergebnissen

**WAS WIRD GEPRÜFT?**

- Alle Kostenpositionen nach BetrKV (Betriebskostenverordnung)
- Verteilerschlüssel und Berechnungen
- Umlagefähigkeit aller Kosten
- Rechnerische Richtigkeit
- Einhaltung gesetzlicher Vorgaben (HeizKV, WoFlV)

**WENN FEHLER GEFUNDEN WERDEN**

Die App erstellt einen fertigen Widerspruch mit Rechtsgrundlage, den du per E-Mail, PDF oder WhatsApp an deinen Vermieter schicken kannst. Inklusive Hinweis auf dein Belegeinsichtsrecht (§ 259 BGB).

**GLOSSAR MIT 130+ FACHBEGRIFFEN**

Verteilerschlüssel? BetrKV? Wirtschaftseinheit? Das integrierte Glossar erklärt alle wichtigen Begriffe rund um Nebenkosten — verständlich und auf den Punkt. Acht Kategorien, Volltextsuche.

**DATENSCHUTZ**

- Texterkennung direkt auf deinem Gerät (Apple Vision)
- Daten werden vor der Analyse anonymisiert (Namen, Adressen, Kontonummern entfernt)
- Anonymisierte Daten werden per API analysiert und danach gelöscht
- Kein Account nötig, keine Registrierung
- Face ID / Touch ID Schutz optional
- Komplette Datenlöschung jederzeit möglich (DSGVO Art. 17)

**HINWEIS**

Diese App bietet keine Rechtsberatung im Sinne des Rechtsdienstleistungsgesetzes (RDG). Die Analyse-Ergebnisse sind automatisch generiert. Im Zweifel wende dich an deinen örtlichen Mieterverein oder einen Fachanwalt für Mietrecht.

---

## Promotional Text (max. 170 Zeichen)
Jede 2. Nebenkostenabrechnung ist falsch. Fotografiere deine und finde Fehler in 3 Minuten — mit fertigem Widerspruch.

## Keywords (max. 100 Zeichen, kommagetrennt, keine Leerzeichen)
Nebenkosten,Abrechnung,Mieter,Betriebskosten,Widerspruch,Mietrecht,BetrKV,Heizkosten,Prüfen

## Altersfreigabe
4+

## Support-URL
(eintragen — z. B. `https://nk-pruefer.de/support`)

## Marketing-URL (optional)
(eintragen)

## Datenschutz-URL
(Pflicht — z. B. `https://nk-pruefer.de/datenschutz`)

---

## App Privacy (App Store Connect — App-Datenschutzangaben)

### Daten die mit dir verknüpft werden
**Keine.** Die App nutzt keinen Account, kein Login, keine Identifikation.

### Daten die NICHT mit dir verknüpft werden
- **Nutzungsdaten**: Lokale Statistik (geprüfte Abrechnungen). Nur auf dem Gerät.
- **Diagnose-Daten**: System-Crash-Reports (nur wenn du Apple zugestimmt hast).

### Daten die für Tracking verwendet werden
**Keine.** Es gibt kein Tracking.

### Verarbeitete Datenkategorien
- **Kamera-Inhalte (Fotos der Abrechnung)** — werden ausschließlich auf deinem Gerät verarbeitet (Apple Vision OCR). Keine Übertragung an Server.
- **Anonymisierter Text der Abrechnung** — wird zur Analyse an Anthropic (Claude API) übertragen. Vor der Übertragung werden Namen, Adressen, IBANs und Telefonnummern entfernt. Anthropic löscht API-Daten nach 7 Tagen und nutzt sie laut Nutzungsbedingungen nicht für KI-Training.

### Berechtigungen
- **NSCameraUsageDescription** — „Der Nebenkosten-Prüfer braucht Zugriff auf deine Kamera, um die Abrechnung zu fotografieren."
- **NSPhotoLibraryUsageDescription** — „Der Nebenkosten-Prüfer braucht Zugriff auf deine Fotos, damit du bereits fotografierte Abrechnungen auswählen kannst."
- **NSFaceIDUsageDescription** — „Der Nebenkosten-Prüfer verwendet Face ID um deine Daten zu schützen."

### Encryption-Erklärung
`ITSAppUsesNonExemptEncryption` = NO (keine eigene Verschlüsselung, nur Standard-HTTPS).

---

## Screenshots (für App Store Connect)

Pflicht: mindestens 3 Screenshots in **6.7" iPhone-Display** (1290×2796 px). Optional zusätzlich für 6.5" und 5.5".

Empfohlene Reihenfolge:
1. **HomeView** — „Stimmt deine Abrechnung?" CTA + Logo
2. **CaptureView** — Multi-Page-Scan mit Thumbnails
3. **AnalyseView** — Live-Pipeline (alle 7 Phasen, eine aktiv)
4. **BerichtView** — „Alles korrekt" oder „X Auffälligkeiten gefunden" + Eckdaten + Positionen
5. **WiderspruchView** — Fertiger Widerspruch mit Frist-Card
6. **GlossarBrowseView** — Suche nach Begriffen

Jedes Screenshot mit kurzem deutschem Overlay-Text (z. B. „Fotografiere deine Abrechnung" / „Wir prüfen jede Position" / „Du bekommst einen fertigen Widerspruch").

---

## Versions-Notes (was ist neu)

```
Version 1.0 — Erstveröffentlichung

• Multi-Page Dokument-Scanner (Apple VisionKit)
• 7-stufige KI-Prüfung jeder Abrechnung
• Glossar mit 130+ Mietrecht-Begriffen
• PDF-Export des Prüfberichts
• Fertiger Widerspruch mit Rechtsgrundlage
• DSGVO-konform — Daten werden anonymisiert verarbeitet
```

---

## Submission-Checkliste

- [ ] Bundle-ID stimmt mit App Store Connect überein
- [ ] App-Icon 1024×1024 (vorhanden in `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)
- [ ] Privacy Usage Descriptions in Info.plist (Camera, PhotoLibrary, FaceID) ✓
- [ ] `ITSAppUsesNonExemptEncryption` in Info.plist gesetzt ✓
- [ ] `UIDesignRequiresCompatibility = YES` (iOS-26-Liquid-Glass deaktiviert) ✓
- [ ] Mindest-iOS-Version 17.0 (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`) ✓
- [ ] Code-Signing mit „Apple Development" für Debug / „Apple Distribution" für Release
- [ ] Datenschutz-URL hinterlegt (Pflicht für Apps mit Datenübertragung)
- [ ] Mindestens 3 Screenshots pro Pflicht-Größe
- [ ] App-Beschreibung + Untertitel + Keywords eingetragen
- [ ] Test-Account-Daten (falls Reviewer benötigt) — hier nicht relevant, weil kein Login
- [ ] Reviewer-Notizen: Eigener Anthropic-Zugangsschlüssel erforderlich (in App unter Mehr → Zugangsschlüssel eintragbar)
