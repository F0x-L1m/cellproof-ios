import Foundation

/// Lightweight two-language table (English source, German translation).
/// Adding a language = adding one column per key.
enum L {
    static let isGerman: Bool = (Locale.preferredLanguages.first ?? "en").hasPrefix("de")

    static func t(_ key: String) -> String {
        guard let row = table[key] else { return key }
        return isGerman ? row.de : row.en
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale.current, arguments: args)
    }

    private static let table: [String: (en: String, de: String)] = [
        // Navigation
        "tab.check": ("Check", "Prüfen"),
        "tab.history": ("History", "Verlauf"),
        "app.subtitle": ("Battery check for e-scooters", "Akku-Check für E-Scooter"),

        // Home
        "home.title": ("Know the battery before you buy.", "Kenne den Akku, bevor du kaufst."),
        "home.body": ("Close the manufacturer app, switch the scooter on and start the scan. CellProof only reads data and never changes anything on the scooter.",
                      "Schließ die Hersteller-App, schalte den Scooter ein und starte die Suche. CellProof liest nur Daten und verändert nichts am Scooter."),
        "home.scan": ("Find scooter", "Scooter suchen"),
        "home.sample": ("Show sample report", "Beispielbericht ansehen"),

        // Scan
        "scan.title": ("Nearby scooters", "Scooter in der Nähe"),
        "scan.searching": ("Searching …", "Suche läuft …"),
        "scan.hint": ("Nothing found? Make sure the scooter is on and no other app is connected to it.",
                      "Nichts gefunden? Der Scooter muss eingeschaltet sein und darf mit keiner anderen App verbunden sein."),
        "scan.cancel": ("Cancel", "Abbrechen"),
        "scan.signal.strong": ("strong signal", "starkes Signal"),
        "scan.signal.medium": ("medium signal", "mittleres Signal"),
        "scan.signal.weak": ("weak signal", "schwaches Signal"),

        // States
        "state.connecting": ("Connecting …", "Verbinde …"),
        "state.keyExchange": ("Exchanging keys …", "Schlüsseltausch …"),
        "state.reading": ("Reading battery …", "Lese Akku …"),
        "state.done": ("Measured", "Gemessen"),
        "state.bluetoothOff": ("Bluetooth is off", "Bluetooth ist aus"),
        "state.unauthorized": ("Bluetooth access not allowed. Enable it for CellProof in Settings.", "Bluetooth-Zugriff nicht erlaubt. Bitte in den Einstellungen für CellProof erlauben."),

        // Pairing
        "pair.title": ("Press the power button now", "Jetzt den Einschaltknopf drücken"),
        "pair.body": ("Tap the scooter's power button once. Don't hold it, or the scooter switches off. This confirms the pairing and is only needed the first time.",
                      "Tipp den Einschaltknopf am Scooter einmal kurz an. Nicht gedrückt halten, sonst schaltet er aus. Damit bestätigst du die Kopplung, das ist nur beim ersten Mal nötig."),

        // Failures
        "fail.noButtonPress": ("No button press detected. Connect again and tap the power button briefly when asked.",
                               "Kein Knopfdruck erkannt. Verbinde neu und tipp kurz auf den Einschaltknopf, sobald die Aufforderung erscheint."),
        "fail.encryptedUnreadable": ("The scooter answers, but pairing failed. Open the log and send it to support.",
                                     "Der Scooter antwortet, aber die Kopplung schlägt fehl. Öffne das Protokoll und schick es an den Support."),
        "fail.noAnswer": ("No answer from the scooter. Is it switched on and the manufacturer app fully closed?",
                          "Keine Antwort vom Scooter. Ist er eingeschaltet und die Hersteller-App komplett geschlossen?"),
        "fail.noBatteryData": ("Paired, but the battery returned no values.", "Gekoppelt, aber der Akku liefert keine Werte."),
        "fail.noCells": ("General values read, single cells not available on this model.", "Allgemeine Werte gelesen, Einzelzellen liefert dieses Modell nicht."),
        "fail.disconnected": ("Connection lost. Move closer to the scooter and try again.", "Verbindung verloren. Geh näher an den Scooter und versuch es erneut."),
        "fail.serviceMissing": ("This device doesn't offer the expected data channel. Is it really a scooter?", "Das Gerät bietet den erwarteten Datenkanal nicht an. Ist es wirklich ein Scooter?"),
        "action.retry": ("Try again", "Erneut versuchen"),

        // Report
        "report.sample": ("Sample data", "Beispieldaten"),
        "report.drift": ("Cell drift", "Zelldrift"),
        "report.drift.caption": ("Largest voltage difference between cells", "Größte Spannungsdifferenz zwischen den Zellen"),
        "level.good": ("Cells balanced", "Zellen im Gleichgewicht"),
        "level.watch": ("Slight drift · keep an eye on it", "Leichte Drift · beobachten"),
        "level.critical": ("Significant drift · act", "Deutliche Drift · handeln"),
        "kpi.charge": ("Charge", "Ladestand"),
        "kpi.voltage": ("Pack voltage", "Packspannung"),
        "kpi.current": ("Current", "Strom"),
        "kpi.temp": ("Battery temp", "Akkutemperatur"),
        "cells.title": ("Single cells", "Einzelzellen"),
        "cells.count": ("%d cell groups in series (%dS)", "%d Zellgruppen in Reihe (%dS)"),
        "health.title": ("Battery health", "Akku-Gesundheit"),
        "health.bms": ("as reported by BMS", "laut BMS"),
        "health.capF": ("Rated capacity", "Nennkapazität"),
        "health.capA": ("Actual capacity", "Ist-Kapazität"),
        "health.capR": ("Remaining now", "Restkapazität jetzt"),
        "file.title": ("Battery record", "Akkuakte"),
        "file.cycles": ("Full charge cycles", "Volle Ladezyklen"),
        "file.charges": ("Charging sessions", "Ladevorgänge"),
        "file.mfg": ("Manufactured", "Herstelldatum"),
        "file.odo": ("Total distance", "Gesamtstrecke"),
        "file.fw": ("BMS firmware", "BMS-Firmware"),
        "file.sn": ("Serial number", "Seriennummer"),
        "verdict.title": ("Verdict", "Befund"),
        "verdict.a": ("Situation", "Ansprechen"),
        "verdict.b": ("Assessment", "Beurteilen"),
        "verdict.f": ("Conclusion", "Folgern"),
        "action.save": ("Save measurement", "Messung speichern"),
        "action.saved": ("Saved", "Gespeichert"),
        "action.share": ("Share report", "Bericht teilen"),
        "action.remeasure": ("Measure again", "Neu messen"),
        "action.newScan": ("Check another scooter", "Anderen Scooter prüfen"),
        "action.log": ("Diagnostic log", "Diagnose-Protokoll"),
        "action.copyLog": ("Copy log", "Protokoll kopieren"),
        "action.copied": ("Copied", "Kopiert"),
        "action.forget": ("Reset all pairings", "Alle Kopplungen zurücksetzen"),
        "action.done": ("Done", "Fertig"),
        "footer.readonly": ("CellProof only sends read commands. Capacity and health values are reported by the battery's BMS, not an independent measurement.",
                            "CellProof sendet ausschließlich Lesebefehle. Kapazitäts- und Gesundheitswerte stammen vom BMS des Akkus und sind keine unabhängige Messung."),

        // Verdict texts
        "v.a.cells": ("%d cell groups measured at %d %% charge, %@ V, battery %@ °C, current %@ A.",
                      "%d Zellgruppen gemessen bei %d %% Ladestand, %@ V, Akku %@ °C, Strom %@ A."),
        "v.a.nocells": ("General battery values available, single cells could not be read.",
                        "Allgemeine Akkuwerte liegen vor, Einzelzellen konnten nicht gelesen werden."),
        "v.b.drift": ("Drift %d mV between C%d (%@ V) and C%d (%@ V).", "Drift %d mV zwischen Z%d (%@ V) und Z%d (%@ V)."),
        "v.b.drift.good": ("Below 30 mV counts as healthy.", "Unter 30 mV gilt als gesund."),
        "v.b.drift.watch": ("Between 30 and 80 mV: not critical yet, but noticeable.", "Zwischen 30 und 80 mV: noch unkritisch, aber auffällig."),
        "v.b.drift.critical": ("Above 80 mV: the weakest cell limits usable capacity.", "Über 80 mV: Die schwächste Zelle begrenzt die nutzbare Kapazität."),
        "v.b.health": ("Health per BMS %d %%.", "Gesundheit laut BMS %d %%."),
        "v.b.health.good": ("Practically as new.", "Praktisch neuwertig."),
        "v.b.health.ok": ("Normal ageing.", "Normale Alterung."),
        "v.b.health.bad": ("Noticeable capacity loss.", "Spürbarer Kapazitätsverlust."),
        "v.b.cycles": ("%d full charge cycles.", "%d volle Ladezyklen."),
        "v.b.cycles.low": ("Cycle wear doesn't matter yet.", "Zyklenverschleiß spielt noch keine Rolle."),
        "v.b.cycles.mid": ("Moderate cycle wear.", "Moderater Zyklenverschleiß."),
        "v.b.cycles.high": ("This battery has been through a lot.", "Der Akku hat viel hinter sich."),
        "v.b.load": ("Limitation: current was flowing during the measurement. Drift under load is less meaningful.",
                     "Einschränkung: Während der Messung floss Strom. Drift unter Last ist weniger aussagekräftig."),
        "v.b.soc": ("Limitation: drift shows most clearly on a full battery. At this charge level it may be underestimated.",
                    "Einschränkung: Drift zeigt sich am deutlichsten bei vollem Akku. Bei diesem Ladestand kann sie unterschätzt werden."),
        "v.b.cold": ("Limitation: cold battery. Voltages and capacity values are lower in the cold.",
                     "Einschränkung: Kalter Akku. Spannungen und Kapazitätsangaben sind bei Kälte niedriger."),
        "v.f.nocells": ("Open the diagnostic log and send it to support so the cell registers can be mapped.",
                        "Öffne das Diagnose-Protokoll und schick es an den Support, damit die Zellregister zugeordnet werden können."),
        "v.f.good": ("No action needed. If you're buying: the battery shows no warning signs.",
                     "Kein Handlungsbedarf. Beim Kauf: Der Akku zeigt keine Warnzeichen."),
        "v.f.watch": ("Do two or three balancing charges (charge to 100 %, leave the charger on 3–4 hours after it turns green), then measure again. If you're buying: ask for that first, or factor it into the price.",
                      "Zwei bis drei Ausgleichsladungen machen (auf 100 % laden, Ladegerät nach dem grünen Licht noch 3–4 Stunden dranlassen), dann neu messen. Beim Kauf: Darum bitten oder im Preis berücksichtigen."),
        "v.f.critical": ("Cell group C%d is the weak point. Balancing charges may help; if drift stays above 80 mV, have the battery checked. If you're buying: expect a battery replacement.",
                         "Zellgruppe Z%d ist der Schwachpunkt. Ausgleichsladungen können helfen, bleibt die Drift über 80 mV, gehört der Akku in die Werkstatt. Beim Kauf: Mit einem Akkutausch rechnen."),

        // History
        "history.empty": ("No saved measurements yet. Measure right after a full charge so values are comparable.",
                          "Noch keine gespeicherten Messungen. Miss am besten direkt nach dem Vollladen, dann sind die Werte vergleichbar."),
        "history.driftTrend": ("Drift over time", "Drift im Verlauf"),
        "history.healthTrend": ("Health over time", "Gesundheit im Verlauf"),
        "history.delete": ("Delete", "Löschen"),

        // Share
        "share.header": ("CellProof battery report", "CellProof Akkubericht"),
    ]
}
