import 'package:flutter/material.dart';
import 'package:sms_to_api/storage/settings/api_endpoint.dart';
import 'package:sms_to_api/storage/settings/storage.dart';
import 'package:sms_to_api/storage/settings/type.dart';
import 'package:sms_to_api/service/api_service.dart';

class ApiEndpointsScreen extends StatefulWidget {
  const ApiEndpointsScreen({super.key});

  @override
  State<ApiEndpointsScreen> createState() => _ApiEndpointsScreenState();
}

class _ApiEndpointsScreenState extends State<ApiEndpointsScreen> {
  final Storage _storage = Storage();
  bool _isLoading = true;
  List<ApiEndpoint> _endpoints = [];
  final Map<String, bool?> _validationStatus = {}; // endpointId -> last result
  final Set<String> _validating = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _storage.load();
    if (!mounted) return;
    setState(() {
      _endpoints = List.of(s?.endpoints ?? []);
      _isLoading = false;
    });
  }

  Future<void> _save({Settings? base}) async {
    final existing = base ?? await _storage.load();
    final updated = Settings(
      endpoints: _endpoints,
      authHeaderName: existing?.authHeaderName ?? 'Authorization',
      phoneNumbers: existing?.phoneNumbers ?? const [],
    );
    await _storage.save(updated);
  }

  void _toggleActive(ApiEndpoint ep, bool active) async {
    setState(() {
      _endpoints = _endpoints
          .map((e) => e.id == ep.id ? e.copyWith(active: active) : e)
          .toList();
    });
    await _save();
  }

  void _remove(ApiEndpoint ep) async {
    setState(() {
      _endpoints.removeWhere((e) => e.id == ep.id);
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed ${ep.name}')));
    }
  }

  Future<void> _upsertDialog({ApiEndpoint? initial}) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final urlCtrl = TextEditingController(text: initial?.url ?? '');
    final keyCtrl = TextEditingController(text: initial?.apiKey ?? '');
    final headerCtrl =
        TextEditingController(text: initial?.authHeaderName ?? 'Authorization');
    bool obscured = true;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'Add Endpoint' : 'Edit Endpoint'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Friendly Name',
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter URL';
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null ||
                        !(uri.isScheme('http') || uri.isScheme('https'))) {
                      return 'Enter valid http(s) URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: headerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Auth Header Name',
                    prefixIcon: Icon(Icons.security),
                    helperText: 'Header to carry the API key',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter header name' : null,
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setSBState) => TextFormField(
                    controller: keyCtrl,
                    obscureText: obscured,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        onPressed: () => setSBState(() => obscured = !obscured),
                        icon: Icon(
                          obscured ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                      helperText: 'Kept secure locally',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter API key'
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final nowId =
                  initial?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString();
              final updated = ApiEndpoint(
                id: nowId,
                name: nameCtrl.text.trim(),
                url: urlCtrl.text.trim(),
                apiKey: keyCtrl.text.trim(),
                authHeaderName: headerCtrl.text.trim(),
                active: initial?.active ?? true,
              );
              setState(() {
                final idx = _endpoints.indexWhere((e) => e.id == nowId);
                if (idx >= 0) {
                  _endpoints[idx] = updated;
                } else {
                  _endpoints.add(updated);
                }
                _validationStatus[nowId] = null; // reset status after edit
              });
              await _save();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: Text(initial == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _validate(ApiEndpoint ep) async {
    setState(() {
      _validating.add(ep.id);
    });
    final settings = await _storage.load();
    final api = ApiService();
    final ok = await api.validateEndpoint(
      ep,
      fallbackHeaderName: settings?.authHeaderName,
    );
    if (!mounted) return;
    setState(() {
      _validationStatus[ep.id] = ok;
      _validating.remove(ep.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Validated ${ep.name}' : 'Validation failed for ${ep.name}',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _upsertDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _endpoints.isEmpty
                      ? Center(
                          child: Text(
                            'No endpoints configured. Tap + to add.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _endpoints.length,
                          itemBuilder: (context, index) {
                            final ep = _endpoints[index];
                            return Dismissible(
                              key: ValueKey('ep_${ep.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                color: Colors.red.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                              onDismissed: (_) => _remove(ep),
                              child: ListTile(
                                title: Text(ep.name),
                                subtitle: Text(
                                  '${ep.url}\nHeader: ${ep.authHeaderName}',
                                  maxLines: 2,
                                ),
                                leading: Switch(
                                  value: ep.active,
                                  onChanged: (v) => _toggleActive(ep, v),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_validating.contains(ep.id))
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else ...[
                                      Icon(
                                        _validationStatus[ep.id] == true
                                            ? Icons.cloud_done
                                            : _validationStatus[ep.id] == false
                                                ? Icons.cloud_off
                                                : Icons.help_outline,
                                        color: _validationStatus[ep.id] == true
                                            ? Colors.green
                                            : _validationStatus[ep.id] == false
                                                ? Colors.red
                                                : Colors.grey,
                                      ),
                                      IconButton(
                                        tooltip: 'Validate',
                                        icon: const Icon(Icons.check_circle),
                                        onPressed: () => _validate(ep),
                                      ),
                                    ],
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _upsertDialog(initial: ep),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
