import AsyncStorage from '@react-native-async-storage/async-storage';

// Storage keys
const STORAGE_KEYS = {
  FILTER_MODE: '@sms_to_api:filter_mode',
  ALLOWED_NUMBERS: '@sms_to_api:allowed_numbers',
  BLOCKED_NUMBERS: '@sms_to_api:blocked_numbers',
};

/**
 * Contact Filter Service for managing SMS forwarding rules
 * Professional implementation for selective SMS forwarding
 */
export class ContactFilterService {
  /**
   * Filter modes available
   */
  static FILTER_MODES = {
    ALL: 'all', // Forward all SMS
    WHITELIST: 'whitelist', // Forward only from allowed numbers
    BLACKLIST: 'blacklist', // Forward all except blocked numbers
  };

  /**
   * Save filter mode
   * @param {string} mode - Filter mode (all, whitelist, blacklist)
   */
  static async saveFilterMode(mode) {
    try {
      if (!Object.values(this.FILTER_MODES).includes(mode)) {
        throw new Error('Invalid filter mode');
      }
      await AsyncStorage.setItem(STORAGE_KEYS.FILTER_MODE, mode);
      return true;
    } catch (error) {
      console.error('Error saving filter mode:', error);
      return false;
    }
  }

  /**
   * Get current filter mode
   * @returns {Promise<string>} Current filter mode
   */
  static async getFilterMode() {
    try {
      const mode = await AsyncStorage.getItem(STORAGE_KEYS.FILTER_MODE);
      return mode || this.FILTER_MODES.ALL;
    } catch (error) {
      console.error('Error getting filter mode:', error);
      return this.FILTER_MODES.ALL;
    }
  }

  /**
   * Add number to allowed list
   * @param {string} phoneNumber - Phone number to add
   */
  static async addAllowedNumber(phoneNumber) {
    try {
      const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
      const allowedNumbers = await this.getAllowedNumbers();
      
      if (!allowedNumbers.includes(normalizedNumber)) {
        allowedNumbers.push(normalizedNumber);
        await AsyncStorage.setItem(
          STORAGE_KEYS.ALLOWED_NUMBERS, 
          JSON.stringify(allowedNumbers)
        );
      }
      return true;
    } catch (error) {
      console.error('Error adding allowed number:', error);
      return false;
    }
  }

  /**
   * Remove number from allowed list
   * @param {string} phoneNumber - Phone number to remove
   */
  static async removeAllowedNumber(phoneNumber) {
    try {
      const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
      const allowedNumbers = await this.getAllowedNumbers();
      const updatedNumbers = allowedNumbers.filter(num => num !== normalizedNumber);
      
      await AsyncStorage.setItem(
        STORAGE_KEYS.ALLOWED_NUMBERS, 
        JSON.stringify(updatedNumbers)
      );
      return true;
    } catch (error) {
      console.error('Error removing allowed number:', error);
      return false;
    }
  }

  /**
   * Get all allowed numbers
   * @returns {Promise<Array<string>>} Array of allowed phone numbers
   */
  static async getAllowedNumbers() {
    try {
      const numbersJson = await AsyncStorage.getItem(STORAGE_KEYS.ALLOWED_NUMBERS);
      return numbersJson ? JSON.parse(numbersJson) : [];
    } catch (error) {
      console.error('Error getting allowed numbers:', error);
      return [];
    }
  }

  /**
   * Add number to blocked list
   * @param {string} phoneNumber - Phone number to add
   */
  static async addBlockedNumber(phoneNumber) {
    try {
      const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
      const blockedNumbers = await this.getBlockedNumbers();
      
      if (!blockedNumbers.includes(normalizedNumber)) {
        blockedNumbers.push(normalizedNumber);
        await AsyncStorage.setItem(
          STORAGE_KEYS.BLOCKED_NUMBERS, 
          JSON.stringify(blockedNumbers)
        );
      }
      return true;
    } catch (error) {
      console.error('Error adding blocked number:', error);
      return false;
    }
  }

  /**
   * Remove number from blocked list
   * @param {string} phoneNumber - Phone number to remove
   */
  static async removeBlockedNumber(phoneNumber) {
    try {
      const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
      const blockedNumbers = await this.getBlockedNumbers();
      const updatedNumbers = blockedNumbers.filter(num => num !== normalizedNumber);
      
      await AsyncStorage.setItem(
        STORAGE_KEYS.BLOCKED_NUMBERS, 
        JSON.stringify(updatedNumbers)
      );
      return true;
    } catch (error) {
      console.error('Error removing blocked number:', error);
      return false;
    }
  }

  /**
   * Get all blocked numbers
   * @returns {Promise<Array<string>>} Array of blocked phone numbers
   */
  static async getBlockedNumbers() {
    try {
      const numbersJson = await AsyncStorage.getItem(STORAGE_KEYS.BLOCKED_NUMBERS);
      return numbersJson ? JSON.parse(numbersJson) : [];
    } catch (error) {
      console.error('Error getting blocked numbers:', error);
      return [];
    }
  }

  /**
   * Check if SMS from a number should be forwarded
   * @param {string} phoneNumber - Phone number to check
   * @returns {Promise<boolean>} Whether to forward SMS from this number
   */
  static async shouldForwardSms(phoneNumber) {
    try {
      const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
      const filterMode = await this.getFilterMode();

      switch (filterMode) {
        case this.FILTER_MODES.ALL:
          return true;

        case this.FILTER_MODES.WHITELIST:
          const allowedNumbers = await this.getAllowedNumbers();
          return allowedNumbers.includes(normalizedNumber);

        case this.FILTER_MODES.BLACKLIST:
          const blockedNumbers = await this.getBlockedNumbers();
          return !blockedNumbers.includes(normalizedNumber);

        default:
          return true;
      }
    } catch (error) {
      console.error('Error checking if SMS should be forwarded:', error);
      return true; // Default to forwarding on error
    }
  }

  /**
   * Normalize phone number for consistent comparison
   * @param {string} phoneNumber - Raw phone number
   * @returns {string} Normalized phone number
   */
  static normalizePhoneNumber(phoneNumber) {
    if (!phoneNumber) return '';
    
    // Remove all non-digit characters except +
    let normalized = phoneNumber.replace(/[^\d+]/g, '');
    
    // If it starts with +, keep it
    if (normalized.startsWith('+')) {
      return normalized;
    }
    
    // If it's a long number without +, assume it includes country code
    if (normalized.length > 10) {
      return '+' + normalized;
    }
    
    // For shorter numbers, assume US (+1)
    if (normalized.length === 10) {
      return '+1' + normalized;
    }
    
    return normalized;
  }

  /**
   * Get filter configuration summary
   * @returns {Promise<Object>} Filter configuration summary
   */
  static async getFilterSummary() {
    try {
      const [filterMode, allowedNumbers, blockedNumbers] = await Promise.all([
        this.getFilterMode(),
        this.getAllowedNumbers(),
        this.getBlockedNumbers(),
      ]);

      return {
        filterMode,
        allowedCount: allowedNumbers.length,
        blockedCount: blockedNumbers.length,
        allowedNumbers,
        blockedNumbers,
        isActive: filterMode !== this.FILTER_MODES.ALL,
      };
    } catch (error) {
      console.error('Error getting filter summary:', error);
      return {
        filterMode: this.FILTER_MODES.ALL,
        allowedCount: 0,
        blockedCount: 0,
        allowedNumbers: [],
        blockedNumbers: [],
        isActive: false,
      };
    }
  }

  /**
   * Clear all filter settings
   */
  static async clearAllFilters() {
    try {
      await Promise.all([
        AsyncStorage.removeItem(STORAGE_KEYS.FILTER_MODE),
        AsyncStorage.removeItem(STORAGE_KEYS.ALLOWED_NUMBERS),
        AsyncStorage.removeItem(STORAGE_KEYS.BLOCKED_NUMBERS),
      ]);
      return true;
    } catch (error) {
      console.error('Error clearing filters:', error);
      return false;
    }
  }

  /**
   * Validate phone number format
   * @param {string} phoneNumber - Phone number to validate
   * @returns {Object} Validation result
   */
  static validatePhoneNumber(phoneNumber) {
    if (!phoneNumber || typeof phoneNumber !== 'string') {
      return {
        valid: false,
        message: 'Phone number is required',
      };
    }

    const normalized = this.normalizePhoneNumber(phoneNumber);
    
    if (normalized.length < 7) {
      return {
        valid: false,
        message: 'Phone number is too short',
      };
    }

    if (normalized.length > 17) {
      return {
        valid: false,
        message: 'Phone number is too long',
      };
    }

    return {
      valid: true,
      message: 'Valid phone number',
      normalized,
    };
  }
}

export default ContactFilterService;
