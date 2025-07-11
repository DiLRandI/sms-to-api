import { Platform, PermissionsAndroid, Alert } from 'react-native';
import SmsListener from 'react-native-android-sms-listener';
import ApiService from './ApiService';
import StorageService from './StorageService';
import ContactFilterService from './ContactFilterService';

/**
 * SMS Service for handling incoming SMS messages on Android
 * Professional implementation with proper permissions and error handling
 */
export class SmsService {
  static subscription = null;
  static isListening = false;

  /**
   * Request SMS permissions from user
   * @returns {Promise<boolean>} Permission granted status
   */
  static async requestSmsPermissions() {
    if (Platform.OS !== 'android') {
      Alert.alert('Platform Error', 'SMS listening is only available on Android devices');
      return false;
    }

    try {
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
        console.log('SMS permission granted');
        return true;
      } else {
        console.log('SMS permission denied');
        Alert.alert(
          'Permission Required',
          'SMS permission is required to listen for incoming messages. Please enable it in your device settings.'
        );
        return false;
      }
    } catch (error) {
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
      return false;
    }

    try {
      const granted = await PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.RECEIVE_SMS);
      return granted;
    } catch (error) {
      console.error('Error checking SMS permission:', error);
      return false;
    }
  }

  /**
   * Start listening for incoming SMS messages
   * @returns {Promise<boolean>} Success status
   */
  static async startListening() {
    try {
      // Check platform
      if (Platform.OS !== 'android') {
        Alert.alert('Platform Error', 'SMS listening is only available on Android devices');
        return false;
      }

      // Check if already listening
      if (this.isListening) {
        console.log('SMS listener is already active');
        return true;
      }

      // Check permissions
      const hasPermission = await this.checkSmsPermissions();
      if (!hasPermission) {
        const granted = await this.requestSmsPermissions();
        if (!granted) {
          return false;
        }
      }

      // Check API configuration
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        Alert.alert(
          'Configuration Required',
          'Please configure your API endpoint and key in Settings before starting SMS listening.'
        );
        return false;
      }

      // Start listening
      this.subscription = SmsListener.addListener(message => {
        this.handleIncomingSms(message, apiSettings);
      });

      this.isListening = true;
      console.log('SMS listener started successfully');
      
      Alert.alert(
        'SMS Listener Active',
        'Now listening for incoming SMS messages. They will be forwarded to your configured API endpoint.',
        [{ text: 'OK', style: 'default' }]
      );

      return true;
    } catch (error) {
      console.error('Error starting SMS listener:', error);
      Alert.alert('Error', 'Failed to start SMS listener: ' + error.message);
      return false;
    }
  }

  /**
   * Stop listening for SMS messages
   * @returns {boolean} Success status
   */
  static stopListening() {
    try {
      if (this.subscription) {
        this.subscription.remove();
        this.subscription = null;
      }
      
      this.isListening = false;
      console.log('SMS listener stopped');
      
      Alert.alert(
        'SMS Listener Stopped',
        'No longer listening for incoming SMS messages.',
        [{ text: 'OK', style: 'default' }]
      );

      return true;
    } catch (error) {
      console.error('Error stopping SMS listener:', error);
      Alert.alert('Error', 'Failed to stop SMS listener: ' + error.message);
      return false;
    }
  }

  /**
   * Handle incoming SMS message
   * @param {Object} message - SMS message object
   * @param {Object} apiSettings - API configuration
   */
  static async handleIncomingSms(message, apiSettings) {
    try {
      console.log('Incoming SMS received:', {
        originatingAddress: message.originatingAddress,
        body: message.body,
        timestamp: new Date().toISOString(),
      });

      // Check if this number should be forwarded based on user filters
      const shouldForward = await ContactFilterService.shouldForwardSms(message.originatingAddress);
      
      if (!shouldForward) {
        console.log(`SMS from ${message.originatingAddress} blocked by user filter`);
        this.showFilteredNotification(message.originatingAddress);
        return;
      }

      // Prepare SMS data for API
      const smsData = {
        from: message.originatingAddress,
        message: message.body,
        timestamp: new Date().toISOString(),
        messageId: this.generateMessageId(),
        deviceInfo: {
          platform: Platform.OS,
          appVersion: '1.0.0', // You could import this from package.json
        },
      };

      // Send to API
      const result = await ApiService.sendSms({
        endpoint: apiSettings.endpoint,
        apiKey: apiSettings.apiKey,
        to: smsData.from,
        message: smsData.message,
        additionalData: {
          originalMessage: smsData,
          direction: 'incoming',
        },
      });

      if (result.success) {
        console.log('SMS forwarded to API successfully:', result);
        // Optionally show a subtle notification
        this.showSuccessNotification(smsData);
      } else {
        console.error('Failed to forward SMS to API:', result);
        this.showErrorNotification(result.message);
      }
    } catch (error) {
      console.error('Error handling incoming SMS:', error);
      this.showErrorNotification('Failed to process incoming SMS');
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
    console.log(`✅ SMS from ${smsData.from} forwarded to API`);
  }

  /**
   * Show filtered notification
   * @param {string} phoneNumber - Phone number that was filtered
   */
  static showFilteredNotification(phoneNumber) {
    console.log(`🚫 SMS from ${phoneNumber} filtered (not forwarded)`);
  }

  /**
   * Show error notification
   * @param {string} message - Error message
   */
  static showErrorNotification(message) {
    // For production, you might want to use a toast notification instead
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
      const hasPermission = await this.checkSmsPermissions();
      const apiSettings = await StorageService.getApiSettings();
      const hasApiConfig = !!(apiSettings.endpoint && apiSettings.apiKey);

      return {
        hasPermission,
        hasApiConfig,
        isListening: this.isListening,
        platform: Platform.OS,
        ready: hasPermission && hasApiConfig,
      };
    } catch (error) {
      console.error('Error testing SMS setup:', error);
      return {
        hasPermission: false,
        hasApiConfig: false,
        isListening: false,
        platform: Platform.OS,
        ready: false,
        error: error.message,
      };
    }
  }
}

export default SmsService;
