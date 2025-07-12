import React, { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createDrawerNavigator } from '@react-navigation/drawer';
import { Ionicons } from '@expo/vector-icons';

// Import screens
import HomeScreen from './screens/HomeScreen';
import SettingsScreen from './screens/SettingsScreen';
import SmsScreen from './screens/SmsScreen';
import ContactFilterScreen from './screens/ContactFilterScreen';
import LogsScreen from './screens/LogsScreen';
import BackgroundServiceScreen from './screens/BackgroundServiceScreen';

// Import custom drawer content
import CustomDrawerContent from './components/CustomDrawerContent';

// Import logging service and background service manager
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './services/LoggingService';
import BackgroundServiceManager from './services/BackgroundServiceManager';

const Drawer = createDrawerNavigator();

export default function App() {
  // Initialize services when app starts
  useEffect(() => {
    const initializeApp = async () => {
      try {
        // Initialize logging service first
        await LoggingService.initialize();
        await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'SMS to API application started');
        
        // Initialize background services for SMS processing
        await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'Initializing background SMS processing services');
        const backgroundInitialized = await BackgroundServiceManager.initialize();
        
        if (backgroundInitialized) {
          await LoggingService.success(LOG_CATEGORIES.SYSTEM, 'Background SMS processing services initialized successfully');
        } else {
          await LoggingService.warn(LOG_CATEGORIES.SYSTEM, 'Background SMS processing services failed to initialize');
        }
        
      } catch (error) {
        console.error('Failed to initialize app services:', error);
        await LoggingService.error(LOG_CATEGORIES.SYSTEM, 'Failed to initialize app services', { error: error.message });
      }
    };

    initializeApp();
  }, []);

  return (
    <NavigationContainer>
      <StatusBar style="auto" />
      <Drawer.Navigator
        initialRouteName="Home"
        drawerContent={(props) => <CustomDrawerContent {...props} />}
        screenOptions={({ navigation }) => ({
          headerStyle: {
            backgroundColor: '#007AFF',
          },
          headerTintColor: '#fff',
          headerTitleStyle: {
            fontWeight: 'bold',
          },
          headerLeft: () => (
            <Ionicons
              name="menu"
              size={24}
              color="#fff"
              style={{ marginLeft: 15 }}
              onPress={() => navigation.toggleDrawer()}
            />
          ),
          drawerStyle: {
            backgroundColor: '#fff',
            width: 280,
          },
          swipeEnabled: true,
        })}
      >
        <Drawer.Screen 
          name="Home" 
          component={HomeScreen}
          options={{
            headerTitle: 'Home',
          }}
        />
        <Drawer.Screen 
          name="SMS" 
          component={SmsScreen}
          options={{
            headerTitle: 'SMS Listener',
          }}
        />
        <Drawer.Screen 
          name="Filters" 
          component={ContactFilterScreen}
          options={{
            headerTitle: 'Contact Filters',
          }}
        />
        <Drawer.Screen 
          name="Logs" 
          component={LogsScreen}
          options={{
            headerTitle: 'Application Logs',
          }}
        />
        <Drawer.Screen 
          name="BackgroundService" 
          component={BackgroundServiceScreen}
          options={{
            headerTitle: 'Background Service',
          }}
        />
        <Drawer.Screen 
          name="Settings" 
          component={SettingsScreen}
          options={{
            headerTitle: 'Settings',
          }}
        />
      </Drawer.Navigator>
    </NavigationContainer>
  );
}
