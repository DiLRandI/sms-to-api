import 'package:flutter/material.dart';
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/type.dart';
import 'package:sms_to_api/screen/api_endpoints.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _SettingsForm(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  @override
  _SettingsFormState createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final _authHeaderController = TextEditingController();
  int _endpointsCount = 0;

  final Storage _storage = Storage();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _authHeaderController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _storage.load();
    if (settings != null) {
      setState(() {
        _authHeaderController.text = settings.authHeaderName;
        _endpointsCount = settings.endpoints.length;
      });
    } else {
      setState(() {
        _authHeaderController.text = 'Authorization';
        _endpointsCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _authHeaderController,
                      decoration: InputDecoration(
                        labelText: 'HTTP Header Name',
                        hintText: 'Authorization',
                        prefixIcon: const Icon(Icons.security),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        helperText: 'Header name for API authentication',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a header name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.cloud),
                      title: const Text('Manage API Endpoints'),
                      subtitle: Text('$_endpointsCount configured'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ApiEndpointsScreen(),
                          ),
                        );
                        await _loadSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    // Load existing settings to preserve endpoints and phone numbers
                    final existingSettings = await _storage.load();
                    var saved = await _storage.save(
                      Settings(
                        url: existingSettings?.url ?? '',
                        apiKey: existingSettings?.apiKey ?? '',
                        endpoints: existingSettings?.endpoints ?? const [],
                        authHeaderName: _authHeaderController.text,
                        phoneNumbers: existingSettings?.phoneNumbers ?? [],
                      ),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          saved
                              ? 'Settings saved successfully!'
                              : 'Failed to save settings.',
                        ),
                        backgroundColor: saved ? Colors.green : Colors.red,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error saving settings: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
