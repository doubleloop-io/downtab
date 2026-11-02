# Obiettivo di Downtab

## Intento

Downtab è un app switcher macOS personale. Il primo livello si comporta come il ⌘Tab nativo, ma permette anche di scendere alle singole finestre di un'app e di portare in primo piano solo quella.

Nasce perché AltTab e Witch non soddisfano pienamente l'esigenza: AltTab ha il comportamento giusto, ma una UI che mescola app e finestre e non si può cambiare. Downtab mantiene il gesto familiare del nativo e aggiunge solo il livello delle finestre.

## Comportamento

- Prima riga: app in ordine MRU, come il nativo.
- Le app con più finestre mostrano il numero e una freccia in basso (`3 ▾`), che suggerisce il gesto.
- `↓` su un'app mostra le sue finestre; frecce + `Enter` (o rilascio del modificatore) portano in primo piano solo quella finestra.
- Si passa solo fra finestre dello Space attuale.
- ⌘` sostituisce il ciclo nativo fra finestre dell'app attiva: apre il selettore con l'app attiva selezionata e la lista delle sue finestre già aperta sotto.

## Decisioni UI

Scelta la variante A di `prototype-ui-variants.html`: lista sotto l'icona. La griglia (variante E) è scartata per ora: senza anteprime i titoli si scorrono meglio in colonna, e `←` `→` restano liberi per cambiare app.

- Le app senza finestre nello Space attuale, ma con finestre in altri Space, non compaiono: attivarle farebbe cambiare Space. Le app senza alcuna finestra restano, come nel nativo.
- Da un'app a schermo intero compaiono tutte le app, come nel nativo. Da decidere più avanti se elencare tutte le finestre o nessuna.
- Le finestre minimizzate dello Space attuale compaiono nella lista con un'etichetta. Quelle di altri Space no: il ripristino le riporta nel loro Space, senza effetti visibili.
- La riga delle app non si muove mai e resta identica al nativo.
- `←` `→` a livello finestre cambiano app restando a livello finestre.
- `↑` dalla prima finestra torna alle app; `Tab` torna sempre alle app e avanza.
- Il rilascio del modificatore conferma sempre, a qualsiasi livello; `Esc` annulla.
- `↓` sull'app già in primo piano seleziona la sua seconda finestra, perché la prima è quella da cui si parte.
- ⌘` seleziona subito la seconda finestra dell'app attiva; ogni ulteriore pressione avanza, ⇧ torna indietro. Da quel punto valgono le stesse regole del livello finestre.
- Solo titoli, niente thumbnail: evita il permesso Screen Recording e la latenza di cattura.

## Stack

Scelti Swift + AppKit, app non sandboxed fuori dal Mac App Store.

| Bisogno | API |
| --- | --- |
| Intercettare i tasti | Hotkey Carbon (`RegisterEventHotKey`); ⌘Tab richiede anche `CGSSetSymbolicHotKeyEnabled`, privata (da AltTab, non provato) |
| Rilascio del modificatore | `CGEventTap` in solo ascolto (permesso Accessibility) |
| Pannello che non ruba il focus | `NSPanel` con `.nonactivatingPanel` |
| Elenco e titoli finestre | `AXUIElement`, id con `_AXUIElementGetWindow` (privata); i titoli non vengono da `CGWindowList`, che richiederebbe Screen Recording |
| Space delle finestre | `CGSCopySpacesForWindows` e `CGSCopyManagedDisplaySpaces` (private) |
| Alzare una sola finestra | `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo` (private) + `AXRaise` |

Motivi: le parti difficili sono API native che ogni stack dovrebbe comunque chiamare, e AltTab, il riferimento da cui prendere ispirazione, è scritto così. Electron e Tauri semplificherebbero solo la UI, che qui è la parte più piccola.

Swift e AppKit sono sconosciuti all'autore, che non intende leggere il codice: il progetto si valuta dal comportamento, non dalla lettura del sorgente.

Provato su macOS 27.0.1 con ⌥ al posto di ⌘: esito e limiti in `spike-results.md`.

## Spike

Concluso con go con riserva. Istruzioni in `SPIKE.md`, esito, ricette e rischi aperti in `spike-results.md`.
