# SMS to API

A Flutter app that automatically reads incoming SMS messages and forwards them to a configured API endpoint.

## Features

- 📱 **Background SMS Monitoring**: Automatically detects incoming SMS messages
- 🚀 **API Integration**: Forwards SMS data to your configured API endpoint
- 🔐 **Permission Management**: Handles SMS permissions gracefully
- ⚙️ **Easy Configuration**: Simple UI to configure API endpoint and authentication
- 📊 **Statistics Tracking**: Monitor how many messages have been forwarded
- 🎨 **Modern UI**: Clean Material Design 3 interface

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.8.1 or higher)
- Android device or emulator (iOS not supported due to SMS limitations)
- API endpoint to receive SMS data

### 2. Installation

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Build and install the app: `flutter run`

### 3. Configuration

1. Open the app and tap the settings icon
2. Enter your API endpoint URL (e.g., `https://your-api.com/webhook`)
3. Optionally add an API key for authentication
4. Test the connection to verify your endpoint
5. Save the configuration

### 4. Usage

1. Grant SMS permissions when prompted
2. Enable the service by tapping "Start Service"
3. The app will now forward all incoming SMS to your API

## API Payload Format

The app sends HTTP POST requests with the following JSON structure:

```json
{
  "sender": "+1234567890",
  "message": "Your SMS message content",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "device_info": {
    "platform": "android",
    "app": "sms_to_api"
  }
}
```

For test messages, an additional `"test": true` field is included.

## Authentication

If you configure an API key, it will be sent as a Bearer token in the Authorization header:

```
Authorization: Bearer your-api-key-here
```

## Permissions Required

- **READ_SMS**: To read incoming SMS messages
- **RECEIVE_SMS**: To receive SMS messages in the background
- **INTERNET**: To send HTTP requests to your API

## Technical Details

### Dependencies

- `telephony`: SMS reading and background listening
- `permission_handler`: Managing app permissions
- `http`: Making API requests
- `shared_preferences`: Storing configuration
- `provider`: State management

### Background Processing

The app registers a background SMS receiver that continues to work even when the app is closed. This ensures all SMS messages are captured and forwarded.

## Troubleshooting

### SMS Not Being Forwarded

1. Ensure SMS permissions are granted
2. Check that the service is enabled (green status)
3. Verify your API endpoint is accessible
4. Check the app logs for error messages

### API Connection Issues

1. Test the connection using the "Test Connection" button
2. Verify your API endpoint accepts POST requests
3. Check if your endpoint requires specific headers or authentication
4. Ensure your device has internet connectivity

### Permissions Denied

1. Go to Android Settings > Apps > SMS to API > Permissions
2. Enable SMS permissions manually
3. Restart the app

## Security Considerations

- Store API keys securely on device using SharedPreferences
- Use HTTPS for API endpoints to encrypt data in transit
- Consider implementing endpoint authentication
- Review SMS data before forwarding sensitive information

## Building for Production

1. Update `android/app/build.gradle` with proper signing configuration
2. Generate a signed APK: `flutter build apk --release`
3. Test thoroughly on different Android versions
4. Consider adding crash reporting and analytics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Please ensure compliance with SMS and privacy regulations in your jurisdiction.

## Support

For issues and questions, please create an issue in the repository or contact the maintainer.
