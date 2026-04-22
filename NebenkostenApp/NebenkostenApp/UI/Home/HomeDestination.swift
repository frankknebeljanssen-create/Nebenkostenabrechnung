//
//  HomeDestination.swift
//  NebenkostenApp — UI/Home
//
//  Typed-Navigation-Ziele unterhalb des Home-Tabs. Alle `NavigationLink`s
//  im Uebersicht-Stack (HomeView, KachelansichtView, …) pushen
//  *value-typed* gegen dieses Enum statt direkt eine View zu
//  instanziieren. So landen sie in `AppShell.pathUebersicht` und
//  lassen sich durch `AppShell.leerePfad(fuer: .uebersicht)` bei
//  einem Re-Tap auf den Home-Tab zuverlaessig bis zur Root leeren
//  — was der iOS-Standard (Pop-to-Root) ist.
//
//  Vor dem Umbau nutzte HomeView `NavigationLink { KachelansichtView() }`
//  (value-less Form). Diese Variante pusht zwar, aber NICHT in den
//  Pfad des umschliessenden `NavigationStack(path:)`. Das fiel erst
//  beim Tab-Re-Tap auf: `pathUebersicht.count` blieb bei 0, der
//  Reset war wirkungslos, die Kachelansicht blieb sichtbar.
//

import Foundation

enum HomeDestination: Hashable, Sendable {
    /// 2x2-Kachel-Grid mit Stammdaten / Zaehlerstaende /
    /// Dokumente & Rechnungen / Abrechnung.
    case kachelansicht
    case stammdaten
    case zaehlerstaende
    case dokumenteRechnungen
    case abrechnungsKachel
}
