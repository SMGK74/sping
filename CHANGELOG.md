# Changelog

*English | [Versione italiana](CHANGELOG.it.md)*

All notable changes to this project are documented in this file.

## [Infrastructure]

### Added
- GitHub Action with PSScriptAnalyzer (`.github/workflows/psscriptanalyzer.yml`): automatic static analysis of `Sping.ps1` on every push/pull request to `main`. Fails only on blocking errors, shows warnings as informational; excludes `PSAvoidUsingWriteHost` (deliberate choice for the color-coded console dashboard). Status badge added at the top of both READMEs.

## [2.8.4]

### Fixed
- `-IgnoreCertificateErrors` for the actual HTTPS monitoring (not the certificate probe, already fixed in 2.5.9) used the same pattern later proven broken: a PowerShell scriptblock as a TLS validation callback, invoked by .NET on a thread with no Runspace. Even a simple `{ $true }` is still PowerShell code that needs a Runspace to run, so the bypass risked failing silently (or breaking the whole connection) exactly like the bug already diagnosed for the certificate. Fixed by compiling a real .NET class with `Add-Type` (actual bytecode, no Runspace dependency) instead of the scriptblock.

## [2.8.3]

### Added
- With more than 40 hosts in full dashboard mode (and `-Summary` not already specified), the script now asks interactively whether to switch to `-Summary` instead of just showing a warning. Press Enter or answer "no" to stay in full mode.

## [2.8.2]

### Fixed
- The "too many hosts, consider -Summary" warning (introduced in 2.8.1) was never actually visible with many hosts, because it was printed before the hundreds of host rows, ending up out of view once the console scrolled to print them all. It is now printed afterward, staying as the last visible line (dashboard rows, once created, update in place and no new ones are appended).

### Added
- `-SummaryColumns` parameter (default 4): number of hosts per row in the `-Summary` compact grid, previously fixed. Persisted with `-SaveAsDefault`.

## [2.8.1]

### Added
- `-TraceCooldownMinutes` (default 10) and `-MaxConcurrentTraces` (default 5) parameters for `-TraceOnFailure`: prevent re-tracing a flapping host too often and exhausting system resources when many hosts go down together (e.g. a broad CIDR range). Excess traceroutes are skipped, not queued.
- Live notice on dashboard row 1 (full mode only, not `-Summary`) showing the latest traceroute started or skipped, with the reason.
- Warning when monitoring more than 40 hosts in full dashboard mode, suggesting `-Summary` for a more compact view. Particularly useful with broad ranges/CIDRs (e.g. a `/24`).

### Changed
- Increased safety margin on the console buffer height, for extra peace of mind with high host counts.

## [2.8.0]

### Added
- The default language is now auto-detected from the system's UI culture on first run (Italian if the system is in Italian, English otherwise), instead of always starting in English. Detection only applies when settings are first created; once a choice is saved (explicit or via `-SaveAsDefault`), that choice is authoritative.
- `-DisableAlerts` parameter: starts with the sound/voice alert disabled instead of enabled by default, persisted with `-SaveAsDefault`. The live toggle with the `A` key during monitoring is still available.

## [2.7.0]

### Added
- `-TraceOnFailure` parameter: when a host goes from reachable to unreachable (or TTL expired), runs `tracert` for that host as an independent background process, saving its output to a timestamped file under `SpingData\traces`. Fires once per down episode (0 to 1 consecutive-failure transition), not on every failed cycle, and does not block the dashboard in any way. No real-time output capture or parsing; the user reads the file when needed. Files generated during the session are listed in the final summary.

## [2.6.0]

### Added
- Each host in `-ComputerName` (or in a saved list) can now be a range/CIDR/subnet mask instead of a single address, automatically expanded into multiple hosts: `10.0.0.0/23`, `10.0.0.0/255.255.254.0`, `10.0.0.1-10.0.0.50`, or the shorthand `10.0.0.1-50` (last octet only). Network and broadcast addresses are excluded automatically (except for /31 and /32). Automatic deduplication if a host appears both explicitly and inside a range.
- `-MaxRangeHosts` parameter (default 1024): safety cap on how many hosts a single range/CIDR can generate, to avoid accidentally monitoring thousands of hosts from an overly broad range.

### Removed
- Removed the temporary diagnostic block for the CERT(d) column (introduced in 2.5.5, no longer needed after the definitive fix in 2.5.9).

## [2.5.8]

### Changed
- The CERT(d) column now only appears with `-Protocol Https`, instead of always being present with a `-` for ICMP/HTTP/TCP where it doesn't apply.

## [2.5.5] - [2.5.7]

### Fixed
- Multi-step diagnosis and fix for the CERT(d) column staying empty: the root cause was ultimately identified as a TLS connection reused from the PowerShell process's connection pool (from a previous run of the script), which prevented certificate validation, and therefore our reading point, from firing again. Fixed by forcing a fresh connection (`KeepAlive = $false`) for the dedicated probe, and capturing the certificate directly from `ServicePointManager`'s validation callback instead of the `ServicePoint.Certificate` property (known to be unreliable in .NET Framework).

## [2.5.4]

### Fixed
- CERT(d) column still always `-` even with working HTTPS monitoring: the probe opened a fresh "cold" connection (full TCP+TLS handshake) but with the same tight timeout used for monitoring (which instead reuses already-open connections), likely too short on networks with significant latency or inspection. The probe now uses a dedicated, much larger timeout (since it only runs once at startup). Also added a fallback via `ServicePointManager.FindServicePoint` for proxy scenarios where `req.ServicePoint` might not be the object actually used for the connection.

## [2.5.3]

### Fixed
- **Critical regression introduced in 2.5.2**: hooking certificate-expiry capture into the TLS validation callback of the monitoring's HTTPS requests (invoked by .NET on a background I/O thread) could make the whole HTTPS connection fail ("The SSL connection could not be established"), breaking the actual monitoring. That mechanism was removed.
- Reading the certificate expiry is once again a separate, isolated call (a failure there does not affect monitoring), now based on `HttpWebRequest`/`ServicePoint` instead of the raw TLS connection from 2.5.0/2.5.1: it automatically respects proxy and network path like the real HTTPS monitoring, fixing the issue where the CERT(d) column stayed `-` even with reachable hosts.

## [2.5.2]

### Fixed
- The CERT(d) column always showed `-` even with `-Protocol Https` working (200 OK): the dedicated probe opened a separate raw TLS connection (`TcpClient`+`SslStream`), which in some network environments (a corporate proxy not traversed by a direct connection, firewall TLS inspection, too tight a timeout) failed silently even when the actual HTTPS monitoring worked fine. Fixed by capturing the certificate expiry directly from the monitoring's already-working HTTPS requests (same `HttpClient`, same network path), instead of opening an extra connection.

## [2.5.1]

### Changed
- TLS certificate expiry (`-Protocol Https`) now has a dedicated CERT(d) column in the dashboard and final summary, always visible (shows `-` for other protocols), instead of a text suffix appended to STATUS only when close to expiry. A `!` flags when it falls within `-CertWarningDays` days.

## [2.5.0]

### Added
- New `-Protocol Tcp` with a required `-Port` parameter: checks whether a specific TCP port accepts connections, instead of an ICMP ping or a web request.
- TLS certificate expiry check with `-Protocol Https`: read once at startup per host (not every cycle, to avoid adding load), the STATUS column flags when expiry falls within `-CertWarningDays` days (default 30) or has already passed.
- JITTER(ms) column in the dashboard and final summary, calculated with the same formula as RFC 3550/1889 (moving average of the variation between consecutive RTTs).
- The minimum safety pause against flood/DDoS-like behavior (introduced in 2.3.1 for Http/Https) now also applies to `-Protocol Tcp`.

## [2.4.0]

### Added
- RECEIVED column in the live dashboard (previously only in the final summary).
- UI localization via external JSON files: English by default, Italian selectable with `-Language it`, extensible to other languages by copying `SpingData\lang\en.json` as a base for a new `<code>.json`.
- Data path (settings, lists, logs, languages) auto-detected: `SpingData` next to the script if writable (for a truly portable folder), otherwise `%APPDATA%\SM-Script\Sping` as a fallback.
- `-Language` parameter, persisted with `-SaveAsDefault` like the other behavioral parameters.

## [2.3.1]

### Added
- Minimum interval of 3000 ms automatically enforced with `-Protocol Http`/`Https` (even if a lower one is requested, with an explicit warning), to avoid the monitoring resembling a flood/DDoS against the checked hosts: an HTTP/HTTPS request is far heavier than an ICMP ping.

## [2.3.0]

### Added
- `A` key during monitoring to toggle the sound/voice alert on the fly, without stopping the script. Status (ON/OFF) shown in the console window title.
- `-Protocol` parameter (`Icmp` by default, `Http`, `Https`): with Http/Https each cycle sends a parallel async web request to every host instead of an ICMP ping. Success on a 2xx/3xx status code, RTT(ms) is the full response latency, STATUS shows the code (or the error/timeout reason).
- `-IgnoreCertificateErrors` parameter (only with `-Protocol Https`) to skip TLS certificate validation, useful for internal hosts with self-signed certificates.
- `Protocol` persisted among the settings savable with `-SaveAsDefault` and shown by `-ShowSettings`.

## [2.2.0]

### Added
- Full rewrite from VBScript to PowerShell.
- Parallel ping of all hosts every cycle via async `System.Net.NetworkInformation.Ping` (instead of WMI).
- Live console dashboard: one fixed row per host, updated in place with no flicker or scrolling.
- `-Summary` mode: a single compact row with symbols per host (`!!` success, `TX` TTL Expired, `..` other failure).
- Optional CSV log (`-Log` / `-LogFile`), disabled by default, file opened only once at startup.
- Sound/voice alert (WAV + speech synthesis, falling back to beeps) when a host recovers past the consecutive-failure threshold.
- Settings and host lists saved as JSON in `%APPDATA%\SM-Script\Sping`, no longer in the registry.
- Clean interruption handling (`Q` or `Ctrl+C`), with a final summary always printed.
- Full help via comment-based help (`-Help` or no parameters).
- Per-row dashboard colors: green (success), orange (failure below threshold), red (failure at or above `-ResumeThreshold`), yellow (FQDN not resolving, highest priority). Also applied to `-Summary` symbols and the final summary.
- Independent, async DNS resolution every cycle (parallel to the ping), so the IP column always reflects current resolution even if the DNS cache expires or the record changes.
- Host column width calculated dynamically on the longest monitored name, so long FQDNs don't misalign the following columns.
- Final summary reformatted with the same headers, colors, and column widths as the live dashboard, instead of PowerShell's generic table.

### Fixed
- Binding of multiple positional hosts (`ValueFromRemainingArguments`) that failed with more than one positional argument.
- IP column showing `0.0.0.0` on timeouts instead of keeping the last valid IP.
- Dashboard rows not all updating (only the last one) due to a race condition in repeated `CursorTop` reads on Windows Terminal/ConPTY. Fixed with a single initial read and arithmetic per-row offsets.
- Header/row word-wrap wider than the window, which threw off row indices and caused `SetCursorPosition` crashes. Fixed by truncating/padding every row to the console width.
- Duplicate rows and crashes after repeated runs caused by buffer scroll from previous content. Fixed with `Clear-Host` at the start of every monitoring session.
- Version banner disappearing because it was printed before `Clear-Host`. Now reprinted right after.
- Visible console error when an FQDN failed to resolve, caused by `Task.WaitAll` rethrowing the aggregate exception before the intended handling. Fixed by waiting for task completion without propagating the exception at that point.
- Dashboard breaking on consoles with a small vertical buffer (e.g. classic Windows PowerShell on some PCs): the buffer scrolled and renumbered rows during the initial printing, invalidating the calculated absolute coordinates. Fixed by forcing a sufficient buffer height and truncating the width-warning message, which was wrapping onto extra unaccounted lines.

## [1.x] - Sping.vbs (original)

Original VBScript version: multi-host ping, TTL/timeout, sound alert on recovery, settings and host lists in the Windows registry.
