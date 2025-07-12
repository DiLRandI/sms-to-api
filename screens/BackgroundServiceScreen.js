import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  TouchableOpacity,
  Alert,
  ScrollView,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import BackgroundServiceManager from '../services/BackgroundServiceManager';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from '../services/LoggingService';

/**
 * Background Service Status Screen
 * Shows status and controls for background SMS processing
 */
const BackgroundServiceScreen = () => {
  const [serviceStatus, setServiceStatus] = useState({
    isRegistered: false,
    backgroundFetchStatus: 'unknown',
    taskName: '',
  });
  const [queueStatus, setQueueStatus] = useState({
    total: 0,
    pending: 0,
    processed: 0,
    failed: 0,
  });
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadStatus();
  }, []);

  const loadStatus = useCallback(async () => {
    try {
      const [service, queue] = await Promise.all([
        BackgroundServiceManager.getStatus(),
        BackgroundServiceManager.getQueueStatus(),
      ]);
      
      setServiceStatus(service);
      setQueueStatus(queue);
      
      await LoggingService.debug(LOG_CATEGORIES.SYSTEM, 'Background service status loaded', {
        serviceRegistered: service.isRegistered,
        queuePending: queue.pending
      });
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to load background service status', { error: error.message });
      Alert.alert('Error', 'Failed to load background service status');
    }
  }, []);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadStatus();
    setRefreshing(false);
  }, [loadStatus]);

  const reinitializeService = async () => {
    try {
      await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'User requested background service reinitialization');
      
      const result = await BackgroundServiceManager.initialize();
      
      if (result) {
        Alert.alert('Success', 'Background services reinitialized successfully');
        await LoggingService.success(LOG_CATEGORIES.SYSTEM, 'Background services reinitialized successfully');
      } else {
        Alert.alert('Failed', 'Failed to reinitialize background services');
        await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to reinitialize background services');
      }
      
      await loadStatus();
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Error reinitializing background services', { error: error.message });
      Alert.alert('Error', 'Error reinitializing background services: ' + error.message);
    }
  };

  const stopService = async () => {
    Alert.alert(
      'Stop Background Service',
      'Are you sure you want to stop background SMS processing? SMS will only be processed when the app is active.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Stop',
          style: 'destructive',
          onPress: async () => {
            try {
              await BackgroundServiceManager.stop();
              Alert.alert('Stopped', 'Background SMS processing has been stopped');
              await LoggingService.warn(LOG_CATEGORIES.SYSTEM, 'Background services stopped by user');
              await loadStatus();
            } catch (error) {
              Alert.alert('Error', 'Failed to stop background service: ' + error.message);
            }
          },
        },
      ]
    );
  };

  const clearQueue = async () => {
    Alert.alert(
      'Clear SMS Queue',
      'Are you sure you want to clear all pending SMS messages? This will remove both processed and unprocessed messages.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear',
          style: 'destructive',
          onPress: async () => {
            try {
              await BackgroundServiceManager.clearQueue();
              Alert.alert('Cleared', 'SMS queue has been cleared');
              await LoggingService.info(LOG_CATEGORIES.SMS, 'SMS queue cleared by user');
              await loadStatus();
            } catch (error) {
              Alert.alert('Error', 'Failed to clear queue: ' + error.message);
            }
          },
        },
      ]
    );
  };

  const processNow = async () => {
    try {
      await LoggingService.info(LOG_CATEGORIES.SMS, 'Manual SMS processing triggered by user');
      
      // Trigger immediate processing using the new force method
      const result = await BackgroundServiceManager.forceProcessPendingSms();
      
      if (result) {
        Alert.alert('Processing', 'Manual SMS processing triggered successfully. Check logs for results.');
        await LoggingService.success(LOG_CATEGORIES.SMS, 'Manual SMS processing completed successfully');
      } else {
        Alert.alert('Failed', 'Failed to trigger SMS processing. Check logs for details.');
        await LoggingService.error(LOG_CATEGORIES.SMS, 'Manual SMS processing failed');
      }
      
      // Refresh status after a short delay
      setTimeout(async () => {
        await loadStatus();
      }, 2000);
    } catch (error) {
      await LoggingService.error(LOG_CATEGORIES.SMS, 'Error in manual SMS processing', { error: error.message });
      Alert.alert('Error', 'Failed to process SMS: ' + error.message);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'available':
      case true:
        return '#4CAF50';
      case 'restricted':
      case 'denied':
      case false:
        return '#F44336';
      default:
        return '#FF9800';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'available':
      case true:
        return 'checkmark-circle';
      case 'restricted':
      case 'denied':
      case false:
        return 'close-circle';
      default:
        return 'warning';
    }
  };

  const renderStatusCard = (title, value, subtitle, icon) => (
    <View style={styles.statusCard}>
      <View style={styles.statusHeader}>
        <Ionicons name={icon} size={24} color={getStatusColor(value)} />
        <Text style={styles.statusTitle}>{title}</Text>
      </View>
      <Text style={[styles.statusValue, { color: getStatusColor(value) }]}>
        {typeof value === 'boolean' ? (value ? 'Active' : 'Inactive') : String(value)}
      </Text>
      {subtitle && <Text style={styles.statusSubtitle}>{subtitle}</Text>}
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        style={styles.scrollView}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Background SMS Processing</Text>
          <Text style={styles.subtitle}>
            Monitor and control background SMS forwarding service
          </Text>
        </View>

        {/* Service Status */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Service Status</Text>
          
          {renderStatusCard(
            'Background Task',
            serviceStatus.isRegistered,
            serviceStatus.isRegistered ? 'Registered and ready' : 'Not registered',
            getStatusIcon(serviceStatus.isRegistered)
          )}

          {renderStatusCard(
            'Background Fetch',
            serviceStatus.backgroundFetchStatus,
            'System background execution status',
            getStatusIcon(serviceStatus.backgroundFetchStatus === 'available')
          )}
        </View>

        {/* Queue Status */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>SMS Queue</Text>
          
          <View style={styles.queueContainer}>
            <View style={styles.queueItem}>
              <Text style={styles.queueNumber}>{queueStatus.total}</Text>
              <Text style={styles.queueLabel}>Total</Text>
            </View>
            <View style={styles.queueItem}>
              <Text style={[styles.queueNumber, { color: '#FF9800' }]}>{queueStatus.pending}</Text>
              <Text style={styles.queueLabel}>Pending</Text>
            </View>
            <View style={styles.queueItem}>
              <Text style={[styles.queueNumber, { color: '#4CAF50' }]}>{queueStatus.processed}</Text>
              <Text style={styles.queueLabel}>Processed</Text>
            </View>
            <View style={styles.queueItem}>
              <Text style={[styles.queueNumber, { color: '#F44336' }]}>{queueStatus.failed}</Text>
              <Text style={styles.queueLabel}>Failed</Text>
            </View>
          </View>
        </View>

        {/* Actions */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Actions</Text>
          
          <TouchableOpacity style={styles.actionButton} onPress={processNow}>
            <Ionicons name="play-circle" size={20} color="#fff" />
            <Text style={styles.actionButtonText}>Process Pending SMS Now</Text>
          </TouchableOpacity>

          <TouchableOpacity style={[styles.actionButton, styles.secondaryButton]} onPress={reinitializeService}>
            <Ionicons name="refresh-circle" size={20} color="#007AFF" />
            <Text style={[styles.actionButtonText, styles.secondaryButtonText]}>Reinitialize Service</Text>
          </TouchableOpacity>

          <TouchableOpacity style={[styles.actionButton, styles.warningButton]} onPress={clearQueue}>
            <Ionicons name="trash" size={20} color="#fff" />
            <Text style={styles.actionButtonText}>Clear SMS Queue</Text>
          </TouchableOpacity>

          <TouchableOpacity style={[styles.actionButton, styles.dangerButton]} onPress={stopService}>
            <Ionicons name="stop-circle" size={20} color="#fff" />
            <Text style={styles.actionButtonText}>Stop Background Service</Text>
          </TouchableOpacity>
        </View>

        {/* Information */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>How It Works</Text>
          <Text style={styles.infoText}>
            • Background service processes SMS even when app is closed{'\n'}
            • SMS are queued and processed automatically{'\n'}
            • Failed SMS are retried up to 3 times{'\n'}
            • Notifications show processing status{'\n'}
            • Service starts automatically when SMS listener is enabled
          </Text>
        </View>

        {/* Troubleshooting */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Troubleshooting</Text>
          <Text style={styles.infoText}>
            If background processing isn't working:{'\n'}
            • Ensure battery optimization is disabled for this app{'\n'}
            • Check that background app refresh is enabled{'\n'}
            • Verify notification permissions are granted{'\n'}
            • Try reinitializing the service{'\n'}
            • Check application logs for errors
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollView: {
    flex: 1,
  },
  header: {
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
  },
  section: {
    backgroundColor: '#fff',
    margin: 16,
    padding: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  statusCard: {
    backgroundColor: '#f8f9fa',
    padding: 12,
    borderRadius: 6,
    marginBottom: 8,
  },
  statusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  statusTitle: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
    marginLeft: 8,
  },
  statusValue: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  statusSubtitle: {
    fontSize: 12,
    color: '#666',
  },
  queueContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: '#f8f9fa',
    padding: 16,
    borderRadius: 6,
  },
  queueItem: {
    alignItems: 'center',
  },
  queueNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  queueLabel: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 6,
    marginBottom: 8,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 8,
  },
  secondaryButton: {
    backgroundColor: '#f0f0f0',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  secondaryButtonText: {
    color: '#007AFF',
  },
  warningButton: {
    backgroundColor: '#FF9800',
  },
  dangerButton: {
    backgroundColor: '#F44336',
  },
  infoText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
});

export default BackgroundServiceScreen;
