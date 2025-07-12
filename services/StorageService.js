import AsyncStorage from '@react-native-async-storage/async-storage';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './LoggingService';

// Storage keys
const STORAGE_KEYS = {
  API_ENDPOINT: '@sms_to_api:api_endpoint',
  API_KEY: '@sms_to_api:api_key',
};

/**
 * Storage service for API settings
 */
export class StorageService {
  /**
   * Save API endpoint
   * @param {string} endpoint - API endpoint URL
   */
  static async saveApiEndpoint(endpoint) {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.API_ENDPOINT, endpoint);
      await LoggingService.info(LOG_CATEGORIES.STORAGE, 'API endpoint saved successfully', { endpoint });
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.STORAGE, 'Failed to save API endpoint', { error: error.message });
      console.error('Error saving API endpoint:', error);
      return false;
    }
  }

  /**
   * Save API key
   * @param {string} apiKey - API key
   */
  static async saveApiKey(apiKey) {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.API_KEY, apiKey);
      await LoggingService.info(LOG_CATEGORIES.STORAGE, 'API key saved successfully');
      return true;
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.STORAGE, 'Failed to save API key', { error: error.message });
      console.error('Error saving API key:', error);
      return false;
    }
  }

  /**
   * Save both API settings at once
   * @param {Object} settings - Object containing endpoint and apiKey
   */
  static async saveApiSettings({ endpoint, apiKey }) {
    try {
      const promises = [];
      if (endpoint !== undefined) {
        promises.push(AsyncStorage.setItem(STORAGE_KEYS.API_ENDPOINT, endpoint));
      }
      if (apiKey !== undefined) {
        promises.push(AsyncStorage.setItem(STORAGE_KEYS.API_KEY, apiKey));
      }
      
      await Promise.all(promises);
      return true;
    } catch (error) {
      console.error('Error saving API settings:', error);
      return false;
    }
  }

  /**
   * Get API endpoint
   * @returns {Promise<string|null>}
   */
  static async getApiEndpoint() {
    try {
      return await AsyncStorage.getItem(STORAGE_KEYS.API_ENDPOINT);
    } catch (error) {
      console.error('Error getting API endpoint:', error);
      return null;
    }
  }

  /**
   * Get API key
   * @returns {Promise<string|null>}
   */
  static async getApiKey() {
    try {
      return await AsyncStorage.getItem(STORAGE_KEYS.API_KEY);
    } catch (error) {
      console.error('Error getting API key:', error);
      return null;
    }
  }

  /**
   * Get both API settings
   * @returns {Promise<Object>}
   */
  static async getApiSettings() {
    try {
      const [endpoint, apiKey] = await Promise.all([
        AsyncStorage.getItem(STORAGE_KEYS.API_ENDPOINT),
        AsyncStorage.getItem(STORAGE_KEYS.API_KEY),
      ]);
      
      return {
        endpoint: endpoint || '',
        apiKey: apiKey || '',
      };
    } catch (error) {
      console.error('Error getting API settings:', error);
      return {
        endpoint: '',
        apiKey: '',
      };
    }
  }

  /**
   * Clear all API settings
   */
  static async clearApiSettings() {
    try {
      await Promise.all([
        AsyncStorage.removeItem(STORAGE_KEYS.API_ENDPOINT),
        AsyncStorage.removeItem(STORAGE_KEYS.API_KEY),
      ]);
      return true;
    } catch (error) {
      console.error('Error clearing API settings:', error);
      return false;
    }
  }
}

export default StorageService;
