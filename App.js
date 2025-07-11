import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createDrawerNavigator } from '@react-navigation/drawer';
import { Ionicons } from '@expo/vector-icons';

// Import screens
import HomeScreen from './screens/HomeScreen';
import SettingsScreen from './screens/SettingsScreen';
import SmsScreen from './screens/SmsScreen';

// Import custom drawer content
import CustomDrawerContent from './components/CustomDrawerContent';

const Drawer = createDrawerNavigator();

export default function App() {
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
