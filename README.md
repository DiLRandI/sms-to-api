
# sms_to_api

Forward SMS messages to a REST API using Flutter.

## Overview

`sms_to_api` is a Flutter application that listens for incoming SMS messages and forwards them to a configurable REST API endpoint. The app allows you to set the API URL and API key in the settings screen, and stores these securely using `shared_preferences`.

## Features

- Configure REST API endpoint and API key
- Validate API connectivity
- Store settings securely
- Forward SMS messages to the API

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android device or emulator

### Installation

1. Clone the repository:
   ```sh
   git clone <repo-url>
   cd sms-to-api
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Run the app:
   ```sh
   flutter run
   ```

## Configuration

Go to the **Settings** screen in the app to set your API URL and API key. These are required for the app to forward SMS messages.

## Project Structure

- `lib/main.dart`: App entry point
- `lib/screen/home.dart`: Home screen and main logic
- `lib/screen/settings.dart`: Settings screen for API configuration
- `lib/service/api_service.dart`: API service for sending SMS data
- `lib/storage/settings/`: Settings storage and type definitions

## Dependencies

- `flutter`
- `cupertino_icons`
- `shared_preferences`
- `http`

## License

This project is private and not published to pub.dev.
