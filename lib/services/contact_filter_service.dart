import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class ContactFilterService {
  // Check if a contact should be forwarded
  static Future<bool> shouldForwardMessage(String sender) async {
    final isUsingWhitelistMode = await isWhitelistMode();

    // Get the appropriate contact list based on mode
    final filteredContacts = isUsingWhitelistMode
        ? await getWhitelistContacts()
        : await getBlacklistContacts();

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

    if (isUsingWhitelistMode) {
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
