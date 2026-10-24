# Security

Full mode deliberately enables Outlook's local WebView debugging interface. The port is randomly assigned and bound to loopback, but this is **not authentication**. Other local processes, and potentially other users on the same computer, can reach that endpoint and access the signed-in session. Loopback protects against direct network access, not against untrusted local software.

Use hosts-only mode when that risk is unacceptable. The full installer requires explicit acceptance. Uninstall with Outlook fully closed to terminate its listener and remove the configuration that enables it on the next launch.

The helper connects only to the port advertised by the Outlook WebView profile, checks loopback WebSocket addresses, refuses HTTP redirects, and limits the script to known Outlook mail origins. These are scope restrictions, not a security boundary against a compromised user account or tampered local files.

## Data handling

No telemetry or external service is used by the helper. It queries relevant DOM structure and element counts; it does not read email bodies or tokens. Status and installation metadata remain on the PC. The Outlook app itself continues its normal network activity.

## Reporting

Do not attach email screenshots, session captures, network traces, profile databases, cookies, tokens, config files containing account data, or raw logs to public issues. For a vulnerability involving session access, use this repository's private vulnerability reporting feature if enabled; otherwise report the issue privately to the maintainer through an available GitHub contact channel without publishing sensitive details.

Only the current release is maintained. This is an experimental utility, not a Microsoft-supported enterprise deployment method.
