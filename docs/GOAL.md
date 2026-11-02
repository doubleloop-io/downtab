# Obiettivo di Downtab

## Intento

Downtab è un app switcher macOS personale. Il primo livello si comporta come il ⌘Tab nativo, ma permette anche di scendere alle singole finestre di un'app e di portare in primo piano solo quella.

Nasce perché AltTab e Witch non soddisfano pienamente l'esigenza: AltTab ha il comportamento giusto, ma una UI che mescola app e finestre e non si può cambiare. Downtab mantiene il gesto familiare del nativo e aggiunge solo il livello delle finestre.

I termini sono definiti in `GLOSSARY.md`.

## Comportamento

- App row: app in ordine MRU, come il nativo.
- Le app con almeno 2 finestre mostrano il Window count badge (`3 ▾`), che suggerisce il gesto.
- `↓` su un'app con almeno 2 finestre apre la sua Window list; frecce + `Enter` (o rilascio del Modifier) portano in primo piano solo quella finestra. Con 0 o 1 finestra `↓` non fa niente.
- Si passa solo fra finestre del Current Space.
- La Window shortcut sostituisce il ciclo nativo fra finestre dell'app attiva: apre lo Switcher sul Frontmost app con la Window list già aperta sotto.

## Decisioni UI

Scelta la variante A di `prototype-ui-variants.html`: lista sotto l'icona. La griglia (variante E) è scartata per ora: senza anteprime i titoli si scorrono meglio in colonna, e `←` `→` restano liberi per cambiare app.

### Cosa compare

- Le app senza finestre nel Current Space, ma con finestre in altri Space, non compaiono: attivarle farebbe cambiare Space. Le app senza alcuna finestra restano, come nel nativo.
- Eccezione: un'app la cui unica finestra è a schermo intero compare, come nel nativo, e attivarla porta al suo Space.
- Una finestra a schermo intero compare nella Window list con l'etichetta "schermo intero"; sceglierla cambia Space.
- Da un'app a schermo intero compaiono tutte le app, come nel nativo, ma senza Window list: solo App level. Da rivedere con l'uso.
- Le finestre minimizzate del Current Space compaiono nella lista con un'etichetta. Quelle di altri Space no: il ripristino le riporta nel loro Space, senza effetti visibili.
- Le app nascoste (⌘H) compaiono con le loro finestre e l'etichetta "nascosta"; scegliere una finestra la mostra.
- Con più monitor il Current Space è l'insieme degli Space correnti di tutti i display. Lo Switcher appare sullo schermo del puntatore.
- Ogni processo è una voce a sé, come nel nativo: due istanze della stessa app (es. Chrome dell'utente e Chrome di un agente) restano indistinguibili.
- Solo titoli, niente thumbnail: evita il permesso Screen Recording e la latenza di cattura. Finestra senza titolo: "Senza titolo". I titoli doppi restano come sono.

### Ordine

- App: MRU. All'avvio Downtab non conosce la storia: parte dall'ordine di `CGWindowList`, poi registra ogni attivazione.
- Finestre: ordine z dell'app, minimizzate in fondo.

### Navigazione

- La App row non si muove mai e resta identica al nativo.
- `←` `→` a Window level cambiano app restando a Window level. Su un'app con meno di 2 finestre la selezione resta sull'app, senza lista; il passo successivo riapre la lista della prossima app che ne ha una.
- `↑` dalla prima finestra torna ad App level; il tasto della App shortcut torna sempre ad App level e avanza.
- Il rilascio del Modifier conferma sempre, a qualsiasi livello; `Esc` annulla.
- `↓` sul Frontmost app seleziona la sua seconda finestra, perché la prima è quella da cui si parte.
- La Window shortcut seleziona subito la seconda finestra del Frontmost app; ogni ulteriore pressione avanza, ⇧ torna indietro. Da quel punto valgono le stesse regole del Window level. Con meno di 2 finestre non fa niente.
- Pressione rapida: se il Modifier si rilascia entro un breve ritardo (circa 100 ms, da tarare), si conferma senza mostrare lo Switcher. Vale per entrambe le scorciatoie.
- Escluso dalla prima versione: mouse, `Q` per chiudere e `H` per nascondere un'app.

## Scorciatoie

- Default: App shortcut ⌥Tab, Window shortcut ⌥`. Ciascuna si registra liberamente nelle Preferences; un pulsante ripristina i default.
- Il Modifier è quello della scorciatoia che ha aperto lo Switcher: basta rilasciarne uno dei tasti per confermare.
- Dentro lo Switcher contano i soli tasti delle due scorciatoie, premuti con il Modifier di apertura.
- Registrazione: almeno un modificatore; ⇧ vietato, serve per tornare indietro; le due scorciatoie devono essere diverse. Una scorciatoia già usata dal sistema si rifiuta con un messaggio.
- Solo se si registra ⌘Tab o ⌘` Downtab spegne la scorciatoia nativa, e la riaccende quando esce o la scorciatoia cambia. In questo caso il ripristino di emergenza di `alttab-notes.md` è obbligatorio prima dell'uso quotidiano.

## App

- Avvio al login, attivo di default.
- Icona nella barra dei menu: apre le Preferences, chiude l'app, segnala se manca il permesso Accessibility.
- Preferences: le due scorciatoie, l'avvio al login, lo stato del permesso Accessibility con un pulsante che apre Impostazioni di Sistema.
- Primo avvio senza permesso: si aprono le Preferences con il permesso evidenziato; le scorciatoie non fanno niente finché il permesso non c'è.

## Stack

Scelti Swift + AppKit, app non sandboxed fuori dal Mac App Store.

| Bisogno | API |
| --- | --- |
| Intercettare i tasti | Hotkey Carbon (`RegisterEventHotKey`); ⌘Tab e ⌘` richiedono anche `CGSSetSymbolicHotKeyEnabled`, privata (da AltTab, non provato) |
| Rilascio del modificatore | `CGEventTap` in solo ascolto (permesso Accessibility) |
| Pannello che non ruba il focus | `NSPanel` con `.nonactivatingPanel` |
| Elenco e titoli finestre | `AXUIElement`, id con `_AXUIElementGetWindow` (privata); i titoli non vengono da `CGWindowList`, che richiederebbe Screen Recording |
| Space delle finestre | `CGSCopySpacesForWindows` e `CGSCopyManagedDisplaySpaces` (private) |
| Alzare una sola finestra | `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo` (private) + `AXRaise` |

Motivi: le parti difficili sono API native che ogni stack dovrebbe comunque chiamare, e AltTab, il riferimento da cui prendere ispirazione, è scritto così. Electron e Tauri semplificherebbero solo la UI, che qui è la parte più piccola.

Swift e AppKit sono sconosciuti all'autore, che non intende leggere il codice: il progetto si valuta dal comportamento, non dalla lettura del sorgente.

Provato su macOS 27.0.1 con ⌥ al posto di ⌘: esito e limiti in `spike-results.md`.

## Rischi

- Più monitor: mai provati nello spike.
- Scorciatoie già usate dal sistema: si riconoscono solo i casi noti e quelli in cui `RegisterEventHotKey` fallisce.
- Spegnimento di ⌘Tab e ⌘` nativi: mai provato.

## Spike

Concluso con go con riserva. Istruzioni in `SPIKE.md`, esito, ricette e rischi aperti in `spike-results.md`.
