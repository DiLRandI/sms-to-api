# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- _No notable changes yet._

## [2.1.0] - 2025-11-12
### Changed
- Bumped the Flutter app version metadata to `2.1.0+3` so the next minor release is reflected in both Dart and native targets.
- Updated release-specific documentation and agent guidance to reference the new version and line up with the ship date.

### Docs
- Added this release entry and refreshed any downstream guidance that previously pointed at `2.0.0`.

## [2.0.0] - 2025-11-06
### Added
- Secure settings bridge using encrypted storage with automatic legacy migration.
- Structured Kotlin coroutine dispatcher for foreground service network work.
- Test coverage for storage migration, API header fallbacks, and log sanitization.

### Breaking
- Removed legacy single-endpoint storage fallbacks; the v2 settings model now requires endpoint profiles for API forwarding.

### Changed
- Foreground service now returns `START_NOT_STICKY` and stops from the main thread once work completes.
- Flutter UI guards asynchronous `setState` calls with `mounted` checks and detaches native listeners on dispose.
- Android activity surfaces SMS permission rationale and shared method channels for secure storage without requiring default-SMS handover.

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
