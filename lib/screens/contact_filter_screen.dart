import 'package:flutter/material.dart';
import '../services/contact_filter_service.dart';

class ContactFilterScreen extends StatefulWidget {
  const ContactFilterScreen({super.key});

  @override
  State<ContactFilterScreen> createState() => _ContactFilterScreenState();
}

class _ContactFilterScreenState extends State<ContactFilterScreen> {
  final TextEditingController _contactController = TextEditingController();
  List<String> _whitelistContacts = [];
  List<String> _blacklistContacts = [];
  bool _isWhitelistMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final isWhitelist = await ContactFilterService.isWhitelistMode();
      final whitelist = await ContactFilterService.getWhitelistContacts();
      final blacklist = await ContactFilterService.getBlacklistContacts();

      setState(() {
        _isWhitelistMode = isWhitelist;
        _whitelistContacts = whitelist;
        _blacklistContacts = blacklist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load contact filter settings');
    }
  }

  Future<void> _toggleFilterMode(bool isWhitelist) async {
    try {
      await ContactFilterService.setWhitelistMode(isWhitelist);
      setState(() {
        _isWhitelistMode = isWhitelist;
      });
      _showSuccessSnackBar(
        'Switched to ${isWhitelist ? "Whitelist" : "Blacklist"} mode',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to change filter mode');
    }
  }

  Future<void> _addContact() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      _showErrorSnackBar('Please enter a contact number or text');
      return;
    }

    try {
      if (_isWhitelistMode) {
        await ContactFilterService.addWhitelistContact(contact);
        setState(() {
          _whitelistContacts.add(contact);
        });
      } else {
        await ContactFilterService.addBlacklistContact(contact);
        setState(() {
          _blacklistContacts.add(contact);
        });
      }

      _contactController.clear();
      _showSuccessSnackBar('Contact added successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to add contact');
    }
  }

  Future<void> _removeContact(String contact) async {
    try {
      if (_isWhitelistMode) {
        await ContactFilterService.removeWhitelistContact(contact);
        setState(() {
          _whitelistContacts.remove(contact);
        });
      } else {
        await ContactFilterService.removeBlacklistContact(contact);
        setState(() {
          _blacklistContacts.remove(contact);
        });
      }

      _showSuccessSnackBar('Contact removed successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to remove contact');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Filter'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Mode Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Mode',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Whitelist'),
                                  subtitle: const Text(
                                    'Only forward from selected contacts',
                                  ),
                                  value: true,
                                  groupValue: _isWhitelistMode,
                                  onChanged: (value) =>
                                      _toggleFilterMode(value!),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Blacklist'),
                                  subtitle: const Text(
                                    'Block selected contacts',
                                  ),
                                  value: false,
                                  groupValue: _isWhitelistMode,
                                  onChanged: (value) =>
                                      _toggleFilterMode(value!),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Add Contact Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Contact',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter phone numbers (e.g., +1234567890), short codes (e.g., 8899), or bank names (e.g., HDFC)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _contactController,
                                  decoration: const InputDecoration(
                                    hintText: 'Contact number or name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_add),
                                  ),
                                  onSubmitted: (_) => _addContact(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addContact,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contact List
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isWhitelistMode
                                      ? Icons.check_circle
                                      : Icons.block,
                                  color: _isWhitelistMode
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_isWhitelistMode ? "Whitelist" : "Blacklist"} Contacts',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  '${_isWhitelistMode ? _whitelistContacts.length : _blacklistContacts.length} contacts',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(child: _buildContactList()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactList() {
    final contacts = _isWhitelistMode ? _whitelistContacts : _blacklistContacts;

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_phone_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No contacts added yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add contacts to ${_isWhitelistMode ? "allow" : "block"} SMS forwarding',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _isWhitelistMode ? Colors.green : Colors.red,
              child: Icon(
                _isWhitelistMode ? Icons.check : Icons.block,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(contact),
            subtitle: Text(
              _isContactNumber(contact)
                  ? 'Phone number'
                  : _isShortCode(contact)
                  ? 'Short code'
                  : 'Bank/Service name',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteConfirmation(contact),
            ),
          ),
        );
      },
    );
  }

  bool _isContactNumber(String contact) {
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(contact);
  }

  bool _isShortCode(String contact) {
    return RegExp(r'^[0-9]{3,6}$').hasMatch(contact);
  }

  void _showDeleteConfirmation(String contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text(
          'Are you sure you want to remove "$contact" from the ${_isWhitelistMode ? "whitelist" : "blacklist"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeContact(contact);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
