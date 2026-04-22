//
//  MailComposer.swift
//  NebenkostenApp — Services
//
//  SwiftUI-Wrapper um MFMailComposeViewController. Verwendet von zwei
//  Stellen:
//
//    - `UeberSection` im EinstellungenSheet → Feedback-Mail mit
//      vorgegebenem Empfaenger und Diagnose-Footer (Version + Device).
//    - `AbrechnungDetailView` → Abrechnungs-PDF als Anlage an den
//      Mieter.
//
//  Auf dem Simulator liefert `MFMailComposeViewController.canSendMail()`
//  in der Regel `false`. Der Composer wird dann nicht geoeffnet —
//  die Call-Site nutzt `mailto:`-Fallback oder deaktiviert den
//  Knopf. Mail mit Attachment geht nur ueber den Composer; fuer
//  reine Text-Mails kann der mailto-Fallback Standard-Mail-Apps
//  anstossen.
//

import Foundation
import SwiftUI
import MessageUI

/// Datei-Anlage fuer eine Mail. Die API nimmt bewusst `Data` statt
/// URL entgegen — so muessen Aufrufer kein Temp-File schreiben.
struct MailAnlage: Equatable {
    let data: Data
    let mimeType: String
    let dateiname: String
}

/// Inhalt einer zu erstellenden Mail. Alle Felder optional bis auf
/// `betreff` — der Composer sieht ohne Recipient/Body besser aus.
struct MailInhalt: Equatable {
    var empfaenger: [String] = []
    var betreff: String = ""
    var nachricht: String = ""
    var anlagen: [MailAnlage] = []
}

struct MailComposer: UIViewControllerRepresentable {
    let inhalt: MailInhalt
    /// Optional: wird nach Abschluss (.sent, .saved, .cancelled) oder
    /// Fehler aufgerufen. Das Sheet schliesst sich in allen Faellen
    /// automatisch — der Callback erlaubt nur Logging/Snapshot-Reset.
    var onFertig: ((MFMailComposeResult, Error?) -> Void)? = nil

    /// Wahr, wenn iOS mindestens einen konfigurierten Mail-Account
    /// hat. Simulator ohne Account → false; Call-Site faellt dann
    /// auf `mailto:`-URL zurueck oder disabled den Button.
    static var kannMailSenden: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFertig: onFertig)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(inhalt.empfaenger)
        vc.setSubject(inhalt.betreff)
        if !inhalt.nachricht.isEmpty {
            vc.setMessageBody(inhalt.nachricht, isHTML: false)
        }
        for a in inhalt.anlagen {
            vc.addAttachmentData(a.data,
                                 mimeType: a.mimeType,
                                 fileName: a.dateiname)
        }
        return vc
    }

    func updateUIViewController(
        _ vc: MFMailComposeViewController,
        context: Context
    ) {
        // Der Composer-View ist stateful im UIKit-VC; nichts zu aktualisieren.
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFertig: ((MFMailComposeResult, Error?) -> Void)?
        init(onFertig: ((MFMailComposeResult, Error?) -> Void)?) {
            self.onFertig = onFertig
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFertig?(result, error)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - mailto-Fallback

enum MailToFallback {

    /// Baut eine `mailto:`-URL, wie sie von iOS an die Default-Mail-App
    /// uebergeben werden kann. Attachments sind ueber mailto nicht
    /// moeglich — nur Text.
    static func url(fuer inhalt: MailInhalt) -> URL? {
        var komponenten = URLComponents()
        komponenten.scheme = "mailto"
        komponenten.path = inhalt.empfaenger.joined(separator: ",")
        var items: [URLQueryItem] = []
        if !inhalt.betreff.isEmpty {
            items.append(.init(name: "subject", value: inhalt.betreff))
        }
        if !inhalt.nachricht.isEmpty {
            items.append(.init(name: "body", value: inhalt.nachricht))
        }
        if !items.isEmpty {
            komponenten.queryItems = items
        }
        return komponenten.url
    }
}
