import * as TaskManager from 'expo-task-manager';
import * as BackgroundFetch from 'expo-background-fetch';
import * as Notifications from 'expo-notifications';
import { Platform, AppState } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import SmsListener from '@ernestbies/react-native-android-sms-listener';
import ApiService from './ApiService';
import StorageService from './StorageService';
import ContactFilterService from './ContactFilterService';
import LoggingService, { LOG_CATEGORIES } from './LoggingService';

/**
 * Expo-Compatible Enhanced SMS Service
 * Uses Expo's background capabilities for improved reliability
 */
export class ExpoEnhancedSmsService {
  static isServiceRunning = false;
  static smsSubscription = null;
  static STORAGE_KEY = '@sms_to_api:enhanced_sms_state';
  static BACKGROUND_TASK_NAME = 'enhanced-sms-processing';
  static messageQueue = [];
  static processedMessages = new Set();
  static isTaskRegistered = false;

  /**
   * Initialize the enhanced SMS service
   */
  static async initialize() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Initializing Enhanced SMS Service');
      
      // Setup notifications
      await this.setupNotifications();
      
      // Register background task
      await this.registerBackgroundTask();
      
      // Check if service was previously running
      const savedState = await AsyncStorage.getItem(this.STORAGE_KEY);
      const wasRunning = savedState ? JSON.parse(savedState).isRunning : false;
      
      if (wasRunning) {
        await LoggingService.info(LOG_CATEGORIES.SMS, 'Enhanced SMS service was previously active, restoring');
        await this.startEnhancedService();
      }
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to initialize Enhanced SMS Service', { error: error.message });
      return false;
    }
  }

  /**
   * Setup notification channel
   */
  static async setupNotifications() {
    try {
      if (Platform.OS === 'android') {
        await Notifications.setNotificationChannelAsync('sms-enhanced', {
          name: 'SMS Enhanced Service',
          importance: Notifications.AndroidImportance.DEFAULT,
          vibrationPattern: [0, 250, 250, 250],
          lightColor: '#007AFF',
        });
      }
    } catch (error) {
      await LoggingService.warn(LOG_CATEGORIES.NOTIFICATIONS, 'Failed to setup notification channel', { error: error.message });
    }
  }

  /**
   * Register background task for SMS processing
   */
  static async registerBackgroundTask() {
    try {
      if (this.isTaskRegistered) {
        return true;
      }

      // Define the background task
      TaskManager.defineTask(this.BACKGROUND_TASK_NAME, async () => {
        try {
          await LoggingService.debug(LOG_CATEGORIES.SMS, 'Background task executing');
          
          // Process any queued SMS messages
          await this.processQueuedMessages();
          
          // Update notification with current status
          await this.updateStatusNotification();
          
          return BackgroundFetch.BackgroundFetchResult.NewData;
        } catch (error) {
          await LoggingService.error(LOG_CATEGORIES.SMS, 'Background task error', { error: error.message });
          return BackgroundFetch.BackgroundFetchResult.Failed;
        }
      });

      this.isTaskRegistered = true;
      await LoggingService.success(LOG_CATEGORIES.SMS, 'Background task registered');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to register background task', { error: error.message });
      return false;
    }
  }

  /**
   * Start the enhanced background service
   */
  static async startEnhancedService() {
    try {
      if (this.isServiceRunning) {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'Enhanced SMS service already running');
        return true;
      }

      // Check if we have API configuration
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        throw new Error('API configuration required before starting enhanced service');
      }

      // Start background fetch
      const backgroundStatus = await BackgroundFetch.getStatusAsync();
      if (backgroundStatus === BackgroundFetch.BackgroundFetchStatus.Available) {
        await BackgroundFetch.registerTaskAsync(this.BACKGROUND_TASK_NAME, {
          minimumInterval: 30, // 30 seconds minimum interval
          stopOnTerminate: false,
          startOnBoot: true,
        });
        
        await LoggingService.success(LOG_CATEGORIES.SMS, 'Background fetch registered');
      } else {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'Background fetch not available', { status: backgroundStatus });
      }

      // Start SMS listener with enhanced processing
      if (Platform.OS === 'android') {
        this.smsSubscription = SmsListener.addListener(async (message) => {
          await this.handleEnhancedSms(message, apiSettings);
        });
      }

      this.isServiceRunning = true;

      // Save state
      await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify({ 
        isRunning: true, 
        startedAt: new Date().toISOString() 
      }));

      await LoggingService.success(LOG_CATEGORIES.SMS, 'Enhanced SMS service started successfully');
      
      // Show notification to user
      await this.showServiceNotification(
        'Enhanced SMS Service Started', 
        'Improved reliability with background processing enabled'
      );
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to start enhanced SMS service', { error: error.message });
      this.isServiceRunning = false;
      throw error;
    }
  }

  /**
   * Stop the enhanced background service
   */
  static async stopEnhancedService() {
    try {
      // Unregister background fetch
      if (await TaskManager.isTaskRegisteredAsync(this.BACKGROUND_TASK_NAME)) {
        await BackgroundFetch.unregisterTaskAsync(this.BACKGROUND_TASK_NAME);
        await LoggingService.info(LOG_CATEGORIES.SMS, 'Background task unregistered');
      }

      // Stop SMS listener
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

      await LoggingService.info(LOG_CATEGORIES.SMS, 'Enhanced SMS service stopped');
      
      // Show notification to user
      await this.showServiceNotification(
        'Enhanced SMS Service Stopped', 
        'Background processing has been disabled'
      );
      
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error stopping enhanced SMS service', { error: error.message });
      return false;
    }
  }

  /**
   * Handle SMS with enhanced processing
   */
  static async handleEnhancedSms(message, apiSettings) {
    try {
      console.log('📨 SMS received with enhanced processing:', message.originatingAddress);
      
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
        await LoggingService.warn(LOG_CATEGORIES.FILTERS, 'SMS blocked by user filter (enhanced)', {
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
          processedWithEnhanced: true,
          serviceType: 'expo-enhanced',
        },
      };

      console.log('🔄 Forwarding SMS with enhanced service');

      // Try immediate sending
      const result = await ApiService.sendSms({
        endpoint: apiSettings.endpoint,
        apiKey: apiSettings.apiKey,
        to: smsData.from,
        message: smsData.message,
        additionalData: {
          originalMessage: smsData,
          direction: 'incoming',
          enhancedProcessed: true,
          serviceType: 'expo-enhanced',
        },
      });

      if (result.success) {
        console.log('✅ SMS forwarded successfully with enhanced service');
        this.processedMessages.add(messageId);
        
        await LoggingService.success(LOG_CATEGORIES.API, 'SMS forwarded with enhanced service', {
          messageId: smsData.messageId,
          from: smsData.from
        });

      } else {
        console.log('❌ Failed to forward SMS, adding to enhanced queue');
        
        // Add to queue for background retry
        this.messageQueue.push({
          ...smsData,
          attempts: 0,
          lastAttempt: new Date().toISOString(),
        });

        // Save queue to storage for persistence
        await AsyncStorage.setItem(`${this.STORAGE_KEY}_queue`, JSON.stringify(this.messageQueue));

        await LoggingService.warn(LOG_CATEGORIES.API, 'Enhanced SMS forwarding failed, queued for retry', {
          messageId: smsData.messageId,
          error: result.message
        });
      }

    } catch (error) {
      console.error('❌ Error processing SMS with enhanced service:', error);
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error processing SMS in enhanced service', { 
        error: error.message,
        phoneNumber: message?.originatingAddress 
      });
    }
  }

  /**
   * Process queued messages (called by background task)
   */
  static async processQueuedMessages() {
    try {
      // Load queue from storage
      const queueData = await AsyncStorage.getItem(`${this.STORAGE_KEY}_queue`);
      if (queueData) {
        this.messageQueue = JSON.parse(queueData);
      }

      if (this.messageQueue.length === 0) return;

      console.log(`🔄 Processing ${this.messageQueue.length} queued messages (enhanced)`);
      
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        console.log('⚠️ API settings missing, cannot process queue');
        return;
      }

      const messagesToRetry = [...this.messageQueue];
      this.messageQueue = [];

      for (const smsData of messagesToRetry) {
        try {
          if (smsData.attempts >= 3) {
            console.log(`⚠️ Message ${smsData.messageId} exceeded retry limit, dropping`);
            await LoggingService.warn(LOG_CATEGORIES.API, 'Message dropped after max retries (enhanced)', {
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
              processedByBackgroundTask: true,
            },
          });

          if (result.success) {
            console.log(`✅ Queued message ${smsData.messageId} sent successfully (enhanced)`);
            this.processedMessages.add(smsData.messageId);
            
            await LoggingService.success(LOG_CATEGORIES.API, 'Queued SMS sent successfully (enhanced)', {
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
            
            console.log(`⚠️ Message ${smsData.messageId} retry failed, re-queued (enhanced)`);
          }

        } catch (error) {
          console.error(`❌ Error retrying message ${smsData.messageId} (enhanced):`, error);
          
          // Re-queue with incremented attempt count
          this.messageQueue.push({
            ...smsData,
            attempts: smsData.attempts + 1,
            lastAttempt: new Date().toISOString(),
          });
        }
      }

      // Save updated queue
      await AsyncStorage.setItem(`${this.STORAGE_KEY}_queue`, JSON.stringify(this.messageQueue));

    } catch (error) {
      console.error('❌ Error processing message queue (enhanced):', error);
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error processing message queue', { error: error.message });
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
          channelId: 'sms-enhanced',
        },
        trigger: null,
      });
    } catch (error) {
      console.error('Error showing service notification:', error);
    }
  }

  /**
   * Update status notification
   */
  static async updateStatusNotification() {
    try {
      if (this.isServiceRunning) {
        const queueCount = this.messageQueue.length;
        const processedCount = this.processedMessages.size;
        
        await this.showServiceNotification(
          'Enhanced SMS Service Active',
          `Processed: ${processedCount}, Queued: ${queueCount}`
        );
      }
    } catch (error) {
      console.error('Error updating status notification:', error);
    }
  }

  /**
   * Get service status
   */
  static async getServiceStatus() {
    try {
      const savedState = await AsyncStorage.getItem(this.STORAGE_KEY);
      const state = savedState ? JSON.parse(savedState) : { isRunning: false };
      
      // Load queue count
      const queueData = await AsyncStorage.getItem(`${this.STORAGE_KEY}_queue`);
      const queueCount = queueData ? JSON.parse(queueData).length : 0;
      
      return {
        isRunning: this.isServiceRunning,
        processedCount: this.processedMessages.size,
        queuedCount: queueCount,
        startedAt: state.startedAt,
        serviceType: 'expo-enhanced',
        ...state,
      };
    } catch (error) {
      return { isRunning: false, error: error.message };
    }
  }

  /**
   * Check if background tasks are available
   */
  static async isBackgroundAvailable() {
    try {
      const status = await BackgroundFetch.getStatusAsync();
      return status === BackgroundFetch.BackgroundFetchStatus.Available;
    } catch (error) {
      return false;
    }
  }
}

export default ExpoEnhancedSmsService;
