import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import 'config_screen.dart';

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
                              ? 'SMS messages will be automatically forwarded to your API'
                              : 'Enable the service to start forwarding SMS messages',
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
                            'This app runs in the background and forwards SMS to your configured API endpoint.',
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
}
