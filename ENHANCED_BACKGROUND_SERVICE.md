# Enhanced Background Service Implementation

## Overview
The SMS-to-API app now includes an **Enhanced Persistent Background Service** using `react-native-background-actions` that ensures SMS forwarding continues even when the app is completely closed.

## Service Types

### 1. Regular SMS Listener (Original)
- Uses `@ernestbies/react-native-android-sms-listener`
- Works in background when app is minimized
- May stop working when app is force-closed or after device restart

### 2. Persistent Background Service (NEW) 🚀
- Uses `react-native-background-actions` for persistent foreground service
- Shows a permanent notification while running
- Continues working even when app is completely closed
- Automatically restarts after device reboot
- Enhanced message queuing and retry logic

## Key Features

### ✅ True Background Operation
- SMS listening continues when app is force-closed
- Survives device reboot (with proper configuration)
- Persistent foreground service with notification

### ✅ Enhanced Reliability
- Automatic message queuing for failed API calls
- Retry logic with exponential backoff
- Duplicate message detection
- Real-time status monitoring

### ✅ Smart Battery Management
- Optimized background processing
- Efficient resource usage
- Automatic cleanup of processed messages

### ✅ User Experience
- Real-time status updates in UI
- Service statistics (processed/queued messages)
- Clear start/stop controls
- Comprehensive error handling

## How to Use

### Starting Persistent Service
1. Configure your API endpoint and key in Settings
2. Grant SMS permissions when prompted
3. Go to SMS Screen
4. Tap "Start Persistent Service" in the Enhanced Background Service section
5. A notification will appear confirming the service is active

### Service Management
- **View Status**: Check processed/queued message counts
- **Stop Service**: Use the "Stop Persistent Service" button
- **Refresh Status**: Tap the refresh icon to update statistics

### Notifications
- Persistent service shows a permanent notification while running
- Additional notifications for service start/stop events
- Success/failure notifications for message processing

## Technical Implementation

### Background Task
```javascript
// Continuous background loop
while (BackgroundService.isRunning()) {
  // Process queued messages every 30 seconds
  // Update notification every 5 minutes
  // Log heartbeat every 10 minutes
  await sleep(1000);
}
```

### Message Processing
```javascript
// Handle SMS in background
const handleBackgroundSms = async (message, apiSettings) => {
  // Duplicate detection
  // Contact filtering
  // API forwarding
  // Queue failed messages for retry
};
```

### Retry Logic
- Failed messages are queued for retry
- Maximum 3 retry attempts per message
- Exponential backoff between retries
- Automatic cleanup after max retries

## Required Permissions

The following Android permissions are required for the persistent service:

```json
"permissions": [
  "RECEIVE_SMS",           // Listen for SMS messages
  "READ_SMS",              // Read SMS content
  "WAKE_LOCK",             // Keep device awake for processing
  "RECEIVE_BOOT_COMPLETED", // Auto-start after reboot
  "FOREGROUND_SERVICE",    // Run persistent foreground service
  "SYSTEM_ALERT_WINDOW",   // Show system notifications
  "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" // Prevent battery optimization
]
```

## Battery Optimization

### Android 12+ Considerations
- Background task restrictions may apply
- Users may need to disable battery optimization for the app
- Foreground service notification is mandatory

### Best Practices
- The persistent service is designed to be battery-efficient
- Use the regular SMS listener when possible
- Only use persistent service for critical 24/7 monitoring

## Troubleshooting

### Service Not Starting
1. Check API configuration is complete
2. Ensure SMS permissions are granted
3. Verify no battery optimization restrictions
4. Check device storage space

### Messages Not Forwarding
1. Check API endpoint connectivity
2. Verify API key is correct
3. Review app logs for error details
4. Ensure contact filters aren't blocking messages

### Service Stops Unexpectedly
1. Check if battery optimization is disabled
2. Verify foreground service permissions
3. Review device manufacturer's background app restrictions
4. Check available device memory

## Monitoring and Logs

### Service Status
- Real-time status in SMS Screen
- Processed message count
- Queued message count
- Service start/stop timestamps

### Logging
- All service events are logged
- Background processing logged with debug level
- Error conditions logged with full context
- Logs accessible through Logs screen in app

## Migration from Regular Service

Existing users can:
1. Continue using the regular SMS listener (no changes required)
2. Optionally enable the persistent service for enhanced reliability
3. Use both services simultaneously for maximum coverage

The persistent service complements the existing functionality and doesn't replace it.
