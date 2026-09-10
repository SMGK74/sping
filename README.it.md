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

## Utilizzo

```powershell
# Help completo (anche lanciando lo script senza parametri)
.\Sping.ps1 -Help

# Ping di più host in parallelo
.\Sping.ps1 192.168.1.1 web-server-01 10.0.0.5 -Count 50 -TimeoutMillis 500

# Lista salvata + suffisso DNS + modalità compatta + log CSV
.\Sping.ps1 -ListName Core -Domain contoso.local -Summary -Log

# Ping HTTP/HTTPS invece di ICMP (utile se ICMP e' filtrato ma il servizio web e' quello da monitorare)
.\Sping.ps1 www.contoso.local -Protocol Https -IgnoreCertificateErrors

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
.\Sping.ps1 vpn-remoto.contoso.local -TracePathChanges -PathTraceIntervalMinutes 30

# Mostra solo gli host non raggiungibili (F per cambiare filtro al volo durante il monitoraggio)
.\Sping.ps1 -ListName Core -DisplayFilter DownOnly

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

Durante il monitoraggio: premi `A` in qualsiasi momento per attivare/disattivare l'allarme sonoro/vocale (lo stato è visibile nel titolo della finestra), oppure `Q`/`Ctrl+C` per interrompere in modo pulito. Viene sempre stampato un riepilogo finale, senza errori di terminazione.

## Parametri principali

| Parametro | Descrizione |
|---|---|
| `ComputerName` (posizionale) | Uno o più host/IP da pingare in parallelo. Ogni voce accetta anche un range/CIDR/subnet mask (es. `10.0.0.0/23`, `10.0.0.1-10.0.0.50`, `10.0.0.1-50`), espanso automaticamente in più host |
| `-MaxRangeHosts` | Limite di sicurezza sul numero di host che un singolo range/CIDR può generare (default 1024), per evitare di monitorare per errore migliaia di host da un range troppo ampio |
| `-TraceOnFailure` | Quando i fallimenti consecutivi di un host passano da 0 a 1 (inizio di un nuovo episodio di down), avvia `tracert -d -h 20 -w 1000` per quell'host come processo indipendente in background (non blocca la dashboard), salvando l'output in un file con timestamp sotto `SpingData\traces`. Scatta una volta per episodio, non ad ogni ciclo fallito. Un avviso in riga 1 della dashboard mostra l'ultimo traceroute avviato o saltato |
| `-TraceCooldownMinutes` | Solo con `-TraceOnFailure`: minuti minimi tra due traceroute per lo stesso host, per non ritracciare un host che flappa a ogni episodio (default 10) |
| `-MaxConcurrentTraces` | Solo con `-TraceOnFailure`: tetto massimo di `tracert` in esecuzione contemporanea su tutti gli host, per non esaurire le risorse quando molti host cadono insieme (es. un range CIDR ampio) (default 5) |
| `-TracePathChanges` | Ritraccia periodicamente il percorso verso ogni host (indipendente dal ciclo di ping e da `-TraceOnFailure`) con una sonda nativa non bloccante spalmata su più cicli, segnalando se il percorso cambia rispetto alla traccia precedente. Una riga dedicata della dashboard mostra live la traccia in corso (host, hop attuale, IP scoperti finora) o il conto alla rovescia alla prossima. Il dettaglio completo prima/dopo viene salvato in un file sotto `SpingData\pathtraces` |
| `-PathTraceIntervalMinutes` | Solo con `-TracePathChanges`: minuti tra la fine di una traccia completata e l'inizio della successiva, per host (default 15) |
| `-PathTraceMaxHops` | Solo con `-TracePathChanges`: numero massimo di hop da sondare prima di rinunciare a raggiungere la destinazione (default 20) |
| `-DisplayFilter` | Quali host mostrare nella dashboard: `All` (default), `UpOnly` (solo raggiungibili), `DownOnly` (solo non raggiungibili). Gli host esclusi mantengono la loro riga, che resta vuota - le righe non si spostano mai. Cambia al volo con il tasto `F` durante il monitoraggio (Tutti → Solo attivi → Solo inattivi → Tutti). Non disponibile in modalità `-Summary` |
| `-ListName` | Nome di una lista host salvata (combinabile con `ComputerName`) |
| `-Domain` | Suffisso DNS aggiunto a ogni host |
| `-Count` | Numero di cicli di ping (default: continuo) |
| `-Protocol` | `Icmp` (default), `Http`, `Https` o `Tcp`: con Http/Https ogni ciclo invia una richiesta web parallela, con Tcp un tentativo di connessione a `-Port`, invece di un ping ICMP |
| `-Port` | Porta TCP di destinazione. Obbligatorio con `-Protocol Tcp` |
| `-IgnoreCertificateErrors` | Solo con `-Protocol Https`: salta la validazione del certificato TLS (utile per host interni con certificati self-signed) |
| `-CertWarningDays` | Solo con `-Protocol Https`: soglia in giorni sotto la quale la colonna STATO segnala che il certificato sta per scadere (default 30) |
| `-Language` | Lingua dell'interfaccia: `en` o `it`. Default: rilevata automaticamente dalla lingua di sistema al primo avvio (italiano se il sistema è in italiano, altrimenti inglese), poi quella salvata l'ultima volta. Personalizzabile ed estendibile, vedi sezione Lingua |
| `-DisableAlerts` | Parte con l'allarme sonoro/vocale disattivato invece che attivo di default (resta comunque attivabile/disattivabile al volo col tasto `A`). Persistibile con `-SaveAsDefault` per partire sempre disattivato |
| `-TimeToLive` | TTL dei pacchetti ping (solo `-Protocol Icmp`) |
| `-TimeoutMillis` | Timeout in ms per ogni risposta |
| `-IntervalMillis` | Pausa in ms tra un ciclo e l'altro. Con `-Protocol Http`/`Https`/`Tcp` viene imposto un minimo di 3000 ms, anche se richiedi un valore più basso, per non rischiare di sembrare un flood/DDoS verso gli host monitorati |
| `-ResumeThreshold` | Fallimenti consecutivi da cui la riga passa da arancione a rosso, e sotto cui scatta l'allarme sonoro al ripristino |
| `-Summary` | Griglia compatta invece di una riga per host, vedi `-SummaryColumns` |
| `-SummaryColumns` | Solo con `-Summary`: numero di host per riga nella griglia compatta (default 4) |
| `-SoundFile` | WAV riprodotto al ripristino di un host |
| `-Log` / `-LogFile` | Abilita il logging (default o percorso custom) |
| `-LogFormat` | `Csv` (default) o `Json`: quest'ultimo scrive un oggetto JSON compatto per riga (JSON Lines/NDJSON), adatto all'ingestione da parte di strumenti SIEM/monitoring, con più campi del CSV (protocollo, jitter, giorni alla scadenza del certificato) |
| `-SaveAsDefault` | Salva i parametri di questa esecuzione come nuovi default |
| `-ShowSettings` / `-ShowLists` | Mostra impostazioni/liste salvate ed esce |
| `-SaveList` / `-RemoveList` | Salva o elimina una lista host sotto `-ListName` |

## Configurazione e portabilità

Impostazioni, liste host, log e file di lingua persistono come JSON, non più nel registro di Windows come nella versione VBScript originale. La cartella dove vengono salvati è scelta automaticamente:

1. **`SpingData` accanto allo script** (es. `C:\Tools\SpingData`), se quella posizione è scrivibile. Così l'intera cartella `Sping` è portabile: copiala su un altro PC o su una chiavetta e impostazioni/liste/log viaggiano insieme allo script.
2. **`%APPDATA%\SM-Script\Sping`** come ripiego, se lo script si trova in un percorso non scrivibile (es. `Program Files` o una condivisione in sola lettura).

## Lingua

L'interfaccia parte in italiano se il sistema è in italiano, altrimenti in inglese (rilevato automaticamente al primo avvio). Con `-Language it`/`-Language en` puoi forzarla esplicitamente. Al primo avvio, lo script genera i file `en.json` e `it.json` dentro `SpingData\lang\`: puoi modificarli, oppure copiarne uno come base e crearne uno nuovo (es. `fr.json` con le stesse chiavi) per aggiungere un'altra lingua, basta poi richiamarlo con `-Language fr`.

## Colori dashboard

- **Verde**: ping riuscito
- **Arancione**: ping fallito, sotto la soglia di `-ResumeThreshold` fallimenti consecutivi
- **Rosso**: fallimenti consecutivi arrivati o oltre `-ResumeThreshold`
- **Giallo**: l'FQDN non risolve (priorità su tutti gli altri colori)

## Jitter e scadenza certificato

- **JITTER(ms)**: media mobile della variazione tra RTT consecutivi (stessa formula di RFC 3550/1889), visibile in dashboard e nel riepilogo finale. Utile per individuare collegamenti instabili anche quando la perdita pacchetti è bassa.
- **Scadenza certificato** (`-Protocol Https`): all'avvio, una sola volta per host (non ad ogni ciclo, per non aggiungere carico oltre al monitoraggio stesso), viene letta la data di scadenza del certificato TLS. La colonna CERT(gg) mostra i giorni rimanenti (negativo se già scaduto), con un `!` quando rientra entro `-CertWarningDays` giorni (default 30).

## Rilevamento cambi di percorso

`-TracePathChanges` traccia periodicamente il percorso di rete (hop per hop) verso ogni host e segnala se cambia rispetto alla traccia precedente. Utile per notare un failover su un collegamento di backup, una riconvergenza di routing, o instradamenti inattesi. La sonda è nativa (nessun processo esterno), non bloccante (un hop per ciclo, spalmato su più cicli) e completamente separata da `-TraceOnFailure`.

**Attenzione alle reti con bilanciamento di carico (ECMP)**: se la tua rete instrada pacchetti diversi dello stesso flusso su percorsi leggermente diversi (comune con più collegamenti WAN in bilanciamento), potresti vedere avvisi anche senza nessun problema reale. La funzione confronta l'intera lista di hop: qualunque differenza, anche di un solo hop a parità di lunghezza del percorso, scatena la segnalazione.

## Note di compatibilità console

Su console con buffer verticale ridotto (tipico di "Windows PowerShell" classica/conhost su alcuni PC, a differenza di Windows Terminal) lo script forza esplicitamente un'altezza di buffer sufficiente a contenere banner, intestazione e tutte le righe host, per evitare che lo scroll automatico rinumeri le righe e sballi la dashboard.

## Changelog

Vedi [CHANGELOG.it.md](CHANGELOG.it.md).
