import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  TextInput,
  Modal,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import useContactFilters from '../hooks/useContactFilters';

const ContactFilterScreen = () => {
  const {
    filterSummary,
    isLoading,
    error,
    updateFilterMode,
    addAllowedNumber,
    removeAllowedNumber,
    addBlockedNumber,
    removeBlockedNumber,
    clearAllFilters: clearFilters,
    validatePhoneNumber,
    FILTER_MODES,
  } = useContactFilters();

  const [showAddModal, setShowAddModal] = useState(false);
  const [addModalType, setAddModalType] = useState('allowed'); // 'allowed' or 'blocked'
  const [newPhoneNumber, setNewPhoneNumber] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  const { filterMode, allowedNumbers, blockedNumbers } = filterSummary;

  const handleFilterModeChange = async (mode) => {
    setIsSaving(true);
    try {
      const success = await updateFilterMode(mode);
      if (!success) {
        Alert.alert('Error', 'Failed to update filter mode');
      }
    } catch (error) {
      console.error('Error updating filter mode:', error);
      Alert.alert('Error', 'Failed to update filter mode');
    } finally {
      setIsSaving(false);
    }
  };

  const openAddModal = (type) => {
    setAddModalType(type);
    setNewPhoneNumber('');
    setShowAddModal(true);
  };

  const handleAddNumber = async () => {
    if (!newPhoneNumber.trim()) {
      Alert.alert('Error', 'Please enter a phone number');
      return;
    }

    const validation = validatePhoneNumber(newPhoneNumber);
    if (!validation.valid) {
      Alert.alert('Invalid Phone Number', validation.message);
      return;
    }

    try {
      let success = false;
      if (addModalType === 'allowed') {
        success = await addAllowedNumber(newPhoneNumber);
      } else {
        success = await addBlockedNumber(newPhoneNumber);
      }

      if (success) {
        setShowAddModal(false);
        setNewPhoneNumber('');
        Alert.alert('Success', `Phone number added to ${addModalType} list`);
      } else {
        Alert.alert('Error', 'Failed to add phone number');
      }
    } catch (error) {
      console.error('Error adding phone number:', error);
      Alert.alert('Error', 'Failed to add phone number');
    }
  };

  const handleRemoveNumber = async (phoneNumber, type) => {
    Alert.alert(
      'Remove Number',
      `Are you sure you want to remove ${phoneNumber} from the ${type} list?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            try {
              let success = false;
              if (type === 'allowed') {
                success = await removeAllowedNumber(phoneNumber);
              } else {
                success = await removeBlockedNumber(phoneNumber);
              }

              if (!success) {
                Alert.alert('Error', 'Failed to remove phone number');
              }
            } catch (error) {
              console.error('Error removing phone number:', error);
              Alert.alert('Error', 'Failed to remove phone number');
            }
          },
        },
      ]
    );
  };

  const clearAllFilters = () => {
    Alert.alert(
      'Clear All Filters',
      'Are you sure you want to clear all filter settings? This will remove all allowed and blocked numbers.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All',
          style: 'destructive',
          onPress: async () => {
            try {
              const success = await clearFilters();
              if (success) {
                Alert.alert('Success', 'All filters cleared');
              } else {
                Alert.alert('Error', 'Failed to clear filters');
              }
            } catch (error) {
              console.error('Error clearing filters:', error);
              Alert.alert('Error', 'Failed to clear filters');
            }
          },
        },
      ]
    );
  };

  const renderPhoneNumber = ({ item, index }) => (
    <View style={styles.phoneNumberItem}>
      <View style={styles.phoneNumberContent}>
        <Text style={styles.phoneNumberText}>{item}</Text>
      </View>
      <TouchableOpacity
        style={styles.removeButton}
        onPress={() => handleRemoveNumber(item, addModalType === 'allowed' ? 'blocked' : 'allowed')}
      >
        <Ionicons name="trash-outline" size={20} color="#FF3B30" />
      </TouchableOpacity>
    </View>
  );

  const getFilterModeDescription = (mode) => {
    switch (mode) {
      case FILTER_MODES.ALL:
        return 'Forward SMS from all phone numbers';
      case FILTER_MODES.WHITELIST:
        return 'Forward SMS only from allowed numbers';
      case FILTER_MODES.BLACKLIST:
        return 'Forward SMS from all numbers except blocked ones';
      default:
        return '';
    }
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
        <Text style={styles.loadingText}>Loading filter settings...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Contact Filters</Text>
      <Text style={styles.subtitle}>
        Control which phone numbers should have their SMS forwarded to your API
      </Text>

      {/* Filter Mode Selection */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Filter Mode</Text>
        
        {Object.entries(FILTER_MODES).map(([key, mode]) => (
          <TouchableOpacity
            key={mode}
            style={[
              styles.filterModeOption,
              filterMode === mode && styles.filterModeSelected,
            ]}
            onPress={() => handleFilterModeChange(mode)}
            disabled={isSaving}
          >
            <View style={styles.filterModeContent}>
              <Ionicons
                name={filterMode === mode ? "radio-button-on" : "radio-button-off"}
                size={24}
                color={filterMode === mode ? "#007AFF" : "#666"}
              />
              <View style={styles.filterModeText}>
                <Text style={[
                  styles.filterModeTitle,
                  filterMode === mode && styles.filterModeSelectedText
                ]}>
                  {key.charAt(0) + key.slice(1).toLowerCase()}
                </Text>
                <Text style={styles.filterModeDescription}>
                  {getFilterModeDescription(mode)}
                </Text>
              </View>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      {/* Allowed Numbers Section */}
      {filterMode === FILTER_MODES.WHITELIST && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Allowed Numbers ({allowedNumbers.length})</Text>
            <TouchableOpacity
              style={styles.addButton}
              onPress={() => openAddModal('allowed')}
            >
              <Ionicons name="add" size={20} color="#007AFF" />
            </TouchableOpacity>
          </View>
          
          {allowedNumbers.length === 0 ? (
            <Text style={styles.emptyText}>
              No allowed numbers. Add numbers to start filtering SMS.
            </Text>
          ) : (
            <View style={styles.phoneNumbersList}>
              {allowedNumbers.map((number, index) => (
                <View key={number} style={styles.phoneNumberItem}>
                  <View style={styles.phoneNumberContent}>
                    <Ionicons name="checkmark-circle" size={20} color="#34C759" />
                    <Text style={styles.phoneNumberText}>{number}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.removeButton}
                    onPress={() => handleRemoveNumber(number, 'allowed')}
                  >
                    <Ionicons name="trash-outline" size={20} color="#FF3B30" />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* Blocked Numbers Section */}
      {filterMode === FILTER_MODES.BLACKLIST && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Blocked Numbers ({blockedNumbers.length})</Text>
            <TouchableOpacity
              style={styles.addButton}
              onPress={() => openAddModal('blocked')}
            >
              <Ionicons name="add" size={20} color="#007AFF" />
            </TouchableOpacity>
          </View>
          
          {blockedNumbers.length === 0 ? (
            <Text style={styles.emptyText}>
              No blocked numbers. Add numbers to block their SMS from being forwarded.
            </Text>
          ) : (
            <View style={styles.phoneNumbersList}>
              {blockedNumbers.map((number, index) => (
                <View key={number} style={styles.phoneNumberItem}>
                  <View style={styles.phoneNumberContent}>
                    <Ionicons name="close-circle" size={20} color="#FF3B30" />
                    <Text style={styles.phoneNumberText}>{number}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.removeButton}
                    onPress={() => handleRemoveNumber(number, 'blocked')}
                  >
                    <Ionicons name="trash-outline" size={20} color="#FF3B30" />
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* Actions */}
      <View style={styles.section}>
        <TouchableOpacity style={styles.clearButton} onPress={clearAllFilters}>
          <Ionicons name="trash-outline" size={20} color="#FF3B30" />
          <Text style={styles.clearButtonText}>Clear All Filters</Text>
        </TouchableOpacity>
      </View>

      {/* Add Number Modal */}
      <Modal
        visible={showAddModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowAddModal(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setShowAddModal(false)}>
              <Text style={styles.modalCancelButton}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>
              Add {addModalType === 'allowed' ? 'Allowed' : 'Blocked'} Number
            </Text>
            <TouchableOpacity onPress={handleAddNumber}>
              <Text style={styles.modalSaveButton}>Add</Text>
            </TouchableOpacity>
          </View>
          
          <View style={styles.modalContent}>
            <Text style={styles.modalDescription}>
              Enter a phone number to add to the {addModalType} list:
            </Text>
            
            <TextInput
              style={styles.modalInput}
              placeholder="e.g., +1234567890 or (123) 456-7890"
              value={newPhoneNumber}
              onChangeText={setNewPhoneNumber}
              keyboardType="phone-pad"
              autoFocus
            />
            
            <Text style={styles.modalHelp}>
              The number will be automatically formatted. You can include or exclude country codes.
            </Text>
          </View>
        </View>
      </Modal>
    </ScrollView>
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
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 15,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  addButton: {
    backgroundColor: '#E3F2FD',
    borderRadius: 20,
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
  },
  filterModeOption: {
    paddingVertical: 15,
    paddingHorizontal: 10,
    borderRadius: 8,
    marginBottom: 10,
  },
  filterModeSelected: {
    backgroundColor: '#E3F2FD',
  },
  filterModeContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  filterModeText: {
    marginLeft: 12,
    flex: 1,
  },
  filterModeTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
  },
  filterModeSelectedText: {
    color: '#007AFF',
    fontWeight: '600',
  },
  filterModeDescription: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  phoneNumbersList: {
    marginTop: 10,
  },
  phoneNumberItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 10,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  phoneNumberContent: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  phoneNumberText: {
    fontSize: 16,
    color: '#333',
    marginLeft: 10,
    fontFamily: 'monospace',
  },
  removeButton: {
    padding: 8,
  },
  emptyText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    fontStyle: 'italic',
    paddingVertical: 20,
  },
  clearButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
    paddingVertical: 15,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#FF3B30',
  },
  clearButtonText: {
    color: '#FF3B30',
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 8,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: '#fff',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  modalCancelButton: {
    fontSize: 16,
    color: '#666',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  modalSaveButton: {
    fontSize: 16,
    color: '#007AFF',
    fontWeight: '600',
  },
  modalContent: {
    padding: 20,
  },
  modalDescription: {
    fontSize: 16,
    color: '#333',
    marginBottom: 20,
  },
  modalInput: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 15,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#fff',
    marginBottom: 15,
  },
  modalHelp: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
});

export default ContactFilterScreen;
