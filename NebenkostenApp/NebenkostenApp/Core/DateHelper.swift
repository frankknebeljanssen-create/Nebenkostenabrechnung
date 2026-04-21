//
//  DateHelper.swift
//  NebenkostenApp — Core
//
//  Kleine Date-Convenience-Extensions. Erste Erweiterung: einen
//  stabilen Default fuer DatePicker, die auf den „ersten des
//  aktuellen Monats" zeigen sollen (Mietbeginn, Perioden-Anfang,
//  NK-VZ-Gueltig-ab, Mieterhoehung usw.). Ein Mietvertrag beginnt
//  in Deutschland praktisch nie mitten im Monat — der Default
//  spart Tipparbeit und verhindert, dass der User versehentlich
//  „heute" stehen laesst.
//

import Foundation

extension Date {
    /// Erster Kalendertag des aktuellen Monats in der aktuellen
    /// System-Zeitzone. Fallback auf `Date()` ist rein defensiv;
    /// `Calendar.date(from:)` mit Jahr+Monat schlaegt in der Praxis
    /// nie fehl.
    static var ersterDesMonats: Date {
        let kal = Calendar.current
        let komps = kal.dateComponents([.year, .month], from: Date())
        return kal.date(from: komps) ?? Date()
    }

    /// Erster Kalendertag desselben Monats fuer einen gegebenen
    /// Bezugszeitpunkt. Praktisch fuer Migrations-/Recalc-Pfade.
    static func ersterDesMonats(fuer datum: Date) -> Date {
        let kal = Calendar.current
        let komps = kal.dateComponents([.year, .month], from: datum)
        return kal.date(from: komps) ?? datum
    }
}
