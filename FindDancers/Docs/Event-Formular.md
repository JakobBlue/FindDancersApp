# Create-Event-Formular (`NurCreateEvents`)

> 🚧 WIP – Stand 24.09.2026.

Der umfangreichste Bildschirm der App. Alle Eingaben liegen in **einem**
`EventFormularEntwurf`-Wert, der bei jeder Änderung persistiert wird
(siehe [Architektur.md](Architektur.md)).

## Felder und ihr Ziel in der API

| UI | Entwurf | EV-API |
| --- | --- | --- |
| Event Typ | `typ: EventTyp` | `engagementTyp` *(Column fehlt noch)* |
| Name | `name` | `Engagement.title` |
| Beschreibung | `beschreibung` | `Engagement.description` |
| Beginn / Ende | `beginn`, `ende` | `start`, `end` |
| „wöchentlich … bis“ | `letztes_datum_von_Kurs` | – nur lokal, steuert die Schleife |
| Ort | `bestehenderOrtId` **oder** `neuerOrt` | `venueId` |
| Tänze | `taenze: [String: Bool]` | `taenze` *(Column fehlt noch)* |
| Bild | `bildDateiname` | `POST /Engagement/{id}/File` |

`letztes_datum_von_Kurs` heißt absichtlich so wie in der Anforderung, obwohl
der Stil sonst camelCase vorschreibt.

## Ortsauswahl: zwei Seiten, horizontal gewischt

Ein `Engagement` verweist über `venueId` auf eine **bestehende** Venue. Es gibt
deshalb zwei Wege, und dazwischen wird gewischt:

- **Seite 1 „Bereits hinzugefügter Ort“** – Picker über `GET /Venue`.
- **Seite 2 „Neuer Ort“** – Adressfelder + Karte, legt per `POST /Venue` an.

Umgesetzt als `TabView` mit `.tabViewStyle(.page)`, gebunden an
`entwurf.ortModus`. Ein erster Versuch mit `ScrollView` +
`.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)` hat die gespeicherte
Seite beim ersten Layout **nicht** wiederhergestellt: Titel und Indikator
zeigten Seite 2, der Inhalt aber Seite 1. Die Selection des `TabView` tut das
zuverlässig. Wer hier umbaut, sollte genau das nachprüfen.

Die Eingaben beider Seiten bleiben beim Wechseln erhalten, weil beide in
denselben Entwurf schreiben und nie zurückgesetzt werden.

Die Seitenhöhe ist mit `540` fest verdrahtet, damit beim Wischen nichts
springt. Kommt ein Element auf Seite 2 dazu, muss dieser Wert mitwachsen.

### „Name der Location“

Hieß früher „Ortsname“ und war missverständlich – gemeint ist der Name der
Spielstätte (`Venue.name`), nicht die Stadt. Das Feld ist das einzige mit
`axis: .vertical` und `.lineLimit(1...5)`: es beginnt einzeilig und wächst mit
dem Text bis auf fünf Zeilen, danach scrollt es intern. Lange Namen wie
„Bürgerhaus am Bürgerpark, Großer Saal im Obergeschoss“ passen so ohne
abgeschnittenen Text.

## Adresssuche (Geokodierung)

4 Sekunden nach der letzten Eingabe in Straße, PLZ oder Stadt fragt
`Geokodierung.suche(strasse:plz:stadt:)` bei Nominatim nach; Pin und Kamera
springen auf den Treffer.

Das Debounce ist `.task(id: adressSchluessel)` – SwiftUI bricht den laufenden
Task bei jeder Änderung ab und startet ihn neu, die Wartezeit beginnt also nach
dem letzten Tastendruck von vorn.

Zwei Dinge, die nicht offensichtlich sind:

- **Beim Öffnen wird nicht gesucht.** `zuletztGesuchteAdresse` wird im `init`
  aus dem geladenen Entwurf vorbelegt. Sonst würde eine von Hand verschobene
  Pin beim nächsten Öffnen des Formulars überschrieben.
- **PLZ-Fallback.** Bleibt die Suche mit PLZ leer, wird einmal ohne PLZ
  nachgefragt (mit 1,1 s Pause wegen des Rate-Limits). Findet sie dann etwas,
  warnt die UI. Beispiel: „Hauptstraße 1, 64283 Darmstadt“ liefert mit PLZ
  nichts, ohne PLZ aber einen Treffer in **Reinheim (64354)** – ohne Warnung
  läge die Pin unbemerkt im Nachbarort.

Die Suche ist **strukturiert** (`street=`, `postalcode=`, `city=`) statt als
Freitext-`q`, weil Nominatim dann weiß, welcher Teil was ist.
`Accept-Language: de,en` sorgt dafür, dass „Munich“ und „München“ beide
funktionieren.

Grenzen der aktuellen Lösung und Ideen dazu:
`../../VorschlagStreetValidation.md`.

## Karte (`OrtKarteView`)

Koordinaten werden nicht getippt. Drei Wege setzen die Pin:

1. **Aktueller Standort** – beim ersten Öffnen ohne gespeicherte Position,
   außerdem per Button.
2. **Pin ziehen** – gerechnet über `MapProxy.convert`: Bildschirmpunkt der Pin
   plus Verschiebung, zurück in eine Koordinate. Während des Ziehens bewegt
   sich nur ein `offset`; gesetzt wird erst beim Loslassen.
3. **Karte antippen** – zweiter Weg, weil eine 32 pt große Pin ein kleines
   Ziel ist.

`zentrierungsAnstoss` ist ein Zähler, den das Formular nach einem
Geocoding-Treffer erhöht. Bewusst ein Anstoß und keine Reaktion auf jede
Koordinatenänderung: sonst würde die Kamera dem Nutzer beim Ziehen
hinterherlaufen.

**Nicht am Gerät geprüft:** ob die Zieh-Geste auf der Annotation gegen die
Pan-Geste der Karte gewinnt. Previews rendern MapKit-Inhalte verzögert, und
Device Interaction verlangt einen iOS-27-Simulator. Falls das Ziehen klemmt,
bleibt Antippen als Ausweg.

## Tänze

`TanzKatalog` ist die einzige Quelle für die 19 Tanznamen (Reihenfolge und
Schreibweise wie in `NurEventsAnzeige`). Die Namen sind gleichzeitig die
Schlüssel der `taenze`-Column und dürfen nicht umbenannt werden, ohne die Daten
zu migrieren.

Dargestellt als `DisclosureGroup` mit einem `VStack` von Zeilen – **keine**
`List` wie in `AddTanzView`, weil das Formular selbst in einem `ScrollView`
steckt und eine verschachtelte `List` einen zweiten vertikalen Scrollbereich
aufziehen würde. Sortierung `sorted(by: >)`, wie in den bestehenden Views.

Die App sendet immer **alle** Tänze, auch die mit `false`. Ein fehlender
Schlüssel bedeutet „unbekannt“, nicht „nein“.

## Kurs-Reihe

Bei `typ == .Kurs` wechselt die Datumsauswahl: die beiden Picker beschreiben
den **ersten** Termin, darunter kommt „wöchentlich gleich bleibend bis“
(nur Datum). Beim Umschalten auf „Kurs“ wird das Enddatum mit
`beginn + 7 Tage` vorbelegt, damit der Picker einen Wert hat.

`EventFormularEntwurf.kursTermine` erzeugt die Liste:

- Schrittweite 7 Tage über `Calendar.date(byAdding: .day, value: 7, …)`. Das
  rechnet kalendarisch, die Uhrzeit bleibt deshalb auch über eine
  Zeitumstellung gleich – geprüft über den 25.10.2026 hinweg.
- Verglichen wird auf **Tagesebene**; die Uhrzeit des Enddatums ist egal.
- Der Termin **auf** dem Enddatum wird mitgeschickt (inklusiv).
- Liegt das Enddatum vor dem ersten Termin, ist die Liste leer und es entsteht
  ein einzelnes Event.
- Sicherheitsnetz bei 520 Terminen (10 Jahre) gegen eine Endlosschleife.

Beim Anlegen läuft dann pro Termin ein `POST /Engagement` plus
`PUT /Engagement/{id}/Organizers`. Gleich bleiben Typ, Ort, Name, Beschreibung
und Tänze; nur `start`/`end` wandern.

Zwei Dinge passieren **nur einmal**, nicht pro Termin:

- Die Venue wird vor der Schleife angelegt – sonst entstehen N Dubletten.
- Das Bild hängt nur am ersten Termin.

Bricht die Schleife in der Mitte ab, nennt die Fehlermeldung, wie viele
Termine schon auf dem Server liegen, und das Formular wird **nicht** geleert.
Sonst legt man beim zweiten Versuch Dubletten an.

## Validierung

„Event erstellen“ ist aktiv, wenn ein Name da ist, `ende >= beginn` gilt und
der neue Ort entweder komplett leer **oder** vollständig ist. Teilweise
gefüllt wird blockiert, weil `POST /Venue` das ablehnt; welche Felder fehlen,
steht unter der Seite.

Es gibt bewusst **keine Reset-Buttons** in den Adressfeldern – Korrekturen
laufen über die Tastatur.
