# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- Add tests or samples for early-stop logic (planned)

## [1.1.0] - 2025-09-03
### Fixed
- Android foreground service no longer lingers when SMS sender is not allowed or when no endpoints are configured.
  - `SmsForwardingService.sendToApi(...)` now returns a boolean indicating whether any work started.
  - `onStartCommand(...)` stops the service early (without calling `startForeground`) when no work is required and `auto_stop` is set.

### Docs
- Updated `AGENTS.md` with Android Service Behavior details and verification steps.
- Updated `README.md` Configuration and Android Notes to describe allowed number filtering and early-stop behavior.

### Notes
- Consider adding a pre-check in `SmsReceiver` to skip starting the service when the sender is known to be disallowed (optimization).

