# Spike Downtab

Codice usa e getta per `../docs/SPIKE.md`. Build: `./spike.sh build`. Elenco comandi: `./spike.sh`.

- **Arresto:** `./spike.sh stop`, oppure ⌃⌥⇧Q. Il timeout chiude da solo (300 s di default, `--timeout S` per cambiarlo).
- **Emergenza:** `pkill -9 -x DowntabSpike`. Non c'è nulla da ripristinare: lo spike non disattiva gli hotkey di sistema.
- **Firma:** certificato autofirmato in `.signing/`, keychain dedicato, escluso da git. Se cancelli `.signing/`, va riconcesso il permesso Accessibility.
- **Log:** `build/spike.log`; l'esecuzione precedente è in `build/spike.prev.log`.

## Prove

Prima di ogni prova chiudi AltTab.

| Punto | Comando | Cosa fare | Cosa guardare |
| --- | --- | --- | --- |
| 4 | `./spike.sh list` | Finestre in 2 Space, una minimizzata, Finder con tab, un'app solo nell'altro Space | `build/list.txt`: `ALTRO_SPACE`, `DISAGREE`, finestre scartate `no` |
| 3 | `./spike.sh start`, poi `start --focus private` | VS Code, Chrome, Finder e un'app nativa con 3 finestre, da altra app e dalla stessa app, anche minimizzate | Righe `focus verified`: `frontmost`, `key`, `top`, `siblingsMovedForward=0` |
| 1 | `./spike.sh start --timeout 900` | ⌥Tab, ⌥⇧Tab, ⌥\`, ⌥⇧\`, frecce, `Enter`, `Esc`, pressioni rapide. 10 minuti di uso normale. A metà: `pkill -USR1 -x DowntabSpike` | `hotkey ... keycode=`, `key ...`, `./spike.sh stats`: `poll_di_riserva` deve essere 0, tap riattivato |
| 2 | `./spike.sh start` | Apri su un'app a schermo intero; `Esc` e digita subito | Righe `cancel verified`: tutti `true` |
| 5 | `./spike.sh start --timeout 900` | Con almeno 10 app e 20 finestre, 50 aperture | `./spike.sh stats` |
