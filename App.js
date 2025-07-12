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

// Import custom drawer content
import CustomDrawerContent from './components/CustomDrawerContent';

// Import logging service
import LoggingService, { LOG_LEVELS, LOG_CATEGORIES } from './services/LoggingService';

const Drawer = createDrawerNavigator();

export default function App() {
  // Initialize logging service when app starts
  useEffect(() => {
    const initializeApp = async () => {
      try {
        await LoggingService.initialize();
        await LoggingService.info(LOG_CATEGORIES.SYSTEM, 'SMS to API application started');
      } catch (error) {
        console.error('Failed to initialize logging service:', error);
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
