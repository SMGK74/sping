*🇬🇧 English | [🇮🇹 Versione italiana](README.it.md)*

[![PSScriptAnalyzer](https://github.com/SMGK74/sping/actions/workflows/psscriptanalyzer.yml/badge.svg)](https://github.com/SMGK74/sping/actions/workflows/psscriptanalyzer.yml)

# Sping

Parallel multi-host ping monitor for PowerShell, a modern rewrite of the old `Sping.vbs`.

Shows a live console dashboard (one fixed row per host, updated in place - no flicker, no scrolling), optionally writes a structured CSV log, and plays a sound/voice alert when a host that was down comes back up.

## History

Sping started out as `Sping.vbs`, an old VBScript tool for pinging multiple hosts, with a sound alert on recovery and settings stored in the Windows Registry. This version is a full PowerShell rewrite that keeps the original goal (a simple, lightweight, dependency-free monitor) while iteratively adding: a live color-coded dashboard, CSV logging, portable JSON configuration, support for multiple protocols (ICMP, HTTP/HTTPS, TCP), jitter and TLS certificate expiry monitoring, UI localization, CIDR/range expansion, and automatic traceroute on failure. Developed with the assistance of Claude (Anthropic).

## Requirements

- Windows PowerShell 5.1 or later (`#Requires -Version 5.1`)
- No external dependencies: uses only `System.Net.NetworkInformation.Ping`, `System.Net.Dns`, `System.Media.SoundPlayer` and `System.Speech.Synthesis`, all already present in .NET Framework on Windows

## Installing on a new PC

```powershell
# 1. Copy Sping.ps1 to a folder of your choice

# 2. Unblock the file (needed if downloaded from the internet/email/chat)
Unblock-File -Path .\Sping.ps1

# 3. Allow local scripts to run (once per user/PC)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 4. Run
.\Sping.ps1
```

## Usage

```powershell
# Full help (also shown by running the script with no parameters)
.\Sping.ps1 -Help

# Ping multiple hosts in parallel
.\Sping.ps1 192.168.1.1 web-server-01 10.0.0.5 -Count 50 -TimeoutMillis 500

# Saved list + DNS suffix + compact mode + CSV log
.\Sping.ps1 -ListName Core -Domain contoso.local -Summary -Log

# HTTP/HTTPS ping instead of ICMP (useful when ICMP is filtered but the web service is what matters)
.\Sping.ps1 www.contoso.local -Protocol Https -IgnoreCertificateErrors

# TCP port check (e.g. a database listening on a specific port)
.\Sping.ps1 db-server-01 -Protocol Tcp -Port 1433

# Range/CIDR/subnet mask: each entry expands into multiple hosts (network and broadcast excluded)
.\Sping.ps1 10.0.0.0/23 -Summary
.\Sping.ps1 10.0.0.1-10.0.0.50
.\Sping.ps1 10.0.0.1-50
.\Sping.ps1 10.0.0.0/255.255.254.0

# Automatic traceroute on the first failure of each "down" episode (independent background process)
.\Sping.ps1 db-server-01 web-server-02 -TraceOnFailure -Log

# Italian UI (default: English)
.\Sping.ps1 -ListName Core -Language it

# JSON Lines logging instead of CSV, for a SIEM or monitoring tool
.\Sping.ps1 -ListName Core -Log -LogFormat Json

# Start with the sound alert disabled
.\Sping.ps1 -ListName Core -DisableAlerts

# Save a host list for future reuse
.\Sping.ps1 10.0.0.1 10.0.0.2 -ListName Core -SaveList

# View current default settings
.\Sping.ps1 -ShowSettings
```

While monitoring: press `A` at any time to toggle the sound/voice alert on or off (status shown in the window title), or `Q`/`Ctrl+C` to stop cleanly. A final summary is always printed, with no terminating errors.

## Main parameters

| Parameter | Description |
|---|---|
| `ComputerName` (positional) | One or more hosts/IPs to ping in parallel. Each entry also accepts a range/CIDR/subnet mask (e.g. `10.0.0.0/23`, `10.0.0.1-10.0.0.50`, `10.0.0.1-50`), automatically expanded into multiple hosts |
| `-MaxRangeHosts` | Safety cap on how many hosts a single range/CIDR can generate (default 1024), to avoid accidentally monitoring thousands of hosts from an overly broad range |
| `-TraceOnFailure` | When a host's consecutive-failure count goes from 0 to 1 (the start of a new down episode), runs `tracert -d -h 20 -w 1000` for that host as an independent background process (does not block the dashboard), saving its output to a timestamped file under `SpingData\traces`. Fires once per episode, not on every failed cycle. A notice on dashboard row 1 shows the latest trace started or skipped |
| `-TraceCooldownMinutes` | Only with `-TraceOnFailure`: minimum minutes between two traceroutes for the same host, to avoid re-tracing a flapping host on every episode (default 10) |
| `-MaxConcurrentTraces` | Only with `-TraceOnFailure`: cap on how many `tracert` processes can run at once across all hosts, to avoid exhausting resources when many hosts fail together (e.g. a broad CIDR range) (default 5) |
| `-ListName` | Name of a saved host list (can be combined with `ComputerName`) |
| `-Domain` | DNS suffix appended to every host |
| `-Count` | Number of ping cycles (default: continuous) |
| `-Protocol` | `Icmp` (default), `Http`, `Https`, or `Tcp`: with Http/Https each cycle sends a parallel web request, with Tcp a connection attempt to `-Port`, instead of an ICMP ping |
| `-Port` | Destination TCP port. Required with `-Protocol Tcp` |
| `-IgnoreCertificateErrors` | Only with `-Protocol Https`: skips TLS certificate validation (useful for internal hosts with self-signed certificates) |
| `-CertWarningDays` | Only with `-Protocol Https`: day threshold below which the STATUS column flags an upcoming certificate expiry (default 30) |
| `-Language` | UI language: `en` or `it`. Default: auto-detected from the system's UI language on first run (Italian if the system is in Italian, English otherwise), then whatever was last saved. Customizable and extensible, see the Language section |
| `-DisableAlerts` | Starts with the sound/voice alert disabled instead of the default enabled (can still be toggled live with the `A` key). Persist with `-SaveAsDefault` to always start disabled |
| `-TimeToLive` | TTL of ping packets (`-Protocol Icmp` only) |
| `-TimeoutMillis` | Timeout in ms to wait for each reply |
| `-IntervalMillis` | Pause in ms between cycles. With `-Protocol Http`/`Https`/`Tcp` a minimum of 3000 ms is enforced, even if you request a lower value, to avoid resembling a flood/DDoS against the monitored hosts |
| `-ResumeThreshold` | Consecutive failures after which the row switches from orange to red, and below which the sound alert fires on recovery |
| `-Summary` | Compact grid instead of one row per host, see `-SummaryColumns` |
| `-SummaryColumns` | Only with `-Summary`: hosts per row in the compact grid (default 4) |
| `-SoundFile` | WAV file played when a host recovers |
| `-Log` / `-LogFile` | Enable logging (default or custom path) |
| `-LogFormat` | `Csv` (default) or `Json`: the latter writes one compact JSON object per line (JSON Lines/NDJSON), suitable for ingestion by SIEM/monitoring tools, with more fields than the CSV (protocol, jitter, certificate days-to-expiry) |
| `-SaveAsDefault` | Save this run's parameters as the new defaults |
| `-ShowSettings` / `-ShowLists` | Show saved settings/lists and exit |
| `-SaveList` / `-RemoveList` | Save or delete a host list under `-ListName` |

## Configuration and portability

Settings, host lists, logs and language files persist as JSON, no longer in the Windows Registry as in the original VBScript version. The storage folder is chosen automatically:

1. **`SpingData` next to the script** (e.g. `C:\Tools\SpingData`), if that location is writable. This makes the whole `Sping` folder portable: copy it to another PC or a USB drive and settings/lists/logs travel along with the script.
2. **`%APPDATA%\SM-Script\Sping`** as a fallback, if the script is in a non-writable location (e.g. `Program Files` or a read-only share).

## Language

The UI starts in Italian if the system is in Italian, otherwise in English (auto-detected on first run). Use `-Language it`/`-Language en` to force it explicitly. On first run, the script generates `en.json` and `it.json` under `SpingData\lang\`: edit them, or copy one as a base to create a new one (e.g. `fr.json` with the same keys) to add another language, then call it with `-Language fr`.

## Dashboard colors

- **Green**: ping succeeded
- **Orange**: ping failed, below the `-ResumeThreshold` consecutive-failure threshold
- **Red**: consecutive failures at or beyond `-ResumeThreshold`
- **Yellow**: the FQDN doesn't resolve (takes priority over all other colors)

## Jitter and certificate expiry

- **JITTER(ms)**: a moving average of the variation between consecutive RTTs (same formula as RFC 3550/1889), shown in the dashboard and the final summary. Useful for spotting unstable links even when packet loss is low.
- **Certificate expiry** (`-Protocol Https`): at startup, once per host (not every cycle, to avoid adding load beyond the monitoring itself), the TLS certificate's expiry date is read. The CERT(d) column shows the remaining days (negative if already expired), with a `!` when it falls within `-CertWarningDays` days (default 30).

## Console compatibility notes

On consoles with a small vertical buffer (typical of the classic "Windows PowerShell"/conhost on some PCs, unlike Windows Terminal) the script explicitly forces a buffer height large enough to hold the banner, header, and all host rows, to prevent automatic scrolling from renumbering rows and breaking the dashboard.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
