# Note su AltTab

Passo 1 di `SPIKE.md`, scritto prima delle prove. Ciò che è stato provato, e le correzioni a queste note, è in `spike-results.md`.

- **Riferimento:** `lwouis/alt-tab-macos`, commit `c500294bdb01186011a5c64a412b04cef9931bef` (11.10.1, 2026-10-23), clonato in `$TMPDIR/alttab-reference`. I percorsi sotto sono relativi a quella copia.
- **Licenza:** GPL-3.0 (`LICENCE.md`). Non copiare codice in un progetto che non sarà GPL: si reimplementa dal comportamento e dalle firme delle API. Da rivedere alla graduazione o per un fork.
- **Macchina:** macOS 27.0.1, arm64, solo Command Line Tools (niente Xcode), Swift 6.4, layout `U.S.`, nessuna identità di firma.

Legenda: **[codice]** letto nel sorgente; **[misura AltTab]** misura dichiarata nei commenti, spesso su macOS 26; **[qui]** verificato su questa macchina; **[ipotesi]** da provare.

## Sorprese rispetto a `GOAL.md`

1. **⌘Tab non si intercetta con un `CGEventTap`.** AltTab usa hotkey Carbon, disattiva gli hotkey simbolici nativi e tiene un tap solo in ascolto. [codice]
2. **L'hotkey disattivato resta tale dopo l'uscita.** È il rischio principale per la sicurezza: vedi punto 1. [codice]
3. **Per il focus servono più API private**, non solo `AXRaise` più l'attivazione. [codice]
4. **AltTab non è un riferimento di velocità sotto i 50 ms.** Attende 100 ms di default prima di mostrare il pannello, e cita ~110 ms per una apertura. [codice, misura AltTab]

## Punto 1: sostituire ⌘Tab e ⌘`

| Bisogno | Soluzione | Riferimento |
| --- | --- | --- |
| Ricevere ⌘Tab e ⌘⇧Tab | `RegisterEventHotKey`, dopo aver disattivato gli hotkey simbolici 1 e 2 con `CGSSetSymbolicHotKeyEnabled` (privata) | `src/events/KeyboardEvents.swift`, `src/macos/api-wrappers/CGSSymbolicHotKey.swift` |
| Ricevere ⌘` | Solo `RegisterEventHotKey`: l'hotkey Carbon arriva prima dell'app, nulla da disattivare | `src/preferences/settings-window/tabs/controls/NativeHotkeyResolverSpecs.md` |
| Rilascio di ⌘ | Tap `.cgSessionEventTap` `.listenOnly` su `flagsChanged`, su un thread dedicato | `KeyboardEvents.swift` |
| Frecce, `Enter`, ⇧Tab | Pannello key e `NSEvent.addLocalMonitorForEvents`; l'evento assorbito non raggiunge l'app | `KeyboardEvents.swift`, `src/switcher/main-window/TilesPanel.swift` |
| `Esc` con ⌘ premuto | Tap attivo `.cghidEventTap`, acceso solo a pannello aperto: su macOS 26 ⌘⎋ è conteso da Game Overlay | `KeyboardEvents.swift` |
| Tap disattivato da macOS | Su `tapDisabledByTimeout` e `tapDisabledByUserInput` riattivare il tap | `KeyboardEvents.swift` |

**Casi particolari**

- Carbon non segnala l'auto-repeat: per ⌘Tab tenuto premuto AltTab ha un timer proprio. [codice]
- Pressioni rapide con main thread occupato possono far arrivare in ritardo l'hotkey rispetto al rilascio. AltTab li riallinea con `src/events/ModifierReleaseLog.swift`. Lo spike parte più semplice: il main thread resta libero e ogni evento va nel log. Se il rilascio si perde, è il primo sospetto. [codice, ipotesi]
- Un tap attivo permanente su `keyDown` ha rotto metodi di input di terzi (#5766): tenerlo acceso solo a pannello aperto. [codice]
- Durante la chiusura, i tasti ancora diretti al pannello vanno scartati. [codice]
- Mission Control aperto: AltTab non apre il pannello. [codice]

**Layout.** AltTab non riconosce un carattere: registra un keycode. Il default è `kVK_ANSI_Grave` (50), con il carattere ricavato dal layout attivo. Nelle tue preferenze AltTab `nextWindowShortcut2` non è impostata, quindi usi il default, e il layout è `U.S.` [qui] Non so se la tastiera fisica è ANSI o ISO: su ISO il tasto sopra Tab può avere un altro keycode. Lo spike deve loggare il keycode alla prima prova. [ipotesi]

**Non coperto da AltTab:** i commenti parlano di ⌘`, non di ⌘⇧`. Lo spike deve provare che ⌘⇧` non scateni il ciclo nativo. [ipotesi]

**Sicurezza**

- AltTab ripristina su `applicationWillTerminate`, SIGTERM, SIGINT, SIGHUP ed eccezioni Objective-C non gestite (`src/main.swift`, `src/App.swift`). [codice]
- SIGKILL non è intercettabile, e non ho trovato gestione per SIGSEGV e SIGABRT. In quei casi ⌘Tab nativo resta spento. [codice]
- Lo spike ha quindi bisogno di un eseguibile separato di emergenza che chiama `CGSSetSymbolicHotKeyEnabled(1, true)` e `(2, true)`, costruito e provato **prima** di disattivare qualcosa.
- Avviare e chiudere AltTab dovrebbe ripristinare ⌘Tab come ripiego. [ipotesi]

## Punto 2: pannello senza furto di focus

- `NSPanel` con `.nonactivatingPanel`, `canBecomeKey = true`, `level = .popUpMenu`, `hidesOnDeactivate = false`, `collectionBehavior = .canJoinAllSpaces`. Si mostra con `makeKeyAndOrderFront`. [codice: `TilesPanel.swift`, `HelperExtensions.swift`]
- App con `LSUIElement = true`, non sandboxed. [codice: `Info.plist`]
- Il pannello principale non ha `.fullScreenAuxiliary`, che altri pannelli di AltTab hanno: se non appare sopra lo schermo intero è il primo tentativo. [ipotesi]
- **Dopo `Esc`:** il pannello è key, quindi l'app sotto riprende la tastiera quando si chiude. AltTab rimanda la pulizia finché il pannello non ha rilasciato la tastiera. Va provato digitando subito. [codice, ipotesi]
- **Alla conferma:** il pannello si chiude solo dopo che la finestra scelta è davanti, con un limite di 100 ms. Alcune app riprendono il primo piano se ricevono prima la tastiera (#6097). [codice]

## Punto 3: alzare una sola finestra

Sequenza in `src/switcher/state/Window.swift` (`applyFocus`), fuori dal main thread: [codice]

1. Se minimizzata: `AXUIElementSetAttributeValue(kAXMinimized, false)`. Può bloccare fino a 1 s.
2. `_SLPSSetFrontProcessWithOptions(psn, wid, 0x200)` (privata): porta avanti processo e sola finestra `wid`.
3. `makeKeyWindow`: `SLPSPostEventRecordTo` (privata) con un mouse-down sintetico.
4. `AXUIElementPerformAction(kAXRaiseAction)`. Se l'elemento è scaduto, lo si cerca di nuovo per `wid`.
5. Dopo 150 ms, se un'altra finestra la copre ancora, ripetere il solo raise (#6064).

`_AXUIElementGetWindow` (privata) lega l'elemento AX al `wid`. Su una parte interna della finestra restituisce il `wid` della finestra contenitore, quindi va verificato il ruolo. [codice]

**Casi particolari**

- `NSRunningApplication.activate` da macOS 14 è solo una richiesta: non basta. [codice]
- **Evento di mouse-down:** solo il down, mai l'up, e punto `(300000, 300000)`. Un punto vicino al bordo su macOS 27 ridimensiona la finestra (#5900); `NaN` o `(0, 0)` clicca contenuti reali (#5381). Il record è da `0x100` byte azzerati: più corto causa SIGABRT da macOS 14.7.4. Gli offset sono in `src/macos/api-wrappers/SkyLight.framework.swift`. [codice]
- Finestre di altri Space: servono passi extra, ma qui si alterna solo nello Space attuale. [codice]
- Selezioni rapide: AltTab annulla le richieste superate. Allo spike basta una sola richiesta per volta. [codice, ipotesi]

## Punto 4: elenco per app nello Space attuale

**API** (`src/macos/CGSCallScheduler.swift`, `src/switcher/state/Spaces.swift`, `src/windowserver/`) [codice]

| Dato | API | Tipo |
| --- | --- | --- |
| Space e Space corrente | `CGSCopyManagedDisplaySpaces`, `CGSManagedDisplayGetCurrentSpace` | privata |
| Finestre di uno Space | `CGSCopyWindowsWithOptionsAndTags` | privata |
| Pid, livello, minimizzata, dimensioni | `SLSWindowQueryWindows` e iteratori: una sola chiamata per tutto il gruppo | privata |
| Space di una finestra | `CGSCopySpacesForWindows` | privata |
| Titolo, subrole, ruolo, main | `AXUIElement` su `kAXWindows` di ogni app | pubblica |

**Filtro delle finestre reali** (`src/switcher/state/WindowAdmissionResolver.swift`) [codice]

- Scarta: `parentWid != 0`, subrole `AXFloatingWindow` o `AXSystemDialog`, livello sotto 0.
- Sopra il livello 0 ammette solo finestre `kAXMain` o a schermo intero.
- Ammette: `kAXMain`, `AXStandardWindow`, `AXDialog` con titolo.
- Altro con ruolo finestra: serve titolo e dimensione minima 100×50.

**Casi particolari**

- **Minimizzate:** bit 60 di `SLSWindowIteratorGetTags`. L'assenza da uno Space non significa nulla, perché CGS può togliere le minimizzate dagli elenchi per Space. Quindi non vanno ricavate solo da quegli elenchi. Non ho verificato a quale Space AltTab attribuisce una minimizzata di un altro Space: da provare. [codice, misura AltTab]
- **`kAXWindows` è già filtrato per Space corrente:** una finestra in un altro Space non vi compare, quindi l'elemento AX si ottiene solo con tentativi forzati (`_AXUIElementCreateWithRemoteToken`). Allo spike non serve. [codice]
- **App solo in altri Space:** invertire l'elenco per Space, poi leggere il pid con `SLSWindowQueryWindows`. [codice, ipotesi]
- **Tab nativi (Finder):** i tab inattivi hanno un `wid` proprio e nessuno Space. Possono sembrare finestre fantasma: da controllare con Finder nelle prove. [codice]
- **Space condivisi:** se "Displays have separate Spaces" è spento, tutti i display risultano in una sola voce `Main`. [codice]

**Screen Recording: non serve per i titoli via AX**

- AltTab permette di saltarlo e lo collega a thumbnail e anteprime (`src/macos/PermissionCalloutResolver.swift`). [codice]
- `kCGWindowName` di altre app è visibile solo con il permesso: AltTab lo usa proprio per rilevarlo. Quindi **i titoli non vanno presi da `CGWindowList`**, a differenza di quanto suggerisce `GOAL.md`. [codice]
- Le app con titolo AX vuoto (web app di Chrome) ripiegano su `SLSWindowIteratorCopyTitle`. Non ho verificato se questa strada richiede il permesso. [ipotesi]

## Punto 5: velocità

- **Elenco già pronto:** durante l'apertura AltTab non interroga le app. Mantiene il modello in background con notifiche WindowServer (`SLSRegisterConnectionNotifyProc`) e un osservatore AX per app. Alla pressione filtra e ordina dati già in memoria. [codice: `src/switcher/state/Windows.swift` `updatesBeforeShowing`, `src/events/WindowServerEvents.swift`]
- **Interrogare AX all'apertura è la strada sbagliata:** un'app lenta blocca fino a 1 s per chiamata; una configurazione reale costava ~550 ms a ogni apertura. [misura AltTab: `src/util/SchedulingPolicySpecs.md`]
- **Costi citati:** `makeKeyAndOrderFront` 7 ms (14 ms alla prima apertura), inventario completo ~280 ms, prima apertura ~60 ms in più. [misura AltTab: `src/main-thread-ipc.md`, `src/App.swift`]
- **Attesa voluta:** `windowDisplayDelay` è 100 ms di default. Il confronto a sensazione con AltTab dipende da questa impostazione e dal suo render più pesante: va annotato il valore usato durante le prove. [codice]
- **Per lo spike:** una scansione in background a intervalli più gli eventi di apertura e chiusura delle app può bastare, senza il tracciamento completo di AltTab. La soglia di 50 ms è plausibile perché il pannello è solo testo, ma non è provata. [ipotesi]
- **Misura:** l'istante di partenza va preso all'arrivo dell'hotkey, che è dopo la pressione fisica. Il ritardo prima di Carbon sfugge. [ipotesi]

## Build e permessi

- **Firma:** AltTab usa un certificato locale autofirmato per non dover riconcedere il permesso a ogni build (`scripts/codesign/setup_local.sh`, `docs/contributing.md`). Qui non c'è alcuna identità di firma [qui], quindi lo spike ne deve creare una: **va nel portachiavi dell'autore e richiede il suo consenso**.
- **Toolchain:** Xcode assente; `swiftc` funziona. Il bundle `.app` va assemblato da script. [qui]
- **Link delle API private:** tutti i simboli provati si risolvono a runtime con `dlsym` su SkyLight in macOS 27.0.1; era la prova più semplice. Il link diretto con `-framework SkyLight` è fallito per `CGSMainConnectionID`, assente dallo stub di SkyLight nell'SDK. Nella prova mancava `-framework CoreGraphics`, da riprovare prima di scegliere. Esistere non significa funzionare: firme e comportamento restano da provare. [qui]
- **Permessi:** Accessibility è sufficiente per hotkey, tap e focus. AltTab si riavvia se `tapCreate` fallisce per permesso mancante; allo spike basta un errore chiaro nel log e l'uscita. [codice, ipotesi]

## Scelte dello spike diverse da AltTab

- **⌥Tab e ⌥` invece di ⌘Tab e ⌘`:** niente `CGSSetSymbolicHotKeyEnabled` e niente eseguibile di emergenza. Le parti su ⌘ del punto 1 valgono solo per dopo l'esito.
- **Prima le API pubbliche:** per il focus `activate` e `AXRaise` sull'elemento AX; per l'elenco `kAXWindows` più `CGWindowListCopyWindowInfo`, usato senza titoli. Le API private entrano solo se una prova fallisce.
- **Hotkey con Carbon:** una libreria come HotKey o KeyboardShortcuts ne è un involucro e non aggiunge nulla allo spike. [ipotesi, da memoria]

## Ordine consigliato per lo spike

1. Bundle firmato.
2. Punti 4 e 3, solo con log e senza intercettare nulla: sono i meno pericolosi e i più incerti.
3. Punti 1 e 2, con timeout e uscita da tastiera.
4. Punto 5, solo quando il resto funziona.

## Rischi per il verdetto

- **macOS 27:** molte misure di AltTab sono su macOS 26. Ci sono note e correzioni per 27 (#5900, #6125), e `SLSWindowQueryWindows` è stato misurato su 27.0.1, ma il resto non è garantito.
- **API private:** il progetto dipenderebbe da almeno 3 API private per funzioni centrali (hotkey simbolici, front process, evento di focus), senza alternativa pubblica nota.
- **Complessità nascosta:** gran parte di AltTab gestisce casi limite emersi negli anni. Lo spike può passare i punti 1-5 senza rivelare il costo reale di un'app affidabile; il verdetto deve dirlo.
