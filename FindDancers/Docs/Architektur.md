# Architektur

> 🚧 WIP – Stand 24.09.2026.

## Schichten

```
Views/                  SwiftUI, MainActor
   │  liest/schreibt
   ▼
Data Models/            Wertetypen + Persistenz (nonisolated, Sendable)
   │  ruft
   ▼
Networking/             EVAPIClient (actor), Geokodierung (enum)
   │
   ▼
EV-API @ localhost:8080 / Nominatim
```

Es gibt kein ViewModel-Layer. Die Views halten ihren Zustand in `@State`, die
Wertetypen in `Data Models/` rechnen, und `Networking/` spricht mit der Welt.
Für den aktuellen Umfang ist das ausreichend; wenn ein Zustand von mehreren
Bildschirmen gebraucht wird, ist das der Punkt, an dem es sich lohnt,
`@Observable` einzuziehen.

Combine wird bewusst nicht benutzt (siehe `CLAUDE.md`), alles Asynchrone läuft
über `async`/`await`.

## Concurrency

Das Projekt baut mit `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` und
`SWIFT_APPROACHABLE_CONCURRENCY = YES`. Jeder Typ ist also standardmäßig an den
MainActor gebunden.

Konsequenz: alles, was der `EVAPIClient`-Actor benutzt, muss ausdrücklich
`nonisolated` sein. Deshalb steht bei den Modellen, beim `EventFormularStore`,
beim `StandortDienst`, bei `Geokodierung` und sogar bei einer privaten
`Data`-Extension ein `nonisolated` vor der Deklaration. Fehlt es, kommt beim
Bauen „Main actor-isolated … cannot be called from outside of the actor“.

## Zustand und Persistenz

Drei getrennte Speicherorte, jeder mit eigenem Grund:

| Was | Wo | Warum dort |
| --- | --- | --- |
| Angemeldeter Nutzer (`AppSessionData`) | `session.json` im Documents-Verzeichnis | überlebt Neustarts, unkritischer Inhalt |
| Zugangsdaten für HTTP Basic | **Keychain** (`EVCredentialStore`) | das Passwort wird bei jeder Anfrage erneut gebraucht und darf nicht in einer JSON-Datei liegen |
| Event-Formular-Entwurf | `event-formular-entwurf.json` + Ordner `event-formular-bilder` | soll auch einen plötzlichen Stromausfall überleben |

### Warum der Entwurf bei jeder Änderung geschrieben wird

`EventFormularStore.speichern(_:)` wird aus `onChange(of: entwurf)` bei **jeder**
Änderung aufgerufen, also bei jedem Tastendruck, und schreibt atomar
(`.atomic`). Nicht erst beim Wechsel in den Hintergrund: wenn der Akku von 1 %
auf 0 % geht, bekommt die App keinen Lifecycle-Callback mehr. Ein atomarer
Write kann außerdem keine halb geschriebene Datei hinterlassen.

Die Datei ist klein (< 1 KB), der Schreibvorgang ist deshalb unkritisch.

### Fehlertolerantes Decoding

`EventFormularEntwurf` und `NeuerOrtEntwurf` haben handgeschriebene
`init(from:)`, die **jedes Feld einzeln** mit `try?` lesen und auf einen
Standardwert zurückfallen. Grund: ein Entwurf, der mit einer älteren Version der
App geschrieben wurde, soll nicht komplett verloren gehen, nur weil ein Feld
fehlt oder den Typ gewechselt hat.

Konkrete Fälle, die dadurch überlebt haben:

- `taenze` wird über `TanzKatalog.normalisiert(_:)` auf den aktuellen Katalog
  gezogen – unbekannte Tänze fallen raus, neue kommen als `false` dazu.
- `latitude`/`longitude` waren früher `String` (mit Komma als Dezimaltrenner)
  und sind heute `Double?`. Der Decoder liest beides.

Eine kaputte Datei führt zu einem leeren Formular, nicht zu einem Absturz.

## Standort

`StandortDienst.aktuellePosition()` iteriert über
`CLLocationUpdate.liveUpdates()` und verlässt die Schleife nach dem ersten Fix.
Diese API fragt die Berechtigung beim ersten Iterieren selbst ab – ein eigener
`CLLocationManager` samt Delegate ist nicht nötig, und es bleibt bei
`async`/`await`.

Die Berechtigungstexte stehen **nicht** in `Info.plist`, sondern als
Build-Setting `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`. In der
gebauten `.app` landen sie trotzdem korrekt in der `Info.plist`.

## Netzwerkkonfiguration

- `Info.plist` enthält `NSAppTransportSecurity` → `NSAllowsLocalNetworking`,
  damit der Simulator das unverschlüsselte `http://localhost:8080` erreichen
  darf. Nominatim läuft über HTTPS und braucht keine Ausnahme.
- Der Ordner `FindDancers/` ist eine **file-system-synchronized group**. Jede
  Datei, die dort abgelegt wird, gehört automatisch zum Target – auch
  Nicht-Quelldateien. `api_docs.json` liegt deshalb im App-Bundle, und diese
  Markdown-Dateien tun es ebenfalls. Wer das nicht will, muss die Dateien im
  File Inspector aus der Target-Mitgliedschaft nehmen oder außerhalb des
  Ordners ablegen.

## Was bewusst nicht gemacht wurde

- **Kein ViewModel pro View.** Der Zustand des Create-Event-Formulars steckt
  komplett in einem `EventFormularEntwurf`-Wert; das macht Persistenz und
  Gleichheitsvergleich (`onChange`) trivial.
- **Kein Caching der EV-API-Antworten.** Venues werden bei jedem Öffnen des
  Formulars neu geladen.
- **Keine Offline-Warteschlange.** Fällt die API aus, schlägt das Anlegen fehl
  und der Entwurf bleibt erhalten – ein erneuter Versuch ist Handarbeit.
