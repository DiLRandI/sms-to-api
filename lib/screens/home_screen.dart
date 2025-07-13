import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/app_state_provider.dart';
import '../services/logging_service.dart';
import '../services/persistent_sms_service.dart';
import 'config_screen.dart';
import 'contact_filter_screen.dart';
import 'logs_screen.dart';
import 'debug_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS to API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          provider.isServiceEnabled
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 48,
                          color: provider.isServiceEnabled
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          provider.statusMessage,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isServiceEnabled
                              ? 'Background SMS service is running independently'
                              : 'Enable the service to start the background SMS forwarder',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Control Button
                FilledButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () => _toggleService(context, provider),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          provider.isServiceEnabled
                              ? Icons.stop
                              : Icons.play_arrow,
                        ),
                  label: Text(
                    provider.isServiceEnabled
                        ? 'Stop Service'
                        : 'Start Service',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: provider.isServiceEnabled
                        ? Colors.red
                        : Colors.green,
                  ),
                ),

                const SizedBox(height: 20),

                // Statistics Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Messages Forwarded',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '${provider.messageCount}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: provider.messageCount > 0
                                  ? () => _resetCounter(context, provider)
                                  : null,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Configuration Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Configuration',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ConfigScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildConfigItem(
                          context,
                          'Permissions',
                          provider.hasPermissions ? 'Granted' : 'Not Granted',
                          provider.hasPermissions
                              ? Icons.check_circle
                              : Icons.error,
                          provider.hasPermissions ? Colors.green : Colors.red,
                        ),
                        _buildConfigItem(
                          context,
                          'API URL',
                          provider.apiUrl.isNotEmpty ? 'Configured' : 'Not Set',
                          provider.apiUrl.isNotEmpty
                              ? Icons.check_circle
                              : Icons.error,
                          provider.apiUrl.isNotEmpty
                              ? Colors.green
                              : Colors.red,
                        ),
                        _buildConfigItem(
                          context,
                          'API Key',
                          provider.apiKey.isNotEmpty ? 'Set' : 'Not Set',
                          Icons.info,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Actions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ContactFilterScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.filter_list),
                                label: const Text('Contact Filter'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FutureBuilder<List<AppLog>>(
                                future: LoggingService.getAllLogs(),
                                builder: (context, snapshot) {
                                  final logCount = snapshot.data?.length ?? 0;
                                  return ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LogsScreen(),
                                        ),
                                      );
                                    },
                                    icon: Badge(
                                      isLabelVisible: logCount > 0,
                                      label: Text('$logCount'),
                                      child: const Icon(Icons.article),
                                    ),
                                    label: const Text('View Logs'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Test SMS Processing Button
                        ElevatedButton.icon(
                          onPressed: () => _testSmsProcessing(context),
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Test SMS Processing'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Debug buttons row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _checkServiceStatus(context),
                                icon: const Icon(Icons.info, size: 16),
                                label: const Text('Check Status'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _manualSmsCheck(context),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Manual Check'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Advanced debug button
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DebugScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.build),
                          label: const Text('Advanced Debug'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Clear logs button
                        ElevatedButton.icon(
                          onPressed: () => _clearLogs(context),
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Logs'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.red.shade300,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Information Footer
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This app uses an Android background service that runs independently. The service will continue forwarding SMS even when the app is closed.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleService(
    BuildContext context,
    AppStateProvider provider,
  ) async {
    if (!provider.hasPermissions) {
      final granted = await provider.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permissions are required to forward messages'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (provider.apiUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please configure your API URL first'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConfigScreen()),
        );
      }
      return;
    }

    await provider.toggleService();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.isServiceEnabled
                ? 'Service started - SMS forwarding enabled'
                : 'Service stopped - SMS forwarding disabled',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _resetCounter(BuildContext context, AppStateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Counter'),
        content: const Text(
          'Are you sure you want to reset the message counter?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.resetMessageCount();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _testSmsProcessing(BuildContext context) async {
    try {
      await LoggingService.info(
        'Test SMS Processing initiated',
        'User pressed test button - calling Android service',
      );

      const platform = MethodChannel('sms_forwarding_service');
      await platform.invokeMethod('testSmsProcessing');

      await LoggingService.success(
        'Test SMS Processing method called',
        'Android service method invoked successfully',
      );

      // Also try the Dart service as a fallback
      await LoggingService.info(
        'Test SMS Processing - Dart fallback',
        'Also calling Dart SMS service for comparison',
      );

      await PersistentSmsService.checkForNewSmsWithPersistence();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test SMS processing triggered (both Android & Dart) - check logs for results',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      await LoggingService.error(
        'Failed to trigger test SMS processing',
        'Error: $e',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkServiceStatus(BuildContext context) async {
    try {
      const platform = MethodChannel('sms_forwarding_service');
      final isRunning = await platform.invokeMethod('isServiceRunning');

      await LoggingService.info(
        'Service status check',
        'Android service running: $isRunning',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRunning == true
                  ? 'Android background service is running'
                  : 'Android background service is NOT running',
            ),
            backgroundColor: isRunning == true ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      await LoggingService.error('Failed to check service status', 'Error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _manualSmsCheck(BuildContext context) async {
    try {
      await LoggingService.info(
        'Manual SMS check triggered',
        'Checking for new SMS messages manually',
      );

      // Call the Dart persistent SMS service directly
      await PersistentSmsService.checkForNewSmsWithPersistence();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Manual SMS check completed - check logs for results',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      await LoggingService.error(
        'Failed to perform manual SMS check',
        'Error: $e',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manual check failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
          'Are you sure you want to clear all logs? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await LoggingService.clearLogs();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All logs cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear logs: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
