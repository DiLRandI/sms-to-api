import * as TaskManager from 'expo-task-manager';
import * as BackgroundFetch from 'expo-background-fetch';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Import our services
import ApiService from './ApiService';
import StorageService from './StorageService';
import ContactFilterService from './ContactFilterService';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './LoggingService';

// Task name for background SMS processing
const BACKGROUND_SMS_TASK = 'background-sms-processing';
const SMS_QUEUE_KEY = '@sms_to_api:sms_queue';

/**
 * Background Service Manager
 * Handles SMS processing when the app is in background or closed
 */
export class BackgroundServiceManager {
  static isRegistered = false;
  static notificationChannel = 'sms-forwarding';

  /**
   * Initialize background services
   */
  static async initialize() {
    try {
      await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'Initializing background services');
      
      // Setup notifications
      await this.setupNotifications();
      
      // Register background task
      await this.registerBackgroundTask();
      
      // Start background fetch if not already started
      await this.startBackgroundFetch();
      
      await LoggingService.success(LOG_CATEGORIES.SYSTEM, 'Background services initialized successfully');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to initialize background services', { error: error.message });
      console.error('Failed to initialize background services:', error);
      return false;
    }
  }

  /**
   * Setup notification channel and permissions
   */
  static async setupNotifications() {
    try {
      // Request notification permissions
      const { status } = await Notifications.requestPermissionsAsync();
      if (status !== 'granted') {
        await LoggingService.warn(LOG_CATEGORIES.PERMISSIONS, 'Notification permissions not granted');
        return false;
      }

      // Set notification channel (Android)
      if (Platform.OS === 'android') {
        await Notifications.setNotificationChannelAsync(this.notificationChannel, {
          name: 'SMS Forwarding',
          description: 'Notifications for SMS forwarding service',
          importance: Notifications.AndroidImportance.HIGH,
          vibrationPattern: [0, 250, 250, 250],
          lightColor: '#007AFF',
          sound: true,
        });
      }

      // Configure notification behavior
      Notifications.setNotificationHandler({
        handleNotification: async () => ({
          shouldShowAlert: true,
          shouldPlaySound: true,
          shouldSetBadge: false,
        }),
      });

      await LoggingService.success(LOG_CATEGORIES.PERMISSIONS, 'Notification permissions and channel configured');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.PERMISSIONS, 'Failed to setup notifications', { error: error.message });
      return false;
    }
  }

  /**
   * Register the background task
   */
  static async registerBackgroundTask() {
    try {
      if (this.isRegistered) {
        await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'Background task already registered');
        return true;
      }

      // Define the background task
      TaskManager.defineTask(BACKGROUND_SMS_TASK, async ({ data, error }) => {
        if (error) {
          await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Background task error', { error: error.message });
          return;
        }

        try {
          await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'Background task executing');
          await this.processPendingSms();
        } catch (taskError) {
          await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Background task execution failed', { error: taskError.message });
        }
      });

      this.isRegistered = true;
      await LoggingService.success(LOG_CATEGORIES.SYSTEM, 'Background task registered successfully');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to register background task', { error: error.message });
      return false;
    }
  }

  /**
   * Start background fetch
   */
  static async startBackgroundFetch() {
    try {
      const status = await BackgroundFetch.getStatusAsync();
      
      if (status === BackgroundFetch.BackgroundFetchStatus.Available) {
        await BackgroundFetch.registerTaskAsync(BACKGROUND_SMS_TASK, {
          minimumInterval: 1000 * 60 * 1, // Check every minute (minimum allowed by most Android versions)
          stopOnTerminate: false,
          startOnBoot: true,
        });
        
        await LoggingService.success(LOG_CATEGORIES.SYSTEM, 'Background fetch registered successfully');
        return true;
      } else {
        await LoggingService.warn(LOG_CATEGORIES.SYSTEM, 'Background fetch not available', { status });
        return false;
      }
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to start background fetch', { error: error.message });
      return false;
    }
  }

  /**
   * Add SMS to background processing queue
   * This will be called by the SMS listener when a message is received
   */
  static async queueSmsForProcessing(message) {
    try {
      const smsData = {
        id: `sms_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
        originatingAddress: message.originatingAddress,
        body: message.body,
        timestamp: new Date().toISOString(),
        processed: false,
        retryCount: 0,
      };

      // Get existing queue
      const queueJson = await AsyncStorage.getItem(SMS_QUEUE_KEY);
      const queue = queueJson ? JSON.parse(queueJson) : [];

      // Add new SMS to queue
      queue.push(smsData);

      // Keep only last 100 SMS in queue to prevent storage bloat
      if (queue.length > 100) {
        queue.splice(0, queue.length - 100);
      }

      // Save updated queue
      await AsyncStorage.setItem(SMS_QUEUE_KEY, JSON.stringify(queue));

      await LoggingService.info(LOG_CATEGORIES.SMS, 'SMS queued for background processing', {
        smsId: smsData.id,
        from: smsData.originatingAddress,
        queueLength: queue.length
      });

      // Try to process immediately if app is active
      this.processPendingSms();

      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to queue SMS for processing', { error: error.message });
      return false;
    }
  }

  /**
   * Process pending SMS messages in the queue
   */
  static async processPendingSms() {
    try {
      // Get SMS queue
      const queueJson = await AsyncStorage.getItem(SMS_QUEUE_KEY);
      if (!queueJson) {
        return; // No pending SMS
      }

      const queue = JSON.parse(queueJson);
      const pendingSms = queue.filter(sms => !sms.processed);

      if (pendingSms.length === 0) {
        return; // No pending SMS to process
      }

      await LoggingService.info(LOG_CATEGORIES.SMS, 'Processing pending SMS in background', { count: pendingSms.length });

      // Get API settings
      const apiSettings = await StorageService.getApiSettings();
      if (!apiSettings.endpoint || !apiSettings.apiKey) {
        await LoggingService.warn(LOG_CATEGORIES.SMS, 'Cannot process SMS: API not configured');
        return;
      }

      let processedCount = 0;
      const maxRetries = 3;

      for (const sms of pendingSms) {
        try {
          // Check if should forward based on filters
          const shouldForward = await ContactFilterService.shouldForwardSms(sms.originatingAddress);
          
          if (!shouldForward) {
            await LoggingService.warn(LOG_CATEGORIES.FILTERS, 'SMS blocked by filter in background processing', {
              smsId: sms.id,
              from: sms.originatingAddress
            });
            sms.processed = true;
            continue;
          }

          // Prepare API payload
          const payload = {
            from: sms.originatingAddress,
            message: sms.body,
            timestamp: sms.timestamp,
            messageId: sms.id,
            deviceInfo: {
              platform: Platform.OS,
              appVersion: '1.1.0',
              processedInBackground: true,
            },
          };

          // Send to API
          const result = await ApiService.sendSms({
            endpoint: apiSettings.endpoint,
            apiKey: apiSettings.apiKey,
            to: payload.from,
            message: payload.message,
            additionalData: {
              originalMessage: payload,
              direction: 'incoming',
              backgroundProcessed: true,
            },
          });

          if (result.success) {
            sms.processed = true;
            processedCount++;
            
            await LoggingService.success(LOG_CATEGORIES.SMS, 'SMS forwarded successfully in background', {
              smsId: sms.id,
              from: sms.originatingAddress
            });

            // Send success notification
            await this.sendNotification(
              'SMS Forwarded',
              `Message from ${sms.originatingAddress} forwarded to API`,
              { smsId: sms.id }
            );
          } else {
            sms.retryCount = (sms.retryCount || 0) + 1;
            
            if (sms.retryCount >= maxRetries) {
              sms.processed = true; // Mark as processed to avoid infinite retries
              
              await LoggingService.error(LOG_CATEGORIES.SMS, 'SMS forwarding failed after max retries', {
                smsId: sms.id,
                from: sms.originatingAddress,
                retryCount: sms.retryCount,
                error: result.message
              });

              // Send failure notification
              await this.sendNotification(
                'SMS Forwarding Failed',
                `Failed to forward message from ${sms.originatingAddress} after ${maxRetries} attempts`,
                { smsId: sms.id, error: true }
              );
            } else {
              await LoggingService.warn(LOG_CATEGORIES.SMS, 'SMS forwarding failed, will retry', {
                smsId: sms.id,
                from: sms.originatingAddress,
                retryCount: sms.retryCount,
                error: result.message
              });
            }
          }
        } catch (error) {
          await LoggingService.error(LOG_CATEGORIES.SMS, 'Error processing SMS in background', {
            smsId: sms.id,
            error: error.message
          });
        }
      }

      // Save updated queue
      await AsyncStorage.setItem(SMS_QUEUE_KEY, JSON.stringify(queue));

      if (processedCount > 0) {
        await LoggingService.success(LOG_CATEGORIES.SMS, 'Background SMS processing completed', {
          processedCount,
          totalPending: pendingSms.length
        });
      }

    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to process pending SMS', { error: error.message });
    }
  }

  /**
   * Send a notification
   */
  static async sendNotification(title, body, data = {}) {
    try {
      await Notifications.scheduleNotificationAsync({
        content: {
          title,
          body,
          data,
          sound: true,
        },
        trigger: null, // Send immediately
      });
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to send notification', { error: error.message });
    }
  }

  /**
   * Stop background services
   */
  static async stop() {
    try {
      await BackgroundFetch.unregisterTaskAsync(BACKGROUND_SMS_TASK);
      await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'Background services stopped');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to stop background services', { error: error.message });
      return false;
    }
  }

  /**
   * Get background service status
   */
  static async getStatus() {
    try {
      const isRegistered = await TaskManager.isTaskRegisteredAsync(BACKGROUND_SMS_TASK);
      const backgroundFetchStatus = await BackgroundFetch.getStatusAsync();
      
      return {
        isRegistered,
        backgroundFetchStatus,
        taskName: BACKGROUND_SMS_TASK,
      };
    } catch (error) {
      return {
        isRegistered: false,
        backgroundFetchStatus: 'error',
        error: error.message,
      };
    }
  }

  /**
   * Clear SMS queue
   */
  static async clearQueue() {
    try {
      await AsyncStorage.removeItem(SMS_QUEUE_KEY);
      await LoggingService.info(LOG_CATEGORIES.SMS, 'SMS queue cleared');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Failed to clear SMS queue', { error: error.message });
      return false;
    }
  }

  /**
   * Get queue status
   */
  static async getQueueStatus() {
    try {
      const queueJson = await AsyncStorage.getItem(SMS_QUEUE_KEY);
      const queue = queueJson ? JSON.parse(queueJson) : [];
      
      return {
        total: queue.length,
        pending: queue.filter(sms => !sms.processed).length,
        processed: queue.filter(sms => sms.processed).length,
        failed: queue.filter(sms => sms.retryCount >= 3).length,
      };
    } catch (error) {
      return {
        total: 0,
        pending: 0,
        processed: 0,
        failed: 0,
        error: error.message,
      };
    }
  }
}

export default BackgroundServiceManager;
