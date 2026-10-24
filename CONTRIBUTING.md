# Contributing

Please keep changes scoped to ad presentation, reversibility, compatibility, and tests.

Before opening a pull request, run `npm run check`, `npm test`, and `npm run test:windows` on Windows. Add a synthetic regression fixture for selector changes. Never commit profile copies, user inbox screenshots, network captures, credentials, or personal paths.

For bug reports, include the Outlook version, Windows version, installation mode, whether the helper is running, and whether the problem occurs after a restart or folder change. Share only sanitized numeric status fields. Describe expected and actual behavior; avoid posting message subjects, senders, or account addresses.

Do not add downgrades, security-policy changes, broad DOM selectors that hide real messages, or new data collection. Document any change to local debugging behavior prominently.
