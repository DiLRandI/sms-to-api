# SMS to API - React Native App

A professional React Native application that listens for incoming SMS messages on Android devices and forwards them to a configured API endpoint.

## 🚀 Features

- **SMS Listening**: Real-time monitoring of incoming SMS messages
- **API Forwarding**: Automatic forwarding of SMS to your configured API endpoint
- **Secure Storage**: Local storage of API credentials using AsyncStorage
- **Permission Management**: Proper handling of Android SMS permissions
- **Professional UI**: Modern, clean interface with hamburger menu navigation
- **Status Monitoring**: Real-time status of SMS listener and API configuration

## 📱 Screens

1. **Home**: Overview of app status and quick actions
2. **SMS Listener**: Configure and manage SMS listening functionality
3. **Settings**: Configure API endpoint and credentials

## 🔧 Setup Instructions

### Prerequisites

- React Native development environment
- Android device or emulator
- Expo CLI

### Installation

1. Clone the repository
2. Install dependencies:

   ```bash
   npm install
   ```

3. Start the development server:

   ```bash
   npm start
   ```

4. Run on Android device:

   ```bash
   npm run android
   ```

## 🔐 Permissions Required

The app requires the following Android permissions:

- `RECEIVE_SMS`: To listen for incoming SMS messages
- `READ_SMS`: To read SMS message content

These permissions are requested at runtime when you first try to activate SMS listening.

## ⚙️ Configuration

### API Settings

1. Navigate to **Settings** screen
2. Enter your **API Endpoint** (full URL where SMS will be forwarded)
3. Enter your **API Key** for authentication
4. Tap **Save Settings**

### SMS Listener

1. Navigate to **SMS Listener** screen
2. Grant SMS permissions when prompted
3. Toggle the SMS listener switch to start/stop listening
4. Monitor status and test configuration

## 📡 API Integration

### Expected API Format

When an SMS is received, the app will send a POST request to your configured endpoint:

```json
{
  "to": "+1234567890",
  "message": "Hello, this is a test SMS",
  "timestamp": "2025-07-11T10:30:00.000Z",
  "originalMessage": {
    "from": "+1234567890",
    "message": "Hello, this is a test SMS",
    "timestamp": "2025-07-11T10:30:00.000Z",
    "messageId": "sms_1625998200000_abc123def",
    "deviceInfo": {
      "platform": "android",
      "appVersion": "1.0.0"
    }
  },
  "direction": "incoming"
}
```

### Headers

- `Content-Type: application/json`
- `Authorization: Bearer YOUR_API_KEY`
- `User-Agent: SMS-to-API-App/1.0.0`

## 🛠 Technical Implementation

### Architecture

- **Service Layer**: `SmsService` for SMS handling, `StorageService` for data persistence, `ApiService` for API communication
- **Custom Hooks**: `useApiSettings` for state management
- **Navigation**: React Navigation with drawer navigation
- **Storage**: AsyncStorage for secure local data persistence

### Key Components

- `SmsService`: Handles SMS permissions, listening, and forwarding
- `StorageService`: Manages secure local storage of API settings
- `ApiService`: Handles API communication and validation
- `useApiSettings`: Custom hook for API settings management

## 🔒 Security Features

- **Local Storage Only**: API credentials stored locally on device
- **No Data Sharing**: Messages only sent to your configured API
- **Permission Controls**: Explicit user permission for SMS access
- **Secure Text Entry**: API key input with hide/show toggle
- **Input Validation**: Comprehensive validation of API settings

## 🐛 Troubleshooting

### Common Issues

1. **SMS Permission Denied**
   - Go to Android Settings > Apps > SMS to API > Permissions
   - Enable SMS permissions manually

2. **API Connection Failed**
   - Verify your API endpoint URL is correct and accessible
   - Check your API key is valid
   - Ensure your server accepts POST requests with JSON body

3. **SMS Not Being Forwarded**
   - Check SMS listener is active (green status)
   - Verify API configuration is complete
   - Check app has necessary permissions
   - Review console logs for error messages

### Testing Configuration

Use the "Test Configuration" button in the SMS Listener screen to verify:

- SMS permissions status
- API configuration completeness
- SMS listener status
- Overall readiness

## 📝 Development

### Project Structure

```
├── components/
│   └── CustomDrawerContent.js
├── hooks/
│   └── useApiSettings.js
├── screens/
│   ├── HomeScreen.js
│   ├── SmsScreen.js
│   └── SettingsScreen.js
├── services/
│   ├── ApiService.js
│   ├── SmsService.js
│   └── StorageService.js
└── App.js
```

### Building for Production

1. Configure your app signing
2. Build APK/AAB:

   ```bash
   expo build:android
   ```

## 📄 License

This project is licensed under the 0BSD License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ⚠️ Disclaimer

This app is designed for legitimate use cases such as SMS-to-email forwarding, notification systems, or SMS backup solutions. Users are responsible for complying with local laws and regulations regarding SMS monitoring and data handling.
