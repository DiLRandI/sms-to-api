import { useState, useEffect } from 'react';
import ContactFilterService from '../services/ContactFilterService';

/**
 * Custom hook for managing contact filter settings
 * @returns {Object} Contact filter state and methods
 */
export const useContactFilters = () => {
  const [filterSummary, setFilterSummary] = useState({
    filterMode: ContactFilterService.FILTER_MODES.ALL,
    allowedCount: 0,
    blockedCount: 0,
    allowedNumbers: [],
    blockedNumbers: [],
    isActive: false,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load filter settings on mount
  useEffect(() => {
    loadFilterSummary();
  }, []);

  const loadFilterSummary = async () => {
    try {
      setIsLoading(true);
      setError(null);
      const summary = await ContactFilterService.getFilterSummary();
      setFilterSummary(summary);
    } catch (err) {
      setError('Failed to load contact filter settings');
      console.error('Error loading filter summary:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const updateFilterMode = async (mode) => {
    try {
      setError(null);
      const success = await ContactFilterService.saveFilterMode(mode);
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to update filter mode');
    } catch (err) {
      setError('Failed to update filter mode');
      console.error('Error updating filter mode:', err);
      return false;
    }
  };

  const addAllowedNumber = async (phoneNumber) => {
    try {
      setError(null);
      const success = await ContactFilterService.addAllowedNumber(phoneNumber);
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to add allowed number');
    } catch (err) {
      setError('Failed to add allowed number');
      console.error('Error adding allowed number:', err);
      return false;
    }
  };

  const removeAllowedNumber = async (phoneNumber) => {
    try {
      setError(null);
      const success = await ContactFilterService.removeAllowedNumber(phoneNumber);
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to remove allowed number');
    } catch (err) {
      setError('Failed to remove allowed number');
      console.error('Error removing allowed number:', err);
      return false;
    }
  };

  const addBlockedNumber = async (phoneNumber) => {
    try {
      setError(null);
      const success = await ContactFilterService.addBlockedNumber(phoneNumber);
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to add blocked number');
    } catch (err) {
      setError('Failed to add blocked number');
      console.error('Error adding blocked number:', err);
      return false;
    }
  };

  const removeBlockedNumber = async (phoneNumber) => {
    try {
      setError(null);
      const success = await ContactFilterService.removeBlockedNumber(phoneNumber);
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to remove blocked number');
    } catch (err) {
      setError('Failed to remove blocked number');
      console.error('Error removing blocked number:', err);
      return false;
    }
  };

  const clearAllFilters = async () => {
    try {
      setError(null);
      const success = await ContactFilterService.clearAllFilters();
      if (success) {
        await loadFilterSummary(); // Refresh summary
        return true;
      }
      throw new Error('Failed to clear filters');
    } catch (err) {
      setError('Failed to clear filters');
      console.error('Error clearing filters:', err);
      return false;
    }
  };

  const shouldForwardSms = async (phoneNumber) => {
    try {
      return await ContactFilterService.shouldForwardSms(phoneNumber);
    } catch (err) {
      console.error('Error checking if SMS should be forwarded:', err);
      return true; // Default to forwarding on error
    }
  };

  const validatePhoneNumber = (phoneNumber) => {
    return ContactFilterService.validatePhoneNumber(phoneNumber);
  };

  const isFiltersConfigured = () => {
    return filterSummary.isActive && (
      (filterSummary.filterMode === ContactFilterService.FILTER_MODES.WHITELIST && filterSummary.allowedCount > 0) ||
      (filterSummary.filterMode === ContactFilterService.FILTER_MODES.BLACKLIST && filterSummary.blockedCount > 0) ||
      filterSummary.filterMode === ContactFilterService.FILTER_MODES.ALL
    );
  };

  return {
    // State
    filterSummary,
    isLoading,
    error,
    
    // Actions
    loadFilterSummary,
    updateFilterMode,
    addAllowedNumber,
    removeAllowedNumber,
    addBlockedNumber,
    removeBlockedNumber,
    clearAllFilters,
    shouldForwardSms,
    validatePhoneNumber,
    
    // Computed
    isFiltersConfigured,
    
    // Constants
    FILTER_MODES: ContactFilterService.FILTER_MODES,
  };
};

export default useContactFilters;
