import { Platform, PermissionsAndroid, Alert, AppState } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import SmsListener from '@ernestbies/react-native-android-sms-listener';
import ApiService from './ApiService';
import StorageService from './StorageService';
import ContactFilterService from './ContactFilterService';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './LoggingService';
import ExpoEnhancedSmsService from './ExpoEnhancedSmsService';

/**
 * SMS Service for handling incoming SMS messages on Android
 * Professional implementation with proper permissions and error handling
 * Uses ExpoEnhancedSmsService for improved background operation
 */
export class SmsService {
  static subscription = null;
  static isListening = false;
  static STORAGE_KEY = '@sms_to_api:sms_listener_state';
  static currentAppState = AppState.currentState;

  /**
   * Initialize SMS service and restore previous state
   */
  static async initialize() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Initializing SMS service');
      
      // Setup AppState monitoring for background/foreground detection
      this.setupAppStateListener();
      
      // Check if SMS listener was previously active
      const savedState = await AsyncStorage.getItem(this.STORAGE_KEY);
      const wasListening = savedState ? JSON.parse(savedState).isListening : false;
      
      if (wasListening) {
        await LoggingService.info(LOG_CATEGORIES.SMS, 'SMS listener was previously active, attempting to restore');
        
        // Check if we still have permissions and API config
        const hasPermission = await this.checkSmsPermissions();
        const apiSettings = await StorageService.getApiSettings();
        const hasApiConfig = !!(apiSettings.endpoint && apiSettings.apiKey);
        
        if (hasPermission && hasApiConfig) {
          // Restore the SMS listener
          const restored = await this.startListening(true); // true = silent restore
          
          if (restored) {
            await LoggingService.success(LOG_CATEGORIES.SMS, 'SMS listener restored successfully on app start');
          } else {
            await LoggingService.warn(LOG_CATEGORIES.SMS, 'Failed to restore SMS listener on app start');
          }
        } else {
          await LoggingService.warn(LOG_CATEGORIES.SMS, 'Cannot restore SMS listener: missing permissions or API config', {
            hasPermission,
            hasApiConfig
          });
          // Clear the saved state since we can't restore
          await this.saveListenerState(false);
        }
      } else {
        await LoggingService.debug(LOG_CATEGORIES.SMS, 'SMS listener was not previously active');
      }
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to initialize SMS service', { error: error.message });
      return false;
    }
  }

  /**
   * Setup AppState listener to track when app is in foreground/background
   */
  static setupAppStateListener() {
    AppState.addEventListener('change', (nextAppState) => {
      const previousState = this.currentAppState;
      this.currentAppState = nextAppState;
      
      LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'App state changed', {
        from: previousState,
        to: nextAppState
      });
    });
  }

  /**
   * Check if app is currently in foreground
   */
  static isAppInForeground() {
    return this.currentAppState === 'active';
  }

  /**
   * Save SMS listener state to persistent storage
   */
  static async saveListenerState(isListening) {
    try {
      const state = {
        isListening,
        timestamp: new Date().toISOString(),
      };
      await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify(state));
      await LoggingService.debug(LOG_CATEGORIES.STORAGE, 'SMS listener state saved', state);
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.STORAGE, 'Failed to save SMS listener state', { error: error.message });
    }
  }

  /**
   * Request SMS permissions from user
   * @returns {Promise<boolean>} Permission granted status
   */
  static async requestSmsPermissions() {
    if (Platform.OS !== 'android') {
      const errorMsg = 'SMS listening is only available on Android devices';
      await LoggingService.error(LOG_CATEGORIES.PERMISSIONS, errorMsg);
      Alert.alert('Platform Error', errorMsg);
      return false;
    }

    try {
      await LoggingService.info(LOG_CATEGORIES.PERMISSIONS, 'Requesting SMS permissions from user');
      
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECEIVE_SMS,
        {
          title: 'SMS Permission Required',
          message: 'This app needs access to your SMS messages to forward them to your API endpoint. Your messages will only be sent to your configured API and not stored or shared elsewhere.',
          buttonNeutral: 'Ask Me Later',
          buttonNegative: 'Cancel',
          buttonPositive: 'Allow',
        }
      );

      if (granted === PermissionsAndroid.RESULTS.GRANTED) {
        await LoggingService.success(LOG_CATEGORIES.PERMISSIONS, 'SMS permission granted by user');
        console.log('SMS permission granted');
        return true;
      } else {
        await LoggingService.warn(LOG_CATEGORIES.PERMISSIONS, 'SMS permission denied by user', { granted });
        console.log('SMS permission denied');
        Alert.alert(
          'Permission Required',
          'SMS permission is required to listen for incoming messages. Please enable it in your device settings.'
        );
        return false;
      }
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.PERMISSIONS, 'Failed to request SMS permission', { error: error.message });
      console.error('Error requesting SMS permission:', error);
      Alert.alert('Error', 'Failed to request SMS permission');
      return false;
    }
  }

  /**
   * Check if SMS permissions are granted
   * @returns {Promise<boolean>} Permission status
   */
  static async checkSmsPermissions() {
    if (Platform.OS !== 'android') {
      await LoggingService.warn(LOG_CATEGORIES.PERMISSIONS, 'SMS permissions check failed: Not Android platform');
      return false;
    }

    try {
      const granted = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.RECEIVE_SMS);
      await LoggingService.debug(LOG_CATEGORIES.PERMISSIONS, 'SMS permission check completed', { granted });
      return granted;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.PERMISSIONS, 'Error checking SMS permission', { error: error.message });
      console.error('Error checking SMS permission:', error);
      return false;
    }
  }

  /**
   * Start listening for incoming SMS messages
   * @param {boolean} silentRestore - If true, don't show alerts (for automatic restore)
   * @returns {Promise<boolean>} Success status
   */
  static async startListening(silentRestore = false) {
    try {
      if (!silentRestore) {
        await LoggingService.info(LOG_CATEGORIES.SMS, 'Attempting to start SMS listener');
      } else {
        await LoggingService.info(LOG_CATEGORIES.SMS, 'Attempting to restore SMS listener silently');
      }

      // Check platform
      if (Platform.OS !== 'android') {
        const errorMsg = 'SMS listening is only available on Android devices';
        await LoggingService.error(LOG_CATEGORIES.SMS, errorMsg);
        if (!silentRestore) {
          Alert.alert('Platform Error', errorMsg);
        }
        return false;
      }

      // Check if already listening
      if (this.isListening) {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'SMS listener start requested but already active');
        if (!silentRestore) {
          console.log('SMS listener is already active');
        }
        return true;
      }

      // Check permissions
      const hasPermission = await this.checkSmsPermissions();
      if (!hasPermission) {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'SMS permissions not granted, requesting permissions');
        if (!silentRestore) {
          const granted = await this.requestSmsPermissions();
          if (!granted) {
            await LoggingService.error(LOG_CATEGORIES.SMS, 'SMS listener failed to start: permissions denied');
            return false;
          }
        } else {
          await LoggingService.error(LOG_CATEGORIES.SMS, 'SMS listener restore failed: permissions not granted');
          return false;
        }
      }

      // Check API configuration
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        const errorMsg = 'API configuration missing (endpoint or key)';
        await LoggingService.error(LOG_CATEGORIES.SMS, errorMsg, { 
          hasEndpoint: !!apiSettings.endpoint, 
          hasApiKey: !!apiSettings.apiKey 
        });
        if (!silentRestore) {
          Alert.alert(
            'Configuration Required',
            'Please configure your API endpoint and key in Settings before starting SMS listening.'
          );
        }
        return false;
      }

      // Start SMS listening with background-capable library
      this.subscription = SmsListener.addListener(message => {
        this.handleIncomingSms(message, apiSettings);
      });

      this.isListening = true;
      
      // Save the listening state
      await this.saveListenerState(true);
      
      await LoggingService.success(LOG_CATEGORIES.SMS, 'SMS listener started with background-capable library', {
        backgroundLibrarySupport: true,
        silentRestore
      });
      
      if (!silentRestore) {
        console.log('SMS listener started successfully');
        
        Alert.alert(
          'SMS Listener Active',
          `Now listening for incoming SMS messages. They will be forwarded to your configured API endpoint.\n\n✅ ENHANCED BACKGROUND SUPPORT - Using background-capable SMS library that works even when app is closed.\n\nFor 24/7 operation when app is completely closed, use the Persistent Service option.`,
          [{ text: 'OK', style: 'default' }]
        );
      }

      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to start SMS listener', { error: error.message, silentRestore });
      if (!silentRestore) {
        console.error('Error starting SMS listener:', error);
        Alert.alert('Error', 'Failed to start SMS listener: ' + error.message);
      }
      return false;
    }
  }

  /**
   * Stop listening for SMS messages
   * @returns {boolean} Success status
   */
  static async stopListening() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Stopping SMS listener');

      if (this.subscription) {
        this.subscription.remove();
        this.subscription = null;
      }
      
      this.isListening = false;
      
      // Save the stopped state
      await this.saveListenerState(false);
      
      await LoggingService.success(LOG_CATEGORIES.SMS, 'SMS listener stopped successfully');
      console.log('SMS listener stopped');
      
      Alert.alert(
        'SMS Listener Stopped',
        'No longer listening for incoming SMS messages.',
        [{ text: 'OK', style: 'default' }]
      );

      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to stop SMS listener', { error: error.message });
      console.error('Error stopping SMS listener:', error);
      Alert.alert('Error', 'Failed to stop SMS listener: ' + error.message);
      return false;
    }
  }

  /**
   * Start enhanced background service for SMS listening
   * This service provides improved reliability with Expo background tasks
   * @returns {Promise<boolean>} Success status
   */
  static async startEnhancedService() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Starting enhanced SMS background service');

      // Check permissions first
      const hasPermission = await this.checkSmsPermissions();
      if (!hasPermission) {
        const granted = await this.requestSmsPermissions();
        if (!granted) {
          throw new Error('SMS permissions required for enhanced service');
        }
      }

      // Check API configuration
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        throw new Error('API configuration required for enhanced service');
      }

      // Check if background fetch is available
      const backgroundAvailable = await ExpoEnhancedSmsService.isBackgroundAvailable();
      if (!backgroundAvailable) {
        Alert.alert(
          'Background Processing Limited',
          'Background app refresh is not available on this device. The enhanced service will work when the app is open or minimized, but may not work when completely closed.\n\nYou can enable background app refresh in your device settings.',
          [{ text: 'Continue Anyway', style: 'default' }, { text: 'Cancel', style: 'cancel' }],
          { cancelable: true }
        );
      }

      // Initialize and start enhanced service
      await ExpoEnhancedSmsService.initialize();
      const started = await ExpoEnhancedSmsService.startEnhancedService();

      if (started) {
        await LoggingService.success(LOG_CATEGORIES.SMS, 'Enhanced SMS service started successfully');
        
        Alert.alert(
          'Enhanced SMS Service Started',
          '🚀 Improved Background Service Active!\n\n' +
          '✅ Enhanced SMS listening with background processing\n' +
          '✅ Automatic message queuing and retry\n' +
          '✅ Improved reliability for background operation\n' +
          `${backgroundAvailable ? '✅ Background processing available' : '⚠️ Background processing limited - check device settings'}\n\n` +
          'The service will work better when background app refresh is enabled in device settings.',
          [{ text: 'Great!', style: 'default' }]
        );
        
        return true;
      }
      
      return false;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to start enhanced SMS service', { error: error.message });
      
      Alert.alert(
        'Enhanced Service Error',
        `Failed to start enhanced background service:\n\n${error.message}\n\nYou can still use the regular SMS listener, but enhanced background processing won't be available.`,
        [{ text: 'OK', style: 'default' }]
      );
      
      return false;
    }
  }

  /**
   * Stop enhanced background service
   * @returns {Promise<boolean>} Success status
   */
  static async stopEnhancedService() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Stopping enhanced SMS background service');
      
      const stopped = await ExpoEnhancedSmsService.stopEnhancedService();
      
      if (stopped) {
        await LoggingService.success(LOG_CATEGORIES.SMS, 'Enhanced SMS service stopped successfully');
        
        Alert.alert(
          'Enhanced Service Stopped',
          'The enhanced background SMS service has been stopped.\n\nSMS forwarding reliability may be reduced when the app is in the background.',
          [{ text: 'OK', style: 'default' }]
        );
        
        return true;
      }
      
      return false;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to stop enhanced SMS service', { error: error.message });
      
      Alert.alert(
        'Error',
        `Failed to stop enhanced service: ${error.message}`,
        [{ text: 'OK', style: 'default' }]
      );
      
      return false;
    }
  }

  /**
   * Get status of both regular and enhanced SMS services
   * @returns {Promise<Object>} Service status information
   */
  static async getServiceStatus() {
    try {
      const regularStatus = {
        isListening: this.isListening,
        hasSubscription: !!this.subscription,
        currentAppState: this.currentAppState,
      };

      const enhancedStatus = await ExpoEnhancedSmsService.getServiceStatus();
      
      return {
        regular: regularStatus,
        enhanced: enhancedStatus,
        // For compatibility with existing UI
        persistent: enhancedStatus,
        isAnyActive: this.isListening || enhancedStatus.isRunning,
      };
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to get service status', { error: error.message });
      return {
        regular: { isListening: false, error: error.message },
        enhanced: { isRunning: false, error: error.message },
        persistent: { isRunning: false, error: error.message },
        isAnyActive: false,
      };
    }
  }

  /**
   * Handle incoming SMS message
   * @param {Object} message - SMS message object
   * @param {Object} apiSettings - API configuration
   */
  static async handleIncomingSms(message, apiSettings) {
    try {
      const smsInfo = {
        originatingAddress: message.originatingAddress,
        body: message.body,
        timestamp: new Date().toISOString(),
        messageId: this.generateMessageId(),
      };
      
      const currentAppState = AppState.currentState;
      await LoggingService.info(LOG_CATEGORIES.SMS, 'SMS received via background-capable library', {
        ...smsInfo,
        appState: currentAppState
      });
      console.log('SMS received:', smsInfo, 'App State:', currentAppState);

      // Check if this number should be forwarded based on user filters
      const shouldForward = await ContactFilterService.shouldForwardSms(message.originatingAddress);
      
      if (!shouldForward) {
        await LoggingService.warn(LOG_CATEGORIES.FILTERS, 'SMS blocked by user filter', {
          phoneNumber: message.originatingAddress,
          messagePreview: message.body.substring(0, 50)
        });
        console.log(`SMS from ${message.originatingAddress} blocked by user filter`);
        this.showFilteredNotification(message.originatingAddress);
        return;
      }

      // Prepare SMS data for API
      const smsData = {
        from: message.originatingAddress,
        message: message.body,
        timestamp: smsInfo.timestamp,
        messageId: smsInfo.messageId,
        deviceInfo: {
          platform: Platform.OS,
          appVersion: '1.3.0',
          appState: currentAppState,
          processedWithBackgroundLibrary: true,
          libraryUsed: '@ernestbies/react-native-android-sms-listener'
        },
      };

      await LoggingService.debug(LOG_CATEGORIES.API, 'Forwarding SMS to API via background library', {
        messageId: smsData.messageId,
        from: smsData.from,
        appState: currentAppState,
        endpoint: apiSettings.endpoint
      });

      // Send to API
      const result = await ApiService.sendSms({
        endpoint: apiSettings.endpoint,
        apiKey: apiSettings.apiKey,
        to: smsData.from,
        message: smsData.message,
        additionalData: {
          originalMessage: smsData,
          direction: 'incoming',
          backgroundLibraryProcessed: true,
        },
      });

      if (result.success) {
        await LoggingService.success(LOG_CATEGORIES.API, 'SMS forwarded successfully via background library', {
          messageId: smsData.messageId,
          from: smsData.from,
          appState: currentAppState,
          responseData: result.data
        });
        console.log('SMS forwarded successfully:', result);
        this.showSuccessNotification(smsData);
      } else {
        await LoggingService.error(LOG_CATEGORIES.API, 'Failed to forward SMS via background library', {
          messageId: smsData.messageId,
          from: smsData.from,
          appState: currentAppState,
          error: result.message,
          statusCode: result.statusCode
        });
        console.error('Failed to forward SMS:', result);
        this.showErrorNotification(`SMS forwarding failed: ${result.message}. Consider using Persistent Service for reliable delivery.`);
      }

    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Critical error handling SMS with background library', {
        error: error.message,
        phoneNumber: message?.originatingAddress,
        messagePreview: message?.body?.substring(0, 50),
        appState: AppState.currentState
      });
      console.error('Error handling SMS:', error);
      this.showErrorNotification('Failed to process SMS - use Persistent Service for reliable background processing');
    }
  }

  /**
   * Generate unique message ID
   * @returns {string} Unique ID
   */
  static generateMessageId() {
    return `sms_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Show success notification (subtle)
   * @param {Object} smsData - SMS data
   */
  static showSuccessNotification(smsData) {
    // For production, you might want to use a toast notification instead
    LoggingService.debug(LOG_CATEGORIES.USER, 'Success notification shown', {
      messageId: smsData.messageId,
      from: smsData.from
    });
    console.log(`✅ SMS from ${smsData.from} forwarded to API`);
  }

  /**
   * Show filtered notification
   * @param {string} phoneNumber - Phone number that was filtered
   */
  static showFilteredNotification(phoneNumber) {
    LoggingService.debug(LOG_CATEGORIES.USER, 'Filtered notification shown', { phoneNumber });
    console.log(`🚫 SMS from ${phoneNumber} filtered (not forwarded)`);
  }

  /**
   * Show error notification
   * @param {string} message - Error message
   */
  static showErrorNotification(message) {
    // For production, you might want to use a toast notification instead
    LoggingService.warn(LOG_CATEGORIES.USER, 'Error notification shown', { message });
    console.error(`❌ SMS forwarding failed: ${message}`);
    
    // Only show alert for critical errors
    if (message.includes('network') || message.includes('connection')) {
      Alert.alert(
        'SMS Forwarding Error',
        `Failed to forward SMS: ${message}`,
        [{ text: 'OK', style: 'default' }]
      );
    }
  }

  /**
   * Get current listening status
   * @returns {boolean} Current status
   */
  static getListeningStatus() {
    return this.isListening;
  }

  /**
   * Test SMS functionality (for development)
   * @returns {Promise<boolean>} Test result
   */
  static async testSmsSetup() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'Testing SMS setup configuration');
      
      const hasPermission = await this.checkSmsPermissions();
      const apiSettings = await StorageService.getApiSettings();
      const hasApiConfig = !!(apiSettings.endpoint && apiSettings.apiKey);

      const testResult = {
        hasPermission,
        hasApiConfig,
        isListening: this.isListening,
        platform: Platform.OS,
        ready: hasPermission && hasApiConfig,
      };

      await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'SMS setup test completed', testResult);

      return testResult;
    } catch (error) {
      const errorResult = {
        hasPermission: false,
        hasApiConfig: false,
        isListening: false,
        platform: Platform.OS,
        ready: false,
        error: error.message,
      };
      
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'SMS setup test failed', errorResult);
      console.error('Error testing SMS setup:', error);
      
      return errorResult;
    }
  }
}

export default SmsService;
