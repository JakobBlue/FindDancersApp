# FindDancers

> **🚧 Work in Progress.** Diese App ist in aktiver Entwicklung und nicht
> releasefertig. Einzelne Bildschirme sind Platzhalter, Namen von Views und
> Feldern ändern sich noch, und die Anbindung an die EV-API ist nur für den
> Organisator-Teil fertig. Nichts hier ist als stabile Schnittstelle gedacht.

iOS-App rund ums Paartanzen: Organisatoren legen Tanzgelegenheiten
(Workshops, Kurse, Veranstaltungen) an, Tanzende finden sie und einander.

## Stand

| Bereich | Status | Anmerkung |
| --- | --- | --- |
| Registrierung Organisator | ✅ funktioniert | `POST /UserAccount` + `POST /Organizer` + Staff-Verknüpfung |
| Anmeldung Organisator | ✅ funktioniert | HTTP Basic, Benutzername ist die **E-Mail** |
| Event anlegen | ✅ funktioniert | inkl. Kurs-Reihe, Ort, Tänze, Bild-Upload |
| Ort per Karte setzen | 🟡 teilweise | Adresssuche und Pin sind da, Ziehen der Pin nicht am Gerät geprüft |
| `taenze` / `engagementTyp` | 🟡 wartet auf Backend | App sendet beides, Server verwirft es noch (siehe `integration-aufgaben.md`) |
| Registrierung / Anmeldung Nutzer | ❌ Platzhalter | speichert nur lokal, kein API-Aufruf |
| Events anzeigen | ❌ Platzhalter | `NurEventsAnzeige` arbeitet mit Beispieldaten |
| Anfragen / Chats | ❌ nicht begonnen | leere Tabs |
| Tests | ❌ keine | bisher nur manuelle Prüfung gegen die laufende API |

## Voraussetzungen

- Xcode mit iOS-27-SDK, Deployment-Target **iOS 26.5**
- Eine **laufende EV-API** unter `http://localhost:8080` (Java/Spring, eigenes
  Repository). Ohne sie funktionieren Registrierung, Anmeldung und das
  Anlegen von Events nicht.
- Internet für die Adresssuche (Nominatim) und die Kartendarstellung.

## Loslegen

1. EV-API starten und prüfen, dass sie antwortet:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/Organizer   # 200
   ```
2. App im Simulator starten.
3. „Wir möchten Tanzgelegenheiten anbieten“ → „Registrieren“. Name, Passwort
   und **E-Mail** sind Pflicht; die E-Mail ist später der Anmeldename.
4. Danach steht der Tab „Events“ zum Anlegen bereit.

Die Server-Adresse steht in `Networking/EVAPIClient.swift` in
`EVAPIConfiguration.baseURL`.

## Aufbau

```
FindDancers/
├── ContentView.swift          Einstieg, Registrierung/Anmeldung, TabView
├── Data Models/               Formularzustand, Persistenz, Session, Standort
├── Networking/                EV-API-Client, Zugangsdaten, Geokodierung
├── Views/                     Bildschirme
└── Docs/                      Entwicklerdokumentation (WIP)
```

Einstiegspunkte zum Lesen:

- `Docs/Uebersicht.md` – Index der Entwicklerdokumentation
- `Docs/Architektur.md` – wie Zustand, Persistenz und Netzwerk zusammenspielen
- `Docs/EV-API.md` – welche Endpunkte genutzt werden und wo die Fallen liegen
- `Docs/Event-Formular.md` – das Create-Event-Formular im Detail

> Achtung: `FindDancers/` ist eine file-system-synchronized group. Jede Datei
> darin gehört automatisch zum Target und landet im App-Bundle – auch diese
> Markdown-Dateien. Weil das Bundle flach ist, darf kein Dateiname doppelt
> vorkommen: `Docs/README.md` und dieses `README.md` würden beide zu
> `FindDancers.app/README.md` und brechen den Build. Daher heißt der Index
> `Docs/Uebersicht.md`. Wer die Dokumentation nicht mitausliefern will, nimmt
> die Dateien im File Inspector aus der Target-Mitgliedschaft.

## Dokumente im Repository-Wurzelverzeichnis

- `integration-aufgaben.md` – Arbeitsanweisung für die **EV-API**: zwei neue
  Columns (`taenze`, `engagementTyp`) auf `Engagement`.
- `VorschlagStreetValidation.md` – Ideensammlung zur Adressvalidierung
  (Tippfehler, mehrdeutige Straßennamen, deutsche/englische Ortsnamen).
  Vorschläge, nicht umgesetzt.

## Bekannte Baustellen

- Der Nutzer-Zweig („Ich möchte tanzen gehen“) legt nichts auf dem Server an.
- `NurEventsAnzeige`, `NurParticipantsView`, `MatchAnfrageView` und
  `AddTanzView` hängen noch an Beispieldaten.
- `Event.swift` und `GrafikKontext.swift` stammen aus dem Vorgängerprojekt
  und werden nicht mehr benutzt.
- Die öffentliche Nominatim-Instanz ist für Dauerbetrieb nicht gedacht; der
  `User-Agent` in `Networking/Geokodierung.swift` muss vor einer
  Veröffentlichung auf eine eigene Kontaktadresse geändert werden.
- Kein Gerätetest der Karten-Gesten: Device Interaction verlangt einen
  iOS-27-Simulator, vorhanden sind nur 26.5.
