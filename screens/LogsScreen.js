import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  Alert,
  Share,
  RefreshControl,
  StyleSheet,
  SafeAreaView,
  TextInput,
} from 'react-native';
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from '../services/LoggingService';

/**
 * Logs Screen Component
 * Displays and manages application logs with filtering and export capabilities
 */
const LogsScreen = () => {
  const [logs, setLogs] = useState([]);
  const [filteredLogs, setFilteredLogs] = useState([]);
  const [selectedLevel, setSelectedLevel] = useState('ALL');
  const [selectedCategory, setSelectedCategory] = useState('ALL');
  const [searchText, setSearchText] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const [summary, setSummary] = useState({});

  // Load logs on component mount
  useEffect(() => {
    loadLogs();
  }, []);

  // Filter logs when filters change
  useEffect(() => {
    filterLogs();
  }, [logs, selectedLevel, selectedCategory, searchText]);

  /**
   * Load logs from service
   */
  const loadLogs = useCallback(async () => {
    try {
      const allLogs = LoggingService.getLogs();
      const logsSummary = LoggingService.getLogsSummary();
      setLogs(allLogs);
      setSummary(logsSummary);
    } catch (error) {
      Alert.alert('Error', 'Failed to load logs: ' + error.message);
    }
  }, []);

  /**
   * Filter logs based on selected criteria
   */
  const filterLogs = useCallback(() => {
    let filtered = [...logs];

    // Filter by level
    if (selectedLevel !== 'ALL') {
      filtered = filtered.filter(log => log.level === selectedLevel);
    }

    // Filter by category
    if (selectedCategory !== 'ALL') {
      filtered = filtered.filter(log => log.category === selectedCategory);
    }

    // Filter by search text
    if (searchText.trim()) {
      const search = searchText.toLowerCase();
      filtered = filtered.filter(log => 
        log.message.toLowerCase().includes(search) ||
        log.category.toLowerCase().includes(search) ||
        log.level.toLowerCase().includes(search) ||
        (log.data && JSON.stringify(log.data).toLowerCase().includes(search))
      );
    }

    setFilteredLogs(filtered);
  }, [logs, selectedLevel, selectedCategory, searchText]);

  /**
   * Handle refresh
   */
  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadLogs();
    setRefreshing(false);
  }, [loadLogs]);

  /**
   * Clear all logs
   */
  const clearLogs = () => {
    Alert.alert(
      'Clear Logs',
      'Are you sure you want to clear all logs? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear',
          style: 'destructive',
          onPress: async () => {
            try {
              await LoggingService.clearLogs();
              await loadLogs();
              Alert.alert('Success', 'All logs have been cleared');
            } catch (error) {
              Alert.alert('Error', 'Failed to clear logs: ' + error.message);
            }
          },
        },
      ]
    );
  };

  /**
   * Export logs
   */
  const exportLogs = async () => {
    try {
      const logsData = LoggingService.exportLogs();
      await Share.share({
        message: logsData,
        title: 'SMS to API - Application Logs',
      });
    } catch (error) {
      Alert.alert('Error', 'Failed to export logs: ' + error.message);
    }
  };

  /**
   * Get log level color
   */
  const getLogLevelColor = (level) => {
    switch (level) {
      case LOG_LEVELS.ERROR:
        return '#FF6B6B';
      case LOG_LEVELS.WARN:
        return '#FFD93D';
      case LOG_LEVELS.SUCCESS:
        return '#6BCF7F';
      case LOG_LEVELS.INFO:
        return '#4DABF7';
      case LOG_LEVELS.DEBUG:
        return '#868E96';
      default:
        return '#868E96';
    }
  };

  /**
   * Format timestamp
   */
  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  /**
   * Render log item
   */
  const renderLogItem = ({ item }) => (
    <TouchableOpacity
      style={styles.logItem}
      onPress={() => {
        Alert.alert(
          'Log Details',
          `Level: ${item.level}\nCategory: ${item.category}\nTime: ${formatTimestamp(item.timestamp)}\nMessage: ${item.message}${item.data ? '\nData: ' + JSON.stringify(item.data, null, 2) : ''}`,
          [{ text: 'OK' }]
        );
      }}
    >
      <View style={styles.logHeader}>
        <View style={[styles.levelBadge, { backgroundColor: getLogLevelColor(item.level) }]}>
          <Text style={styles.levelText}>{item.level}</Text>
        </View>
        <Text style={styles.categoryText}>{item.category}</Text>
        <Text style={styles.timestampText}>{formatTimestamp(item.timestamp)}</Text>
      </View>
      <Text style={styles.messageText} numberOfLines={2}>
        {item.message}
      </Text>
      {item.data && (
        <Text style={styles.dataText} numberOfLines={1}>
          Data: {JSON.stringify(item.data)}
        </Text>
      )}
    </TouchableOpacity>
  );

  /**
   * Render filter button
   */
  const renderFilterButton = (title, value, selectedValue, onPress) => (
    <TouchableOpacity
      style={[
        styles.filterButton,
        selectedValue === value && styles.filterButtonActive
      ]}
      onPress={() => onPress(value)}
    >
      <Text style={[
        styles.filterButtonText,
        selectedValue === value && styles.filterButtonTextActive
      ]}>
        {title}
      </Text>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Application Logs</Text>
        <View style={styles.headerActions}>
          <TouchableOpacity style={styles.actionButton} onPress={exportLogs}>
            <Text style={styles.actionButtonText}>Export</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.actionButton, styles.clearButton]} onPress={clearLogs}>
            <Text style={[styles.actionButtonText, styles.clearButtonText]}>Clear</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Summary */}
      <View style={styles.summary}>
        <Text style={styles.summaryText}>
          Total: {summary.total || 0} | 
          Errors: {summary.byLevel?.[LOG_LEVELS.ERROR] || 0} | 
          Warnings: {summary.byLevel?.[LOG_LEVELS.WARN] || 0}
        </Text>
      </View>

      {/* Search */}
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search logs..."
          value={searchText}
          onChangeText={setSearchText}
          placeholderTextColor="#999"
        />
      </View>

      {/* Level Filter */}
      <View style={styles.filterContainer}>
        <Text style={styles.filterLabel}>Level:</Text>
        <View style={styles.filterButtons}>
          {renderFilterButton('ALL', 'ALL', selectedLevel, setSelectedLevel)}
          {Object.values(LOG_LEVELS).map(level => 
            renderFilterButton(level, level, selectedLevel, setSelectedLevel)
          )}
        </View>
      </View>

      {/* Category Filter */}
      <View style={styles.filterContainer}>
        <Text style={styles.filterLabel}>Category:</Text>
        <View style={styles.filterButtons}>
          {renderFilterButton('ALL', 'ALL', selectedCategory, setSelectedCategory)}
          {Object.values(LOG_CATEGORIES).map(category => 
            renderFilterButton(category, category, selectedCategory, setSelectedCategory)
          )}
        </View>
      </View>

      {/* Logs List */}
      <FlatList
        data={filteredLogs}
        renderItem={renderLogItem}
        keyExtractor={(item) => item.id}
        style={styles.logsList}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No logs found</Text>
            <Text style={styles.emptySubtext}>
              {searchText || selectedLevel !== 'ALL' || selectedCategory !== 'ALL'
                ? 'Try adjusting your filters'
                : 'Logs will appear here as you use the app'
              }
            </Text>
          </View>
        }
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  headerActions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#007AFF',
    borderRadius: 6,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  clearButton: {
    backgroundColor: '#FF3B30',
  },
  clearButtonText: {
    color: '#fff',
  },
  summary: {
    padding: 12,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  summaryText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  searchContainer: {
    padding: 12,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  searchInput: {
    backgroundColor: '#f8f8f8',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 16,
    color: '#333',
  },
  filterContainer: {
    padding: 12,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  filterLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
    marginBottom: 8,
  },
  filterButtons: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  filterButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#f0f0f0',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  filterButtonActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  filterButtonText: {
    fontSize: 12,
    color: '#666',
    fontWeight: '500',
  },
  filterButtonTextActive: {
    color: '#fff',
  },
  logsList: {
    flex: 1,
  },
  logItem: {
    backgroundColor: '#fff',
    marginHorizontal: 12,
    marginVertical: 4,
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  logHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
  },
  levelBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
    marginRight: 8,
  },
  levelText: {
    fontSize: 10,
    fontWeight: 'bold',
    color: '#fff',
  },
  categoryText: {
    fontSize: 12,
    fontWeight: '500',
    color: '#666',
    marginRight: 8,
  },
  timestampText: {
    fontSize: 11,
    color: '#999',
    marginLeft: 'auto',
  },
  messageText: {
    fontSize: 14,
    color: '#333',
    lineHeight: 18,
  },
  dataText: {
    fontSize: 12,
    color: '#666',
    fontStyle: 'italic',
    marginTop: 4,
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyText: {
    fontSize: 18,
    color: '#666',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
  },
});

export default LogsScreen;
