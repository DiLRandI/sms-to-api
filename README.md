
# sms_to_api

Forward SMS messages to a REST API using Flutter.

## Overview

`sms_to_api` is a Flutter application that listens for incoming SMS messages and forwards them to a configurable REST API endpoint. The app allows you to set the API URL and API key in the settings screen, and stores these securely using `shared_preferences`.

## Architecture

```mermaid
architecture-beta
    group app(cloud)[Flutter App]
    service sms_receiver(server)[SMS Receiver] in app
    service api_forwarder(cloud)[API Forwarder] in app
    service rest_api(database)[REST API Endpoint]

    sms_receiver:R -- L:api_forwarder
    api_forwarder:R -- L:rest_api
```

**Diagram Explanation:**
- The Flutter app receives SMS messages, processes them, and forwards them to a REST API endpoint.
- The architecture is modular, separating SMS reception and API forwarding logic.

## Features

- Configure REST API endpoint and API key
- Validate API connectivity (manual validation with feedback)
- Store settings securely
- Forward SMS messages to the API
- Start/stop/bind/unbind Android foreground service
- View service status and logs

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
- `lib/screen/logs.dart`: Logs screen for viewing forwarded SMS logs
- `lib/screen/phone_numbers.dart`: Manage allowed/blocked phone numbers
- `lib/service/api_service.dart`: API service for sending SMS data
- `lib/service/log_service.dart`: Service for managing and storing logs
- `lib/storage/settings/`: Settings storage and type definitions
- `lib/storage/logs/`: Log storage implementation

## Dependencies

- `flutter`: Flutter SDK
- `cupertino_icons`: iOS-style icons
- `shared_preferences`: Local storage for settings
- `http`: HTTP requests
- (and any other dependencies listed in `pubspec.yaml`)

## License

This project is private and not published to pub.dev.
