# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Secure settings bridge using encrypted storage with automatic legacy migration.
- Structured Kotlin coroutine dispatcher for foreground service network work.
- Test coverage for storage migration, API header fallbacks, and log sanitization.

### Changed
- Foreground service now returns `START_NOT_STICKY` and stops from the main thread once work completes.
- Flutter UI guards asynchronous `setState` calls with `mounted` checks and detaches native listeners on dispose.
- Android activity surfaces SMS permission rationale and shared method channels for secure storage without requiring default-SMS handover.
- Removed legacy single-endpoint storage fallbacks in preparation for v2; only multi-endpoint profiles are persisted going forward.

### Docs
- Updated README/AGENTS to describe non-default SMS support and the streamlined settings model.

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
