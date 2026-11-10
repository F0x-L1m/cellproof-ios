# CellProof

Akku-Check für E-Scooter (iOS, SwiftUI). Liest Zellspannungen, Drift, Gesundheit und Ladezyklen über Bluetooth – nur Lesebefehle, keine Änderungen am Scooter.

- `CellProof/BLE` – Bluetooth, Ninebot-Verschlüsselung, Kopplung, Registerlesen
- `CellProof/Model` – Messwert, Befund (A/B/F), Verlauf, Sprachen (DE/EN)
- `CellProof/UI` – Oberfläche
- `project.yml` – Projektbeschreibung für XcodeGen (das .xcodeproj entsteht beim Build)
- `codemagic.yaml` – Cloud-Build nach TestFlight

Bundle-ID: `de.foxlim.batterycheck`
