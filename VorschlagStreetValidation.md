# Vorschläge: Adressvalidierung im Create-Event-Formular

Ideensammlung, **nichts davon ist umgesetzt**. Umgesetzt ist derzeit nur:
4 Sekunden nach der letzten Eingabe in Straße/PLZ/Stadt eine strukturierte
Nominatim-Anfrage, Pin und Karte springen auf den ersten Treffer, darunter eine
Statuszeile (`suche…` / `Gefunden: …` / `nur ohne PLZ gefunden` /
`keine Adresse gefunden`).

Alle Beobachtungen unten sind echte Messungen gegen
`nominatim.openstreetmap.org` vom 24.09.2026, nicht geschätzt.

## Was die Messungen gezeigt haben

| Eingabe | Ergebnis | Problem |
| --- | --- | --- |
| `Rheinstraße 1`, `64283`, `Darmstadt` | 1 Treffer, korrekt | – |
| `Munich` | → „München, Bayern, Deutschland“ | keins, funktioniert |
| `Darmschtadt` | **0 Treffer** | Tippfehler = Sackgasse, keine Korrekturhilfe |
| `Bahnhofstraße 1` ohne Stadt | **5 Treffer** in Zürich, Hannover, Saarbrücken | erster Treffer wird stillschweigend genommen |
| `Hauptstraße 1`, `64283`, `Darmstadt` | 0 Treffer mit PLZ, aber 1 Treffer **in Reinheim (64354)** ohne PLZ | Pin landet im Nachbarort |
| `Rheinstraße 1`, `99999`, `Darmstadt` | 1 Treffer, korrekt | Nominatim ignoriert falsche PLZ teils stillschweigend |

Kernbefund: **Nominatim macht kein Fuzzy-Matching.** Entweder es passt, oder es
kommt ein leeres Array. Ein Buchstabendreher führt also nicht zu „Meinten Sie
…?“, sondern zu Stille. Genau da muss die UI ansetzen.

---

## Vorschlag 1: `MKLocalSearchCompleter` statt Freitext-Feldern

**Priorität: hoch. Aufwand: mittel. Löst Tippfehler, Ähnlichkeit und Sprache in einem Schritt.**

Apples Completer ist tippfehlertolerant, arbeitet ab dem ersten Buchstaben,
liefert lokalisierte Namen und hat kein Rate-Limit. Er ersetzt die Straßen- und
Stadt-Textfelder durch ein Feld mit Vorschlagsliste.

```swift
// Skizze
@Observable final class AdressVervollstaendigung: NSObject, MKLocalSearchCompleterDelegate {
    var vorschlaege: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Auf die Region des Nutzers eingrenzen -> weniger Dubletten
        // completer.region = MKCoordinateRegion(center: standort, ...)
    }

    func aktualisiere(_ text: String) { completer.queryFragment = text }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        vorschlaege = completer.results
    }
}
```

Auswahl eines Vorschlags → `MKLocalSearch(request:)` liefert `MKMapItem` mit
`placemark.thoroughfare`, `.postalCode`, `.locality` und der Koordinate. Damit
sind Straße, PLZ, Stadt **und** Pin in einem Schritt gefüllt und garantiert
konsistent.

Nachteil: andere Datenquelle als Nominatim. Wenn OSM die Referenz bleiben soll,
kann der Completer trotzdem nur als Eingabehilfe dienen und die endgültige
Koordinate weiter von Nominatim kommen.

## Vorschlag 2: Mehrere Treffer anzeigen statt den ersten nehmen

**Priorität: hoch. Aufwand: klein.**

`limit=1` ist die eigentliche Ursache des Zürich/Hannover-Problems. Der Client
kann bereits `limit` setzen, `GeocodeTreffer` ist `Identifiable`.

- Bei genau einem Treffer: wie heute automatisch übernehmen.
- Bei mehreren: Pin **nicht** setzen, stattdessen eine Liste mit
  `anzeigeName` einblenden. Erst die Auswahl setzt Pin und Kamera.
- Sortierung nach `importance` (ist in `GeocodeTreffer.wichtigkeit` schon da).
- Bei Treffern in mehreren Ländern zusätzlich das Land fett hervorheben – das
  ist der Unterschied, den man am leichtesten übersieht.

```swift
if antwort.treffer.count > 1 {
    adressStatus = .mehrdeutig(antwort.treffer)   // neue Statusvariante
}
```

Die Auswahl kann als aufklappbare Liste direkt unter den Adressfeldern sitzen –
passend zum bestehenden `DisclosureGroup` bei den Tänzen und ohne Sheet.

## Vorschlag 3: Rückmeldung, *welches* Feld nicht passt

**Priorität: hoch. Aufwand: klein.**

Heute steht nur „nur ohne PLZ gefunden“. Mit `addressdetails=1` (wird schon
mitgeschickt) liefert Nominatim ein `address`-Objekt. Dekodiert man das, kann
man Eingabe und Treffer feldweise vergleichen:

```swift
struct GeocodeAdresse: Decodable {
    let road: String?
    let postcode: String?
    let city: String?
    let town: String?
    let village: String?
    let country: String?
}
```

Dann konkret formulieren statt vage:

> Gefunden, aber in **Reinheim (64354)** statt in Darmstadt (64283).
> PLZ prüfen oder Pin von Hand setzen.

Das ist der Fall, der heute am gefährlichsten ist: der Nutzer bekommt eine Pin,
die plausibel aussieht, aber 15 km entfernt im Nachbarort liegt.

## Vorschlag 4: Tippfehler abfangen, bevor die Suche ins Leere läuft

**Priorität: mittel. Aufwand: mittel.**

Bei 0 Treffern gestaffelt lockerer suchen, statt sofort aufzugeben:

1. Original (Straße + PLZ + Stadt) – wie heute.
2. Ohne PLZ – wie heute.
3. Ohne Hausnummer (nur Straßenname + Stadt): findet die Straße, Pin auf die
   Straßenmitte, Hinweis „Hausnummer nicht gefunden, Pin auf Straßenmitte“.
4. Nur Stadt: grobe Pin, Hinweis „nur Ort gefunden“.

Erst wenn auch Stufe 4 leer ist, ist es wirklich ein Tippfehler. Dann:

- **Phonetischer Vergleich** gegen die Kandidaten der Stufe 4. Für Deutsch ist
  die **Kölner Phonetik** deutlich besser als Soundex (Soundex ist auf Englisch
  ausgelegt und behandelt `sch`, `ä/ö/ü`, `ß` falsch). `Darmschtadt` und
  `Darmstadt` bekommen in Kölner Phonetik denselben Code.
- **Levenshtein-Distanz** als Fallback: Abstand ≤ 2 bei Wörtern > 5 Zeichen
  als „wahrscheinlich gemeint“ anbieten.

```swift
// Skizze Kölner Phonetik: Ziffernfolge statt Buchstaben
func koelnerPhonetik(_ wort: String) -> String { /* … */ }

let gemeint = kandidaten.filter {
    koelnerPhonetik($0) == koelnerPhonetik(eingabe)
        || levenshtein($0.lowercased(), eingabe.lowercased()) <= 2
}
```

UI: `Meinten Sie Darmstadt?` als antippbarer Vorschlag. **Nicht**
automatisch korrigieren – ein stiller Autokorrekt-Eingriff in eine Adresse ist
schlimmer als eine Rückfrage.

## Vorschlag 5: Deutsche und englische Ortsnamen sichtbar machen

**Priorität: niedrig. Aufwand: klein.**

`Accept-Language: de,en` ist gesetzt und funktioniert (`Munich` → `München`).
Was fehlt, ist die Rückmeldung: der Nutzer tippt „Munich“ und bekommt eine Pin,
ohne zu erfahren, dass die Adresse als „München“ gespeichert wird.

- `anzeigeName` in der Statuszeile steht schon da – gut.
- Zusätzlich anbieten, die Stadt auf die kanonische Schreibweise zu setzen:
  „Stadt als **München** übernehmen?“ (ein Tipp, keine Automatik).
- Für Grenzregionen (Südtirol, Elsass, Belgien) liefert OSM `name:de` und
  `name:it`/`name:fr`. Wenn beides existiert, beide anzeigen, damit klar ist,
  welcher Ort gemeint ist.

## Vorschlag 6: Umgekehrte Richtung – Pin verschieben füllt die Adresse

**Priorität: mittel. Aufwand: klein.**

Der Nutzer kann die Pin ziehen. Danach stehen Adressfelder und Pin im
Widerspruch, und `POST /Venue` speichert die getippte Adresse mit der
verschobenen Koordinate.

Mit `CLGeocoder().reverseGeocodeLocation(_:)` (kein Netz-Policy-Thema, kein
Rate-Limit-Ärger) nach dem Ziehen:

- Weicht die Adresse an der neuen Pin von den Feldern ab: fragen
  „Adresse auf **Rheinstraße 3, 64283 Darmstadt** aktualisieren?“
- Felder nur nach Bestätigung überschreiben – konsistent mit der Regel, dass
  nichts ohne Zutun des Nutzers verändert wird.

## Vorschlag 7: Betrieb und Fairness gegenüber Nominatim

**Priorität: mittel. Aufwand: klein.**

Die öffentliche Nominatim-Instanz erlaubt **1 Anfrage pro Sekunde** und keine
Massennutzung. Heute eingehalten durch das 4-Sekunden-Debounce und 1,1 s Pause
vor der Fallback-Anfrage. Für den Produktivbetrieb zusätzlich:

- **Cache** je Adressschlüssel (`straße|plz|stadt`) für die Sitzung. Beim
  Hin- und Herwischen zwischen den Ortsseiten wird sonst dieselbe Adresse
  mehrfach angefragt.
- Kein erneuter Aufruf, wenn die Adresse unverändert ist – ist umgesetzt
  (`zuletztGesuchteAdresse`).
- `429` wird schon als eigener Fehler erkannt; ein automatischer Retry nach
  ein paar Sekunden wäre sinnvoll, aber mit Obergrenze.
- Bei nennenswerten Nutzerzahlen: eigene Nominatim-Instanz oder ein
  Bezahldienst. Die öffentliche Instanz ist für eine App im Store nicht
  gedacht.

## Vorschlag 8: Kleinigkeiten mit guter Wirkung

- **PLZ-Plausibilität offline**: deutsche PLZ sind fünfstellig und numerisch.
  `64283x` oder `642` lässt sich sofort ohne Netzaufruf bemängeln.
- **Debounce verkürzen, sobald ein Feld den Fokus verliert**: wer von der PLZ
  ins Stadtfeld springt, hat die PLZ fertig getippt – dann muss man nicht
  4 Sekunden warten. `@FocusState` beobachten und sofort suchen.
- **Letzte bestätigte Adresse anbieten**: Organisatoren legen Events oft am
  selben Ort an. Die zuletzt gewählte Venue als Ein-Tipp-Vorschlag oben auf der
  Seite „Bereits hinzugefügter Ort“ spart die ganze Adresseingabe.
- **Land explizit machen**: ein Feld oder ein `countrycodes=de,at,ch` in der
  Anfrage hätte den Zürich-Treffer bei „Bahnhofstraße 1“ verhindert.

---

## Empfohlene Reihenfolge

1. Vorschlag 2 (mehrere Treffer zur Auswahl) – kleinster Aufwand, verhindert
   die falschen Pins, die heute stillschweigend entstehen.
2. Vorschlag 3 (sagen, welches Feld klemmt) – macht den Reinheim-Fall sichtbar.
3. Vorschlag 6 (Reverse-Geocoding nach dem Ziehen) – schließt den Widerspruch
   zwischen Feldern und Pin.
4. Vorschlag 1 (`MKLocalSearchCompleter`) – der große Wurf gegen Tippfehler;
   macht Vorschlag 4 fast vollständig überflüssig.
5. Vorschlag 4 (Phonetik/Levenshtein) – nur, wenn OSM zwingend die einzige
   Datenquelle bleiben soll.

Offene Entscheidung für dich: soll die Adresse weiter frei tippbar bleiben
(dann Vorschläge 2–4), oder darf die Eingabe auf Auswahl aus einer
Vorschlagsliste umgestellt werden (dann Vorschlag 1 und der Rest erledigt sich)?
