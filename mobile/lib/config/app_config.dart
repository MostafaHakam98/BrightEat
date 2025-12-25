import 'dart:io';

class AppConfig {
  // Backend server configuration
  // For production server (accessible from internet):
  static const String productionUrl = 'http://51.20.151.57:19992/api';
  
  // For Android emulator (use 10.0.2.2 to access host machine):
  static const String androidEmulatorUrl = 'http://10.0.2.2:19992/api';
  
  // For iOS simulator (use localhost):
  static const String iosSimulatorUrl = 'http://localhost:19992/api';
  
  // Get the appropriate URL based on platform
  static String get apiBaseUrl {
    // Check if running on Android emulator
    if (Platform.isAndroid) {
      // Try to detect if we're on emulator (this is a simple check)
      // For production, use the production URL
      // For emulator testing, you can manually change this to androidEmulatorUrl
      return productionUrl;
    } else if (Platform.isIOS) {
      // For iOS, check if simulator or device
      // Simulator can use localhost, device needs production URL
      return productionUrl;
    }
    // Default to production
    return productionUrl;
  }
  
  // You can manually override by uncommenting one of these:
  // static String get apiBaseUrl => androidEmulatorUrl;  // For Android emulator
  // static String get apiBaseUrl => iosSimulatorUrl;     // For iOS simulator
  // static String get apiBaseUrl => productionUrl;       // For production/physical device
}

