import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import useApiSettings from '../hooks/useApiSettings';
import SmsService from '../services/SmsService';
import ContactFilterService from '../services/ContactFilterService';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from '../services/LoggingService';

const HomeScreen = () => {
  const navigation = useNavigation();
  const { apiSettings, isLoading, isConfigured } = useApiSettings();
  const [smsStatus, setSmsStatus] = useState({
    isListening: false,
    hasPermission: false,
    ready: false,
  });
  const [filterStatus, setFilterStatus] = useState({
    filterMode: 'all',
    isActive: false,
    allowedCount: 0,
    blockedCount: 0,
  });

  // Check SMS status when screen is focused
  useFocusEffect(
    React.useCallback(() => {
      checkSmsStatus();
    }, [])
  );

  const checkSmsStatus = async () => {
    try {
      await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'Checking SMS and filter status from Home screen');
      
      const [smsStatusResult, filterSummary] = await Promise.all([
        SmsService.testSmsSetup(),
        ContactFilterService.getFilterSummary(),
      ]);
      
      setSmsStatus(smsStatusResult);
      setFilterStatus(filterSummary);

      await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'SMS and filter status updated', {
        smsReady: smsStatusResult.ready,
        isListening: smsStatusResult.isListening,
        filterMode: filterSummary.filterMode
      });
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Error checking SMS status', { error: error.message });
      console.error('Error checking SMS status:', error);
    }
  };

  const navigateToSettings = () => {
    navigation.navigate('Settings');
  };

  const navigateToSms = () => {
    navigation.navigate('SMS');
  };

  const navigateToFilters = () => {
    navigation.navigate('Filters');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>SMS to API</Text>
      <Text style={styles.subtitle}>Welcome to your SMS to API app!</Text>
      
      {/* API Configuration Status */}
      <View style={styles.statusContainer}>
        <View style={styles.statusHeader}>
          <Ionicons 
            name={isConfigured() ? "checkmark-circle" : "warning"} 
            size={24} 
            color={isConfigured() ? "#34C759" : "#FF9500"} 
          />
          <Text style={styles.statusTitle}>
            API Configuration {isConfigured() ? "Complete" : "Required"}
          </Text>
        </View>
        
        {isLoading ? (
          <Text style={styles.statusText}>Loading configuration...</Text>
        ) : isConfigured() ? (
          <View>
            <Text style={styles.statusText}>✅ API endpoint configured</Text>
            <Text style={styles.statusText}>✅ API key configured</Text>
            <Text style={styles.configuredEndpoint} numberOfLines={1}>
              Endpoint: {apiSettings.endpoint}
            </Text>
          </View>
        ) : (
          <View>
            <Text style={styles.warningText}>
              Configure your API settings to start sending SMS messages
            </Text>
            <TouchableOpacity style={styles.configureButton} onPress={navigateToSettings}>
              <Ionicons name="settings" size={20} color="#fff" />
              <Text style={styles.configureButtonText}>Configure Now</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* SMS Listener Status */}
      <View style={styles.statusContainer}>
        <View style={styles.statusHeader}>
          <Ionicons 
            name={smsStatus.isListening ? "radio" : "radio-outline"} 
            size={24} 
            color={smsStatus.isListening ? "#34C759" : "#666"} 
          />
          <Text style={styles.statusTitle}>
            SMS Listener {smsStatus.isListening ? "Active" : "Inactive"}
          </Text>
        </View>
        
        {smsStatus.isListening ? (
          <View>
            <Text style={styles.statusText}>✅ Listening for incoming SMS</Text>
            <Text style={styles.statusText}>✅ Forwarding to API endpoint</Text>
          </View>
        ) : (
          <View>
            <Text style={styles.warningText}>
              SMS listener is not active. Tap below to configure and start listening.
            </Text>
            <TouchableOpacity style={styles.configureButton} onPress={navigateToSms}>
              <Ionicons name="radio" size={20} color="#fff" />
              <Text style={styles.configureButtonText}>Start SMS Listener</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      {/* Contact Filter Status */}
      <View style={styles.statusContainer}>
        <View style={styles.statusHeader}>
          <Ionicons 
            name={filterStatus.isActive ? "filter" : "filter-outline"} 
            size={24} 
            color={filterStatus.isActive ? "#FF9500" : "#666"} 
          />
          <Text style={styles.statusTitle}>
            Contact Filters {filterStatus.isActive ? "Active" : "Disabled"}
          </Text>
        </View>
        
        {filterStatus.isActive ? (
          <View>
            <Text style={styles.statusText}>
              📋 Mode: {filterStatus.filterMode.charAt(0).toUpperCase() + filterStatus.filterMode.slice(1)}
            </Text>
            {filterStatus.filterMode === 'whitelist' && (
              <Text style={styles.statusText}>✅ {filterStatus.allowedCount} allowed numbers</Text>
            )}
            {filterStatus.filterMode === 'blacklist' && (
              <Text style={styles.statusText}>🚫 {filterStatus.blockedCount} blocked numbers</Text>
            )}
          </View>
        ) : (
          <View>
            <Text style={styles.statusText}>
              All incoming SMS will be forwarded to your API endpoint.
            </Text>
            <TouchableOpacity style={styles.configureButton} onPress={navigateToFilters}>
              <Ionicons name="filter" size={20} color="#fff" />
              <Text style={styles.configureButtonText}>Configure Filters</Text>
            </TouchableOpacity>
          </View>
        )}
      </View>

      <View style={styles.content}>
        <Text style={styles.description}>
          This app listens for incoming SMS messages and forwards them to your configured API endpoint in real-time. 
          Use the hamburger menu to configure settings and manage SMS listening.
        </Text>
        
        {isConfigured() && smsStatus.ready && (
          <View style={styles.readyContainer}>
            <Ionicons name="rocket" size={48} color="#007AFF" />
            <Text style={styles.readyText}>Ready to Forward SMS!</Text>
            <Text style={styles.readySubtext}>
              Your API is configured and SMS listener is ready
            </Text>
          </View>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    textAlign: 'center',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 18,
    color: '#666',
    textAlign: 'center',
    marginBottom: 30,
  },
  statusContainer: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 15,
  },
  statusTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginLeft: 10,
  },
  statusText: {
    fontSize: 16,
    color: '#666',
    marginBottom: 5,
  },
  configuredEndpoint: {
    fontSize: 14,
    color: '#007AFF',
    fontFamily: 'monospace',
    marginTop: 5,
  },
  warningText: {
    fontSize: 16,
    color: '#FF9500',
    marginBottom: 15,
    lineHeight: 22,
  },
  configureButton: {
    backgroundColor: '#007AFF',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  configureButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  description: {
    fontSize: 16,
    color: '#555',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 30,
  },
  readyContainer: {
    alignItems: 'center',
    backgroundColor: '#E3F2FD',
    padding: 30,
    borderRadius: 15,
    marginTop: 20,
  },
  readyText: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#007AFF',
    marginTop: 15,
    marginBottom: 8,
  },
  readySubtext: {
    fontSize: 16,
    color: '#1976D2',
    textAlign: 'center',
  },
});

export default HomeScreen;
