# Open-Source-Lizenzen

Diese App verwendet die folgenden Komponenten von Drittanbietern. Die Nutzung erfolgt jeweils nach den unten genannten Lizenzbedingungen. Vor jedem App-Store-Release prüfen, ob neu eingebundene Abhängigkeiten hier ergänzt werden müssen.

## IBM Plex® Sans und IBM Plex® Mono

Die App nutzt die Schriftart-Familien IBM Plex Sans und IBM Plex Mono (Gewichte 400, 500, 600).

- **Copyright** © 2017–2023 IBM Corp. with Reserved Font Name "Plex".
- **Lizenz:** SIL Open Font License, Version 1.1.
- **Lizenztext:** <https://scripts.sil.org/OFL>
- **Quelle:** <https://github.com/IBM/plex>

Die Fonts werden unverändert gebündelt. IBM Plex ist eine eingetragene Marke der IBM Corp.; Nutzung erfolgt im Rahmen der OFL-Bedingungen (u. a.: keine Namensänderung, Lizenz liegt jedem Font-Export bei).

## Apple Frameworks

Die App nutzt folgende Apple-eigene Frameworks, die Teil des iOS-SDK sind:

- SwiftUI, SwiftData
- Vision, VisionKit (Dokument-Scan, Text-Erkennung)
- PDFKit (PDF-Anzeige)
- PhotosUI (Mediathek-Import)
- MessageUI (Mail-Composer)
- AVFoundation (Kamera-Zugriff)
- StoreKit (Abo-Verwaltung)

Alle Apple-Frameworks unterliegen der Apple Developer Program License Agreement und der Apple Software License Agreement der jeweiligen iOS-Version.

## Anthropic Claude API

KI-gestützte Dokumentextraktion erfolgt — im Nutzer-aktiven Modus — über einen Proxy gegen die Claude-API von Anthropic, PBC (San Francisco, USA). Die Nutzung unterliegt den Anthropic-Nutzungsbedingungen und dem Anthropic Data Processing Agreement.

- **Anbieter-Policy:** <https://www.anthropic.com/legal>

[TODO (Anwalt): Anthropic-DPA separat abschließen und hier verlinken, sobald vorhanden.]

## Cloudflare Workers

API-Proxying für die Claude-API läuft über Cloudflare Workers. Cloudflare ist Sub-Auftragsverarbeiter.

- **Anbieter:** Cloudflare, Inc. (San Francisco, USA) bzw. Cloudflare Germany GmbH für EU-Kunden.
- **Policy:** <https://www.cloudflare.com/trust-hub/>

[TODO (Anwalt): DPA mit Cloudflare prüfen bzw. neueste SCCs referenzieren.]

## Eigene Komponenten

- **Mustache-Template-Renderer:** Eigene Mini-Implementierung (`Common/Mustache.swift`). Keine externe Abhängigkeit. Falls in Zukunft eine externe Bibliothek (z. B. [GRMustache.swift](https://github.com/groue/GRMustache.swift), MIT) verwendet werden soll, ist sie hier zu ergänzen.

## Ergänzungs-Hinweis

Weitere Open-Source-Komponenten werden hier aufgeführt, sobald sie ins Projekt aufgenommen werden. Swift Package Manager Dependencies sind automatisch in `Package.resolved` gelistet und bei App-Store-Einreichung in dieser Datei zu spiegeln.

_Stand:_ [TODO: Release-Datum beim nächsten App-Store-Release aktualisieren.]
