import BackgroundService from 'react-native-background-actions';
import { Platform, AppState } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import SmsListener from '@ernestbies/react-native-android-sms-listener';
import ApiService from './ApiService';
import StorageService from './StorageService';
import ContactFilterService from './ContactFilterService';
import LoggingService, { LOG_CATEGORIES } from './LoggingService';
import * as Notifications from 'expo-notifications';

/**
 * Persistent SMS Service using react-native-background-actions
 * Ensures SMS listening continues even when app is completely closed
 */
export class PersistentSmsService {
  static isServiceRunning = false;
  static smsSubscription = null;
  static STORAGE_KEY = '@sms_to_api:persistent_sms_state';
  static messageQueue = [];
  static processedMessages = new Set();

  /**
   * Initialize the persistent SMS service
   */
  static async initialize() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Initializing Persistent SMS Service');
      
      // Check if service was previously running
      const savedState = await AsyncStorage.getItem(this.STORAGE_KEY);
      const wasRunning = savedState ? JSON.parse(savedState).isRunning : false;
      
      if (wasRunning) {
        await LoggingService.info(LOG_CATEGORIES.SMS, 'Persistent SMS service was previously active, restoring');
        await this.startPersistentService();
      }
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to initialize Persistent SMS Service', { error: error.message });
      return false;
    }
  }

  /**
   * Start the persistent background service
   */
  static async startPersistentService() {
    try {
      if (this.isServiceRunning || BackgroundService.isRunning()) {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'Persistent SMS service already running');
        return true;
      }

      // Check if we have API configuration
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        throw new Error('API configuration required before starting persistent service');
      }

      const options = {
        taskName: 'SMS_Listener',
        taskTitle: 'SMS Forwarding Service',
        taskDesc: 'Listening for SMS messages to forward to API',
        taskIcon: {
          name: 'ic_launcher',
          type: 'mipmap',
        },
        color: '#ff6347',
        linkingURI: 'smstoapi://service', // For deep linking
        parameters: {
          apiEndpoint: apiSettings.endpoint,
          apiKey: apiSettings.apiKey,
        },
      };

      // Start the background service with our SMS listening task
      await BackgroundService.start(this.backgroundSmsTask, options);
      this.isServiceRunning = true;

      // Save state
      await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify({ 
        isRunning: true, 
        startedAt: new Date().toISOString() 
      }));

      await LoggingService.success(LOG_CATEGORIES.SMS, 'Persistent SMS service started successfully');
      
      // Show notification to user
      await this.showServiceNotification('SMS Forwarding Service Started', 'App will continue listening for SMS even when closed');
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to start persistent SMS service', { error: error.message });
      this.isServiceRunning = false;
      throw error;
    }
  }

  /**
   * Stop the persistent background service
   */
  static async stopPersistentService() {
    try {
      if (BackgroundService.isRunning()) {
        await BackgroundService.stop();
      }

      if (this.smsSubscription) {
        this.smsSubscription.remove();
        this.smsSubscription = null;
      }

      this.isServiceRunning = false;

      // Clear saved state
      await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify({ 
        isRunning: false, 
        stoppedAt: new Date().toISOString() 
      }));

      await LoggingService.info(LOG_CATEGORIES.SMS, 'Persistent SMS service stopped');
      
      // Show notification to user
      await this.showServiceNotification('SMS Forwarding Service Stopped', 'SMS listening has been disabled');
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error stopping persistent SMS service', { error: error.message });
      return false;
    }
  }

  /**
   * Background task that runs continuously
   * This function runs in the background service
   */
  static backgroundSmsTask = async (taskDataArguments) => {
    const { apiEndpoint, apiKey } = taskDataArguments;
    
    console.log('🚀 Background SMS service started');
    await LoggingService.info(LOG_CATEGORIES.SMS, 'Background SMS task initiated', { apiEndpoint });

    // Initialize SMS listener in background
    if (Platform.OS === 'android') {
      try {
        // Start SMS listener
        this.smsSubscription = SmsListener.addListener(async (message) => {
          await this.handleBackgroundSms(message, { endpoint: apiEndpoint, apiKey });
        });

        console.log('📱 SMS listener active in background service');
        await LoggingService.success(LOG_CATEGORIES.SMS, 'SMS listener activated in background service');

      } catch (error) {
        console.error('❌ Failed to start SMS listener in background:', error);
        await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to start SMS listener in background', { error: error.message });
      }
    }

    // Keep the service running
    await new Promise(async (resolve) => {
      let iterationCount = 0;
      
      // Infinite loop to keep service alive
      while (BackgroundService.isRunning()) {
        iterationCount++;
        
        // Process any queued messages every 30 seconds
        if (iterationCount % 30 === 0) {
          await this.processQueuedMessages({ endpoint: apiEndpoint, apiKey });
        }
        
        // Update notification every 5 minutes with status
        if (iterationCount % 300 === 0) {
          await BackgroundService.updateNotification({
            taskDesc: `SMS Service Active - Processed ${this.processedMessages.size} messages`
          });
        }
        
        // Log heartbeat every 10 minutes
        if (iterationCount % 600 === 0) {
          console.log(`💓 SMS service heartbeat - iteration ${iterationCount}`);
          await LoggingService.debug(LOG_CATEGORIES.SMS, 'Background SMS service heartbeat', { 
            iteration: iterationCount,
            processedCount: this.processedMessages.size 
          });
        }
        
        // Wait 1 second before next iteration
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
      
      resolve();
    });

    console.log('🛑 Background SMS service ended');
    await LoggingService.info(LOG_CATEGORIES.SMS, 'Background SMS task ended');
  };

  /**
   * Handle SMS received in background service
   */
  static async handleBackgroundSms(message, apiSettings) {
    try {
      console.log('📨 SMS received in background:', message.originatingAddress);
      
      // Generate unique message ID to prevent duplicates
      const messageId = `${message.originatingAddress}_${message.body.substring(0, 20)}_${Date.now()}`;
      
      // Check if we've already processed this message
      if (this.processedMessages.has(messageId)) {
        console.log('⚠️ Duplicate SMS detected, skipping');
        return;
      }

      // Check if this number should be forwarded
      const shouldForward = await ContactFilterService.shouldForwardSms(message.originatingAddress);
      
      if (!shouldForward) {
        console.log(`🚫 SMS from ${message.originatingAddress} blocked by filter`);
        await LoggingService.warn(LOG_CATEGORIES.FILTERS, 'SMS blocked by user filter (background)', {
          phoneNumber: message.originatingAddress
        });
        this.processedMessages.add(messageId);
        return;
      }

      // Prepare SMS data
      const smsData = {
        from: message.originatingAddress,
        message: message.body,
        timestamp: new Date().toISOString(),
        messageId: messageId,
        deviceInfo: {
          platform: Platform.OS,
          appVersion: '1.3.0',
          processedInBackground: true,
          serviceType: 'persistent',
        },
      };

      console.log('🔄 Forwarding SMS to API from background service');

      // Send to API
      const result = await ApiService.sendSms({
        endpoint: apiSettings.endpoint,
        apiKey: apiSettings.apiKey,
        to: smsData.from,
        message: smsData.message,
        additionalData: {
          originalMessage: smsData,
          direction: 'incoming',
          backgroundProcessed: true,
          serviceType: 'persistent',
        },
      });

      if (result.success) {
        console.log('✅ SMS forwarded successfully from background');
        this.processedMessages.add(messageId);
        
        await LoggingService.success(LOG_CATEGORIES.API, 'SMS forwarded from background service', {
          messageId: smsData.messageId,
          from: smsData.from
        });

        // Update notification with success
        await BackgroundService.updateNotification({
          taskDesc: `Last SMS from ${message.originatingAddress} forwarded successfully`
        });

      } else {
        console.log('❌ Failed to forward SMS, adding to queue');
        
        // Add to queue for retry
        this.messageQueue.push({
          ...smsData,
          attempts: 0,
          lastAttempt: new Date().toISOString(),
        });

        await LoggingService.warn(LOG_CATEGORIES.API, 'Background SMS forwarding failed, queued for retry', {
          messageId: smsData.messageId,
          error: result.message
        });
      }

    } catch (error) {
      console.error('❌ Error processing SMS in background:', error);
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error processing SMS in background service', { 
        error: error.message,
        phoneNumber: message?.originatingAddress 
      });
    }
  }

  /**
   * Process queued messages that failed initial sending
   */
  static async processQueuedMessages(apiSettings) {
    if (this.messageQueue.length === 0) return;

    console.log(`🔄 Processing ${this.messageQueue.length} queued messages`);
    
    const messagesToRetry = [...this.messageQueue];
    this.messageQueue = [];

    for (const smsData of messagesToRetry) {
      try {
        if (smsData.attempts >= 3) {
          console.log(`⚠️ Message ${smsData.messageId} exceeded retry limit, dropping`);
          await LoggingService.warn(LOG_CATEGORIES.API, 'Message dropped after max retries', {
            messageId: smsData.messageId,
            attempts: smsData.attempts
          });
          continue;
        }

        const result = await ApiService.sendSms({
          endpoint: apiSettings.endpoint,
          apiKey: apiSettings.apiKey,
          to: smsData.from,
          message: smsData.message,
          additionalData: {
            ...smsData,
            retryAttempt: smsData.attempts + 1,
          },
        });

        if (result.success) {
          console.log(`✅ Queued message ${smsData.messageId} sent successfully`);
          this.processedMessages.add(smsData.messageId);
          
          await LoggingService.success(LOG_CATEGORIES.API, 'Queued SMS sent successfully', {
            messageId: smsData.messageId,
            attempt: smsData.attempts + 1
          });
        } else {
          // Re-queue with incremented attempt count
          this.messageQueue.push({
            ...smsData,
            attempts: smsData.attempts + 1,
            lastAttempt: new Date().toISOString(),
          });
          
          console.log(`⚠️ Message ${smsData.messageId} retry failed, re-queued`);
        }

      } catch (error) {
        console.error(`❌ Error retrying message ${smsData.messageId}:`, error);
        
        // Re-queue with incremented attempt count
        this.messageQueue.push({
          ...smsData,
          attempts: smsData.attempts + 1,
          lastAttempt: new Date().toISOString(),
        });
      }
    }
  }

  /**
   * Show service notification to user
   */
  static async showServiceNotification(title, body) {
    try {
      await Notifications.scheduleNotificationAsync({
        content: {
          title,
          body,
          sound: false,
          priority: Notifications.AndroidNotificationPriority.DEFAULT,
        },
        trigger: null,
      });
    } catch (error) {
      console.error('Error showing service notification:', error);
    }
  }

  /**
   * Get service status
   */
  static async getServiceStatus() {
    try {
      const savedState = await AsyncStorage.getItem(this.STORAGE_KEY);
      const state = savedState ? JSON.parse(savedState) : { isRunning: false };
      
      return {
        isRunning: this.isServiceRunning && BackgroundService.isRunning(),
        processedCount: this.processedMessages.size,
        queuedCount: this.messageQueue.length,
        startedAt: state.startedAt,
        ...state,
      };
    } catch (error) {
      return { isRunning: false, error: error.message };
    }
  }

  /**
   * Update notification with current status
   */
  static async updateServiceNotification(customMessage = null) {
    try {
      if (BackgroundService.isRunning()) {
        const status = await this.getServiceStatus();
        const message = customMessage || 
          `Active - Processed: ${status.processedCount}, Queued: ${status.queuedCount}`;
        
        await BackgroundService.updateNotification({
          taskDesc: message
        });
      }
    } catch (error) {
      console.error('Error updating service notification:', error);
    }
  }
}

export default PersistentSmsService;
