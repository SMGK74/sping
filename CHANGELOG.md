# Changelog

*English | [Versione italiana](CHANGELOG.it.md)*

All notable changes to this project are documented in this file.

## [2.22.0]

### Removed
- `-SummaryColumns` parameter: with automatic column detection introduced in 2.21.0, a manual value no longer made sense and only remained as a source of confusion (it was the exact cause of auto mode not engaging for anyone with a previously saved value). **Breaking change**: anyone using it in scripts or saved commands needs to drop it, the `-Summary` grid is now always automatic.

## [2.21.0]

### Added
- `-SaveAsDefault` used alone, with no host, now saves settings and exits cleanly instead of giving the "no hosts to ping" error.
- `T` key: toggles `-TraceOnFailure` live during monitoring (disabled above 10 hosts, to avoid a burst of simultaneous tracert launches). Turning it on while a host is already down immediately attempts a trace for it (doesn't wait for a fresh up-to-down transition). Multiple hosts starting a trace in the same pass show up on the same line, comma-separated, instead of overwriting each other. The trace now only fires once a host reaches `ResumeThreshold` (confirmed down), not on the very first packet loss.
- On-screen warning if the log folder exceeds 10 MB (lightweight check every 20 cycles, once per session).
- Richer command-line help with `.NOTES` and `.LINK` sections (requirements, where to find changelog/readme, repository). `-Help` now shows the standard PowerShell concise view; for everything (notes included) use `Get-Help -Full` separately.
- Range shorthand: explicit error if the trailing number exceeds 255, instead of undefined behavior.
- STATUS column moved to the **end** of the row (after TTLEXP, CERT, MAC columns): free-form text with no fixed width, no longer pushes other columns out of alignment when long.
- `-Summary` now auto-computes the column count from window width when `-SummaryColumns` isn't specified (neither on the command line nor as a saved default), also adapting **live during the session** on resize (polling with debounce). **Known limitation**: with very rapid, continuous window-border dragging, a residual visual fragment can occasionally remain; normal use (startup, a single resize) works correctly.
- On first run, offers to add the script's folder to the Windows user PATH (requires explicit Y/N confirmation), so the command can be run from any folder. Requires a new PowerShell window to take effect.

### Fixed
- Pre-existing bug in `-TraceOnFailure`: the active-trace-process list was converted into a fixed-size array on every concurrent-trace-limit check, silently breaking every subsequent attempt to start a new one.
- The width used to pad/truncate rows (`$consoleWidth`) stayed fixed at the startup value and never updated on window resize.

## [2.20.0]

### Changed
- Four parameters renamed for consistency with their "relatives" (subject noun first, not the action): `-MonitorMacAddress` → `-MacMonitor` (like `-MacHistoryDepth`), `-TracePathChanges` → `-PathTrace` (like `-PathTraceIntervalMinutes`/`-PathTraceMaxHops`), `-MaxConcurrentTraces` → `-TraceMaxConcurrent` (like `-TraceOnFailure`/`-TraceCooldownMinutes`), `-IgnoreCertificateErrors` → `-CertIgnoreErrors` (like `-CertWarningDays`). **Breaking change**: the previous names are no longer valid, no alias kept - update any scripts or scheduled tasks that use them.

## [2.19.0]

### Changed
- The "Sping vX.Y.Z" line is now printed first, with "Avvisi: ON/OFF" right below it (previously the other way around).
- Added a dedicated "Log: ON/OFF" line right below Avvisi, updated immediately when pressing `L` - previously log status was only visible in the window title.

## [2.18.1]

### Added
- `en.json`/`it.json` are now stamped with the script version that generated them. When the running version differs from the one in the file, it's automatically regenerated with the latest built-in text (with an on-screen notice), instead of staying stuck forever with whatever text existed when it was first created - the exact cause of the title/instructions staying on old wording after previous updates. A language file for a non-built-in language (e.g. `fr.json`) is never touched automatically.

## [2.18.0]

### Added
- `L` key: toggles logging on or off during monitoring, without stopping and restarting the script. If logging was off at startup, the first activation determines the same default path `-Log` would have used; later activations in the same session resume on the same file. The current state (ON/OFF) is shown live in the window title, alongside alerts and the host filter.

### Changed
- Simplified the startup banner: removed the static log-status line (now misleading, since it can change during the session) - the current state is shown in the window title instead.

## [2.17.0]

### Added
- `H` key: shows/hides a panel listing every available command, below the dashboard, without touching the fixed host rows. Replaces the startup instructions line that kept growing with every new feature (and suffered from the same language-cache issue already fixed elsewhere): the startup line now simply points to `H`.

## [2.16.0]

### Added
- `-LogRetentionDays` parameter: if set, deletes files older than N days once at startup (not during the session) from every `SpingData` subfolder that accumulates files over time, not just CSV/JSON logs but also traceroute, path tracing, and MAC change files. Disabled by default, persists with `-SaveAsDefault` like other workflow settings.

## [2.15.0]

### Changed
- `-MonitorMacAddress` no longer uses `SendARP` (P/Invoke): the resolved MAC didn't match the real one shown by `arp -a`, most likely because `SendARP` with no source specified picks the network interface on its own, and on a PC with multiple adapters (VMware, VPN) can pick the wrong one, returning an unrelated device's MAC. Replaced with `Get-NetNeighbor`, which reads the neighbor table already correctly populated by the ping itself (which necessarily goes through the right interface), removing the ambiguity at the root, and with no compiled C# code left to maintain. Unreachable hosts no longer show a made-up MAC.

## [2.14.5]

### Fixed
- The MAC address, correctly resolved by ARP, never reached the MAC1 column: the condition for saving the very first address checked the "truthiness" of the `MacHistory` list rather than its existence. In PowerShell an empty collection evaluates as false in a boolean context, even if the object itself exists and is valid: the list, being empty on the first cycle, failed exactly the check meant to handle that case, a logical deadlock that permanently prevented the first entry. Fixed by explicitly checking it isn't `$null`, instead of relying on the collection's implicit truthiness. The same pattern was also fixed in `-TracePathChanges`'s route comparison, where the practical risk was lower but the fix belongs there too for consistency.

## [2.14.2]

### Fixed
- MAC always showed `-` even for hosts confirmed to be on the same local network segment (e.g. the gateway): `SendARP` was receiving the wrong IP address due to a byte-order issue. `IPAddress.GetAddressBytes()` returns bytes in network byte order, but `BitConverter.ToUInt32()` on a Windows PC (little-endian) reads them backwards without an explicit reversal - the same fix already applied elsewhere in the script for CIDR range expansion, forgotten in the new ARP C# code.

## [2.14.1]

### Fixed
- MAC1/MAC2/MAC3 headers all showed "MAC1": the column format string was built by repeating a string with `* $MacHistoryDepth`, which in PowerShell repeats the same `{0}` placeholder instead of generating `{0}{1}{2}`. Fixed by building the format with increasing indices.
- MAC columns stuck to the previous column with no gap (e.g. "TTLEXPMAC1"): the preceding numeric column, right-aligned, left no trailing margin. Added an explicit gap before the MAC columns everywhere they're drawn (header, placeholder, live row, final summary).

## [2.14.0]

### Added
- `-MonitorMacAddress` now shows the MAC address directly in the dashboard instead of just a silent alert: MAC1..MACn columns (count reserved at startup, never added mid-session, to avoid recomputing the header and layout while monitoring is running - a risk we'd already learned to avoid with the CERT column). MAC1 is the first address ever seen for that host, always green; each later distinct address fills the next column in red, flagging a deviation from the baseline. Also shown in the final summary.
- `-MacHistoryDepth` parameter (default 3) to decide how many columns to reserve. If changes exceed the reserved space, full detail is still logged to files under `SpingData\macchanges`.

## [2.13.0]

### Added
- `-MonitorMacAddress` parameter: resolves each host's MAC address via ARP every cycle (native `SendARP` API, no language-dependent text parsing like `arp -a`), flagging a change from the previous one (possible IP conflict, replaced device, or ARP spoofing) with a STATUS marker, a live notice on a dedicated row, and a detail file under `SpingData\macchanges`. Only works for hosts on the same local network segment: ARP doesn't cross routers.

## [2.12.3]

### Fixed
- `-DisplayFilter UpOnly`/`DownOnly` wasn't filtering correctly (in some cases zero hosts matched, in others all of them did): the cause was a `switch` nested inside a `Where-Object` block, which silently rebinds `$_` to the value being switched on (the filter string) instead of leaving it bound to the current pipeline host - a known but subtle PowerShell pitfall. Replaced with a plain `if`/`elseif` that doesn't touch `$_`.

## [2.12.1]

### Fixed
- New labels added in a more recent version (e.g. the display-filter ones) showed up in English even with Italian selected, if `SpingData\lang\it.json` had been generated by an older script version and didn't yet contain those keys. The merge now starts from the built-in Italian dictionary instead of the English one, so keys missing from the cached file fall back to the most recent Italian text. Keys already present in the file (even with outdated wording) are left untouched to avoid overwriting customizations: for a full refresh, delete `SpingData\lang\it.json` (and `en.json`) so they regenerate from scratch on the next run.

## [2.12.0]

### Added
- `-DisplayFilter` (`UpOnly`/`DownOnly`) now shows a **compact** view with no gaps between hosts: when the visible set changes, rows are redrawn reusing only the space already reserved at startup (no `Clear-Host`, no buffer-height recalculation). Redraws are limited by a debounce equal to `ResumeThreshold` x `IntervalMillis`, to avoid flicker on flapping networks. Switching back to `All` with the `F` key restores every host's original position.
- `R` key during monitoring: resets all accumulated per-host counters (sent, received, lost, consecutive failures, jitter) without stopping and restarting the script.

### Fixed
- The `F` key was missing from the description shown by `-Help` (it was only present in the runtime instructions).

## [2.11.0]

### Added
- `-DisplayFilter` parameter (`All` default, `UpOnly`, `DownOnly`) to show only reachable or only unreachable hosts in the dashboard. Rows stay at the fixed position assigned at startup (no layout recomputation): excluded hosts keep their row, simply left blank, to avoid reintroducing the buffer-scroll rendering risks already solved earlier. Cycle live with the `F` key during monitoring (All -> Up only -> Down only -> All), with feedback in the window title. Not available in `-Summary` mode.

## [2.10.2]

### Fixed
- The live path-trace row always showed the same host (the first active one in the list), leaving traces on other hosts invisible if that one stayed active longer (typical of an unreachable host, with many hops not responding). It now rotates across all currently active traces, with a counter (e.g. "2/4") when there is more than one.

## [2.10.1]

### Added
- Dedicated dashboard row showing the active path trace live (host, current hop out of total, IPs discovered so far), or a countdown in minutes to the next one when no trace is active. Previously there was no way to confirm `-TracePathChanges` was actually working while the route stayed unchanged.

## [2.10.0]

### Added
- `-TracePathChanges` parameter: periodically re-traces the network path to every host, independent of the ping cycle and of `-TraceOnFailure`, using a native probe (no external process, no dependency on Windows language) that is non-blocking (one hop per cycle, spread across several cycles). Flags any difference from the previous trace, whether in hop count or in the hops themselves at equal length. A marker appears on STATUS for that cycle, and full before/after detail is saved to a file under `SpingData\pathtraces`.
- `-PathTraceIntervalMinutes` (default 15) and `-PathTraceMaxHops` (default 20) parameters to control tracing frequency and depth.

## [2.9.0]

### Added
- `-LogFormat` parameter (`Csv` by default, or `Json`): the JSON format writes one compact object per line (JSON Lines / NDJSON), designed for streaming ingestion by SIEM/monitoring tools (Splunk, ELK, Sentinel, etc.), with more fields than the fixed CSV columns: protocol, jitter, certificate days-to-expiry when available. The default log filename extension matches the chosen format (`.csv` or `.jsonl`). Persisted with `-SaveAsDefault`.

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
