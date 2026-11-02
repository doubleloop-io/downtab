# Risultati dello spike

Esito di `SPIKE.md` e tutto ciò che serve per riscrivere l'app senza rileggere il codice dello spike. L'analisi di AltTab è in `alttab-notes.md`; dove i due file divergono, vale questo.

**Verdetto: go con riserva.** Nessun punto è fallito con le API private. L'autore ha chiuso le prove: quanto elencato sotto "Non eseguito" resta non verificato e passa all'app vera come rischio noto.

- **AltTab analizzato:** commit `c500294bdb01186011a5c64a412b04cef9931bef` (11.10.1), licenza GPL-3.0. Lo spike non copia codice, ma è scritto dopo aver letto quel sorgente, da cui riprende firme, offset e parametri.
- **Ambiente:** macOS 27.0.1 (26A434), arm64, Swift 6.4, solo Command Line Tools, tastiera ANSI, layout U.S., ⌥\` su keycode 50.
- **Permessi:** solo Accessibility, rimasto valido dopo le ricompilazioni. Lo spike non ha chiesto Screen Recording.

## Risultati

| Punto | Esito | Misurato dallo spike | Provato dall'autore |
| --- | --- | --- | --- |
| 1. Intercettazione | Passa, con prove mancanti | 80 rilasci su 80 dal tap, 0 dal controllo di riserva, 14 entro 300 ms dall'apertura. Tap riattivato dopo una disattivazione simulata. | Nessuna anomalia del pannello. |
| 2. Pannello | Passa, con limite | Dopo `Esc`: app e finestra giuste in 4 casi su 4, controllo diverso in 2. | Appare sopra lo schermo intero. Dopo `Esc` si torna nell'editor. |
| 3. Una sola finestra | Passa con API private, con un'anomalia | VS Code, Chrome, Finder, TextEdit: focus sempre giusto. Finestre spostate: quasi sempre 0, contro 10 su 10 di VS Code con le API pubbliche. | Una volta TextEdit ha portato avanti tutte e 3 le finestre: mai riprodotto, nessuna traccia nei log conservati. |
| 4. Elenco | Passa, con un controllo mancante | Raggruppamento, titoli, fantasmi esclusi, tab di Finder, Vivaldi solo in altro Space, VS Code in due Space. | Finestra di VS Code aperta nell'altro Space. |
| 5. Velocità | Passa | 58 aperture in 2 esecuzioni, 18 app, fino a 31 finestre: mediana 42,2 ms, p95 56,5 ms, massimo 67,6 ms. Ultima esecuzione, 26 aperture: mediana 37,0 ms, p95 66,1 ms, massimo 73,6 ms. | "Velocità ottima". |

**Non eseguito:**

- 10 minuti continui: le due esecuzioni più lunghe durano circa 5 minuti ciascuna.
- Timeout reale del tap: provocato solo per simulazione.
- `Enter` per confermare, che non compare nei log conservati.
- Filtro delle minimizzate in altri Space: compilato, mai incontrato in esecuzione.
- Più monitor, app lente o bloccate.
- ⌘Tab e ⌘\`: fuori scope. La loro fattibilità viene dalla lettura di AltTab, non da queste prove.

## Decisioni dell'autore

- Le app senza finestre, come Zoom e iTerm2, restano visibili, come nel nativo.
- Da un'app a schermo intero compaiono tutte le app, come nel nativo. Se elencare tutte le finestre o nessuna si decide più avanti.
- Le minimizzate di altri Space sono nascoste. La scelta è stata proposta dallo spike ed è registrata in `GOAL.md`.

## Cosa non ha funzionato con le API pubbliche

| Bisogno | Prova pubblica | Risultato |
| --- | --- | --- |
| Alzare una finestra | `activate()`, `kAXFrontmost`, `kAXMain`, `AXRaise` | Il focus arriva, ma si alzano anche le altre finestre dell'app: VS Code 10 su 10, Chrome 4, Finder 1. |
| Riconoscere le app solo in altri Space | Finestre di livello 0, almeno 100×50, fuori schermo in `CGWindowList` | Falsi positivi: Zoom e iTerm2 hanno finestre di servizio fuori schermo e sarebbero state nascoste. |
| Escludere le finestre finte | Ruolo e subrole AX | cmux espone `AXDialog` con titolo `Item-0` e `Item-1`, senza finestra reale. |

## API private

| API | Serve a | Se smette di funzionare |
| --- | --- | --- |
| `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`, `GetProcessForPID` | Alzare una sola finestra e darle il focus | Si ripiega su `activate`, che alza l'intera app e perde il valore del progetto. Una modifica della struttura dell'evento può anche far crashare. |
| `_AXUIElementGetWindow` | Id della finestra, esclusione dei fantasmi | Tutte le finestre vengono scartate: elenchi vuoti, va cambiato il codice. |
| `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, `CGSCopySpacesForWindows` | Space delle finestre | Si perde il riconoscimento delle app solo in altri Space e delle minimizzate in altri Space. |

Tutte sono risolte a runtime con `dlsym`: un simbolo assente produce una riga di log, non un errore all'avvio. `_AXUIElementGetWindow` e `GetProcessForPID` si cercano con `RTLD_DEFAULT`, le altre in `/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight`.

Firme usate:

```
CGSMainConnectionID() -> UInt32
CGSCopyManagedDisplaySpaces(cid) -> CFArray     // ogni display: "Current Space" -> "id64"
CGSCopySpacesForWindows(cid, 7, [wid]) -> CFArray of UInt64     // 7 = tutti gli Space
_SLPSSetFrontProcessWithOptions(&psn, wid, 0x200) -> Int32
SLPSPostEventRecordTo(&psn, bytes) -> Int32
_AXUIElementGetWindow(element, &wid) -> AXError
GetProcessForPID(pid, &psn) -> OSStatus
```

## Ricetta: alzare una finestra

Su una coda seriale fuori dal main thread:

1. Se minimizzata: `kAXMinimized = false`.
2. `_SLPSSetFrontProcessWithOptions(&psn, wid, 0x200)`.
3. `SLPSPostEventRecordTo(&psn, record)`, con il record descritto sotto.
4. `AXUIElementPerformAction(window, kAXRaiseAction)`.
5. Dopo 150 ms, se la finestra non è la prima di `CGWindowList`, ripetere il raise.

Il pannello si chiude al termine della sequenza, o comunque dopo 100 ms. Per un'app senza finestre si usa solo `activate()`: con iTerm2 senza finestre l'app è venuta in primo piano.

**Record dell'evento:** buffer di `0x100` byte azzerati, con questi campi:

| Offset | Valore | Note |
| --- | --- | --- |
| `0x04` | `0xf8` | Lunghezza dichiarata |
| `0x08` | `0x01` | Solo mouse-down, mai l'up |
| `0x20` | `CGPoint(300000, 300000)` | Lontano dalla finestra: vicino al bordo macOS 27 la ridimensiona |
| `0x3a` | `0x10` | Campo non documentato |
| `0x3c` | `wid` | Destinatario dell'evento |

Lo spike non libera il buffer: è una perdita minima, da non riportare nell'app vera.

## Ricetta: elenco delle finestre

**Regole di ammissione**, nell'ordine:

1. Minimizzata con Space noti, nessuno dei quali corrente: scartata.
2. Ruolo diverso da `AXWindow`: scartata.
3. Nessun id di finestra: scartata.
4. `AXStandardWindow`: ammessa.
5. `AXDialog`: ammessa solo con titolo.
6. Altri subrole: scartata.

**App solo in altri Space:** nessuna finestra ammessa; tra le sue finestre di livello 0 almeno 100×50, almeno una ha Space noti e nessuna è nello Space corrente.

**Aggiornamento:** scansione in background ogni secondo e a ogni cambio di app attiva, avvio o chiusura di un'app, cambio di Space. Le app si interrogano in parallelo con `AXUIElementSetMessagingTimeout` a 0,25 s. L'apertura legge solo la copia in memoria.

**Ordine:** app secondo la posizione in `CGWindowList`, con l'app attiva per prima; finestre nell'ordine di `kAXWindows`. Non è un vero MRU, che era fuori scope.

## Comportamenti osservati

- **`kAXWindows`:** non elenca le finestre normali di altri Space (provato con VS Code), ma elenca le minimizzate di altri Space (TextEdit). `alttab-notes.md` diceva solo che è filtrato per Space.
- **Minimizzata in altro Space:** il ripristino non la porta qui. L'app non è passata in primo piano e al giro dopo risultava solo nell'altro Space. Dedotto dal log.
- **Subrole delle minimizzate:** una minimizzata di TextEdit in altro Space è risultata `AXDialog`, mentre Orca minimizzata è `AXStandardWindow`. Una minimizzata `AXDialog` senza titolo verrebbe scartata.
- **Tab di Finder:** 2 finestre, di cui una con 3 tab, danno 2 voci; il titolo è quello di un solo tab.
- **Elementi vuoti:** Finder e cmux espongono elementi senza ruolo in `kAXWindows`.
- **Finestre senza Space:** alcune finestre di Zoom e iTerm2 hanno `spaces=[]`, quindi "nessuno Space" non significa "altro Space".
- **Finestre in più Space:** iTerm2 ha mostrato una finestra senza titolo con `spaces=[4, 3, 1]`, ammessa con titolo vuoto.
- **Più processi:** Chrome compare come due app con pid diversi.
- **Scansione:** spesso 200-310 ms, con una punta di 802 ms, senza effetto sull'apertura.

## Ricetta: tasti e pannello

- **Hotkey:** `RegisterEventHotKey` su `GetEventDispatcherTarget()`. L'istante di partenza è `GetEventTime` dell'evento.
- **Tasti registrati:** Tab (48), \` (50) e `kVK_ISO_Section` (10, solo per tastiere ISO, non provato), ciascuno con e senza ⇧.
- **Rilascio:** `CGEvent.tapCreate` su `.cgSessionEventTap`, `.listenOnly`, solo `flagsChanged`, su un thread dedicato. Si riattiva su `tapDisabledByTimeout` e `tapDisabledByUserInput`, più un controllo ogni secondo.
- **Rilascio perso:** un controllo ogni 50 ms di `CGEventSource.flagsState` a pannello aperto fa da riserva. Non è mai intervenuto.
- **Altri tasti:** `NSEvent.addLocalMonitorForEvents(.keyDown)`, restituendo `nil`. Frecce ed `Esc` arrivano al pannello con ⌥ premuto.
- **Pannello:** `NSPanel` con `[.borderless, .nonactivatingPanel]`, `canBecomeKey = true`, `level = .popUpMenu`, `hidesOnDeactivate = false`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. Si apre con `makeKeyAndOrderFront`, si chiude con `orderOut`.
- **App:** `LSUIElement = true`, `setActivationPolicy(.accessory)`.

## Build e firma

- `swiftc -swift-version 5 -O -framework AppKit -framework Carbon -framework ApplicationServices Sources/*.swift`, con il bundle assemblato da script. Xcode non serve.
- **Firma stabile senza toccare il portachiavi di login:** certificato autofirmato con `extendedKeyUsage = codeSigning`, in un keychain dedicato. Dopo `security create-keychain` va ripristinata la lista dei keychain e serve `set-key-partition-list`. Non è necessario segnare il certificato come attendibile.
- **Permesso stabile:** il requisito della firma è `identifier "local.downtab.spike" and certificate leaf = H"..."`, invariato tra le build. Il permesso sopravvive finché resta lo stesso certificato.
- **Avvio:** con `open`, così il permesso è attribuito al bundle e non al terminale.

## Come interpretare le misure

- **`visible_ms`:** dall'evento della hotkey alla notifica di visibilità di macOS. Il pannello è già pronto in circa 6-25 ms (`sync_ms`), quindi il valore può essere sovrastimato. Il ritardo prima dell'hotkey non è misurato.
- **`siblingsMovedForward`:** confronta l'ordine prima e dopo. Può dare falsi positivi se sparisce una finestra davanti. Con le API private ha dato 1 due volte su Chrome, senza anomalie viste dall'autore.
- **`top`:** falso talvolta anche se non c'è nulla davanti. La finestra npm di Chrome risultava `top=false`, ma l'autore ha confermato che era davanti, e nella prova successiva il valore era vero. Non è un indicatore affidabile da solo.
- **`sameControl`:** falso in 2 casi su 4 dopo `Esc`, mentre l'autore torna a scrivere nell'editor. Può dipendere dall'identità dell'elemento AX. Non è stato chiarito.
- **Confronto con AltTab:** il suo `windowDisplayDelay` di default è 100 ms, quindi il confronto a sensazione non è alla pari. Il valore in uso durante il confronto non è stato annotato.

## Limiti e rischi aperti

- **Schermo intero:** lo Space a schermo intero è uno Space a sé, quindi lo spike elenca solo l'app stessa e le app senza finestre riconosciute (Zoom, iTerm2). L'autore vuole invece tutte le app, come il nativo. Il comportamento è da implementare nell'app vera: lo spike non ha provato né il riconoscimento dello schermo intero né l'attivazione di un'app in un altro Space. È la prima cosa da verificare.
- **Sostituzione di ⌘Tab:** se l'app va in crash con l'hotkey nativo disattivato, ⌘Tab può restare spento. Serve l'eseguibile di emergenza descritto in `alttab-notes.md`.
- **TextEdit con tutte e 3 le finestre avanti:** visto una volta, causa ignota, nessuna traccia nei log conservati.
- **Aggiornamento dell'elenco:** l'elenco può essere vecchio di circa un secondo. L'app finale richiede il tracciamento a eventi.
- **Aggiornamenti di macOS:** il valore del progetto dipende da API private che possono cambiare.
- **Costo reale:** gran parte di AltTab gestisce casi limite. Questo spike non misura quanto costerà un'app affidabile.

## Conservare il prototipo

- **Perché tenerlo:** 15 file, circa 800 righe di Swift più lo script. Dopo un aggiornamento di macOS è il modo più rapido per controllare se le API private funzionano ancora. Resta usa e getta: il codice definitivo verrà riscritto.
- **Cosa resta fuori da git:** `build/` e `.signing/`, che contiene la chiave di firma.
- **Dopo un clone, o senza `.signing/`:** rifare `./spike.sh setup-signing` e riconcedere il permesso Accessibility, perché il certificato cambia.
- **Rischio di licenza:** lo spike è scritto dopo aver letto il sorgente GPL-3.0 di AltTab, e ne riprende firme, offset e parametri, senza copiarne il codice. Non è stato verificato se questo repo è pubblico: se lo è, valutare il punto prima di pubblicare. Se è privato, il tema si riapre alla graduazione. Questa non è una valutazione legale.

## Rieseguire lo spike

Da `spike/`:

- **Prima volta:** `./spike.sh setup-signing`, poi `./spike.sh build`
- **Avvio:** `./spike.sh start --focus private --timeout 900`. `start` torna subito al prompt: lo spike resta in background.
- **Arresto:** `./spike.sh stop` oppure ⌃⌥⇧Q
- **Emergenza:** `pkill -9 -x DowntabSpike`
- **Riepilogo:** `./spike.sh stats`
- **Elenco:** `./spike.sh list`. Chiude lo spike in esecuzione.

Il log è in `build/spike.log`, e ogni avvio conserva solo l'esecuzione precedente. Il tap si disattiva per simulazione con `pkill -USR1 -x DowntabSpike`.
