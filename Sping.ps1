#Requires -Version 5.1
<#
.SYNOPSIS
    Sping v2.10.0 - Advanced multi-host ping monitor (PowerShell rewrite of the original Sping.vbs).

.DESCRIPTION
    Pings one or more hosts IN PARALLEL every cycle, showing a live dashboard in the console
    (one fixed row per host, updated in place - no flicker, no scrolling) and optionally writing
    a structured CSV log (opened once at start, not reopened every cycle). Plays a sound/voice
    alert when a host that was down comes back up. Settings, saved host lists and language files
    are stored as JSON in a "SpingData" folder next to the script when that location is writable
    (fully portable - copy the whole folder anywhere), otherwise under %APPDATA%\SM-Script\Sping.

    Press Q or Ctrl+C at any time to stop cleanly - no terminating errors, a final summary is
    always printed. Press A at any time to toggle the sound/voice alert on or off (reflected in
    the console window title).

.PARAMETER ComputerName
    One or more hosts / IP addresses to ping (pinged in parallel every cycle). Besides plain
    hostnames/IPs, each entry also accepts:
      - a CIDR range: 10.0.0.0/23
      - a subnet mask range: 10.0.0.0/255.255.254.0
      - an IP range: 10.0.0.1-10.0.0.50, or the shorthand 10.0.0.1-50 (last octet only)
    Network and broadcast addresses are excluded automatically (except for /31 and /32).

.PARAMETER MaxRangeHosts
    Safety cap on how many hosts a single CIDR/mask/range entry can expand to (default 1024) - to
    avoid accidentally monitoring (and flooding) thousands of hosts from a typo or an overly broad range.

.PARAMETER TraceOnFailure
    When a host's consecutive-failure count goes from 0 to 1 (the start of a new down episode -
    unreachable or TTL expired), runs "tracert -d -h 20 -w 1000" for that host as an independent
    background process (does not block the dashboard) and saves its output to a timestamped file
    under SpingData\traces. Fires once per down episode, not on every failed cycle - subject to
    -TraceCooldownMinutes and -MaxConcurrentTraces below. A brief on-screen notice (row 1) shows the
    latest trace started or skipped.

.PARAMETER TraceCooldownMinutes
    Only relevant with -TraceOnFailure. Minimum minutes between two traceroutes for the SAME host,
    to avoid re-tracing a flapping host on every down episode. Default: 10.

.PARAMETER MaxConcurrentTraces
    Only relevant with -TraceOnFailure. Cap on how many tracert processes can be running at once
    across ALL hosts, to avoid exhausting system resources when many hosts fail together (e.g. a
    broad CIDR range going down at once). Default: 5. Extra traces are skipped, not queued.

.PARAMETER TracePathChanges
    Periodically re-traces the route to every host (independent of the ping cycle, and independent
    of -TraceOnFailure) using a native, non-blocking hop-by-hop probe spread across several cycles
    (one hop per cycle, never pausing the dashboard), and flags it if the route differs from the
    previous trace - different hop count, or same count with different hops. A change appends a
    brief marker to STATO for that cycle, and full before/after hop details are saved to a
    timestamped file under SpingData\pathtraces.

.PARAMETER PathTraceIntervalMinutes
    Only relevant with -TracePathChanges. Minutes between the end of one completed trace and the
    start of the next, per host. Default: 15.

.PARAMETER PathTraceMaxHops
    Only relevant with -TracePathChanges. Maximum hops to probe before giving up on reaching the
    destination. Default: 20.

.PARAMETER ListName
    Name of a previously saved host list to ping (can be combined with -ComputerName).

.PARAMETER Domain
    DNS suffix appended to every host (e.g. "contoso.local").

.PARAMETER Count
    Number of ping cycles to run. Default from config (999999 = effectively continuous).

.PARAMETER Protocol
    Icmp (default), Http, Https, or Tcp. With Http/Https, each cycle sends a parallel async web request
    to every host instead of an ICMP echo: success is a 2xx/3xx status code, RTT(ms) is the full
    response latency, and STATO shows the status code (or the error/timeout reason). With Tcp, each
    cycle attempts a TCP connection to -Port instead: success means the port accepted the connection.

.PARAMETER Port
    TCP port to connect to. Required with -Protocol Tcp.

.PARAMETER IgnoreCertificateErrors
    Only relevant with -Protocol Https. Skip TLS certificate validation (useful for internal hosts
    with self-signed certificates).

.PARAMETER CertWarningDays
    Only relevant with -Protocol Https. Once per host, at startup, the server's TLS certificate
    expiration date is read (a dedicated lightweight handshake, not repeated every cycle). If it
    expires within this many days, STATO shows a warning suffix. Default: 30.

.PARAMETER DisableAlerts
    Starts with the sound/voice alert disabled instead of the default enabled (can still be toggled
    live with the A key during monitoring). Persist with -SaveAsDefault to always start disabled.

.PARAMETER Language
    UI language code, e.g. "en" or "it". Default: auto-detected from the system's UI language on
    first run (Italian if the system is in Italian, English otherwise), then whatever was last saved.
    Reads/writes JSON files under SpingData\lang - edit an existing one or add a new "<code>.json"
    with the same keys to customize or add a language.

.PARAMETER TimeToLive
    TTL for each ping packet. Only relevant with -Protocol Icmp.

.PARAMETER TimeoutMillis
    Timeout in milliseconds to wait for each reply.

.PARAMETER IntervalMillis
    Pause in milliseconds between ping cycles. With -Protocol Http/Https, un minimo di 3000ms viene imposto
    automaticamente (anche se ne chiedi uno piu' basso) per non rischiare di sembrare un flood/DDoS verso
    gli host monitorati.

.PARAMETER ResumeThreshold
    Number of consecutive failures after which a recovery triggers the sound/voice alert.

.PARAMETER Summary
    Show a compact grid instead of one full row per host. Columns per row: see -SummaryColumns.

.PARAMETER SummaryColumns
    Only relevant with -Summary. Number of hosts per row in the compact grid. Default: 4.

.PARAMETER SoundFile
    WAV file to play when a host recovers.

.PARAMETER Log
    Enable logging to the default path (SpingData\logs next to the script, or %APPDATA%\SM-Script\Sping\logs
    as fallback - see DESCRIPTION). Off by default. Format controlled by -LogFormat.

.PARAMETER LogFile
    Enable logging to a specific path (implies -Log). Off by default.

.PARAMETER LogFormat
    Csv (default) or Json. Json writes one compact JSON object per line (JSON Lines / NDJSON,
    suitable for streaming ingestion by SIEM/monitoring tools such as Splunk, ELK, or Sentinel)
    with more fields than the fixed CSV columns: protocol, jitter, and certificate days-to-expiry
    when available. The default log filename extension matches the format (.csv or .jsonl) unless
    -LogFile sets an explicit path.

.PARAMETER SaveAsDefault
    Persist the numeric/behavioural parameters given on this run as the new defaults.

.PARAMETER ShowSettings
    Show current default settings and exit.

.PARAMETER ShowLists
    Show all saved host lists and exit.

.PARAMETER SaveList
    Save -ComputerName under -ListName for future reuse, then exit.

.PARAMETER RemoveList
    Delete the host list named by -ListName, then exit.

.PARAMETER Help
    Show this full help and exit. Also shown automatically if the script is run with no parameters at all.

.EXAMPLE
    .\Sping.ps1

.EXAMPLE
    .\Sping.ps1 192.168.1.1 web-server-01 10.0.0.5 -Count 50 -TimeoutMillis 500

.EXAMPLE
    .\Sping.ps1 10.0.0.0/23 -Summary

.EXAMPLE
    .\Sping.ps1 db-server-01 web-server-02 -TraceOnFailure -Log

.EXAMPLE
    .\Sping.ps1 -ListName Core -Domain contoso.local -Summary -Log

.EXAMPLE
    .\Sping.ps1 10.0.0.1 10.0.0.2 -ListName Core -SaveList

.EXAMPLE
    .\Sping.ps1 www.contoso.local -Protocol Https -IgnoreCertificateErrors

.EXAMPLE
    .\Sping.ps1 db-server-01 -Protocol Tcp -Port 1433

.EXAMPLE
    .\Sping.ps1 -ShowSettings -Language it
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$ComputerName,

    [string]$ListName,
    [string]$Domain = '',
    [int]$Count,
    [ValidateSet('Icmp', 'Http', 'Https', 'Tcp')]
    [string]$Protocol,
    [int]$Port,
    [int]$MaxRangeHosts,
    [switch]$TraceOnFailure,
    [int]$TraceCooldownMinutes,
    [int]$MaxConcurrentTraces,
    [switch]$TracePathChanges,
    [int]$PathTraceIntervalMinutes,
    [int]$PathTraceMaxHops,
    [switch]$IgnoreCertificateErrors,
    [int]$CertWarningDays,
    [switch]$DisableAlerts,
    [string]$Language,
    [int]$TimeToLive,
    [int]$TimeoutMillis,
    [int]$IntervalMillis,
    [int]$ResumeThreshold,
    [switch]$Summary,
    [int]$SummaryColumns,
    [string]$SoundFile,
    [switch]$Log,
    [string]$LogFile,
    [ValidateSet('Csv', 'Json')]
    [string]$LogFormat,
    [switch]$SaveAsDefault,
    [switch]$ShowSettings,
    [switch]$ShowLists,
    [switch]$SaveList,
    [switch]$RemoveList,
    [switch]$Help
)

# Nessun parametro, oppure -Help esplicito: mostra la guida completa ed esci.
if ($Help -or $PSBoundParameters.Count -eq 0) {
    Get-Help -Full $PSCommandPath
    return
}

$script:ScriptVersion = '2.10.0'
Write-Host "Sping v$ScriptVersion" -ForegroundColor DarkCyan

#region Paths & config -------------------------------------------------------

function Resolve-SpingDataDir {
    # Preferisce una cartella accanto allo script (SpingData), cosi' l'intera cartella e' portabile:
    # copiabile su un'altra macchina o su una chiavetta con impostazioni, liste e log al seguito.
    # Se non e' scrivibile (es. script in Program Files o percorso condiviso in sola lettura),
    # ripiega su %APPDATA%, sempre scrivibile per l'utente corrente indipendentemente da dove si trova lo script.
    $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PWD.Path }
    $portableDir = Join-Path $scriptDir 'SpingData'
    try {
        if (-not (Test-Path $portableDir)) { New-Item -ItemType Directory -Path $portableDir -Force -ErrorAction Stop | Out-Null }
        $testFile = Join-Path $portableDir '.writetest'
        [System.IO.File]::WriteAllText($testFile, 'ok')
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $portableDir
    } catch {
        return (Join-Path $env:APPDATA 'SM-Script\Sping')
    }
}

$script:ConfigDir  = Resolve-SpingDataDir
$script:ConfigFile = Join-Path $ConfigDir 'settings.json'
$script:ListsFile  = Join-Path $ConfigDir 'lists.json'
$script:LogDir     = Join-Path $ConfigDir 'logs'
$script:LangDir    = Join-Path $ConfigDir 'lang'
$script:TraceDir   = Join-Path $ConfigDir 'traces'
$script:PathTraceDir = Join-Path $ConfigDir 'pathtraces'

function Get-SpingConfig {
    # Rilevata dalla cultura UI di sistema solo alla creazione iniziale del file (primo avvio in assoluto):
    # se il sistema e' in italiano, il default parte in italiano, altrimenti in inglese. Una volta creato,
    # il file resta autorevole - questo rilevamento non sovrascrive una scelta gia' salvata in seguito.
    $detectedLanguage = if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'it') { 'it' } else { 'en' }
    $defaults = [ordered]@{
        TimeToLive      = 80
        ResumeThreshold = 5
        Count           = 999999
        TimeoutMillis   = 1000
        IntervalMillis  = 1000
        Summary         = $false
        SummaryColumns  = 4
        LogFormat       = 'Csv'
        SoundFile       = 'resume.wav'
        Protocol        = 'Icmp'
        Port            = 0
        CertWarningDays = 30
        Language        = $detectedLanguage
        AlertsEnabled   = $true
    }
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    if (-not (Test-Path $ConfigFile)) {
        $defaults | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
        return [pscustomobject]$defaults
    }
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        foreach ($key in $defaults.Keys) {
            if (-not ($cfg.PSObject.Properties.Name -contains $key)) {
                $cfg | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
            }
        }
        return $cfg
    } catch {
        # Messaggio in inglese: a questo punto la lingua non e' ancora risolta (dipende proprio dal config
        # che qui e' corrotto), quindi resta un fallback neutro invece di dipendere da $S.
        Write-Warning "Config file corrupted, restoring defaults."
        $defaults | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
        return [pscustomobject]$defaults
    }
}

function Save-SpingConfig {
    param($Config)
    $Config | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
}

function Get-SpingLists {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    if (-not (Test-Path $ListsFile)) {
        '{}' | Set-Content -Path $ListsFile -Encoding UTF8
        return [pscustomobject]@{}
    }
    try {
        return Get-Content $ListsFile -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Lists file corrupted, restoring empty."
        '{}' | Set-Content -Path $ListsFile -Encoding UTF8
        return [pscustomobject]@{}
    }
}

function Save-SpingLists {
    param($Lists)
    $Lists | ConvertTo-Json | Set-Content -Path $ListsFile -Encoding UTF8
}

# Stringhe integrate (fallback garantito, e base per generare i file lingua al primo avvio).
# L'inglese e' il default; l'italiano e le altre lingue sono file JSON in SpingData\lang, liberamente
# personalizzabili o duplicabili per aggiungerne di nuove (basta un file <codice>.json con le stesse chiavi).
$script:BuiltInStrings = @{
    en = @{
        CurrentSettingsHeader = "Current settings ({0}):"
        NoSavedLists          = "No saved lists."
        SavedListsHeader      = "Saved lists ({0}):"
        SpecifyListNameSave   = "Specify -ListName to save the list."
        SpecifyHostForList    = "Specify at least one host with -ComputerName to save the list '{0}'."
        ListSaved             = "List '{0}' saved with {1} hosts."
        SpecifyListNameRemove = "Specify -ListName to remove a list."
        ListRemoved           = "List '{0}' removed."
        ListNotExist          = "List '{0}' does not exist."
        ListNotExistIgnored   = "List '{0}' does not exist, it will be ignored."
        SettingsSaved         = "Settings saved as default."
        NoHostsError           = "No hosts to ping. Specify -ComputerName and/or -ListName. Use -ShowLists to see saved lists."
        HttpIntervalWarning   = "With -Protocol {0} the minimum interval is {1}ms to avoid overloading the monitored hosts (requested: {2}ms)."
        AlertsOn              = "Alerts: ON"
        AlertsOff             = "Alerts: OFF"
        WidthWarning          = "Note: the window is narrower than {0} columns, some columns will be cut off. Widen the window or use -Summary."
        ManyHostsWarning      = "Note: monitoring {0} hosts with one row each won't fit on a normal screen. Consider -Summary for a more compact view."
        ManyHostsPrompt       = "You're about to monitor {0} hosts in full dashboard mode, which likely won't fit on one screen. Switch to -Summary? [Y/n]: "
        MonitoringBanner      = "Sping - monitoring {0} hosts in parallel"
        Instructions          = "Press Q or Ctrl+C to stop cleanly, A to toggle alerts on/off."
        LogPath               = "Log: {0}"
        LogDisabled           = "Log: disabled (use -Log or -LogFile to enable it)"
        ColHost               = "HOST"
        ColIp                 = "IP"
        ColStatus             = "STATUS"
        ColRtt                = "RTT(ms)"
        ColSent               = "SENT"
        ColReceived           = "RECEIVED"
        ColLost               = "LOST"
        ColLossPct            = "LOSS%"
        ColTtlExp             = "TTLEXP"
        Waiting               = "waiting..."
        MonitoringEnded       = "Monitoring ended."
        LogSavedTo            = "Log saved to: {0}"
        TraceNoticesHeader    = "Traceroute started on failure (independent background process, output saved to):"
        TraceStarted          = "Traceroute started for {0}"
        TraceSkippedCooldown  = "Traceroute skipped for {0} (cooldown active)"
        TraceSkippedCap       = "Traceroute skipped for {0} (max concurrent reached)"
        PathChanged           = "Route changed for {0}"
        PathChangedSuffix     = "[ROUTE CHANGED]"
        PathChangeNoticesHeader = "Route changes detected (full before/after path saved to):"
        PingError             = "Ping error"
        RequestError          = "Request error"
        Timeout               = "Timeout"
        ResumeSpeech          = "The address {0} is reachable again"
        TcpError              = "Connection error"
        TcpOpen               = "Port {0} open"
        TcpPortRequired       = "-Port is required with -Protocol Tcp."
        ColJitter             = "JITTER(ms)"
        ColCertExp            = "CERT(d)"
    }
    it = @{
        CurrentSettingsHeader = "Impostazioni correnti ({0}):"
        NoSavedLists          = "Nessuna lista salvata."
        SavedListsHeader      = "Liste salvate ({0}):"
        SpecifyListNameSave   = "Specifica -ListName per salvare la lista."
        SpecifyHostForList    = "Specifica almeno un host con -ComputerName per salvare la lista '{0}'."
        ListSaved             = "Lista '{0}' salvata con {1} host."
        SpecifyListNameRemove = "Specifica -ListName per rimuovere una lista."
        ListRemoved           = "Lista '{0}' rimossa."
        ListNotExist          = "La lista '{0}' non esiste."
        ListNotExistIgnored   = "La lista '{0}' non esiste, verra' ignorata."
        SettingsSaved         = "Impostazioni salvate come default."
        NoHostsError           = "Nessun host da pingare. Specifica -ComputerName e/o -ListName. Usa -ShowLists per vedere le liste salvate."
        HttpIntervalWarning   = "Con -Protocol {0} l'intervallo minimo e' {1}ms per non rischiare di sovraccaricare gli host monitorati (richiesto: {2}ms)."
        AlertsOn              = "Avvisi: ON"
        AlertsOff             = "Avvisi: OFF"
        WidthWarning          = "Nota: la finestra e' piu' stretta di {0} colonne, alcune colonne verranno tagliate. Allarga la finestra o usa -Summary."
        ManyHostsWarning      = "Nota: monitorare {0} host con una riga ciascuno non entra in uno schermo normale. Valuta -Summary per una vista piu' compatta."
        ManyHostsPrompt       = "Stai per monitorare {0} host in modalita' completa, che probabilmente non entra in una schermata. Passare a -Summary? [S/n]: "
        MonitoringBanner      = "Sping - monitoraggio {0} host in parallelo"
        Instructions          = "Premi Q oppure Ctrl+C per interrompere in modo pulito, A per attivare/disattivare gli avvisi."
        LogPath               = "Log: {0}"
        LogDisabled           = "Log: disattivato (usa -Log o -LogFile per attivarlo)"
        ColHost               = "HOST"
        ColIp                 = "IP"
        ColStatus             = "STATO"
        ColRtt                = "RTT(ms)"
        ColSent               = "INVIATI"
        ColReceived           = "RICEVUTI"
        ColLost               = "PERSI"
        ColLossPct            = "LOSS%"
        ColTtlExp             = "TTLEXP"
        Waiting               = "in attesa..."
        MonitoringEnded       = "Monitoraggio terminato."
        LogSavedTo            = "Log salvato in: {0}"
        TraceNoticesHeader    = "Traceroute avviati sui fallimenti (processo indipendente in background, output salvato in):"
        TraceStarted          = "Traceroute avviato per {0}"
        TraceSkippedCooldown  = "Traceroute saltato per {0} (cooldown attivo)"
        TraceSkippedCap       = "Traceroute saltato per {0} (limite massimo raggiunto)"
        PathChanged           = "Percorso cambiato per {0}"
        PathChangedSuffix     = "[PERCORSO CAMBIATO]"
        PathChangeNoticesHeader = "Cambi di percorso rilevati (percorso prima/dopo completo salvato in):"
        PingError             = "Errore ping"
        RequestError          = "Errore richiesta"
        Timeout               = "Timeout"
        ResumeSpeech          = "L'indirizzo {0} e' di nuovo raggiungibile"
        TcpError              = "Errore di connessione"
        TcpOpen               = "Porta {0} aperta"
        TcpPortRequired       = "-Port e' obbligatorio con -Protocol Tcp."
        ColJitter             = "JITTER(ms)"
        ColCertExp            = "CERT(gg)"
    }
}

function Get-SpingStrings {
    param([string]$Language)

    if (-not (Test-Path $LangDir)) {
        try { New-Item -ItemType Directory -Path $LangDir -Force -ErrorAction Stop | Out-Null } catch { }
    }

    # Al primo avvio scrive i file delle lingue integrate (se assenti), cosi' l'utente puo' modificarli
    # o copiarne uno come base per aggiungere altre lingue in SpingData\lang\<codice>.json.
    foreach ($langCode in $script:BuiltInStrings.Keys) {
        $langFile = Join-Path $LangDir "$langCode.json"
        if (-not (Test-Path $langFile)) {
            try { $script:BuiltInStrings[$langCode] | ConvertTo-Json | Set-Content -Path $langFile -Encoding UTF8 -ErrorAction Stop } catch { }
        }
    }

    $merged = $script:BuiltInStrings['en'].Clone()
    $langFile = Join-Path $LangDir "$Language.json"
    if (Test-Path $langFile) {
        try {
            $loaded = Get-Content $langFile -Raw | ConvertFrom-Json
            foreach ($prop in $loaded.PSObject.Properties) { $merged[$prop.Name] = $prop.Value }
        } catch { }
    } elseif ($script:BuiltInStrings.ContainsKey($Language)) {
        foreach ($k in $script:BuiltInStrings[$Language].Keys) { $merged[$k] = $script:BuiltInStrings[$Language][$k] }
    } elseif ($Language -ne 'en') {
        Write-Warning "Language '$Language' not found under $LangDir, falling back to English."
    }
    return $merged
}

# Config e lingua vengono risolti subito, prima degli handler di utilita' sotto, cosi' anche i loro
# messaggi sono nella lingua scelta.
$cfg = Get-SpingConfig
$Language = if ($PSBoundParameters.ContainsKey('Language')) { $Language } elseif ($cfg.Language) { $cfg.Language } else { if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'it') { 'it' } else { 'en' } }
if (-not $PSBoundParameters.ContainsKey('DisableAlerts')) { $DisableAlerts = -not [bool]$cfg.AlertsEnabled }
$script:S = Get-SpingStrings -Language $Language

#endregion

#region Handlers for the "utility" parameter sets ----------------------------

if ($ShowSettings) {
    Write-Host ("`n" + ($S.CurrentSettingsHeader -f $ConfigFile)) -ForegroundColor Cyan
    $cfg | Format-List | Out-String | Write-Host
    return
}

if ($ShowLists) {
    $lists = Get-SpingLists
    $names = $lists.PSObject.Properties.Name
    if (-not $names) {
        Write-Host $S.NoSavedLists
    } else {
        Write-Host ("`n" + ($S.SavedListsHeader -f $ListsFile)) -ForegroundColor Cyan
        foreach ($n in $names) {
            Write-Host ("  {0}: {1}" -f $n, ($lists.$n -join ', '))
        }
    }
    return
}

if ($SaveList) {
    if (-not $ListName) {
        throw $S.SpecifyListNameSave
    }
    if (-not $ComputerName -or $ComputerName.Count -eq 0) {
        throw ($S.SpecifyHostForList -f $ListName)
    }
    $lists = Get-SpingLists
    $lists | Add-Member -NotePropertyName $ListName -NotePropertyValue $ComputerName -Force
    Save-SpingLists -Lists $lists
    Write-Host ($S.ListSaved -f $ListName, $ComputerName.Count) -ForegroundColor Green
    return
}

if ($RemoveList) {
    if (-not $ListName) {
        throw $S.SpecifyListNameRemove
    }
    $lists = Get-SpingLists
    if ($lists.PSObject.Properties.Name -contains $ListName) {
        $lists.PSObject.Properties.Remove($ListName)
        Save-SpingLists -Lists $lists
        Write-Host ($S.ListRemoved -f $ListName) -ForegroundColor Green
    } else {
        Write-Warning ($S.ListNotExist -f $ListName)
    }
    return
}

#endregion

#region IP range / CIDR expansion ---------------------------------------------

function ConvertTo-SpingUInt32Ip {
    param([string]$IpString)
    $addr = [System.Net.IPAddress]::Parse($IpString)
    $bytes = $addr.GetAddressBytes()
    if ($bytes.Length -ne 4) { throw "Solo indirizzi IPv4 sono supportati per range/CIDR ('$IpString')." }
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertFrom-SpingUInt32Ip {
    param([uint32]$Value)
    $bytes = [BitConverter]::GetBytes($Value)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Expand-SpingCidr {
    param([string]$BaseIp, [int]$Prefix, [int]$MaxHosts, [string]$Original)
    if ($Prefix -lt 0 -or $Prefix -gt 32) { throw "Prefisso CIDR non valido in '$Original' (deve essere tra 0 e 32)." }
    $baseVal = ConvertTo-SpingUInt32Ip -IpString $BaseIp
    $hostBits = 32 - $Prefix
    $networkVal = if ($Prefix -eq 0) { [uint32]0 } else { $baseVal -band ([uint32]::MaxValue -shl $hostBits) }
    $totalAddresses = [uint64]1 -shl $hostBits

    if ($Prefix -ge 31) {
        # /31 (RFC 3021, coppie punto-punto) e /32 (host singolo): nessun network/broadcast da escludere.
        $firstVal = [uint64]$networkVal
        $lastVal = [uint64]$networkVal + $totalAddresses - 1
    } else {
        $firstVal = [uint64]$networkVal + 1
        $lastVal = [uint64]$networkVal + $totalAddresses - 2
    }

    $count = $lastVal - $firstVal + 1
    if ($count -gt $MaxHosts) {
        throw "'$Original' comprende $count host utilizzabili, oltre il limite di sicurezza di $MaxHosts (usa -MaxRangeHosts per alzarlo - con cautela: monitorare troppi host in parallelo puo' sovraccaricare la rete)."
    }
    $result = New-Object System.Collections.Generic.List[string]
    for ($v = $firstVal; $v -le $lastVal; $v++) { $result.Add((ConvertFrom-SpingUInt32Ip -Value ([uint32]$v))) }
    return $result.ToArray()
}

function Expand-SpingTarget {
    param([string]$Target, [int]$MaxHosts)

    # CIDR: 10.0.0.0/23
    if ($Target -match '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,2})$') {
        return Expand-SpingCidr -BaseIp $Matches[1] -Prefix ([int]$Matches[2]) -MaxHosts $MaxHosts -Original $Target
    }

    # Subnet mask: 10.0.0.0/255.255.254.0
    if ($Target -match '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$') {
        $baseIp = $Matches[1]
        $maskVal = ConvertTo-SpingUInt32Ip -IpString $Matches[2]
        $prefix = 0
        $bit = [uint32]0x80000000
        while ($bit -ne 0 -and ($maskVal -band $bit) -ne 0) { $prefix++; $bit = $bit -shr 1 }
        $expectedMask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]::MaxValue -shl (32 - $prefix) }
        if ($maskVal -ne $expectedMask) { throw "La subnet mask in '$Target' non e' valida (i bit non sono contigui)." }
        return Expand-SpingCidr -BaseIp $baseIp -Prefix $prefix -MaxHosts $MaxHosts -Original $Target
    }

    # Range con trattino: 10.0.0.1-10.0.0.50, oppure scorciatoia 10.0.0.1-50 (solo ultimo ottetto)
    if ($Target -match '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}(?:\.\d{1,3}\.\d{1,3}\.\d{1,3})?)$') {
        $startIp = $Matches[1]
        $endPart = $Matches[2]
        $endIp = if ($endPart -match '^\d{1,3}$') {
            $octets = $startIp.Split('.')
            "$($octets[0]).$($octets[1]).$($octets[2]).$endPart"
        } else {
            $endPart
        }
        $startVal = ConvertTo-SpingUInt32Ip -IpString $startIp
        $endVal = ConvertTo-SpingUInt32Ip -IpString $endIp
        if ($endVal -lt $startVal) { throw "Nel range '$Target' l'IP finale precede quello iniziale." }
        $count = [uint64]$endVal - $startVal + 1
        if ($count -gt $MaxHosts) {
            throw "Il range '$Target' comprende $count host, oltre il limite di sicurezza di $MaxHosts (usa -MaxRangeHosts per alzarlo - con cautela: monitorare troppi host in parallelo puo' sovraccaricare la rete)."
        }
        $result = New-Object System.Collections.Generic.List[string]
        for ($v = $startVal; $v -le $endVal; $v++) { $result.Add((ConvertFrom-SpingUInt32Ip -Value $v)) }
        return $result.ToArray()
    }

    # Non e' un range/CIDR/mask: host singolo, restituito invariato.
    return @($Target)
}

#endregion

#region Build the effective monitor configuration -----------------------------

if (-not $PSBoundParameters.ContainsKey('TimeToLive'))      { $TimeToLive      = $cfg.TimeToLive }
if (-not $PSBoundParameters.ContainsKey('ResumeThreshold')) { $ResumeThreshold = $cfg.ResumeThreshold }
if (-not $PSBoundParameters.ContainsKey('Count'))            { $Count          = $cfg.Count }
if (-not $PSBoundParameters.ContainsKey('TimeoutMillis'))    { $TimeoutMillis  = $cfg.TimeoutMillis }
if (-not $PSBoundParameters.ContainsKey('IntervalMillis'))   { $IntervalMillis = $cfg.IntervalMillis }
if (-not $PSBoundParameters.ContainsKey('SoundFile'))        { $SoundFile      = $cfg.SoundFile }
if (-not $PSBoundParameters.ContainsKey('Summary'))          { $Summary        = [bool]$cfg.Summary }
if (-not $PSBoundParameters.ContainsKey('SummaryColumns') -or $SummaryColumns -le 0) { $SummaryColumns = if ($cfg.SummaryColumns) { $cfg.SummaryColumns } else { 4 } }
if (-not $PSBoundParameters.ContainsKey('LogFormat')) { $LogFormat = if ($cfg.LogFormat) { $cfg.LogFormat } else { 'Csv' } }
if (-not $PSBoundParameters.ContainsKey('Protocol'))         { $Protocol       = $cfg.Protocol }
if (-not $Protocol) { $Protocol = 'Icmp' }
if (-not $PSBoundParameters.ContainsKey('Port') -and $cfg.Port) { $Port = $cfg.Port }
if (-not $PSBoundParameters.ContainsKey('CertWarningDays'))  { $CertWarningDays = if ($cfg.CertWarningDays) { $cfg.CertWarningDays } else { 30 } }
if ($Protocol -eq 'Tcp' -and -not $Port) {
    Write-Error $S.TcpPortRequired
    return
}

# L'intervallo di default (1s) e' pensato per ICMP, molto leggero lato server. Una richiesta HTTP/HTTPS/TCP e'
# ben piu' onerosa (connessione, TLS, generazione risposta): ripetuta troppo di frequente e a lungo puo'
# assomigliare a un flood/DDoS verso l'host monitorato. Imponiamo quindi una pausa minima piu' prudente.
$httpMinIntervalMillis = 3000
if ($Protocol -ne 'Icmp') {
    if (-not $PSBoundParameters.ContainsKey('IntervalMillis') -and $IntervalMillis -lt $httpMinIntervalMillis) {
        $IntervalMillis = $httpMinIntervalMillis
    } elseif ($IntervalMillis -lt $httpMinIntervalMillis) {
        Write-Warning ($S.HttpIntervalWarning -f $Protocol, $httpMinIntervalMillis, $IntervalMillis)
        $IntervalMillis = $httpMinIntervalMillis
    }
}

if ($SaveAsDefault) {
    $cfg.TimeToLive      = $TimeToLive
    $cfg.ResumeThreshold = $ResumeThreshold
    $cfg.Count           = $Count
    $cfg.TimeoutMillis   = $TimeoutMillis
    $cfg.IntervalMillis  = $IntervalMillis
    $cfg.SoundFile       = $SoundFile
    $cfg.Summary         = [bool]$Summary
    $cfg.SummaryColumns  = $SummaryColumns
    $cfg.LogFormat       = $LogFormat
    $cfg.Protocol        = $Protocol
    $cfg.Port            = $Port
    $cfg.CertWarningDays = $CertWarningDays
    $cfg.Language        = $Language
    $cfg.AlertsEnabled   = -not [bool]$DisableAlerts
    Save-SpingConfig -Config $cfg
    Write-Host $S.SettingsSaved -ForegroundColor Green
}

if (-not $PSBoundParameters.ContainsKey('MaxRangeHosts') -or $MaxRangeHosts -le 0) { $MaxRangeHosts = 1024 }
if (-not $PSBoundParameters.ContainsKey('TraceCooldownMinutes') -or $TraceCooldownMinutes -le 0) { $TraceCooldownMinutes = 10 }
if (-not $PSBoundParameters.ContainsKey('MaxConcurrentTraces') -or $MaxConcurrentTraces -le 0) { $MaxConcurrentTraces = 5 }
if (-not $PSBoundParameters.ContainsKey('PathTraceIntervalMinutes') -or $PathTraceIntervalMinutes -le 0) { $PathTraceIntervalMinutes = 15 }
if (-not $PSBoundParameters.ContainsKey('PathTraceMaxHops') -or $PathTraceMaxHops -le 0) { $PathTraceMaxHops = 20 }

# Merge -ComputerName with an optional saved -ListName
$rawTargets = New-Object System.Collections.Generic.List[string]
if ($ComputerName) { $rawTargets.AddRange([string[]]$ComputerName) }
if ($ListName) {
    $lists = Get-SpingLists
    if ($lists.PSObject.Properties.Name -contains $ListName) {
        $rawTargets.AddRange([string[]]$lists.$ListName)
    } else {
        Write-Warning ($S.ListNotExistIgnored -f $ListName)
    }
}
if ($rawTargets.Count -eq 0) {
    Write-Error $S.NoHostsError
    return
}

# Ogni voce puo' essere un host singolo oppure un range/CIDR/subnet mask, che qui viene espanso in piu' host.
$targets = New-Object System.Collections.Generic.List[string]
foreach ($raw in $rawTargets) {
    try {
        $expanded = Expand-SpingTarget -Target $raw -MaxHosts $MaxRangeHosts
    } catch {
        Write-Error $_.Exception.Message
        return
    }
    $targets.AddRange([string[]]$expanded)
}
$seen = New-Object System.Collections.Generic.HashSet[string]
$targets = @($targets | Where-Object { $seen.Add($_) })
if ($targets.Count -eq 0) {
    Write-Error $S.NoHostsError
    return
}

$domainSuffix = if ($Domain) { if ($Domain.StartsWith('.')) { $Domain } else { ".$Domain" } } else { '' }

# Logging is OFF by default. -Log turns it on with the default path, -LogFile turns it on with a custom path.
$loggingEnabled = [bool]$Log -or $PSBoundParameters.ContainsKey('LogFile')
if ($loggingEnabled -and -not $LogFile) {
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $logExtension = if ($LogFormat -eq 'Json') { 'jsonl' } else { 'csv' }
    $LogFile = Join-Path $LogDir ("sping_{0:yyyyMMdd_HHmmss}.{1}" -f (Get-Date), $logExtension)
}

# HttpClient va creato una sola volta e riusato per ogni ciclo/host (a differenza di Ping, non e' pensato
# per essere ricreato ad ogni richiesta: farlo esaurirebbe le socket disponibili nel tempo).
$script:HttpClient = $null
if ($Protocol -ne 'Icmp') {
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $handler = New-Object System.Net.Http.HttpClientHandler
    if ($IgnoreCertificateErrors) {
        # PROVATO con un test diagnostico dedicato (vedi CHANGELOG 2.5.9): un callback di validazione basato
        # su scriptblock PowerShell, anche banale come "{ $true }", fallisce se invocato da .NET su un thread
        # privo di Runspace ("There is no Runspace available to run scripts in this thread") - esattamente
        # cio' che succede qui, dato che HttpClientHandler esegue l'handshake TLS su un thread di I/O in
        # background. Soluzione: una vera classe .NET compilata con Add-Type (bytecode reale, nessuna
        # dipendenza da Runspace) invece di uno scriptblock interpretato.
        if (-not ('SpingCertBypass' -as [type])) {
            Add-Type -TypeDefinition @'
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class SpingCertBypass
{
    public static bool AlwaysValid(HttpRequestMessage request, X509Certificate2 cert, X509Chain chain, SslPolicyErrors errors)
    {
        return true;
    }
}
'@ -ErrorAction Stop
        }
        $handler.ServerCertificateCustomValidationCallback = [SpingCertBypass]::AlwaysValid
    }
    $script:HttpClient = New-Object System.Net.Http.HttpClient($handler)
    $script:HttpClient.Timeout = [TimeSpan]::FromMilliseconds($TimeoutMillis)
}

#endregion

#region Ping engine (parallel) --------------------------------------------------

function Start-SpingCycle {
    param($HostStates, [int]$Ttl, [int]$TimeoutMs, [string]$Protocol, [int]$Port)
    switch ($Protocol) {
        'Icmp' { Start-IcmpCycle -HostStates $HostStates -Ttl $Ttl -TimeoutMs $TimeoutMs }
        'Tcp'  { Start-TcpCycle  -HostStates $HostStates -TimeoutMs $TimeoutMs -Port $Port }
        default { Start-HttpCycle -HostStates $HostStates -TimeoutMs $TimeoutMs -Protocol $Protocol }
    }
}

function Start-IcmpCycle {
    param($HostStates, [int]$Ttl, [int]$TimeoutMs)

    $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($Ttl, $false)
    $buffer = [System.Text.Encoding]::ASCII.GetBytes(('a' * 32))

    # Fire every ping asynchronously so all hosts are tested in parallel this cycle.
    foreach ($state in $HostStates) {
        try {
            $p = New-Object System.Net.NetworkInformation.Ping
            $state.PingObj = $p
            $state.Task    = $p.SendPingAsync($state.Host, $TimeoutMs, $buffer, $pingOptions)
            $state.SyncErr = $null
        } catch {
            $state.PingObj = $null
            $state.Task    = $null
            $state.SyncErr = $_.Exception.Message
        }
        # Risoluzione DNS indipendente ad ogni ciclo (la cache DNS scade, l'IP puo' cambiare nel frattempo).
        try {
            $state.DnsTask = [System.Net.Dns]::GetHostAddressesAsync($state.Host)
        } catch {
            $state.DnsTask = $null
        }
    }

    $pendingTasks = @($HostStates | Where-Object { $_.Task } | ForEach-Object { $_.Task })
    $pendingTasks += @($HostStates | Where-Object { $_.DnsTask } | ForEach-Object { $_.DnsTask })
    if ($pendingTasks.Count -gt 0) {
        # Task.WaitAll/WhenAll rilanciano le eccezioni dei singoli task (es. DNS non risolto) come AggregateException.
        # Aspettiamo solo il completamento (senza leggerne il risultato qui) cosi' nessun errore arriva in console:
        # ogni eccezione viene gestita singolarmente piu' sotto, quando si legge il GetResult() di ogni task.
        $whenAllTask = [System.Threading.Tasks.Task]::WhenAll($pendingTasks)
        try { $whenAllTask.Wait($TimeoutMs + 1000) | Out-Null } catch { }
    }

    foreach ($state in $HostStates) {
        if ($state.DnsTask -and $state.DnsTask.IsCompleted) {
            try {
                $addresses = $state.DnsTask.GetAwaiter().GetResult()
                if ($addresses -and $addresses.Count -gt 0) { $state.ResolvedIp = $addresses[0].ToString() }
            } catch { }
        }
    }

    foreach ($state in $HostStates) {
        if (-not $state.Task) {
            $state.Success    = $false
            $state.StatusText = if ($state.SyncErr) { $state.SyncErr } else { $script:S.PingError }
            $state.LastRtt     = $null
            continue
        }
        try {
            $reply = $state.Task.GetAwaiter().GetResult()
            $state.Success    = ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            $state.StatusText = $reply.Status.ToString()
            $state.LastRtt     = $reply.RoundtripTime
        } catch {
            $state.Success    = $false
            $inner = $_.Exception.InnerException
            $state.StatusText = if ($inner) { $inner.Message } else { $_.Exception.Message }
            $state.LastRtt     = $null
        } finally {
            if ($state.PingObj) { $state.PingObj.Dispose() }
        }
    }
}

function Start-HttpCycle {
    param($HostStates, [int]$TimeoutMs, [string]$Protocol)

    $scheme = $Protocol.ToLower()

    # Fire every request asynchronously so all hosts are tested in parallel this cycle.
    foreach ($state in $HostStates) {
        try {
            $uri = "${scheme}://$($state.Host)"
            $state.Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $state.Task = $script:HttpClient.GetAsync($uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
            $state.SyncErr = $null
        } catch {
            $state.Task    = $null
            $state.SyncErr = $_.Exception.Message
        }
        # Risoluzione DNS indipendente ad ogni ciclo (la cache DNS scade, l'IP puo' cambiare nel frattempo).
        try {
            $state.DnsTask = [System.Net.Dns]::GetHostAddressesAsync($state.Host)
        } catch {
            $state.DnsTask = $null
        }
    }

    $pendingTasks = @($HostStates | Where-Object { $_.Task } | ForEach-Object { $_.Task })
    $pendingTasks += @($HostStates | Where-Object { $_.DnsTask } | ForEach-Object { $_.DnsTask })
    if ($pendingTasks.Count -gt 0) {
        $whenAllTask = [System.Threading.Tasks.Task]::WhenAll($pendingTasks)
        try { $whenAllTask.Wait($TimeoutMs + 1000) | Out-Null } catch { }
    }

    foreach ($state in $HostStates) {
        if ($state.DnsTask -and $state.DnsTask.IsCompleted) {
            try {
                $addresses = $state.DnsTask.GetAwaiter().GetResult()
                if ($addresses -and $addresses.Count -gt 0) { $state.ResolvedIp = $addresses[0].ToString() }
            } catch { }
        }
    }

    foreach ($state in $HostStates) {
        if (-not $state.Task) {
            $state.Success    = $false
            $state.StatusText = if ($state.SyncErr) { $state.SyncErr } else { $script:S.RequestError }
            $state.LastRtt     = $null
            continue
        }
        try {
            $resp = $state.Task.GetAwaiter().GetResult()
            $state.Stopwatch.Stop()
            $code = [int]$resp.StatusCode
            $state.Success    = ($code -ge 200 -and $code -lt 400)
            $state.StatusText = "$code $($resp.ReasonPhrase)"
            $state.LastRtt     = $state.Stopwatch.ElapsedMilliseconds
            $resp.Dispose()
        } catch {
            $state.Stopwatch.Stop()
            $state.Success = $false
            $inner = $_.Exception.InnerException
            if ($_.Exception -is [System.Threading.Tasks.TaskCanceledException] -or ($inner -and $inner -is [System.Threading.Tasks.TaskCanceledException])) {
                $state.StatusText = $script:S.Timeout
            } else {
                $state.StatusText = if ($inner) { $inner.Message } else { $_.Exception.Message }
            }
            $state.LastRtt = $null
        }
    }
}

function Start-TcpCycle {
    param($HostStates, [int]$TimeoutMs, [int]$Port)

    # TcpClient.ConnectAsync in .NET Framework non accetta un CancellationToken: per imporre comunque un
    # timeout, corriamo la connessione in parallelo a un Task.Delay e, se vince il delay, chiudiamo il
    # client (questo aborta il tentativo pendente invece di lasciarlo proseguire in background).
    foreach ($state in $HostStates) {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $state.TcpClientObj = $client
            $state.Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $state.ConnectTask = $client.ConnectAsync($state.Host, $Port)
            $delayTask = [System.Threading.Tasks.Task]::Delay($TimeoutMs)
            $state.Task = [System.Threading.Tasks.Task]::WhenAny($state.ConnectTask, $delayTask)
            $state.SyncErr = $null
        } catch {
            $state.Task    = $null
            $state.SyncErr = $_.Exception.Message
        }
        # Risoluzione DNS indipendente ad ogni ciclo (la cache DNS scade, l'IP puo' cambiare nel frattempo).
        try {
            $state.DnsTask = [System.Net.Dns]::GetHostAddressesAsync($state.Host)
        } catch {
            $state.DnsTask = $null
        }
    }

    $pendingTasks = @($HostStates | Where-Object { $_.Task } | ForEach-Object { $_.Task })
    $pendingTasks += @($HostStates | Where-Object { $_.DnsTask } | ForEach-Object { $_.DnsTask })
    if ($pendingTasks.Count -gt 0) {
        $whenAllTask = [System.Threading.Tasks.Task]::WhenAll($pendingTasks)
        try { $whenAllTask.Wait($TimeoutMs + 1000) | Out-Null } catch { }
    }

    foreach ($state in $HostStates) {
        if ($state.DnsTask -and $state.DnsTask.IsCompleted) {
            try {
                $addresses = $state.DnsTask.GetAwaiter().GetResult()
                if ($addresses -and $addresses.Count -gt 0) { $state.ResolvedIp = $addresses[0].ToString() }
            } catch { }
        }
    }

    foreach ($state in $HostStates) {
        if (-not $state.Task) {
            $state.Success    = $false
            $state.StatusText = if ($state.SyncErr) { $state.SyncErr } else { $script:S.TcpError }
            $state.LastRtt     = $null
            continue
        }
        $connectTask = $state.ConnectTask
        if ($connectTask.IsCompleted -and -not $connectTask.IsFaulted -and -not $connectTask.IsCanceled) {
            $state.Stopwatch.Stop()
            $state.Success    = $true
            $state.StatusText = $script:S.TcpOpen -f $Port
            $state.LastRtt     = $state.Stopwatch.ElapsedMilliseconds
        } elseif ($connectTask.IsFaulted) {
            $state.Stopwatch.Stop()
            $state.Success = $false
            $inner = $connectTask.Exception.InnerException
            $state.StatusText = if ($inner) { $inner.Message } else { $script:S.TcpError }
            $state.LastRtt = $null
        } else {
            # Il delay ha vinto la corsa: la connessione non si e' ancora chiusa, la trattiamo come timeout.
            $state.Success    = $false
            $state.StatusText = $script:S.Timeout
            $state.LastRtt     = $null
        }
        # Chiude comunque il client: se la connect era ancora pendente, questo la aborta senza bloccare il ciclo.
        try { $state.TcpClientObj.Close() } catch { }
    }
}


function Get-CertificateExpiry {
    param([string]$HostName, [int]$TimeoutMs, [bool]$IgnoreCertErrors)

    # PROVATO con un test diagnostico dedicato: un callback di validazione basato su scriptblock
    # PowerShell NON puo' essere invocato in modo affidabile durante un handshake TLS, perche' .NET lo
    # richiama da un thread di I/O interno privo di Runspace PowerShell associato ("There is no
    # Runspace available to run scripts in this thread") - e senza Runspace uno scriptblock non puo'
    # eseguire. Questo spiegava tutti i fallimenti dei tentativi precedenti (silenziosi o con errore).
    # Soluzione: nessun callback custom, si usa la validazione predefinita di .NET (nessun codice
    # PowerShell mai invocato durante l'handshake) e si legge il certificato DOPO, da SslStream.
    $targetHost = $HostName
    $port = 443
    if ($HostName -match '^(.+):(\d+)$') { $targetHost = $Matches[1]; $port = [int]$Matches[2] }

    $tcp = $null
    $ssl = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcp.ConnectAsync($targetHost, $port)
        if (-not $connectTask.Wait($TimeoutMs)) {
            $script:CertDiagnostics += "${HostName}: timeout in connessione TCP (oltre ${TimeoutMs}ms)"
            return $null
        }

        $ssl = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false)
        $authTask = $ssl.AuthenticateAsClientAsync($targetHost)
        try {
            if (-not $authTask.Wait($TimeoutMs)) {
                $script:CertDiagnostics += "${HostName}: timeout nell'handshake TLS (oltre ${TimeoutMs}ms)"
                return $null
            }
        } catch {
            # Puo' fallire per catena non attendibile (es. certificato self-signed): qui non possiamo
            # installare un override (vedi sopra), quindi -IgnoreCertificateErrors non si applica a
            # questa sonda. Il certificato, se il peer l'ha gia' inviato, resta pero' spesso leggibile
            # comunque: proviamo a leggerlo lo stesso invece di arrenderci subito.
            $inner = $_.Exception.InnerException
            $msg = if ($inner) { $inner.Message } else { $_.Exception.Message }
            $script:CertDiagnostics += "${HostName}: handshake TLS non completato ($msg) - provo comunque a leggere il certificato"
        }

        $cert = $ssl.RemoteCertificate
        if (-not $cert) {
            $script:CertDiagnostics += "${HostName}: nessun certificato disponibile da SslStream dopo l'handshake"
            return $null
        }
        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
        return $cert2.NotAfter
    } catch {
        $inner = $_.Exception.InnerException
        $msg = if ($inner) { $inner.Message } else { $_.Exception.Message }
        $script:CertDiagnostics += "${HostName}: $($_.Exception.GetType().Name): $msg"
        return $null
    } finally {
        if ($ssl) { try { $ssl.Close() } catch { } }
        if ($tcp) { try { $tcp.Close() } catch { } }
    }
}

function Start-SpingTraceroute {
    param([string]$TargetHost)

    # tracert.exe lanciato come processo completamente indipendente, con l'output rediretto su file:
    # nessun rischio di bloccare la dashboard (e' fire-and-forget, non aspettiamo il suo completamento),
    # e nessun bisogno di catturare/interpretare il suo output in tempo reale (che sarebbe stato fragile
    # e dipendente dalla lingua di Windows) - l'utente legge il file quando gli serve.
    try {
        if (-not (Test-Path $script:TraceDir)) { New-Item -ItemType Directory -Path $script:TraceDir -Force | Out-Null }
        $safeName = $TargetHost -replace '[:\\/*?"<>|]', '_'
        $traceFile = Join-Path $script:TraceDir ("{0}_{1:yyyyMMdd_HHmmss}.txt" -f $safeName, (Get-Date))
        $proc = Start-Process -FilePath 'tracert.exe' -ArgumentList @('-d', '-h', '20', '-w', '1000', $TargetHost) `
            -RedirectStandardOutput $traceFile -WindowStyle Hidden -PassThru -ErrorAction Stop
        $script:ActiveTraceProcesses.Add($proc)
        return $traceFile
    } catch {
        return $null
    }
}

function Get-SpingActiveTraceCount {
    # Rimuove dalla lista i processi ormai terminati, poi restituisce quanti restano attivi.
    $script:ActiveTraceProcesses = @($script:ActiveTraceProcesses | Where-Object { -not $_.HasExited })
    return $script:ActiveTraceProcesses.Count
}

function Start-SpingPathTraceStep {
    param($State, [int]$MaxHops, [int]$TimeoutMs, [int]$IntervalMinutes)

    # Avanza il tracciamento del percorso di UN hop per chiamata, invece di fare tutto il traceroute in
    # un colpo solo: cosi' non blocca mai il ciclo principale, nemmeno per un secondo. Una traccia completa
    # richiede quindi piu' cicli (fino a MaxHops), esattamente come il motore ping/DNS usa gia' lo stesso
    # schema di polling non bloccante (IsCompleted) invece di attese sincrone.
    $State.PathChangedThisCycle = $false

    if (-not $State.PathTraceActive) {
        if ($State.NextPathTraceTime -and (Get-Date) -lt $State.NextPathTraceTime) { return }
        $State.PathTraceActive = $true
        $State.PathTraceHop = 1
        $State.PathTraceHops = New-Object System.Collections.Generic.List[string]
    }

    if (-not $State.PathTraceTask) {
        try {
            $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($State.PathTraceHop, $false)
            $buffer = [System.Text.Encoding]::ASCII.GetBytes(('a' * 32))
            $p = New-Object System.Net.NetworkInformation.Ping
            $State.PathTracePingObj = $p
            $State.PathTraceTask = $p.SendPingAsync($State.Host, $TimeoutMs, $buffer, $pingOptions)
        } catch {
            $State.PathTraceHops.Add('*')
            $State.PathTracePingObj = $null
            $State.PathTraceTask = $null
            $State.PathTraceHop++
        }
        return
    }

    if (-not $State.PathTraceTask.IsCompleted) { return }

    $reachedDestination = $false
    try {
        $reply = $State.PathTraceTask.GetAwaiter().GetResult()
        if ($reply.Address -and ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::TtlExpired -or $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)) {
            $State.PathTraceHops.Add($reply.Address.ToString())
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $reachedDestination = $true }
        } else {
            $State.PathTraceHops.Add('*')
        }
    } catch {
        $State.PathTraceHops.Add('*')
    } finally {
        if ($State.PathTracePingObj) { try { $State.PathTracePingObj.Dispose() } catch { } }
        $State.PathTracePingObj = $null
        $State.PathTraceTask = $null
    }

    $State.PathTraceHop++

    if ($reachedDestination -or $State.PathTraceHop -gt $MaxHops) {
        $newHops = @($State.PathTraceHops)
        if ($State.LastPathHops) {
            $oldHops = @($State.LastPathHops)
            $changed = $oldHops.Count -ne $newHops.Count
            if (-not $changed) {
                for ($i = 0; $i -lt $newHops.Count; $i++) {
                    if ($oldHops[$i] -ne $newHops[$i]) { $changed = $true; break }
                }
            }
            if ($changed) {
                $State.PathChangedThisCycle = $true
                $State.PathChangeOldHops = $oldHops
                $State.PathChangeNewHops = $newHops
            }
        }
        $State.LastPathHops = $newHops
        $State.PathTraceActive = $false
        $State.NextPathTraceTime = (Get-Date).AddMinutes($IntervalMinutes)
    }
}

function Invoke-ResumeAlert {
    param([string]$TargetHost, [string]$WavFile)
    try {
        if ($WavFile -and (Test-Path $WavFile)) {
            $player = New-Object System.Media.SoundPlayer $WavFile
            $player.Play()
        }
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $synth.SpeakAsync(($script:S.ResumeSpeech -f $TargetHost)) | Out-Null
    } catch {
        1..3 | ForEach-Object { [console]::Beep(900, 250) }
    }
}

#endregion

#region State & dashboard setup -------------------------------------------------

$hostStates = foreach ($h in $targets) {
    [pscustomobject]@{
        Host             = "$h$domainSuffix"
        ResolvedIp       = 'N/D'
        TotalSent        = 0
        TotalReceived    = 0
        TotalLost        = 0
        ConsecutiveFails = 0
        TtlExpiredCount  = 0
        StatusText       = 'in attesa...'
        LastRtt          = $null
        Success          = $false
        PingObj          = $null
        Task             = $null
        SyncErr          = $null
        DnsTask          = $null
        Stopwatch        = $null
        Jitter           = $null
        PrevRtt          = $null
        CertExpiry       = $null
        TcpClientObj     = $null
        ConnectTask      = $null
        LastTraceTime    = $null
        PathTraceActive  = $false
        PathTraceHop     = 1
        PathTraceHops    = $null
        PathTraceTask    = $null
        PathTracePingObj = $null
        LastPathHops     = $null
        NextPathTraceTime = $null
        PathChangedThisCycle = $false
        PathChangeOldHops = $null
        PathChangeNewHops = $null
    }
}

# Risoluzione IP iniziale (best-effort), cosi' la colonna IP e' gia' popolata prima del primo ciclo.
foreach ($state in $hostStates) {
    try {
        $addr = [System.Net.Dns]::GetHostAddresses($state.Host) | Select-Object -First 1
        if ($addr) { $state.ResolvedIp = $addr.ToString() }
    } catch { }
}

if ($Protocol -eq 'Https') {
    $script:CertDiagnostics = @()
    foreach ($state in $hostStates) {
        # Timeout generoso e indipendente da -TimeoutMillis: questa sonda apre una connessione nuova "fredda"
        # (handshake TCP+TLS da zero, a differenza del monitoraggio che riusa connessioni gia' aperte), gira
        # una sola volta all'avvio, quindi puo' permettersi qualche secondo in piu' senza impattare il ciclo.
        $certProbeTimeoutMs = [Math]::Max($TimeoutMillis * 5, 8000)
        $state.CertExpiry = Get-CertificateExpiry -HostName $state.Host -TimeoutMs $certProbeTimeoutMs -IgnoreCertErrors $IgnoreCertificateErrors
    }
}

if ($hostStates.Count -gt 40 -and -not $Summary) {
    $answer = Read-Host ($S.ManyHostsPrompt -f $hostStates.Count)
    if ($answer -notmatch '^\s*n') { $Summary = $true }
}

Clear-Host

$consoleWidth = [console]::WindowWidth - 1
if ($consoleWidth -lt 60) { $consoleWidth = 60 }

# Larghezza della colonna HOST calcolata sul nome piu' lungo tra quelli monitorati (min 12, con un margine di 2),
# cosi' host con FQDN lunghi non sfasano le colonne successive.
$longestHost = ($hostStates | ForEach-Object { $_.Host.Length } | Measure-Object -Maximum).Maximum
$hostColWidth = [Math]::Max(12, $longestHost + 2)
$showCertColumn = ($Protocol -eq 'Https')
$rowFormat = if ($showCertColumn) {
    "{0,-$hostColWidth}{1,-15}{2,-16}{3,7}{4,11}{5,9}{6,10}{7,7}{8,6}{9,7}{10,9}"
} else {
    "{0,-$hostColWidth}{1,-15}{2,-16}{3,7}{4,11}{5,9}{6,10}{7,7}{8,6}{9,7}"
}

function Format-DashboardRow {
    param([string]$Text)
    if ($Text.Length -ge $consoleWidth) { $Text.Substring(0, $consoleWidth) } else { $Text.PadRight($consoleWidth) }
}

# Riga di stato avvisi: sempre la primissima riga stampata (riga 0), colorata, per dare un feedback immediato
# quando si preme A. Il titolo della finestra (aggiornato anch'esso al toggle) non supporta testo colorato.
$script:alertsEnabled = -not [bool]$DisableAlerts
$initialAlertText = if ($script:alertsEnabled) { $S.AlertsOn } else { $S.AlertsOff }
$initialAlertColor = if ($script:alertsEnabled) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red }
Write-Host (Format-DashboardRow $initialAlertText) -ForegroundColor $initialAlertColor
$script:alertsRow = 0

$script:traceNoticeRow = $null
if ($TraceOnFailure -and -not $Summary) {
    Write-Host (Format-DashboardRow '')
    $script:traceNoticeRow = 1
}

$script:pathChangeNoticeRow = $null
if ($TracePathChanges -and -not $Summary) {
    Write-Host (Format-DashboardRow '')
    $script:pathChangeNoticeRow = if ($null -ne $script:traceNoticeRow) { 2 } else { 1 }
}

if (-not $Summary) {
    Write-Host "Sping v$ScriptVersion" -ForegroundColor DarkCyan

    $neededWidth = $hostColWidth + $(if ($showCertColumn) { 97 } else { 88 })
    if ($consoleWidth -lt $neededWidth) {
        $warnText = $S.WidthWarning -f $neededWidth
        if ($warnText.Length -gt $consoleWidth) { $warnText = $warnText.Substring(0, $consoleWidth) }
        Write-Host $warnText -ForegroundColor DarkYellow
    }
}

# Assicura che il buffer verticale della console sia abbastanza alto da contenere tutto il contenuto stampato,
# senza dover scorrere: su alcune console uno scroll del buffer rinumera le righe e invalida le coordinate
# assolute calcolate sotto.
try {
    $rawUi = $Host.UI.RawUI
    $neededHeight = $rawUi.CursorPosition.Y + $hostStates.Count + 25
    $bufSize = $rawUi.BufferSize
    if ($bufSize.Height -lt $neededHeight) {
        $bufSize.Height = $neededHeight
        $rawUi.BufferSize = $bufSize
    }
} catch { }

if (-not $Summary) {
    Write-Host "`n$($S.MonitoringBanner -f $hostStates.Count)" -ForegroundColor Cyan
    Write-Host $S.Instructions
    if ($loggingEnabled) { Write-Host ($S.LogPath -f $LogFile) } else { Write-Host $S.LogDisabled }
    Write-Host ''
}

if (-not $Summary) {
    $headerArgs = @($S.ColHost, $S.ColIp, $S.ColStatus, $S.ColRtt, $S.ColJitter, $S.ColSent, $S.ColReceived, $S.ColLost, $S.ColLossPct, $S.ColTtlExp)
    if ($showCertColumn) { $headerArgs += $S.ColCertExp }
    Write-Host (Format-DashboardRow ($rowFormat -f $headerArgs)) -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 30   # lascia che il buffer/ConPTY si stabilizzi prima di leggere CursorTop
    $dashboardTop = [console]::CursorTop
    for ($i = 0; $i -lt $hostStates.Count; $i++) {
        $state = $hostStates[$i]
        $state | Add-Member -NotePropertyName Row -NotePropertyValue ($dashboardTop + $i) -Force
        $placeholderArgs = @($state.Host, $state.ResolvedIp, $S.Waiting, '-', '-', 0, 0, 0, 0, 0)
        if ($showCertColumn) { $placeholderArgs += '-' }
        Write-Host (Format-DashboardRow ($rowFormat -f $placeholderArgs))
    }
    if ($hostStates.Count -gt 40) {
        # Stampato DOPO tutte le righe host (non prima): le righe della dashboard, una volta create, restano
        # fisse e si aggiornano per posizione, quindi se questo avviso e' l'ultima cosa stampata resta
        # visibile in fondo senza scorrere via, a differenza di un avviso stampato prima di centinaia di righe.
        Write-Host ($S.ManyHostsWarning -f $hostStates.Count) -ForegroundColor DarkYellow
    }
} else {
    # Griglia compatta: -SummaryColumns host per riga (default 4), larghezza cella basata sul nome host piu' lungo.
    $hostsPerRow = $SummaryColumns
    $summaryCellWidth = $hostColWidth + 5
    $gridRows = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $hostStates.Count; $i += $hostsPerRow) {
        $lastIdx = [Math]::Min($i + $hostsPerRow - 1, $hostStates.Count - 1)
        $gridRows.Add([PSCustomObject]@{ Hosts = $hostStates[$i..$lastIdx]; Row = 0 })
    }
    Start-Sleep -Milliseconds 30
    $summaryTop = [console]::CursorTop
    for ($r = 0; $r -lt $gridRows.Count; $r++) {
        $gridRows[$r].Row = $summaryTop + $r
        $placeholder = ($gridRows[$r].Hosts | ForEach-Object { "{0,-$hostColWidth} --  " -f $_.Host }) -join ''
        Write-Host (Format-DashboardRow $placeholder)
    }
}

function Write-DashboardLine {
    param([int]$Row, [string]$Text, [System.ConsoleColor]$Color = [console]::ForegroundColor)
    try {
        [console]::SetCursorPosition(0, $Row)
        $prevColor = [console]::ForegroundColor
        [console]::ForegroundColor = $Color
        [console]::Write((Format-DashboardRow $Text))
        [console]::ForegroundColor = $prevColor
    } catch {
        # Non far crashare il monitoraggio per un problema di rendering: si continua comunque a pingare e a loggare.
    }
}

function Get-StatusColor {
    param($State)
    # Priorita': FQDN non risolto (giallo) > esito ping. Sotto soglia i fallimenti sono arancione (perdita iniziale),
    # da soglia (ResumeThreshold) in su diventano rosso fisso (host considerato down).
    if ($State.ResolvedIp -eq 'N/D') { return [System.ConsoleColor]::Yellow }
    if ($State.Success) { return [System.ConsoleColor]::Green }
    if ($State.ConsecutiveFails -ge $ResumeThreshold) { return [System.ConsoleColor]::Red }
    return [System.ConsoleColor]::DarkYellow
}

function Write-DashboardSegments {
    param([int]$Row, [System.Collections.Generic.List[object]]$Segments)
    try {
        [console]::SetCursorPosition(0, $Row)
        $prevColor = [console]::ForegroundColor
        $written = 0
        foreach ($seg in $Segments) {
            $remaining = $consoleWidth - $written
            if ($remaining -le 0) { break }
            $text = if ($seg.Text.Length -gt $remaining) { $seg.Text.Substring(0, $remaining) } else { $seg.Text }
            [console]::ForegroundColor = $seg.Color
            [console]::Write($text)
            $written += $text.Length
        }
        if ($written -lt $consoleWidth) {
            [console]::ForegroundColor = $prevColor
            [console]::Write(''.PadRight($consoleWidth - $written))
        }
        [console]::ForegroundColor = $prevColor
    } catch {
        # Non far crashare il monitoraggio per un problema di rendering: si continua comunque a pingare e a loggare.
    }
}

#endregion

#region Main loop with clean Ctrl+C / Q handling --------------------------------

$logWriter = $null
$stopRequested = $false
$script:TraceNotices = @()
$script:PathChangeNotices = @()
$script:ActiveTraceProcesses = New-Object System.Collections.Generic.List[System.Diagnostics.Process]
$previousTreatCtrlC = [console]::TreatControlCAsInput
[console]::TreatControlCAsInput = $true
try { $Host.UI.RawUI.WindowTitle = "Sping - $initialAlertText" } catch { }

try {
    if ($loggingEnabled) {
        $logDirForFile = Split-Path $LogFile -Parent
        if ($logDirForFile -and -not (Test-Path $logDirForFile)) { New-Item -ItemType Directory -Path $logDirForFile -Force | Out-Null }
        $fileIsNew = -not (Test-Path $LogFile)
        # Opened once, here, not reopened every cycle.
        $logWriter = New-Object System.IO.StreamWriter($LogFile, $true, [System.Text.Encoding]::UTF8)
        $logWriter.AutoFlush = $true
        if ($fileIsNew -and $LogFormat -ne 'Json') { $logWriter.WriteLine('Timestamp,Cycle,Host,ResolvedIp,Status,RoundtripMs,ConsecutiveFails,TotalSent,TotalReceived,TotalLost') }
    }

    for ($cycle = 1; $cycle -le $Count -and -not $stopRequested; $cycle++) {

        Start-SpingCycle -HostStates $hostStates -Ttl $TimeToLive -TimeoutMs $TimeoutMillis -Protocol $Protocol -Port $Port

        if ($TracePathChanges) {
            foreach ($state in $hostStates) {
                Start-SpingPathTraceStep -State $state -MaxHops $PathTraceMaxHops -TimeoutMs $TimeoutMillis -IntervalMinutes $PathTraceIntervalMinutes
                if ($state.PathChangedThisCycle) {
                    $script:PathChangeNoticeText = $S.PathChanged -f $state.Host
                    if ($null -ne $script:pathChangeNoticeRow) {
                        Write-DashboardLine -Row $script:pathChangeNoticeRow -Text $script:PathChangeNoticeText -Color ([System.ConsoleColor]::Yellow)
                    }
                    try {
                        if (-not (Test-Path $script:PathTraceDir)) { New-Item -ItemType Directory -Path $script:PathTraceDir -Force | Out-Null }
                        $safeName = $state.Host -replace '[:\\/*?"<>|]', '_'
                        $pathFile = Join-Path $script:PathTraceDir ("{0}_{1:yyyyMMdd_HHmmss}.txt" -f $safeName, (Get-Date))
                        $lines = @("Host: $($state.Host)", "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", '', 'Previous path:')
                        $lines += ($state.PathChangeOldHops | ForEach-Object { "  $_" })
                        $lines += ''
                        $lines += 'New path:'
                        $lines += ($state.PathChangeNewHops | ForEach-Object { "  $_" })
                        Set-Content -Path $pathFile -Value $lines -Encoding UTF8
                        $script:PathChangeNotices += "$($state.Host) -> $pathFile"
                    } catch { }
                }
            }
        }

        foreach ($state in $hostStates) {

            # Jitter: media mobile della variazione assoluta tra RTT consecutivi (stessa formula di RFC 3550/1889),
            # calcolata solo quando entrambi i campioni sono disponibili (nessun jitter durante un'interruzione).
            if ($null -ne $state.LastRtt -and $null -ne $state.PrevRtt) {
                $rttDiff = [Math]::Abs($state.LastRtt - $state.PrevRtt)
                $state.Jitter = if ($null -eq $state.Jitter) { $rttDiff } else { $state.Jitter + (($rttDiff - $state.Jitter) / 16) }
            }
            $state.PrevRtt = $state.LastRtt

            if ($state.PathChangedThisCycle) {
                $state.StatusText += " $($S.PathChangedSuffix)"
            }

            $state.TotalSent++
            if ($state.Success) {
                $state.TotalReceived++
                if ($script:alertsEnabled -and $state.ConsecutiveFails -ge $ResumeThreshold -and $state.ConsecutiveFails -gt 0) {
                    Invoke-ResumeAlert -TargetHost $state.Host -WavFile $SoundFile
                }
                $state.ConsecutiveFails = 0
            } else {
                $state.TotalLost++
                if ($TraceOnFailure -and $state.ConsecutiveFails -eq 0) {
                    $cooldownOk = (-not $state.LastTraceTime) -or (((Get-Date) - $state.LastTraceTime).TotalMinutes -ge $TraceCooldownMinutes)
                    if (-not $cooldownOk) {
                        $noticeText = $S.TraceSkippedCooldown -f $state.Host
                    } elseif ((Get-SpingActiveTraceCount) -ge $MaxConcurrentTraces) {
                        $noticeText = $S.TraceSkippedCap -f $state.Host
                    } else {
                        $traceFile = Start-SpingTraceroute -TargetHost $state.Host
                        if ($traceFile) {
                            $state.LastTraceTime = Get-Date
                            $script:TraceNotices += "$($state.Host) -> $traceFile"
                            $noticeText = $S.TraceStarted -f $state.Host
                        } else {
                            $noticeText = $null
                        }
                    }
                    if ($noticeText -and $null -ne $script:traceNoticeRow) {
                        Write-DashboardLine -Row $script:traceNoticeRow -Text $noticeText -Color ([System.ConsoleColor]::DarkGray)
                    }
                }
                if ($state.ConsecutiveFails -lt $ResumeThreshold) { $state.ConsecutiveFails++ }
                if ($state.StatusText -eq 'TtlExpired') { $state.TtlExpiredCount++ }
            }

            if ($loggingEnabled) {
                $rttForLog = if ($null -ne $state.LastRtt) { $state.LastRtt } else { $null }
                if ($LogFormat -eq 'Json') {
                    # JSON Lines (NDJSON): un oggetto JSON compatto per riga, pensato per l'ingestione in
                    # streaming da parte di strumenti SIEM/monitoring (Splunk, ELK, Sentinel, ecc.), a
                    # differenza di un unico array JSON che richiederebbe il file chiuso per essere valido.
                    $jitterForLog = if ($null -ne $state.Jitter) { [math]::Round($state.Jitter, 1) } else { $null }
                    $certDaysForLog = $null
                    if ($Protocol -eq 'Https' -and $state.CertExpiry) {
                        $certDaysForLog = [Math]::Floor(($state.CertExpiry - (Get-Date)).TotalDays)
                    }
                    $logEntry = [ordered]@{
                        timestamp        = (Get-Date).ToString('o')
                        cycle            = $cycle
                        host             = $state.Host
                        resolvedIp       = $state.ResolvedIp
                        protocol         = $Protocol
                        status           = $state.StatusText
                        rttMs            = $rttForLog
                        jitterMs         = $jitterForLog
                        consecutiveFails = $state.ConsecutiveFails
                        totalSent        = $state.TotalSent
                        totalReceived    = $state.TotalReceived
                        totalLost        = $state.TotalLost
                        certDaysToExpiry = $certDaysForLog
                    }
                    $logWriter.WriteLine(($logEntry | ConvertTo-Json -Compress))
                } else {
                    $logWriter.WriteLine(('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f `
                        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $cycle, $state.Host, $state.ResolvedIp, $state.StatusText, `
                        $(if ($null -ne $rttForLog) { $rttForLog } else { '' }), $state.ConsecutiveFails, $state.TotalSent, $state.TotalReceived, $state.TotalLost))
                }
            }

            if (-not $Summary) {
                $lossPct = if ($state.TotalSent -gt 0) { [math]::Round(($state.TotalLost / $state.TotalSent) * 100, 1) } else { 0 }
                $rttDisplay = if ($null -ne $state.LastRtt) { $state.LastRtt } else { '-' }
                $jitterDisplay = if ($null -ne $state.Jitter) { [math]::Round($state.Jitter, 1) } else { '-' }
                $rowArgs = @($state.Host, $state.ResolvedIp, $state.StatusText, $rttDisplay, $jitterDisplay, $state.TotalSent, $state.TotalReceived, $state.TotalLost, $lossPct, $state.TtlExpiredCount)
                if ($showCertColumn) {
                    $certDisplay = '-'
                    if ($state.CertExpiry) {
                        $daysLeft = [Math]::Floor(($state.CertExpiry - (Get-Date)).TotalDays)
                        $certDisplay = if ($daysLeft -le $CertWarningDays) { "$daysLeft!" } else { "$daysLeft" }
                    }
                    $rowArgs += $certDisplay
                }
                $line = $rowFormat -f $rowArgs
                Write-DashboardLine -Row $state.Row -Text $line -Color (Get-StatusColor $state)
            }
        }

        if ($Summary) {
            foreach ($gridRow in $gridRows) {
                $segments = New-Object System.Collections.Generic.List[object]
                foreach ($state in $gridRow.Hosts) {
                    $sym = if ($state.Success) { '!!' } elseif ($state.StatusText -eq 'TtlExpired') { 'TT' } else { '..' }
                    $cellText = "{0,-$hostColWidth} {1,-2}  " -f $state.Host, $sym
                    $segments.Add(@{ Text = $cellText; Color = (Get-StatusColor $state) })
                }
                Write-DashboardSegments -Row $gridRow.Row -Segments $segments
            }
        }

        # Wait for the interval in small chunks so Q / Ctrl+C are picked up immediately.
        $elapsed = 0
        while ($elapsed -lt $IntervalMillis -and -not $stopRequested -and $cycle -lt $Count) {
            if ([console]::KeyAvailable) {
                $key = [console]::ReadKey($true)
                $isCtrlC = ($key.Modifiers -band [System.ConsoleModifiers]::Control) -and ($key.Key -eq [System.ConsoleKey]::C)
                if ($key.Key -eq [System.ConsoleKey]::Q -or $isCtrlC) {
                    $stopRequested = $true
                } elseif ($key.Key -eq [System.ConsoleKey]::A) {
                    $script:alertsEnabled = -not $script:alertsEnabled
                    $alertColor = if ($script:alertsEnabled) { [System.ConsoleColor]::Green } else { [System.ConsoleColor]::Red }
                    $alertText  = if ($script:alertsEnabled) { $script:S.AlertsOn } else { $script:S.AlertsOff }
                    Write-DashboardLine -Row $script:alertsRow -Text $alertText -Color $alertColor
                    try { $Host.UI.RawUI.WindowTitle = "Sping - $alertText" } catch { }
                }
            }
            $wait = [Math]::Min(50, $IntervalMillis - $elapsed)
            Start-Sleep -Milliseconds $wait
            $elapsed += $wait
        }
    }
}
finally {
    [console]::TreatControlCAsInput = $previousTreatCtrlC
    if ($logWriter) { $logWriter.Flush(); $logWriter.Close(); $logWriter.Dispose() }
    if ($script:HttpClient) { $script:HttpClient.Dispose() }

    Write-Host "`n`n$($S.MonitoringEnded)" -ForegroundColor Cyan

    # Riepilogo finale con le stesse colonne/larghezza/colori della dashboard, per coerenza visiva.
    $summaryColWidth = if ($hostColWidth) { $hostColWidth } else {
        [Math]::Max(12, (($hostStates | ForEach-Object { $_.Host.Length } | Measure-Object -Maximum).Maximum) + 2)
    }
    $summaryFormat = if ($showCertColumn) {
        "{0,-$summaryColWidth}{1,-15}{2,9}{3,9}{4,7}{5,7}{6,7}{7,11}{8,9}"
    } else {
        "{0,-$summaryColWidth}{1,-15}{2,9}{3,9}{4,7}{5,7}{6,7}{7,11}"
    }
    $summaryHeaderArgs = @($S.ColHost, $S.ColIp, $S.ColSent, $S.ColReceived, $S.ColLost, $S.ColLossPct, $S.ColTtlExp, $S.ColJitter)
    if ($showCertColumn) { $summaryHeaderArgs += $S.ColCertExp }
    Write-Host ($summaryFormat -f $summaryHeaderArgs) -ForegroundColor DarkGray
    foreach ($state in $hostStates) {
        $lossPct = if ($state.TotalSent -gt 0) { [math]::Round(($state.TotalLost / $state.TotalSent) * 100, 1) } else { 0 }
        $jitterDisplay = if ($null -ne $state.Jitter) { [math]::Round($state.Jitter, 1) } else { '-' }
        $summaryLineArgs = @($state.Host, $state.ResolvedIp, $state.TotalSent, $state.TotalReceived, $state.TotalLost, $lossPct, $state.TtlExpiredCount, $jitterDisplay)
        if ($showCertColumn) {
            $certDisplay = '-'
            if ($state.CertExpiry) {
                $daysLeft = [Math]::Floor(($state.CertExpiry - (Get-Date)).TotalDays)
                $certDisplay = if ($daysLeft -le $CertWarningDays) { "$daysLeft!" } else { "$daysLeft" }
            }
            $summaryLineArgs += $certDisplay
        }
        $line = $summaryFormat -f $summaryLineArgs
        Write-Host $line -ForegroundColor (Get-StatusColor $state)
    }

    if ($loggingEnabled) { Write-Host ($S.LogSavedTo -f $LogFile) }
    if ($script:TraceNotices.Count -gt 0) {
        Write-Host ''
        Write-Host $S.TraceNoticesHeader -ForegroundColor DarkGray
        foreach ($notice in $script:TraceNotices) { Write-Host "  $notice" -ForegroundColor DarkGray }
    }
    if ($script:PathChangeNotices.Count -gt 0) {
        Write-Host ''
        Write-Host $S.PathChangeNoticesHeader -ForegroundColor Yellow
        foreach ($notice in $script:PathChangeNotices) { Write-Host "  $notice" -ForegroundColor Yellow }
    }
}

#endregion
