import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class ContactFilterService {
  static const String _allowedContactsKey = 'allowed_contacts';
  static const String _filterModeKey =
      'filter_mode'; // 'whitelist' or 'blacklist'

  // Get filter mode (whitelist or blacklist)
  static Future<String> getFilterMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_filterModeKey) ?? 'whitelist';
  }

  // Set filter mode
  static Future<void> setFilterMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterModeKey, mode);
  }

  // Get allowed/blocked contacts
  static Future<List<String>> getFilteredContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList(_allowedContactsKey) ?? [];
    return contactsJson;
  }

  // Add contact to filter list
  static Future<void> addContact(String contact) async {
    final contacts = await getFilteredContacts();
    if (!contacts.contains(contact)) {
      contacts.add(contact);
      await _saveContacts(contacts);
    }
  }

  // Remove contact from filter list
  static Future<void> removeContact(String contact) async {
    final contacts = await getFilteredContacts();
    contacts.remove(contact);
    await _saveContacts(contacts);
  }

  // Save contacts list
  static Future<void> _saveContacts(List<String> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedContactsKey, contacts);
  }

  // Check if a contact should be forwarded
  static Future<bool> shouldForwardMessage(String sender) async {
    final filterMode = await getFilterMode();
    final filteredContacts = await getFilteredContacts();

    // Normalize sender for comparison
    final normalizedSender = _normalizeContact(sender);

    // Check if sender matches any filtered contact
    bool isInFilterList = filteredContacts.any((contact) {
      final normalizedContact = _normalizeContact(contact);

      // For phone numbers, also check without the + prefix to handle international numbers
      final senderWithoutPlus = normalizedSender.startsWith('+')
          ? normalizedSender.substring(1)
          : normalizedSender;
      final contactWithoutPlus = normalizedContact.startsWith('+')
          ? normalizedContact.substring(1)
          : normalizedContact;

      // Check multiple matching conditions:
      // 1. Exact match
      // 2. One contains the other (for partial matches)
      // 3. Match without + prefix (for international numbers)
      return normalizedSender == normalizedContact ||
          normalizedSender.contains(normalizedContact) ||
          normalizedContact.contains(normalizedSender) ||
          senderWithoutPlus == contactWithoutPlus ||
          senderWithoutPlus.contains(contactWithoutPlus) ||
          contactWithoutPlus.contains(senderWithoutPlus);
    });

    if (filterMode == 'whitelist') {
      // Whitelist mode: only forward if in the list
      return isInFilterList;
    } else {
      // Blacklist mode: forward unless in the list
      return !isInFilterList;
    }
  }

  // Normalize contact for comparison (remove spaces, dashes, parentheses but keep + for international numbers)
  static String _normalizeContact(String contact) {
    return contact.replaceAll(RegExp(r'[\s\-\(\)]'), '').toLowerCase();
  }

  // Get unique senders from SMS history for suggestion
  static Future<List<String>> getUniqueSenders() async {
    try {
      final SmsQuery query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 200, // Get more messages to find unique senders
      );

      final Set<String> uniqueSenders = {};
      for (final message in messages) {
        if (message.address != null && message.address!.isNotEmpty) {
          uniqueSenders.add(message.address!);
        }
      }

      final List<String> sendersList = uniqueSenders.toList();
      sendersList.sort(); // Sort alphabetically
      return sendersList;
    } catch (e) {
      print('Error getting unique senders: $e');
      return [];
    }
  }

  // Clear all filtered contacts
  static Future<void> clearAllContacts() async {
    await _saveContacts([]);
  }

  // Filter mode management
  static Future<bool> isWhitelistMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('filter_is_whitelist') ?? true;
  }

  static Future<void> setWhitelistMode(bool isWhitelist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('filter_is_whitelist', isWhitelist);
  }

  // Whitelist contact management
  static Future<List<String>> getWhitelistContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('filter_whitelist') ?? [];
  }

  static Future<void> addWhitelistContact(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('filter_whitelist') ?? [];

    // Check if contact already exists (normalized comparison but store original)
    final normalizedNewContact = _normalizeContact(contact);
    final alreadyExists = contacts.any((existingContact) {
      return _normalizeContact(existingContact) == normalizedNewContact;
    });

    if (!alreadyExists) {
      contacts.add(contact); // Store the original contact with + if present
      await prefs.setStringList('filter_whitelist', contacts);
    }
  }

  static Future<void> removeWhitelistContact(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('filter_whitelist') ?? [];

    // Remove by exact match (to maintain the original format)
    contacts.remove(contact);
    await prefs.setStringList('filter_whitelist', contacts);
  }

  // Blacklist contact management
  static Future<List<String>> getBlacklistContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('filter_blacklist') ?? [];
  }

  static Future<void> addBlacklistContact(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('filter_blacklist') ?? [];

    // Check if contact already exists (normalized comparison but store original)
    final normalizedNewContact = _normalizeContact(contact);
    final alreadyExists = contacts.any((existingContact) {
      return _normalizeContact(existingContact) == normalizedNewContact;
    });

    if (!alreadyExists) {
      contacts.add(contact); // Store the original contact with + if present
      await prefs.setStringList('filter_blacklist', contacts);
    }
  }

  static Future<void> removeBlacklistContact(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('filter_blacklist') ?? [];

    // Remove by exact match (to maintain the original format)
    contacts.remove(contact);
    await prefs.setStringList('filter_blacklist', contacts);
  }
}
