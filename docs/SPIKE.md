# Spike di fattibilità

Stabilire se un'app minima può ottenere lo stesso comportamento di AltTab, prima di costruire la UI di Downtab. Leggi prima `GOAL.md`.

L'esito è un verdetto go/no-go, non codice da conservare. L'autore non legge Swift: ogni verifica deve essere osservabile dal comportamento o da un log.

## Cosa è già noto

Provato dall'autore usando AltTab, assegnato a ⌘Tab e al tasto del backtick (presumibilmente ⌘`, da confermare con l'autore), che filtra le finestre per Space, include le minimizzate, alza solo la finestra selezionata ed è responsivo. La sua UI, che mostra app e finestre insieme, non si può cambiare.

Quindi questi comportamenti sono possibili. Resta da dimostrare che si ottengono in un'app piccola, e con quali API.

## Passo 1: leggere AltTab

Clona `https://github.com/lwouis/alt-tab-macos` in `$TMPDIR/alttab-reference`, fuori da questo repository, e annota il commit. È solo un riferimento: non va aggiunto al repo.

Per ogni punto del passo 2, individua API usate, file di riferimento e casi particolari gestiti. Verifica anche:

- la licenza, prima di copiare codice;
- come ottiene la velocità, ad esempio se tiene l'elenco delle finestre già pronto.

Scrivi le note in `docs/alttab-notes.md`.

## Passo 2: costruire lo spike

Le note su AltTab sono un riferimento, non un obbligo. Per ogni bisogno prova prima la soluzione pubblica più semplice; passa a un'API privata solo se la prova fallisce, e annota il motivo. Implementa solo ciò che serve alle verifiche.

### Vincoli

- Codice in `spike/`, usa e getta. Il codice definitivo verrà riscritto.
- Swift + AppKit, build da riga di comando con un solo comando documentato.
- Niente UI curata: un pannello con testo semplice basta.
- Le API citate in `GOAL.md` sono riportate a memoria: le note su AltTab e le prove hanno la precedenza.

### Sicurezza

Lo spike intercetta la tastiera di sistema, quindi un errore può lasciare il Mac scomodo da usare.

- Lo spike non deve disattivare gli hotkey di sistema: ⌘Tab e ⌘` nativi restano intatti.
- Prevedi un'uscita da tastiera sempre attiva, e un timeout che chiude lo spike durante le prime prove.
- Chiudi AltTab durante le prove, per evitare conflitti sulla stessa scorciatoia.
- Fornisci all'autore comando di avvio e comando di arresto prima di ogni prova.

### Permessi

Il permesso Accessibility può concederlo solo l'autore, a mano. Va chiesto una volta sola: usa un bundle `.app` con percorso e firma stabili, perché una firma che cambia a ogni build può invalidare il permesso. Se un'API richiede Screen Recording, segnalalo: è un costo che il progetto vuole evitare.

## Cosa dimostrare

### 1. Intercettare ⌥Tab e ⌥`

Lo spike usa ⌥ al posto di ⌘. La sostituzione di ⌘Tab e ⌘` è rimandata a dopo un esito positivo: AltTab dimostra già che è possibile.

- Tenendo ⌥ e premendo Tab appare il pannello dello spike.
- Tenendo ⌥ e premendo il tasto del backtick, il pannello si apre sull'app attiva, con le sue finestre già elencate e la seconda selezionata. Ogni nuova pressione avanza, con ⇧ torna indietro.
- La scorciatoia funziona sulla tastiera e sul layout dell'autore, dove il backtick può non corrispondere allo stesso tasto fisico: logga il keycode.
- ⇧Tab, frecce, `Enter` ed `Esc` arrivano allo spike e non all'app in primo piano.
- Il rilascio di ⌥ viene rilevato ogni volta, anche con pressioni rapide.
- L'intercettazione sopravvive a 10 minuti di uso normale, compreso il caso in cui macOS disattiva il tap per timeout.

### 2. Pannello senza furto di focus

- Il pannello appare sopra le altre finestre e sopra un'app a schermo intero.
- Dopo `Esc`, si continua a digitare dove si era.

### 3. Alzare una sola finestra

Prova con VS Code, Chrome, Finder e un'app nativa con almeno 3 finestre sovrapposte, partendo sia da un'altra app sia dalla stessa app.

- Solo la finestra scelta viene avanti, e riceve il focus da tastiera.
- Una finestra minimizzata viene ripristinata e portata avanti.
- Annota se servono API private e quali.

### 4. Elencare per app le finestre dello Space attuale

- Le finestre sono raggruppate per app, con titolo corretto: è il dato che serve ai due livelli di Downtab e che la UI di AltTab non mostra così.
- Sono elencate solo le finestre dello Space attuale, più le minimizzate.
- Vanno escluse le finestre non reali, come palette e pannelli di servizio.
- Le app con finestre solo in altri Space sono riconoscibili, per poterle nascondere.

### 5. Velocità

Con almeno 10 app e 20 finestre aperte, misura su 50 aperture il tempo dalla pressione di Tab al pannello visibile con l'elenco completo.

Soglia provvisoria: mediana sotto 50 ms e 95° percentile sotto 100 ms. Riporta i numeri misurati. L'autore giudica anche a sensazione, confrontando con AltTab.

## Fuori scope

Ordine MRU, indicatori, icone, layout definitivo, preferenze, avvio al login, distribuzione.

## Verdetto

- **Go:** i punti 1-5 passano, anche usando API private.
- **Go con riserva:** un punto passa con limiti accettabili; descrivili e chiedi all'autore se li accetta.
- **No-go:** lo spike non riesce a ottenere ciò che AltTab ottiene. Solo in questo caso valuta un fork di AltTab, indicando quanto è difficile sostituirne la UI.

## Consegna

Scrivi in `spike-results.md`:

- verdetto;
- commit di AltTab analizzato e licenza;
- risultato di ogni punto, indicando cosa è stato misurato dallo spike e cosa provato a mano dall'autore;
- API private usate e cosa succede se smettono di funzionare;
- versione di macOS, permessi richiesti, limiti scoperti;
- comandi di avvio, arresto ed emergenza.

Aggiorna `GOAL.md` se lo spike smentisce lo stack o il comportamento previsto. Fai commit solo se l'autore lo chiede.

## Esito

In `spike-results.md`.
