# Dokumentation FindDancers

> **🚧 Work in Progress.** Beschreibt den Stand vom 24.09.2026. Die App ist in
> aktiver Entwicklung; Struktur und Feldnamen ändern sich noch.

| Dokument | Inhalt |
| --- | --- |
| [Architektur.md](Architektur.md) | Schichten, Zustandsfluss, Persistenz, Concurrency |
| [EV-API.md](EV-API.md) | Genutzte Endpunkte, Authentifizierung, Eigenheiten des Servers |
| [Event-Formular.md](Event-Formular.md) | Create-Event-Formular: Entwurf, Ort, Karte, Tänze, Kurs-Reihe |

Ergänzend im Repository-Wurzelverzeichnis:

- `integration-aufgaben.md` – offene Aufgabe **in der EV-API**: die Columns
  `taenze` und `engagementTyp` auf `Engagement`.
- `VorschlagStreetValidation.md` – Vorschläge zur Adressvalidierung, nicht
  umgesetzt.

## Wie diese Dokumentation gepflegt werden sollte

Alles hier Beschriebene ist gegen die laufende EV-API geprüft worden, nicht aus
der OpenAPI-Spezifikation abgeleitet. Mehrere Eigenheiten in
[EV-API.md](EV-API.md) stehen **nicht** in `api_docs.json` – wer etwas ändert,
sollte den Aufruf einmal wirklich abschicken und das Ergebnis hier nachziehen,
statt sich auf die Spezifikation zu verlassen.

Was noch fehlt: Dokumentation des Nutzer-Zweigs (Registrierung, Matching,
Chats), sobald der über Platzhalter hinaus ist.
