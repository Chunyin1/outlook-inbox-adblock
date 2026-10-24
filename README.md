# Outlook Inbox Adblock

[![Tests](https://github.com/Chunyin1/outlook-inbox-adblock/actions/workflows/test.yml/badge.svg)](https://github.com/Chunyin1/outlook-inbox-adblock/actions/workflows/test.yml)

Hide sponsored inbox clutter in the **new Outlook for Windows**, including the Microsoft Upgrade card left behind by hostname blocking.

This is an unofficial Windows utility. It has two layers:

- **Hosts blocking:** blocks three advertising endpoints at the Windows resolver.
- **Cosmetic filtering:** hides the Upgrade card inside Outlook with a pre-paint CSS rule. A small local helper reapplies the filter after Outlook restarts.

## Choose a mode

| | Hosts only | Full filtering |
|---|---|---|
| Launcher | `Install-Hosts-Only.cmd` | `Install.cmd` |
| Third-party ad endpoints | Blocked | Blocked |
| Microsoft Upgrade card | May remain | Hidden on the tested layout |
| Background helper | No | Yes, at Windows sign-in |
| Node.js required | No | Version 24 or newer |
| Local debugging access | No | Yes; explicit consent required |

**Full filtering has a security tradeoff:** Outlook exposes an unauthenticated debugging connection on a randomly selected loopback port. Other programs that can reach loopback on your computer may use it to access your signed-in Outlook session. It is not bound to an external network interface. Choose hosts-only mode if this is unacceptable. Read [SECURITY.md](SECURITY.md) before installing.

## Install

1. Download the [source ZIP](https://github.com/Chunyin1/outlook-inbox-adblock/archive/refs/heads/main.zip) and extract it. Keep the folder for status, repairs, and uninstalling.
2. For full filtering, install [Node.js 24 LTS or newer](https://nodejs.org/). Open a new terminal or installer window afterward so Node is on `PATH`.
3. Open new Outlook at least once and sign in. Save drafts and fully quit Outlook before installation.
4. Double-click `Install.cmd`, read the debugging notice, and type **ENABLE** if you accept it. Alternatively, use `Install-Hosts-Only.cmd`.
5. Approve the Windows administrator prompt for the hosts-file change. The cosmetic helper itself is installed for the current user.
6. Open Outlook normally. Use `Status.cmd` to inspect the configuration and helper's last observation.

No npm install is needed to use the utility. There are no third-party runtime packages, browser extensions, DLL injections, or changes to Outlook's executables. Existing Outlook updates stay enabled.

PowerShell commands for users who prefer a terminal:

```powershell
# Interactive installation, including the risk notice
.\Manage.ps1 -Action Install

# Hostname blocking only
.\Manage.ps1 -Action Install -Mode HostsOnly

# Status or complete uninstall
.\Manage.ps1 -Action Status
.\Manage.ps1 -Action Undo
```

For deliberate unattended installation, `-AcceptDebuggingRisk` explicitly accepts the full mode's risk. Do not include it in deployment scripts without obtaining the affected user's consent. Enterprise policies may prevent these scripts from running; this project does not change system execution policy or security policy.

## Uninstall or repair

Save drafts and fully quit Outlook, then run `Uninstall.cmd`. This removes the marked hosts entries, the current-user startup entry, and the debugging arguments owned by this tool. Later unrelated config and hosts edits are preserved. Inert helper files and undo metadata remain under Local AppData for recovery; they no longer start automatically.

For a partial uninstall:

```powershell
# Remove the helper/debugging connection but retain hostname blocking
.\Manage.ps1 -Action Undo -Mode CosmeticOnly

# Remove only the hosts block
.\Manage.ps1 -Action Undo -Mode HostsOnly
```

Rerun the appropriate installer to repair an installation. Conflicting pre-existing debugging or hosts settings cause a refusal rather than an overwrite. If installation is interrupted, some successful steps may remain: fully quit Outlook, run `Uninstall.cmd`, then retry. The two installation layers are not a single atomic transaction.

## What changes

- A marked block in `%SystemRoot%\System32\drivers\etc\hosts` blocks `outlookads.live.com`, `m.adnxs.com`, and `msft-ssp.adnxs.com` over IPv4/IPv6. This affects those hostnames in **all applications**, not only Outlook. Timestamped hosts backups are saved beside the original file.
- Full mode adds owned arguments to `%LOCALAPPDATA%\Microsoft\Olk\config.json` to enable loopback debugging.
- Helper files and state live under `%LOCALAPPDATA%\OutlookCosmeticFilter`.
- A value named `OutlookCosmeticFilter` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` launches the helper at sign-in.
- Hosts operation metadata is stored under `%LOCALAPPDATA%\OutlookInboxAdblock`.

The helper watches for WebView startup, registers a document-start script, and applies a scoped CSS `:has()` selector. It checks connection health every two seconds. The filter identifies the Upgrade advertisement by its icon inside the inbox scroller and excludes containers containing real message rows. It does not inspect message bodies, send mail, collect credentials, or transmit mailbox data to a server. Status contains counts and timing, not message content.

## Compatibility and limitations

- Tested with new Outlook **1.2026.1013.100**, WebView2 **155.0.4283.62**, and Node.js **24.20.0** on Windows. Classic Outlook, Outlook for Mac, browsers, and alternate WebView profile locations are outside the tested scope.
- The original implementation was verified in a real inbox: the Upgrade card disappeared, ordinary rows remained visible, restart reapplication worked, uninstall worked, and the user confirmed that the initial flash was gone. The public packaging and additional safeguards are covered by the automated tests below; they have not been tested across other PCs.
- Automated browser tests use synthetic inboxes and verify pre-paint hiding, replacement cards, undo, real-row protection, and origin/path restrictions. They do not substitute for testing every Outlook build and language.
- Ordinary app package updates should preserve the configuration because it lives outside the versioned app folder. **Future updates are not guaranteed:** Microsoft may change the markup, icon, profile location, diagnostic support, or ad endpoints.
- Startup attachment can race a very fast app launch or heavy system load. The tested startup applied CSS before the ad existed; absolute zero-flash behavior under every condition is not guaranteed.
- The cosmetic layer targets the Microsoft Upgrade fallback card. It is not a general-purpose ad blocker or spam filter. Keep the hosts layer enabled for third-party advertisements.
- A VPN, security product, Windows repair, or manual hosts-file replacement can remove the hostname block. Node.js must remain available for the full mode.

## Development

Prerequisites: Node.js 24+, Windows PowerShell 5.1+ for Windows tests.

```powershell
npm ci
npx playwright install chromium
npm run check
npm test
npm run test:windows
```

To test against an installed Edge browser without downloading Chromium:

```powershell
$env:TEST_BROWSER_CHANNEL = 'msedge'
npm test
```

The PowerShell tests run transformations on synthetic inputs; they do not edit the real hosts file, registry, or Outlook profile. Browser tests intercept all fixture requests and use an isolated browser profile. GitHub Actions runs these tests on Windows.

See [CONTRIBUTING.md](CONTRIBUTING.md) for reporting issues without exposing mailbox data.

## Credits and license

Independently written implementation, released under [MIT](LICENSE). Research references:

- [Pyenb/Outlook-desktop-ad-blocker](https://github.com/Pyenb/Outlook-desktop-ad-blocker): the hosts-based approach.
- [valinet/NewOutlookPatcher](https://github.com/valinet/NewOutlookPatcher): demonstrated cosmetic filtering inside new Outlook. This project does not use its DLL injection mechanism.
- [BergNetworks' Upgrade-card userscript](https://greasyfork.org/en/scripts/548769-outlook-web-remove-upgrade-ad-card/code): advertisement icon identification.

Not affiliated with or endorsed by Microsoft. Outlook and Windows are Microsoft trademarks.
