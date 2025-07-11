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
      const response = await fetch(endpoint, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'User-Agent': 'SMS-to-API-App/1.0.0',
        },
        timeout: 10000, // 10 second timeout
      });

      return {
        success: response.ok,
        status: response.status,
        statusText: response.statusText,
        message: response.ok ? 'Connection successful' : `HTTP ${response.status}: ${response.statusText}`,
      };
    } catch (error) {
      return {
        success: false,
        status: 0,
        statusText: 'Connection Error',
        message: error.message || 'Failed to connect to API endpoint',
        error: error.name,
      };
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

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'User-Agent': 'SMS-to-API-App/1.0.0',
        },
        body: JSON.stringify(payload),
        timeout: 15000, // 15 second timeout
      });

      const responseData = await response.json().catch(() => ({}));

      return {
        success: response.ok,
        status: response.status,
        statusText: response.statusText,
        data: responseData,
        message: response.ok 
          ? 'SMS sent successfully' 
          : `Failed to send SMS: ${response.status} ${response.statusText}`,
      };
    } catch (error) {
      return {
        success: false,
        status: 0,
        statusText: 'Network Error',
        data: null,
        message: error.message || 'Failed to send SMS',
        error: error.name,
      };
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
