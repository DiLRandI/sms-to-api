# Contributing

Thanks for your interest in contributing to sms_to_api! This document outlines how to work on the project and what we expect in PRs.

## Commit Conventions

- Use Conventional Commits:
  - `feat:` new feature
  - `fix:` bug fix
  - `docs:` documentation only
  - `chore:` tooling/build/infra changes
  - `refactor:` code change that neither fixes a bug nor adds a feature
- Example: `feat: support multi‑part SMS forwarding`

## Pull Requests

- Include a clear description and link issues (e.g., `Closes #123`).
- For UI changes, add screenshots/GIFs.
- Provide test steps to verify behavior.
- Ensure `flutter analyze` and `flutter test` pass locally with no new warnings.

## Development

- Install deps: `flutter pub get`
- Run app: `flutter run -d <device>`
- Analyze: `flutter analyze`
- Test: `flutter test` (or `flutter test --coverage`)
- Format: `dart format lib test` (or `flutter format .`)

## Testing Guidelines

- Use `flutter_test` with `WidgetTester`.
- Place tests under `test/` and name files `*_test.dart`.
- Keep tests deterministic and reasonably fast.
- Target new logic with unit/widget tests; keep coverage stable or improved.

## Coding Style

- Dart/Flutter, 2‑space indent.
- Prefer `const` widgets and `final` where possible.
- Lints configured via `analysis_options.yaml` (extends `flutter_lints`). Fix warnings before PRs.

## Security & Configuration

- Do not commit secrets. API keys and URLs are configured via the app Settings screen and stored with `shared_preferences`.
- Validate API connectivity using the in‑app validation before release testing.
- Android: test SMS permission flow and foreground service behavior on a real device.

## Project Structure

- `lib/main.dart`: App entry point (`MyApp`)
- `lib/screen/`: UI screens (`home.dart`, `settings.dart`, `logs.dart`, `phone_numbers.dart`)
- `lib/service/`: App services (`api_service.dart`, `log_service.dart`)
- `lib/storage/settings/`: Settings models and persistence
- `lib/storage/logs/`: Log models and persistence
- `android/`: Native Android code (Kotlin services/receivers, manifests, Gradle)
- `test/`: Widget and unit tests (`*_test.dart`)

## Release Builds

- Build APK: `flutter build apk --release`
- Build App Bundle: `flutter build appbundle`

