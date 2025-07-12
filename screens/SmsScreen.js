import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import SmsService from '../services/SmsService';
import useApiSettings from '../hooks/useApiSettings';

const SmsScreen = () => {
  const [isListening, setIsListening] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSwitching, setIsSwitching] = useState(false);
  const { apiSettings, isConfigured } = useApiSettings();

  useEffect(() => {
    checkSmsStatus();
  }, []);

  const checkSmsStatus = async () => {
    setIsLoading(true);
    try {
      const status = await SmsService.testSmsSetup();
      setHasPermission(status.hasPermission);
      setIsListening(status.isListening);
    } catch (error) {
      console.error('Error checking SMS status:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleSmsListener = async (value) => {
    if (isSwitching) return;
    
    setIsSwitching(true);
    try {
      if (value) {
        const success = await SmsService.startListening();
        if (success) {
          setIsListening(true);
          setHasPermission(true);
        }
      } else {
        const success = SmsService.stopListening();
        if (success) {
          setIsListening(false);
        }
      }
    } catch (error) {
      console.error('Error toggling SMS listener:', error);
      Alert.alert('Error', 'Failed to toggle SMS listener');
    } finally {
      setIsSwitching(false);
    }
  };

  const requestPermissions = async () => {
    try {
      const granted = await SmsService.requestSmsPermissions();
      if (granted) {
        setHasPermission(true);
        Alert.alert('Success', 'SMS permissions granted successfully!');
      }
    } catch (error) {
      console.error('Error requesting permissions:', error);
      Alert.alert('Error', 'Failed to request SMS permissions');
    }
  };

  const testConfiguration = async () => {
    try {
      const status = await SmsService.testSmsSetup();
      
      let message = 'SMS Setup Status:\n\n';
      message += `✅ Platform: ${status.platform}\n`;
      message += `${status.hasPermission ? '✅' : '❌'} SMS Permission: ${status.hasPermission ? 'Granted' : 'Not granted'}\n`;
      message += `${status.hasApiConfig ? '✅' : '❌'} API Configuration: ${status.hasApiConfig ? 'Complete' : 'Missing'}\n`;
      message += `${status.isListening ? '✅' : '⏸️'} SMS Listener: ${status.isListening ? 'Active' : 'Inactive'}\n`;
      message += `\nOverall Status: ${status.ready ? '✅ Ready' : '❌ Not Ready'}`;

      Alert.alert('SMS Setup Status', message);
    } catch (error) {
      Alert.alert('Error', 'Failed to test SMS configuration');
    }
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
        <Text style={styles.loadingText}>Checking SMS status...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>SMS Listener</Text>
      <Text style={styles.subtitle}>
        Monitor and forward incoming SMS messages to your API
      </Text>

      {/* SMS Listener Status */}
      <View style={styles.section}>
        <View style={styles.statusHeader}>
          <Ionicons 
            name={isListening ? "radio" : "radio-outline"} 
            size={24} 
            color={isListening ? "#34C759" : "#666"} 
          />
          <Text style={styles.statusTitle}>
            SMS Listener {isListening ? "Active" : "Inactive"}
          </Text>
        </View>
        
        <View style={styles.switchContainer}>
          <Text style={styles.switchLabel}>
            {isListening ? "Stop listening for SMS" : "Start listening for SMS"}
          </Text>
          <Switch
            value={isListening}
            onValueChange={handleToggleSmsListener}
            disabled={isSwitching || !hasPermission || !isConfigured()}
            trackColor={{ false: "#ddd", true: "#007AFF" }}
            thumbColor={isListening ? "#fff" : "#f4f3f4"}
          />
        </View>

        {isSwitching && (
          <View style={styles.loadingRow}>
            <ActivityIndicator size="small" color="#007AFF" />
            <Text style={styles.loadingText}>Updating SMS listener...</Text>
          </View>
        )}
      </View>

      {/* Permissions Status */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Permissions</Text>
        
        <View style={styles.statusRow}>
          <View style={styles.statusLeft}>
            <Ionicons 
              name={hasPermission ? "checkmark-circle" : "alert-circle"} 
              size={20} 
              color={hasPermission ? "#34C759" : "#FF9500"} 
            />
            <Text style={styles.statusText}>
              SMS Permission {hasPermission ? "Granted" : "Required"}
            </Text>
          </View>
          
          {!hasPermission && (
            <TouchableOpacity style={styles.actionButton} onPress={requestPermissions}>
              <Text style={styles.actionButtonText}>Grant Permission</Text>
            </TouchableOpacity>
          )}
        </View>

        <Text style={styles.helpText}>
          SMS permission is required to receive incoming messages and forward them to your API.
        </Text>
      </View>

      {/* API Configuration Status */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>API Configuration</Text>
        
        <View style={styles.statusRow}>
          <View style={styles.statusLeft}>
            <Ionicons 
              name={isConfigured() ? "checkmark-circle" : "alert-circle"} 
              size={20} 
              color={isConfigured() ? "#34C759" : "#FF9500"} 
            />
            <Text style={styles.statusText}>
              API Settings {isConfigured() ? "Configured" : "Required"}
            </Text>
          </View>
        </View>

        {isConfigured() ? (
          <View style={styles.configDetails}>
            <Text style={styles.configLabel}>Endpoint:</Text>
            <Text style={styles.configValue} numberOfLines={2}>
              {apiSettings.endpoint}
            </Text>
            <Text style={styles.configLabel}>API Key:</Text>
            <Text style={styles.configValue}>
              {"*".repeat(Math.min(apiSettings.apiKey.length, 20))}
            </Text>
          </View>
        ) : (
          <Text style={styles.warningText}>
            Configure your API endpoint and key in Settings to enable SMS forwarding.
          </Text>
        )}
      </View>

      {/* Persistent Background Service */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>🚀 Enhanced Background Service</Text>
        <Text style={styles.subtitle2}>
          Keep SMS forwarding active even when app is completely closed
        </Text>
        
        <PersistentServiceCard 
          isConfigured={isConfigured()}
          hasPermission={hasPermission}
        />
      </View>

      {/* Actions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Actions</Text>
        
        <TouchableOpacity style={styles.testButton} onPress={testConfiguration}>
          <Ionicons name="checkmark-done" size={20} color="#007AFF" />
          <Text style={styles.testButtonText}>Test Configuration</Text>
        </TouchableOpacity>
      </View>

      {/* Information */}
      <View style={styles.infoSection}>
        <Ionicons name="information-circle" size={24} color="#007AFF" />
        <Text style={styles.infoText}>
          When SMS listening is active, all incoming text messages will be automatically 
          forwarded to your configured API endpoint. Your messages are processed locally 
          and only sent to your specified API.
        </Text>
      </View>
    </ScrollView>
  );
};

// Persistent Service Card Component
const PersistentServiceCard = ({ isConfigured, hasPermission }) => {
  const [persistentStatus, setPersistentStatus] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    checkPersistentStatus();
  }, []);

  const checkPersistentStatus = async () => {
    try {
      const status = await SmsService.getServiceStatus();
      setPersistentStatus(status.persistent);
    } catch (error) {
      console.error('Error checking persistent status:', error);
    }
  };

  const handleStartPersistent = async () => {
    setIsLoading(true);
    try {
      const success = await SmsService.startEnhancedService();
      if (success) {
        await checkPersistentStatus();
      }
    } catch (error) {
      console.error('Error starting enhanced service:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleStopPersistent = async () => {
    setIsLoading(true);
    try {
      const success = await SmsService.stopEnhancedService();
      if (success) {
        await checkPersistentStatus();
      }
    } catch (error) {
      console.error('Error stopping enhanced service:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const isDisabled = !isConfigured || !hasPermission || isLoading;
  const isRunning = persistentStatus?.isRunning || false;

  return (
    <View style={styles.persistentCard}>
      <View style={styles.persistentHeader}>
        <View style={styles.persistentIcon}>
          <Ionicons 
            name={isRunning ? "rocket" : "rocket-outline"} 
            size={20} 
            color={isRunning ? "#34C759" : "#666"} 
          />
        </View>
        <View style={styles.persistentInfo}>
          <Text style={styles.persistentTitle}>
            Enhanced Service {isRunning ? "ACTIVE" : "INACTIVE"}
          </Text>
          <Text style={styles.persistentDesc}>
            {isRunning 
              ? `Running since ${persistentStatus?.startedAt ? new Date(persistentStatus.startedAt).toLocaleTimeString() : 'unknown'}`
              : "Not running - SMS listening stops when app closes"
            }
          </Text>
        </View>
      </View>

      {persistentStatus && isRunning && (
        <View style={styles.persistentStats}>
          <View style={styles.statItem}>
            <Text style={styles.statLabel}>Processed</Text>
            <Text style={styles.statValue}>{persistentStatus.processedCount || 0}</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statLabel}>Queued</Text>
            <Text style={styles.statValue}>{persistentStatus.queuedCount || 0}</Text>
          </View>
        </View>
      )}

      <View style={styles.persistentActions}>
        {!isRunning ? (
          <TouchableOpacity
            style={[styles.persistentButton, styles.startButton, isDisabled && styles.disabledButton]}
            onPress={handleStartPersistent}
            disabled={isDisabled}
          >
            {isLoading ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <>
                <Ionicons name="play" size={16} color="#fff" />
                <Text style={styles.persistentButtonText}>Start Enhanced Service</Text>
              </>
            )}
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={[styles.persistentButton, styles.stopButton]}
            onPress={handleStopPersistent}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <>
                <Ionicons name="stop" size={16} color="#fff" />
                <Text style={styles.persistentButtonText}>Stop Enhanced Service</Text>
              </>
            )}
          </TouchableOpacity>
        )}

        <TouchableOpacity
          style={styles.refreshButton}
          onPress={checkPersistentStatus}
          disabled={isLoading}
        >
          <Ionicons name="refresh" size={16} color="#007AFF" />
        </TouchableOpacity>
      </View>

      {!isConfigured && (
        <Text style={styles.warningText}>
          ⚠️ Configure API settings first
        </Text>
      )}
      
      {!hasPermission && (
        <Text style={styles.warningText}>
          ⚠️ SMS permissions required
        </Text>
      )}

      <View style={styles.persistentFeatures}>
        <Text style={styles.featuresTitle}>✨ Enhanced Service Features:</Text>
        <Text style={styles.featureItem}>• Works with Expo managed workflow</Text>
        <Text style={styles.featureItem}>• Background task management with TaskManager</Text>
        <Text style={styles.featureItem}>• Automatic message queuing and retry</Text>
        <Text style={styles.featureItem}>• Enhanced reliability for monitoring</Text>
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
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#666',
    marginLeft: 10,
  },
  loadingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    textAlign: 'center',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 30,
  },
  section: {
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
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 15,
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 10,
  },
  switchLabel: {
    flex: 1,
    fontSize: 16,
    color: '#333',
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  statusLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  statusText: {
    fontSize: 16,
    color: '#333',
    marginLeft: 8,
  },
  actionButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  helpText: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
  warningText: {
    fontSize: 14,
    color: '#FF9500',
    fontStyle: 'italic',
  },
  configDetails: {
    marginTop: 10,
  },
  configLabel: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
    marginTop: 8,
  },
  configValue: {
    fontSize: 14,
    color: '#333',
    fontFamily: 'monospace',
    marginTop: 2,
  },
  testButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#E3F2FD',
    paddingVertical: 12,
    borderRadius: 8,
  },
  testButtonText: {
    color: '#007AFF',
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 8,
  },
  infoSection: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: '#E3F2FD',
    padding: 15,
    borderRadius: 10,
    marginBottom: 30,
  },
  infoText: {
    flex: 1,
    marginLeft: 10,
    fontSize: 14,
    color: '#1976D2',
    lineHeight: 20,
  },
  subtitle2: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
  },
  persistentCard: {
    backgroundColor: '#f9f9f9',
    borderRadius: 12,
    padding: 20,
    marginTop: 10,
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
  persistentHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 15,
  },
  persistentIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  persistentInfo: {
    flex: 1,
    marginLeft: 10,
  },
  persistentTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  persistentDesc: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  persistentStats: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 15,
    marginBottom: 15,
    justifyContent: 'space-around',
  },
  statItem: {
    alignItems: 'center',
  },
  statLabel: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#007AFF',
  },
  persistentActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  persistentButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    marginRight: 10,
  },
  startButton: {
    backgroundColor: '#34C759',
  },
  stopButton: {
    backgroundColor: '#FF3B30',
  },
  disabledButton: {
    backgroundColor: '#ccc',
  },
  persistentButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 8,
  },
  refreshButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#fff',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  persistentFeatures: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 15,
    marginTop: 10,
  },
  featuresTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  featureItem: {
    fontSize: 13,
    color: '#666',
    lineHeight: 18,
    marginBottom: 2,
  },
});

export default SmsScreen;
