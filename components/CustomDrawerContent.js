import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { DrawerContentScrollView } from '@react-navigation/drawer';
import { Ionicons } from '@expo/vector-icons';

const CustomDrawerContent = ({ navigation, state }) => {
  const drawerItems = [
    {
      name: 'Home',
      routeName: 'Home',
      icon: 'home-outline',
    },
    {
      name: 'SMS Listener',
      routeName: 'SMS',
      icon: 'chatbubbles-outline',
    },
    {
      name: 'Contact Filters',
      routeName: 'Filters',
      icon: 'filter-outline',
    },
    {
      name: 'Application Logs',
      routeName: 'Logs',
      icon: 'document-text-outline',
    },
    {
      name: 'Settings',
      routeName: 'Settings',
      icon: 'settings-outline',
    },
  ];

  return (
    <DrawerContentScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.appName}>SMS to API</Text>
        <Text style={styles.appVersion}>v1.3.0</Text>
      </View>
      
      <View style={styles.menuItems}>
        {drawerItems.map((item, index) => {
          const isActive = state.index === index;
          
          return (
            <TouchableOpacity
              key={item.routeName}
              style={[styles.menuItem, isActive && styles.activeMenuItem]}
              onPress={() => navigation.navigate(item.routeName)}
            >
              <Ionicons
                name={item.icon}
                size={24}
                color={isActive ? '#007AFF' : '#666'}
                style={styles.menuIcon}
              />
              <Text style={[styles.menuText, isActive && styles.activeMenuText]}>
                {item.name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </DrawerContentScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    paddingHorizontal: 20,
    paddingVertical: 30,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  appName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 5,
  },
  appVersion: {
    fontSize: 14,
    color: '#666',
  },
  menuItems: {
    paddingTop: 20,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 15,
    marginHorizontal: 10,
    borderRadius: 8,
  },
  activeMenuItem: {
    backgroundColor: '#E3F2FD',
  },
  menuIcon: {
    marginRight: 15,
  },
  menuText: {
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
  },
  activeMenuText: {
    color: '#007AFF',
    fontWeight: '600',
  },
});

export default CustomDrawerContent;
