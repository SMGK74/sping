# Changelog

*[English version](CHANGELOG.md) | Italiano*

Tutte le modifiche rilevanti al progetto sono documentate in questo file.

## [2.10.2]

### Corretto
- La riga live del tracciamento percorso mostrava sempre lo stesso host (il primo nell'elenco che risultasse attivo), lasciando invisibili le tracce in corso su altri host se quello restava attivo più a lungo (tipico di un host irraggiungibile, con molti hop senza risposta). Ora ruota tra tutte le tracce attualmente attive, con un contatore (es. "2/4") quando ce n'è più di una.

## [2.10.1]

### Aggiunto
- Riga dedicata della dashboard che mostra live il tracciamento del percorso in corso (host, hop attuale su totale, IP scoperti finora), o quando nessuna traccia è attiva il conto alla rovescia in minuti alla prossima. Prima non c'era modo di confermare che `-TracePathChanges` stesse effettivamente lavorando quando il percorso non cambiava.

## [2.10.0]

### Aggiunto
- Parametro `-TracePathChanges`: ritraccia periodicamente il percorso di rete verso ogni host, indipendentemente dal ciclo di ping e da `-TraceOnFailure`, con una sonda nativa (nessun processo esterno, nessuna dipendenza dalla lingua di Windows) e non bloccante (un hop per ciclo, spalmato su più cicli). Segnala qualunque differenza rispetto alla traccia precedente, sia nel numero di hop sia negli hop stessi a parità di lunghezza. Un marcatore compare su STATO per quel ciclo, e il dettaglio completo prima/dopo viene salvato in un file sotto `SpingData\pathtraces`.
- Parametri `-PathTraceIntervalMinutes` (default 15) e `-PathTraceMaxHops` (default 20) per controllare frequenza e profondità del tracciamento.

## [2.9.0]

### Aggiunto
- Parametro `-LogFormat` (`Csv` di default, o `Json`): il formato JSON scrive un oggetto compatto per riga (JSON Lines/NDJSON), pensato per l'ingestione in streaming da parte di strumenti SIEM/monitoring (Splunk, ELK, Sentinel, ecc.), con più campi rispetto alle colonne fisse del CSV: protocollo, jitter, giorni alla scadenza del certificato quando disponibile. L'estensione del file di log di default segue il formato scelto (`.csv` o `.jsonl`). Persistibile con `-SaveAsDefault`.

## [Infrastruttura]

### Aggiunto
- GitHub Action con PSScriptAnalyzer (`.github/workflows/psscriptanalyzer.yml`): analisi statica automatica di `Sping.ps1` a ogni push/pull request su `main`. Fallisce solo su errori bloccanti, mostra gli avvisi come informativi; esclude `PSAvoidUsingWriteHost` (uso deliberato per la dashboard colorata in console). Badge di stato aggiunto in cima a entrambi i README.

## [2.8.4]

### Corretto
- `-IgnoreCertificateErrors` per il monitoraggio HTTPS vero e proprio (non la sonda del certificato, già corretta in 2.5.9) usava lo stesso schema poi dimostrato rotto: uno scriptblock PowerShell come callback di validazione TLS, invocato da .NET su un thread privo di Runspace. Anche un semplice `{ $true }` è comunque codice PowerShell che richiede un Runspace per eseguire, quindi il bypass rischiava di fallire silenziosamente (o far fallire l'intera connessione) esattamente come il bug già diagnosticato per il certificato. Risolto compilando una vera classe .NET con `Add-Type` (bytecode reale, nessuna dipendenza da Runspace) al posto dello scriptblock.

## [2.8.3]

### Aggiunto
- Con più di 40 host in modalità completa (senza `-Summary` già specificato), lo script ora chiede interattivamente se passare a `-Summary` invece di limitarsi ad avvisare. Basta premere Invio o rispondere "no" per restare in modalità completa.

## [2.8.2]

### Corretto
- L'avviso "troppi host, valuta -Summary" (introdotto in 2.8.1) non si vedeva mai con molti host, perché veniva stampato prima delle centinaia di righe host, finendo fuori vista quando la console scorreva per stamparle. Ora è stampato dopo, restando l'ultima riga visibile (le righe della dashboard, una volta create, si aggiornano per posizione e non ne vengono aggiunte altre).

### Aggiunto
- Parametro `-SummaryColumns` (default 4): numero di host per riga nella griglia compatta di `-Summary`, prima fisso. Persistibile con `-SaveAsDefault`.

## [2.8.1]

### Aggiunto
- Parametri `-TraceCooldownMinutes` (default 10) e `-MaxConcurrentTraces` (default 5) per `-TraceOnFailure`: evitano di ritracciare un host che flappa troppo di frequente e di esaurire le risorse di sistema quando molti host cadono insieme (es. un range CIDR ampio). I traceroute in eccesso vengono saltati, non accodati.
- Avviso live sulla riga 1 della dashboard (solo modalità completa, non `-Summary`) che mostra l'ultimo traceroute avviato o saltato e il motivo.
- Avviso quando si monitorano più di 40 host in modalità dashboard completa, suggerendo `-Summary` per una vista più compatta - utile in particolare con range/CIDR ampi (es. un `/24`).

### Modificato
- Margine di sicurezza sull'altezza del buffer console aumentato, per maggiore tranquillità con conteggi host elevati.

## [2.8.0]

### Aggiunto
- La lingua di default ora viene rilevata automaticamente dalla cultura UI di sistema al primo avvio (italiano se il sistema è in italiano, altrimenti inglese), invece di partire sempre in inglese. Il rilevamento vale solo alla creazione iniziale delle impostazioni: una volta salvata una scelta (esplicita o tramite `-SaveAsDefault`), quella resta autorevole.
- Parametro `-DisableAlerts`: avvia con l'allarme sonoro/vocale disattivato invece che attivo di default, persistibile con `-SaveAsDefault`. Resta comunque disponibile il toggle live col tasto `A` durante il monitoraggio.

## [2.7.0]

### Aggiunto
- Parametro `-TraceOnFailure`: quando un host passa da raggiungibile a non raggiungibile (o TTL scaduto), avvia `tracert` per quell'host come processo indipendente in background, con l'output salvato in un file con timestamp sotto `SpingData\traces`. Scatta una volta per episodio di down (transizione 0→1 fallimenti consecutivi), non ad ogni ciclo fallito, e non blocca in alcun modo la dashboard - nessuna cattura/interpretazione dell'output in tempo reale, l'utente legge il file quando gli serve. I file generati durante la sessione sono elencati nel riepilogo finale.

## [2.6.0]

### Aggiunto
- Ogni host in `-ComputerName` (o in una lista salvata) può ora essere un range/CIDR/subnet mask invece di un singolo indirizzo, espanso automaticamente in più host: `10.0.0.0/23`, `10.0.0.0/255.255.254.0`, `10.0.0.1-10.0.0.50`, o la scorciatoia `10.0.0.1-50` (solo ultimo ottetto). Network e broadcast esclusi automaticamente (eccetto /31 e /32). Deduplica automatica se un host compare sia esplicitamente sia dentro un range.
- Parametro `-MaxRangeHosts` (default 1024): limite di sicurezza sul numero di host generabili da un singolo range/CIDR, per evitare di monitorare per errore migliaia di host da un range troppo ampio.

### Rimosso
- Tolto il blocco diagnostico temporaneo per la colonna CERT(gg) (introdotto in 2.5.5, non più necessario dopo la correzione definitiva in 2.5.9).

## [2.5.8]

### Modificato
- La colonna CERT(gg) ora compare solo con `-Protocol Https`, invece di essere sempre presente con un `-` per ICMP/HTTP/TCP dove non ha senso.

## [2.5.5] - [2.5.7]

### Corretto
- Diagnosi e correzione, in più passaggi, della colonna CERT(gg) rimasta sempre vuota: causa finale identificata in una connessione TLS riusata dal pool del processo PowerShell (da un lancio precedente dello script), che impediva alla validazione del certificato, e quindi al nostro punto di lettura, di scattare di nuovo. Risolto forzando una connessione nuova (`KeepAlive = $false`) per la sonda dedicata, e catturando il certificato direttamente dal callback di validazione di `ServicePointManager` invece che dalla proprietà `ServicePoint.Certificate` (nota per essere inaffidabile in .NET Framework).

## [2.5.4]

### Corretto
- Colonna CERT(gg) ancora sempre `-` con monitoraggio HTTPS funzionante: la sonda apriva una connessione nuova "fredda" (handshake TCP+TLS completo) ma con lo stesso timeout stretto usato per il monitoraggio (che invece riusa connessioni gia' aperte), risultando probabilmente troppo corta su reti con latenza/ispezione significativa. Ora la sonda usa un timeout dedicato, molto piu' ampio (dato che gira una sola volta all'avvio). Aggiunto anche un fallback via `ServicePointManager.FindServicePoint` per gli scenari con proxy in cui `req.ServicePoint` potrebbe non essere l'oggetto realmente usato per la connessione.

## [2.5.3]

### Corretto
- **Regressione critica introdotta in 2.5.2**: agganciare la cattura della scadenza certificato al callback di validazione TLS delle richieste HTTPS del monitoraggio (invocato da .NET su un thread di I/O in background) poteva far fallire l'intera connessione HTTPS ("The SSL connection could not be established"), rompendo il monitoraggio vero e proprio. Rimosso quel meccanismo.
- La lettura della scadenza certificato torna a essere una chiamata separata e isolata (un suo eventuale fallimento non tocca il monitoraggio), ora basata su `HttpWebRequest`/`ServicePoint` invece della connessione TLS grezza di 2.5.0/2.5.1: rispetta automaticamente proxy e percorso di rete come il monitoraggio HTTPS reale, risolvendo il problema per cui la colonna CERT(gg) restava sempre `-` anche con host raggiungibili.

## [2.5.2]

### Corretto
- La colonna CERT(gg) mostrava sempre `-` anche con `-Protocol Https` funzionante (200 OK): la sonda dedicata apriva una connessione TLS grezza separata (`TcpClient`+`SslStream`), che in alcuni ambienti di rete (proxy aziendale non attraversato da una connessione diretta, ispezione TLS del firewall, timeout troppo stretto) falliva silenziosamente anche quando il monitoraggio HTTPS vero e proprio funzionava. Risolto catturando la scadenza del certificato direttamente dalle richieste HTTPS del monitoraggio già funzionanti (stesso `HttpClient`, stesso percorso di rete), invece di aprire una connessione aggiuntiva.

## [2.5.1]

### Modificato
- La scadenza del certificato TLS (`-Protocol Https`) ora ha una colonna dedicata CERT(gg) in dashboard e nel riepilogo finale, sempre visibile (mostra `-` per gli altri protocolli), invece di un suffisso testuale appiccicato a STATO solo quando in prossimità della scadenza. Un `!` segnala quando si rientra entro `-CertWarningDays` giorni.

## [2.5.0]

### Aggiunto
- Nuovo `-Protocol Tcp` con parametro `-Port` obbligatorio: verifica se una porta TCP specifica accetta connessioni, invece di un ping ICMP o una richiesta web.
- Controllo scadenza certificato TLS con `-Protocol Https`: letto una sola volta all'avvio per host (non ad ogni ciclo, per non aggiungere carico), la colonna STATO segnala quando la scadenza rientra entro `-CertWarningDays` giorni (default 30) o è già passata.
- Colonna JITTER(ms) in dashboard e nel riepilogo finale, calcolata con la stessa formula di RFC 3550/1889 (media mobile della variazione tra RTT consecutivi).
- La pausa minima di sicurezza contro comportamenti simili a un flood/DDoS (introdotta in 2.3.1 per Http/Https) si applica ora anche a `-Protocol Tcp`.

## [2.4.0]

### Aggiunto
- Colonna RICEVUTI nella dashboard live (prima presente solo nel riepilogo finale).
- Localizzazione dell'interfaccia tramite file JSON esterni: inglese di default, italiano selezionabile con `-Language it`, estendibile ad altre lingue copiando `SpingData\lang\en.json` come base per un nuovo `<codice>.json`.
- Percorso dati (impostazioni, liste, log, lingue) rilevato automaticamente: `SpingData` accanto allo script se scrivibile (per una cartella davvero portabile), altrimenti `%APPDATA%\SM-Script\Sping` come ripiego.
- Parametro `-Language`, persistibile con `-SaveAsDefault` come gli altri parametri comportamentali.

## [2.3.1]

### Aggiunto
- Intervallo minimo di 3000 ms imposto automaticamente con `-Protocol Http`/`Https` (anche se se ne richiede uno più basso, con avviso esplicito), per non rischiare che il monitoraggio assomigli a un flood/DDoS verso gli host controllati: una richiesta HTTP/HTTPS è molto più onerosa di un ping ICMP.

## [2.3.0]

### Aggiunto
- Tasto `A` durante il monitoraggio per attivare/disattivare l'allarme sonoro/vocale al volo, senza fermare lo script. Lo stato (ON/OFF) è visibile nel titolo della finestra della console.
- Parametro `-Protocol` (`Icmp` di default, `Http`, `Https`): con Http/Https ogni ciclo invia una richiesta web asincrona parallela a ogni host invece di un ping ICMP: successo su codice di stato 2xx/3xx, RTT(ms) è la latenza di risposta completa, STATO mostra il codice (o il motivo dell'errore/timeout).
- Parametro `-IgnoreCertificateErrors` (solo con `-Protocol Https`) per saltare la validazione del certificato TLS, utile per host interni con certificati self-signed.
- `Protocol` persistito tra le impostazioni salvabili con `-SaveAsDefault` e mostrato da `-ShowSettings`.

## [2.2.0]

### Aggiunto
- Riscrittura completa da VBScript a PowerShell.
- Ping parallelo di tutti gli host ad ogni ciclo tramite `System.Net.NetworkInformation.Ping` asincrono (al posto di WMI).
- Dashboard live in console: una riga fissa per host, aggiornata sul posto senza flicker né scroll.
- Modalità `-Summary`: riga compatta unica con simboli per host (`!!` successo, `TX` TTL Expired, `..` altro fallimento).
- Log CSV opzionale (`-Log` / `-LogFile`), disattivato di default, file aperto una sola volta all'avvio.
- Allarme sonoro/vocale (WAV + sintesi vocale, con fallback a beep) al ripristino di un host dopo la soglia di fallimenti consecutivi.
- Impostazioni e liste host salvate come JSON in `%APPDATA%\SM-Script\Sping`, non più nel registro.
- Gestione pulita dell'interruzione (`Q` o `Ctrl+C`), con riepilogo finale sempre stampato.
- Help completo via comment-based help (`-Help` o nessun parametro).
- Colori per riga nella dashboard: verde (successo), arancione (fallimento sotto soglia), rosso (fallimento da soglia `-ResumeThreshold` in su), giallo (FQDN non risolto, priorità massima). Applicati anche ai simboli della modalità `-Summary` e al riepilogo finale.
- Risoluzione DNS indipendente e asincrona ad ogni ciclo (parallela al ping), cosi' la colonna IP riflette sempre la risoluzione corrente anche se la cache DNS scade o il record cambia.
- Larghezza della colonna host calcolata dinamicamente sul nome più lungo tra quelli monitorati, per non sfasare le colonne successive con FQDN lunghi.
- Riepilogo finale riformattato con le stesse intestazioni/colori/larghezza colonna della dashboard live, al posto della tabella generica di PowerShell.

### Corretto
- Binding di più host posizionali (`ValueFromRemainingArguments`) che falliva con più di un argomento posizionale.
- Colonna IP che mostrava `0.0.0.0` sui timeout invece di conservare l'ultimo IP valido.
- Righe della dashboard che non si aggiornavano tutte (solo l'ultima) per una race condition nella lettura ripetuta di `CursorTop` su Windows Terminal/ConPTY. Risolto con una singola lettura iniziale e offset aritmetici per riga.
- Word-wrap di intestazione/righe più larghe della finestra che sfasava gli indici di riga e causava crash su `SetCursorPosition`. Risolto troncando/riempiendo ogni riga alla larghezza console.
- Righe duplicate/crash dopo esecuzioni ripetute dovuti a scroll del buffer da contenuto precedente. Risolto con `Clear-Host` a inizio di ogni sessione di monitoraggio.
- Banner con la versione dello script che spariva perché stampato prima del `Clear-Host`. Ora ristampato subito dopo.
- Errore visibile in console quando un FQDN non risolveva, causato da `Task.WaitAll` che rilanciava l'eccezione aggregata prima della gestione prevista. Risolto attendendo il completamento dei task senza propagare l'eccezione a quel punto.
- Dashboard "sballata" su console con buffer verticale ridotto (es. Windows PowerShell classica su alcuni PC): il buffer scorreva e rinumerava le righe durante la stampa iniziale, invalidando le coordinate assolute calcolate. Risolto forzando un'altezza di buffer sufficiente e troncando il messaggio di avviso larghezza finestra che andava a capo da solo consumando righe non contate.

## [1.x] - Sping.vbs (originale)

Versione VBScript originale: ping multi-host, TTL/timeout, allarme sonoro al ripristino, impostazioni e liste host nel registro di Windows.
