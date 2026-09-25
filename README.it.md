*[🇬🇧 English version](README.md) | 🇮🇹 Italiano*

[![PSScriptAnalyzer](https://github.com/SMGK74/sping/actions/workflows/psscriptanalyzer.yml/badge.svg)](https://github.com/SMGK74/sping/actions/workflows/psscriptanalyzer.yml)

# Sping

Monitor di ping multi-host in parallelo per PowerShell, riscrittura moderna del vecchio `Sping.vbs`.

Mostra una dashboard live in console (una riga fissa per host, aggiornata sul posto senza flicker né scroll), scrive opzionalmente un log CSV strutturato, e riproduce un allarme sonoro/vocale quando un host torna raggiungibile dopo un'interruzione.

## Storia

Sping nasce come `Sping.vbs`, un vecchio script VBScript per il monitoraggio ping di più host, con allarme sonoro al ripristino e impostazioni salvate nel registro di Windows. Questa versione è una riscrittura completa in PowerShell che ne mantiene lo scopo originale (un monitor semplice, leggero, senza dipendenze esterne) aggiungendo via via, in modo iterativo: la dashboard live a colori, il log CSV, la configurazione portabile in JSON, il supporto a più protocolli (ICMP, HTTP/HTTPS, TCP), il controllo di jitter e scadenza certificati TLS, la localizzazione dell'interfaccia, l'espansione di range/CIDR e il traceroute automatico sui fallimenti. Sviluppato con l'assistenza di Claude (Anthropic).

## Requisiti

- Windows PowerShell 5.1 o successivo (`#Requires -Version 5.1`)
- Nessuna dipendenza esterna: usa solo `System.Net.NetworkInformation.Ping`, `System.Net.Dns`, `System.Media.SoundPlayer` e `System.Speech.Synthesis`, tutti già presenti in .NET Framework su Windows

## Installazione su un PC nuovo

```powershell
# 1. Copia Sping.ps1 in una cartella a piacere

# 2. Sblocca il file (necessario se scaricato da internet/email/chat)
Unblock-File -Path .\Sping.ps1

# 3. Consenti l'esecuzione di script locali (una sola volta per utente/PC)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 4. Avvia
.\Sping.ps1
```

Al primo avvio, lo script propone di aggiungere la sua cartella al PATH utente di Windows (richiede conferma esplicita S/N): se accetti, potrai richiamare `sping` da qualsiasi cartella senza specificare il percorso completo. Serve però aprire una nuova finestra PowerShell perché il cambiamento abbia effetto.

## Utilizzo

```powershell
# Help completo (anche lanciando lo script senza parametri)
.\Sping.ps1 -Help

# Ping di più host in parallelo
.\Sping.ps1 192.168.1.1 web-server-01 10.0.0.5 -Count 50 -TimeoutMillis 500

# Lista salvata + suffisso DNS + modalità compatta + log CSV
.\Sping.ps1 -ListName Core -Domain contoso.local -Summary -Log

# Ping HTTP/HTTPS invece di ICMP (utile se ICMP e' filtrato ma il servizio web e' quello da monitorare)
.\Sping.ps1 www.contoso.local -Protocol Https -CertIgnoreErrors

# Controllo porta TCP (es. un database in ascolto su una porta specifica)
.\Sping.ps1 db-server-01 -Protocol Tcp -Port 1433

# Range/CIDR/subnet mask: ogni voce si espande in piu' host (network e broadcast esclusi)
.\Sping.ps1 10.0.0.0/23 -Summary
.\Sping.ps1 10.0.0.1-10.0.0.50
.\Sping.ps1 10.0.0.1-50
.\Sping.ps1 10.0.0.0/255.255.254.0

# Traceroute automatico al primo fallimento di ogni "episodio" di down (processo indipendente in background)
.\Sping.ps1 db-server-01 web-server-02 -TraceOnFailure -Log

# Segnala se il percorso di rete verso un host cambia, controllato ogni 30 minuti
.\Sping.ps1 vpn-remoto.contoso.local -PathTrace -PathTraceIntervalMinutes 30

# Mostra solo gli host non raggiungibili (F per cambiare filtro al volo durante il monitoraggio)
.\Sping.ps1 -ListName Core -DisplayFilter DownOnly

# Segnala eventuali cambi di indirizzo MAC (conflitto IP) - solo per host sulla stessa rete locale
.\Sping.ps1 192.168.1.1 192.168.1.254 -MacMonitor -MacHistoryDepth 4 -Log

# Tiene puliti i log: cancella all'avvio i file piu' vecchi di 30 giorni (salvato come impostazione)
.\Sping.ps1 -ListName Core -Log -LogRetentionDays 30 -SaveAsDefault

# Interfaccia in italiano (default: inglese)
.\Sping.ps1 -ListName Core -Language it

# Log in JSON Lines invece che CSV, per un SIEM o uno strumento di monitoring
.\Sping.ps1 -ListName Core -Log -LogFormat Json

# Avvia con l'allarme sonoro disattivato
.\Sping.ps1 -ListName Core -DisableAlerts

# Salvare un elenco host per riuso futuro
.\Sping.ps1 10.0.0.1 10.0.0.2 -ListName Core -SaveList

# Vedere le impostazioni di default correnti
.\Sping.ps1 -ShowSettings
```

Durante il monitoraggio, premi `H` in qualsiasi momento per mostrare/nascondere un pannello con tutti i comandi disponibili (`A` per gli avvisi, `F` per il filtro host, `R` per azzerare i contatori, `L` per attivare/disattivare la scrittura del log, `T` per attivare/disattivare la traccia automatica su fallimento senza riavviare la sessione, `Q`/`Ctrl+C` per interrompere in modo pulito). Viene sempre stampato un riepilogo finale, senza errori di terminazione.

## Parametri principali

*In v2.20.0 quattro parametri sono stati rinominati per coerenza (`-MonitorMacAddress`→`-MacMonitor`, `-TracePathChanges`→`-PathTrace`, `-MaxConcurrentTraces`→`-TraceMaxConcurrent`, `-IgnoreCertificateErrors`→`-CertIgnoreErrors`): i nomi vecchi non sono più validi, aggiorna eventuali script o task pianificati che li usano.*

| Parametro | Descrizione |
|---|---|
| `ComputerName` (posizionale) | Uno o più host/IP da pingare in parallelo. Ogni voce accetta anche un range/CIDR/subnet mask (es. `10.0.0.0/23`, `10.0.0.1-10.0.0.50`, `10.0.0.1-50`), espanso automaticamente in più host |
| `-MaxRangeHosts` | Limite di sicurezza sul numero di host che un singolo range/CIDR può generare (default 1024), per evitare di monitorare per errore migliaia di host da un range troppo ampio |
| `-TraceOnFailure` | Quando i fallimenti consecutivi di un host raggiungono `-ResumeThreshold` (host confermato giù, non al primo pacchetto perso), avvia `tracert -d -h 20 -w 1000` per quell'host come processo indipendente in background (non blocca la dashboard), salvando l'output in un file con timestamp sotto `SpingData\traces`. Scatta una volta per episodio. Un avviso mostra gli host per cui è appena partita la traccia, raggruppati sulla stessa riga se più di uno insieme. Attivabile/disattivabile anche al volo con il tasto `T` (solo con 10 host o meno) |
| `-TraceCooldownMinutes` | Solo con `-TraceOnFailure`: minuti minimi tra due traceroute per lo stesso host, per non ritracciare un host che flappa a ogni episodio (default 10) |
| `-TraceMaxConcurrent` | Solo con `-TraceOnFailure`: tetto massimo di `tracert` in esecuzione contemporanea su tutti gli host, per non esaurire le risorse quando molti host cadono insieme (es. un range CIDR ampio) (default 5) |
| `-PathTrace` | Ritraccia periodicamente il percorso verso ogni host (indipendente dal ciclo di ping e da `-TraceOnFailure`) con una sonda nativa non bloccante spalmata su più cicli, segnalando se il percorso cambia rispetto alla traccia precedente. Una riga dedicata della dashboard mostra live la traccia in corso (host, hop attuale, IP scoperti finora) o il conto alla rovescia alla prossima. Il dettaglio completo prima/dopo viene salvato in un file sotto `SpingData\pathtraces` |
| `-PathTraceIntervalMinutes` | Solo con `-PathTrace`: minuti tra la fine di una traccia completata e l'inizio della successiva, per host (default 15) |
| `-PathTraceMaxHops` | Solo con `-PathTrace`: numero massimo di hop da sondare prima di rinunciare a raggiungere la destinazione (default 20) |
| `-DisplayFilter` | Quali host mostrare nella dashboard: `All` (default), `UpOnly` (solo raggiungibili), `DownOnly` (solo non raggiungibili). Con `UpOnly`/`DownOnly` la vista è compatta (senza buchi), ridisegnata quando l'insieme cambia, con un debounce pari a `ResumeThreshold` × `IntervalMillis` per non sfarfallare su reti instabili. Cambia al volo con il tasto `F` durante il monitoraggio (Tutti → Solo attivi → Solo inattivi → Tutti). Non disponibile in modalità `-Summary` |
| `-MacMonitor` | Legge l'indirizzo MAC di ogni host dalla tabella di vicinato di Windows (`Get-NetNeighbor`, già popolata correttamente dal ping stesso), invece di forzare una nuova risoluzione ARP che su PC con più adattatori (VMware, VPN) può scegliere l'interfaccia sbagliata. Aggiunge colonne MAC1..MACn alla dashboard: MAC1 è il primo indirizzo visto (verde), ogni indirizzo diverso successivo riempie la colonna successiva (rosso), a segnalare una deviazione (possibile conflitto IP, dispositivo sostituito, o ARP spoofing). Funziona solo per host sullo stesso segmento di rete locale, quindi non è utile per host raggiungibili solo via WAN. Ogni cambio è comunque salvato per intero in un file sotto `SpingData\macchanges` |
| `-MacHistoryDepth` | Solo con `-MacMonitor`: quante colonne MAC1..MACn mostrare nella dashboard, riservate una volta sola all'avvio (default 3), mai aggiunte a metà sessione per non dover ricalcolare il layout durante il monitoraggio |
| `-ListName` | Nome di una lista host salvata (combinabile con `ComputerName`) |
| `-Domain` | Suffisso DNS aggiunto a ogni host |
| `-Count` | Numero di cicli di ping (default: continuo) |
| `-Protocol` | `Icmp` (default), `Http`, `Https` o `Tcp`: con Http/Https ogni ciclo invia una richiesta web parallela, con Tcp un tentativo di connessione a `-Port`, invece di un ping ICMP |
| `-Port` | Porta TCP di destinazione. Obbligatorio con `-Protocol Tcp` |
| `-CertIgnoreErrors` | Solo con `-Protocol Https`: salta la validazione del certificato TLS (utile per host interni con certificati self-signed) |
| `-CertWarningDays` | Solo con `-Protocol Https`: soglia in giorni sotto la quale la colonna STATO segnala che il certificato sta per scadere (default 30) |
| `-Language` | Lingua dell'interfaccia: `en` o `it`. Default: rilevata automaticamente dalla lingua di sistema al primo avvio (italiano se il sistema è in italiano, altrimenti inglese), poi quella salvata l'ultima volta. Personalizzabile ed estendibile, vedi sezione Lingua |
| `-DisableAlerts` | Parte con l'allarme sonoro/vocale disattivato invece che attivo di default (resta comunque attivabile/disattivabile al volo col tasto `A`). Persistibile con `-SaveAsDefault` per partire sempre disattivato |
| `-TimeToLive` | TTL dei pacchetti ping (solo `-Protocol Icmp`) |
| `-TimeoutMillis` | Timeout in ms per ogni risposta |
| `-IntervalMillis` | Pausa in ms tra un ciclo e l'altro. Con `-Protocol Http`/`Https`/`Tcp` viene imposto un minimo di 3000 ms, anche se richiedi un valore più basso, per non rischiare di sembrare un flood/DDoS verso gli host monitorati |
| `-ResumeThreshold` | Fallimenti consecutivi da cui la riga passa da arancione a rosso, e sotto cui scatta l'allarme sonoro al ripristino |
| `-Summary` | Griglia compatta invece di una riga per host. Il numero di colonne per riga è sempre calcolato automaticamente dalla larghezza della finestra attuale, aggiornandosi anche durante l'esecuzione al ridimensionamento |
| `-SoundFile` | WAV riprodotto al ripristino di un host |
| `-Log` / `-LogFile` | Abilita il logging (default o percorso custom). Attivabile/disattivabile anche al volo durante il monitoraggio con il tasto `L`, senza riavviare la sessione |
| `-LogFormat` | `Csv` (default) o `Json`: quest'ultimo scrive un oggetto JSON compatto per riga (JSON Lines/NDJSON), adatto all'ingestione da parte di strumenti SIEM/monitoring, con più campi del CSV (protocollo, jitter, giorni alla scadenza del certificato) |
| `-LogRetentionDays` | Se impostato, cancella all'avvio (non durante la sessione) i file più vecchi di N giorni da tutte le sottocartelle di `SpingData` che accumulano file nel tempo (log, trace, pathtraces, macchanges). Disattivato di default: nessuna cancellazione automatica se non lo richiedi esplicitamente. Indipendentemente da questo, un avviso a schermo segnala se la cartella dei log supera 10 MB |
| `-SaveAsDefault` | Salva i parametri di questa esecuzione come nuovi default. Usato da solo, senza host, salva ed esce senza avviare il monitoraggio |
| `-ShowSettings` / `-ShowLists` | Mostra impostazioni/liste salvate ed esce |
| `-SaveList` / `-RemoveList` | Salva o elimina una lista host sotto `-ListName` |

## Configurazione e portabilità

Impostazioni, liste host, log e file di lingua persistono come JSON, non più nel registro di Windows come nella versione VBScript originale. La cartella dove vengono salvati è scelta automaticamente:

1. **`SpingData` accanto allo script** (es. `C:\Tools\SpingData`), se quella posizione è scrivibile. Così l'intera cartella `Sping` è portabile: copiala su un altro PC o su una chiavetta e impostazioni/liste/log viaggiano insieme allo script.
2. **`%APPDATA%\SM-Script\Sping`** come ripiego, se lo script si trova in un percorso non scrivibile (es. `Program Files` o una condivisione in sola lettura).

## Lingua

L'interfaccia parte in italiano se il sistema è in italiano, altrimenti in inglese (rilevato automaticamente al primo avvio). Con `-Language it`/`-Language en` puoi forzarla esplicitamente. Al primo avvio, lo script genera i file `en.json` e `it.json` dentro `SpingData\lang\`: puoi modificarli, oppure copiarne uno come base e crearne uno nuovo (es. `fr.json` con le stesse chiavi) per aggiungere un'altra lingua, basta poi richiamarlo con `-Language fr`.

`en.json`/`it.json` sono marcati con la versione dello script che li ha generati. Quando aggiorni lo script, se rilevi che quella versione è cambiata rispetto al file esistente, viene rigenerato automaticamente con il testo più recente (e te ne avvisa a schermo). Eventuali personalizzazioni manuali fatte in quel file vanno quindi rifatte dopo un aggiornamento dello script - un file di lingua creato per un'altra lingua (es. `fr.json`) non viene mai toccato automaticamente, dato che non c'è un testo incorporato con cui confrontarlo.

## Colori dashboard

- **Verde**: ping riuscito
- **Arancione**: ping fallito, sotto la soglia di `-ResumeThreshold` fallimenti consecutivi
- **Rosso**: fallimenti consecutivi arrivati o oltre `-ResumeThreshold`
- **Giallo**: l'FQDN non risolve (priorità su tutti gli altri colori)

## Jitter e scadenza certificato

- **JITTER(ms)**: media mobile della variazione tra RTT consecutivi (stessa formula di RFC 3550/1889), visibile in dashboard e nel riepilogo finale. Utile per individuare collegamenti instabili anche quando la perdita pacchetti è bassa.
- **Scadenza certificato** (`-Protocol Https`): all'avvio, una sola volta per host (non ad ogni ciclo, per non aggiungere carico oltre al monitoraggio stesso), viene letta la data di scadenza del certificato TLS. La colonna CERT(gg) mostra i giorni rimanenti (negativo se già scaduto), con un `!` quando rientra entro `-CertWarningDays` giorni (default 30).

## Rilevamento cambi di percorso

`-PathTrace` traccia periodicamente il percorso di rete (hop per hop) verso ogni host e segnala se cambia rispetto alla traccia precedente. Utile per notare un failover su un collegamento di backup, una riconvergenza di routing, o instradamenti inattesi. La sonda è nativa (nessun processo esterno), non bloccante (un hop per ciclo, spalmato su più cicli) e completamente separata da `-TraceOnFailure`.

**Attenzione alle reti con bilanciamento di carico (ECMP)**: se la tua rete instrada pacchetti diversi dello stesso flusso su percorsi leggermente diversi (comune con più collegamenti WAN in bilanciamento), potresti vedere avvisi anche senza nessun problema reale. La funzione confronta l'intera lista di hop: qualunque differenza, anche di un solo hop a parità di lunghezza del percorso, scatena la segnalazione.

## Note di compatibilità console

Su console con buffer verticale ridotto (tipico di "Windows PowerShell" classica/conhost su alcuni PC, a differenza di Windows Terminal) lo script forza esplicitamente un'altezza di buffer sufficiente a contenere banner, intestazione e tutte le righe host, per evitare che lo scroll automatico rinumeri le righe e sballi la dashboard.

## Changelog

Vedi [CHANGELOG.it.md](CHANGELOG.it.md).
