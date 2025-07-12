import AsyncStorage from '@react-native-async-storage/async-storage';

// Storage key for logs
const STORAGE_KEY = '@sms_to_api:app_logs';

// Log levels
export const LOG_LEVELS = {
  DEBUG: 'DEBUG',
  INFO: 'INFO',
  WARN: 'WARN',
  ERROR: 'ERROR',
  SUCCESS: 'SUCCESS',
};

// Log categories
export const LOG_CATEGORIES = {
  SMS: 'SMS',
  API: 'API',
  PERMISSIONS: 'PERMISSIONS',
  STORAGE: 'STORAGE',
  FILTERS: 'FILTERS',
  SYSTEM: 'SYSTEM',
  USER: 'USER',
};

/**
 * Logging Service for recording app activities
 * Professional implementation with categorized logging and storage
 */
export class LoggingService {
  static maxLogs = 1000; // Maximum number of logs to keep
  static logs = []; // In-memory cache for performance

  /**
   * Initialize logging service
   */
  static async initialize() {
    try {
      await this.loadLogs();
      this.log(LOG_LEVELS.INFO, LOG_CATEGORIES.SYSTEM, 'Logging service initialized');
    } catch (error) {
      console.error('Failed to initialize logging service:', error);
    }
  }

  /**
   * Add a log entry
   * @param {string} level - Log level (DEBUG, INFO, WARN, ERROR, SUCCESS)
   * @param {string} category - Log category (SMS, API, etc.)
   * @param {string} message - Log message
   * @param {Object} data - Additional data (optional)
   */
  static async log(level, category, message, data = null) {
    try {
      const logEntry = {
        id: this.generateLogId(),
        timestamp: new Date().toISOString(),
        level,
        category,
        message,
        data,
      };

      // Add to in-memory cache
      this.logs.unshift(logEntry);

      // Keep only the latest logs
      if (this.logs.length > this.maxLogs) {
        this.logs = this.logs.slice(0, this.maxLogs);
      }

      // Save to storage (async, don't wait)
      this.saveLogs();

      // Also log to console for development
      this.logToConsole(logEntry);

    } catch (error) {
      console.error('Failed to add log entry:', error);
    }
  }

  /**
   * Log to console with appropriate method
   * @param {Object} logEntry - Log entry object
   */
  static logToConsole(logEntry) {
    const logMessage = `[${logEntry.level}][${logEntry.category}] ${logEntry.message}`;
    
    switch (logEntry.level) {
      case LOG_LEVELS.DEBUG:
        console.debug(logMessage, logEntry.data);
        break;
      case LOG_LEVELS.INFO:
      case LOG_LEVELS.SUCCESS:
        console.log(logMessage, logEntry.data);
        break;
      case LOG_LEVELS.WARN:
        console.warn(logMessage, logEntry.data);
        break;
      case LOG_LEVELS.ERROR:
        console.error(logMessage, logEntry.data);
        break;
      default:
        console.log(logMessage, logEntry.data);
    }
  }

  /**
   * Generate unique log ID
   * @returns {string} Unique ID
   */
  static generateLogId() {
    return `log_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
  }

  /**
   * Load logs from storage
   */
  static async loadLogs() {
    try {
      const logsJson = await AsyncStorage.getItem(STORAGE_KEY);
      if (logsJson) {
        this.logs = JSON.parse(logsJson);
      }
    } catch (error) {
      console.error('Failed to load logs from storage:', error);
      this.logs = [];
    }
  }

  /**
   * Save logs to storage
   */
  static async saveLogs() {
    try {
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(this.logs));
    } catch (error) {
      console.error('Failed to save logs to storage:', error);
    }
  }

  /**
   * Get all logs
   * @returns {Array} Array of log entries
   */
  static getLogs() {
    return [...this.logs]; // Return copy to prevent mutation
  }

  /**
   * Get logs by level
   * @param {string} level - Log level to filter by
   * @returns {Array} Filtered logs
   */
  static getLogsByLevel(level) {
    return this.logs.filter(log => log.level === level);
  }

  /**
   * Get logs by category
   * @param {string} category - Category to filter by
   * @returns {Array} Filtered logs
   */
  static getLogsByCategory(category) {
    return this.logs.filter(log => log.category === category);
  }

  /**
   * Get logs from the last N hours
   * @param {number} hours - Number of hours to look back
   * @returns {Array} Recent logs
   */
  static getRecentLogs(hours = 24) {
    const cutoffTime = new Date(Date.now() - (hours * 60 * 60 * 1000));
    return this.logs.filter(log => new Date(log.timestamp) > cutoffTime);
  }

  /**
   * Clear all logs
   */
  static async clearLogs() {
    try {
      this.logs = [];
      await AsyncStorage.removeItem(STORAGE_KEY);
      this.log(LOG_LEVELS.INFO, LOG_CATEGORIES.SYSTEM, 'All logs cleared by user');
    } catch (error) {
      console.error('Failed to clear logs:', error);
    }
  }

  /**
   * Export logs as JSON string
   * @returns {string} JSON string of all logs
   */
  static exportLogs() {
    return JSON.stringify(this.logs, null, 2);
  }

  /**
   * Get logs summary
   * @returns {Object} Summary statistics
   */
  static getLogsSummary() {
    const total = this.logs.length;
    const byLevel = {};
    const byCategory = {};

    // Count by level
    Object.values(LOG_LEVELS).forEach(level => {
      byLevel[level] = this.logs.filter(log => log.level === level).length;
    });

    // Count by category
    Object.values(LOG_CATEGORIES).forEach(category => {
      byCategory[category] = this.logs.filter(log => log.category === category).length;
    });

    return {
      total,
      byLevel,
      byCategory,
      oldestLog: this.logs.length > 0 ? this.logs[this.logs.length - 1].timestamp : null,
      newestLog: this.logs.length > 0 ? this.logs[0].timestamp : null,
    };
  }

  // Convenience methods for different log levels
  static debug(category, message, data) {
    return this.log(LOG_LEVELS.DEBUG, category, message, data);
  }

  static info(category, message, data) {
    return this.log(LOG_LEVELS.INFO, category, message, data);
  }

  static warn(category, message, data) {
    return this.log(LOG_LEVELS.WARN, category, message, data);
  }

  static error(category, message, data) {
    return this.log(LOG_LEVELS.ERROR, category, message, data);
  }

  static success(category, message, data) {
    return this.log(LOG_LEVELS.SUCCESS, category, message, data);
  }
}

export default LoggingService;
