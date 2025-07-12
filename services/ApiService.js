import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './LoggingService';

/**
 * API utility functions for SMS to API communication
 */
export class ApiService {
  /**
   * Test API connection
   * @param {string} endpoint - API endpoint URL
   * @param {string} apiKey - API key for authentication
   * @returns {Promise<Object>} Test result
   */
  static async testConnection(endpoint, apiKey) {
    try {
      await LoggingService.info(LOG_CATEGORIES.API, 'Testing API connection', { endpoint });
      
      const response = await fetch(endpoint, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'User-Agent': 'SMS-to-API-App/1.0.1',
        },
        timeout: 10000, // 10 second timeout
      });

      const result = {
        success: response.ok,
        status: response.status,
        statusText: response.statusText,
        message: response.ok ? 'Connection successful' : `HTTP ${response.status}: ${response.statusText}`,
      };

      if (response.ok) {
        await LoggingService.success(LOG_CATEGORIES.API, 'API connection test successful', result);
      } else {
        await LoggingService.warn(LOG_CATEGORIES.API, 'API connection test failed', result);
      }

      return result;
    } catch (error) {
      const errorResult = {
        success: false,
        status: 0,
        statusText: 'Connection Error',
        message: error.message || 'Failed to connect to API endpoint',
        error: error.name,
      };

      await LoggingService.error(LOG_CATEGORIES.API, 'API connection test error', errorResult);
      return errorResult;
    }
  }

  /**
   * Send SMS via API
   * @param {Object} params - SMS parameters
   * @param {string} params.endpoint - API endpoint
   * @param {string} params.apiKey - API key
   * @param {string} params.to - Recipient phone number
   * @param {string} params.message - SMS message content
   * @param {Object} params.additionalData - Any additional data to send
   * @returns {Promise<Object>} Send result
   */
  static async sendSms({ endpoint, apiKey, to, message, additionalData = {} }) {
    try {
      const payload = {
        to,
        message,
        timestamp: new Date().toISOString(),
        ...additionalData,
      };

      await LoggingService.debug(LOG_CATEGORIES.API, 'Sending SMS to API', {
        endpoint,
        to,
        messageLength: message.length,
        hasAdditionalData: Object.keys(additionalData).length > 0
      });

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'User-Agent': 'SMS-to-API-App/1.0.1',
        },
        body: JSON.stringify(payload),
        timeout: 15000, // 15 second timeout
      });

      const responseData = await response.json().catch(() => ({}));

      const result = {
        success: response.ok,
        status: response.status,
        statusText: response.statusText,
        data: responseData,
        message: response.ok 
          ? 'SMS sent successfully' 
          : `Failed to send SMS: ${response.status} ${response.statusText}`,
      };

      if (response.ok) {
        await LoggingService.success(LOG_CATEGORIES.API, 'SMS sent to API successfully', {
          to,
          status: response.status,
          responseData: Object.keys(responseData).length > 0 ? responseData : 'No response data'
        });
      } else {
        await LoggingService.error(LOG_CATEGORIES.API, 'Failed to send SMS to API', {
          to,
          status: response.status,
          statusText: response.statusText,
          responseData
        });
      }

      return result;
    } catch (error) {
      const errorResult = {
        success: false,
        status: 0,
        statusText: 'Network Error',
        data: null,
        message: error.message || 'Failed to send SMS',
        error: error.name,
      };

      await LoggingService.error(LOG_CATEGORIES.API, 'SMS send request failed', {
        to,
        error: error.message,
        errorName: error.name
      });

      return errorResult;
    }
  }

  /**
   * Validate API endpoint URL
   * @param {string} endpoint - URL to validate
   * @returns {Object} Validation result
   */
  static validateEndpoint(endpoint) {
    try {
      const url = new URL(endpoint);
      
      if (!['http:', 'https:'].includes(url.protocol)) {
        return {
          valid: false,
          message: 'URL must use HTTP or HTTPS protocol',
        };
      }

      if (!url.hostname) {
        return {
          valid: false,
          message: 'URL must have a valid hostname',
        };
      }

      return {
        valid: true,
        message: 'Valid URL',
        protocol: url.protocol,
        hostname: url.hostname,
        pathname: url.pathname,
      };
    } catch (error) {
      return {
        valid: false,
        message: 'Invalid URL format',
        error: error.message,
      };
    }
  }

  /**
   * Validate API key format
   * @param {string} apiKey - API key to validate
   * @returns {Object} Validation result
   */
  static validateApiKey(apiKey) {
    if (!apiKey || typeof apiKey !== 'string') {
      return {
        valid: false,
        message: 'API key is required',
      };
    }

    if (apiKey.trim().length < 10) {
      return {
        valid: false,
        message: 'API key appears to be too short',
      };
    }

    if (apiKey.includes(' ')) {
      return {
        valid: false,
        message: 'API key should not contain spaces',
      };
    }

    return {
      valid: true,
      message: 'API key format appears valid',
    };
  }
}

export default ApiService;
