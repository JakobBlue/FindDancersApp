# EV-API-Anbindung

> 🚧 WIP – Stand 24.09.2026. Alles hier ist gegen die laufende API geprüft,
> nicht aus `api_docs.json` abgeleitet. Mehrere Punkte stehen so **nicht** in
> der Spezifikation.

Basis-URL: `http://localhost:8080` (`EVAPIConfiguration.baseURL`).
Die API ist generiert („kiwi“-Framework, Package `de.wdw.ev`).

## Authentifizierung

HTTP Basic, global für alle Operationen (`security` in der Spezifikation).
`EVAPIClient` verwaltet die Zugangsdaten und legt sie im Keychain ab.

Drei Dinge, die man wissen muss:

1. **Benutzername ist die E-Mail, nicht der Name.** Mit dem `name` eines
   `UserAccount` kommt `401`.
2. **Es gibt keinen Login-Endpunkt.** `signIn(email:password:)` macht ein
   authentifiziertes `GET /UserAccount` – das ist gleichzeitig Passwortprüfung
   und der Weg, den zugehörigen Organizer zu finden.
3. **Falsche Zugangsdaten sind schlimmer als keine.** Auf Endpunkten, die
   anonym erlaubt sind, führt ein `Authorization`-Header mit ungültigen Daten
   zu `401`, bevor der Handler erreicht wird. Deshalb hat der Client ein
   explizites `Anmeldung`-Enum (`.gespeicherte` / `.explizit` / `.keine`), und
   `POST /UserAccount` nutzt `.keine`.

Wer darf was ohne Anmeldung:

| Endpunkt | anonym |
| --- | --- |
| `GET /Organizer`, `GET /Engagement`, `GET /Venue` | ✅ |
| `POST /UserAccount` | ✅ (sonst wäre Registrierung unmöglich) |
| `GET /UserAccount` | ❌ `403 access-denied` |
| alles Schreibende außer `POST /UserAccount` | ❌ |

## Genutzte Endpunkte

| Aufruf | Methode im Client |
| --- | --- |
| `POST /UserAccount` | `createUserAccount(name:email:password:)` |
| `GET /UserAccount?_fields=…` | `signIn(email:password:)` |
| `POST /Organizer` | `createOrganizer(name:)` |
| `PUT /Organizer/{id}/Staff/{userAccountId}` | `addStaff(organizerId:userAccountId:)` |
| `GET /Venue` | `venues()` |
| `POST /Venue` | `createVenue(_:)` |
| `POST /Engagement` | `createEngagement(…)` |
| `PUT /Engagement/{id}/Organizers` | `assignOrganizers(engagementId:organizerIds:)` |
| `POST /Engagement/{id}/File` | `attachFile(…)` |

## Eigenheiten, die Zeit gekostet haben

### Relationen kommen nur auf Anfrage

`GET /UserAccount` liefert `organizer` **nicht** mit, auch wenn die
Staff-Verknüpfung existiert. Nötig ist
`?_fields=id,name,email,organizer`. Ohne das kann die Anmeldung die
`organizerId` nie ermitteln, und neu erstellte Events werden keinem Organisator
zugeordnet.

Gleiches Muster bei `GET /Engagement?_fields=id,title,attachments`.

### Registrierung braucht drei Aufrufe

`Organizer` hat nur einen Namen, die Zugangsdaten hängen am `UserAccount`.
`registerOrganizer(name:email:password:)` macht deshalb:

1. `POST /UserAccount` – **ohne** `Authorization`-Header
2. Zugangsdaten übernehmen
3. `POST /Organizer` – braucht Authentifizierung
4. `PUT /Organizer/{organizerId}/Staff/{userAccountId}`

Schlägt Schritt 3 oder 4 fehl, werden die Zugangsdaten wieder verworfen.

### `POST /Venue` verlangt jedes Feld

Fehlt eines von `name`, `streetNr`, `zipcode`, `city`, `latitude`, `longitude`,
antwortet der Server mit `entity-field-missing-value`
(`de.kiwi.api.domain.EntityFieldMissingValue`). Ein Ort lässt sich also nicht
aus einem einzelnen Ortsnamen anlegen – daher die Adressfelder plus Karte im
Formular.

### Datumsformat

`start` und `end` sind Strings im Format einer Java-`LocalDateTime`, also ISO
**ohne** Zeitzonensuffix: `2026-10-01T20:00:00`. `EVAPIDateFormat` erzeugt das
mit `Date.ISO8601FormatStyle` ohne `timeZone()`-Komponente.

Ein leerer String als `venueId` ist nie gültig (`entity-not-found`); das Feld
wird stattdessen weggelassen, wenn kein Ort gewählt ist.

### Unbekannte Felder werden verworfen

`POST /Engagement` akzeptiert Felder, die der Server nicht kennt, und antwortet
trotzdem `201` – sie werden einfach ignoriert. Deshalb kann die App `taenze`
und `engagementTyp` bereits mitsenden, obwohl die Columns noch fehlen. Sobald
das Backend sie kennt (siehe `integration-aufgaben.md`), greifen sie ohne
Änderung in der App.

Kehrseite: ein Tippfehler in einem Feldnamen fällt **nicht** auf.

### Löschen nur in der richtigen Reihenfolge

Ein `DELETE` auf eine Entität mit bestehenden Relationen endet in `500`.
Reihenfolge beim Aufräumen:

```bash
# 1. Anhänge
DELETE /FileEntity/{id}
# 2. Organizer-Zuordnung leeren
PUT    /Engagement/{id}/Organizers   []
# 3. Engagement, dann Venue
DELETE /Engagement/{id}
DELETE /Venue/{id}
# 4. UserAccount (löst die Staff-Verknüpfung), dann Organizer
DELETE /UserAccount/{id}
DELETE /Organizer/{id}
```

Der `UserAccount`, mit dem man sich authentifiziert, sollte zuletzt weg – sonst
fehlt die Anmeldung für die restlichen Löschungen.

## Bild-Upload

`POST /Engagement/{id}/File?isPublic=true` als `multipart/form-data` mit dem
Feldnamen `file`. Der Body wird in `attachFile(…)` von Hand zusammengesetzt.

Wichtig: die EngagementId gibt es erst **nach** `POST /Engagement`. Der Upload
ist deshalb immer der zweite Schritt und kann nicht in der Bildauswahl
passieren. Bei einer Kurs-Reihe hängt das Bild nur am ersten Termin.

Geprüft: der Server übernimmt Dateiname und `contentType` unverändert und
meldet die exakte Byte-Größe zurück.

## Fehlerbehandlung

`EVAPIError` mit deutschen `errorDescription`s. `401` und `403` werden beide
auf `.unauthorized` („Name oder Passwort ist falsch.“) abgebildet. Bei anderen
Statuscodes wird `message` aus dem Fehler-Body gelesen
(`{"message":"…","errorType":"…"}`).
