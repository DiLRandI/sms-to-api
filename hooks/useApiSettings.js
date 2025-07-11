import { useState, useEffect } from 'react';
import StorageService from '../services/StorageService';

/**
 * Custom hook for managing API settings
 * @returns {Object} API settings state and methods
 */
export const useApiSettings = () => {
  const [apiSettings, setApiSettings] = useState({
    endpoint: '',
    apiKey: '',
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load settings on mount
  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      setIsLoading(true);
      setError(null);
      const settings = await StorageService.getApiSettings();
      setApiSettings(settings);
    } catch (err) {
      setError('Failed to load API settings');
      console.error('Error loading API settings:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const saveSettings = async (newSettings) => {
    try {
      setError(null);
      const success = await StorageService.saveApiSettings(newSettings);
      if (success) {
        setApiSettings(prev => ({ ...prev, ...newSettings }));
        return true;
      }
      throw new Error('Failed to save settings');
    } catch (err) {
      setError('Failed to save API settings');
      console.error('Error saving API settings:', err);
      return false;
    }
  };

  const clearSettings = async () => {
    try {
      setError(null);
      const success = await StorageService.clearApiSettings();
      if (success) {
        setApiSettings({ endpoint: '', apiKey: '' });
        return true;
      }
      throw new Error('Failed to clear settings');
    } catch (err) {
      setError('Failed to clear API settings');
      console.error('Error clearing API settings:', err);
      return false;
    }
  };

  const isConfigured = () => {
    return apiSettings.endpoint.trim() !== '' && apiSettings.apiKey.trim() !== '';
  };

  return {
    apiSettings,
    isLoading,
    error,
    loadSettings,
    saveSettings,
    clearSettings,
    isConfigured,
  };
};

export default useApiSettings;
