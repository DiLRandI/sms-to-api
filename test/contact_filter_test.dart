import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/contact_filter_service.dart';

void main() {
  group('ContactFilterService Tests', () {
    setUp(() async {
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('Whitelist Mode Tests', () {
      test('should forward message from whitelisted contact', () async {
        // Setup whitelist mode with a contact
        await ContactFilterService.setWhitelistMode(true);
        await ContactFilterService.addWhitelistContact('+941234567890');

        // Test: SMS from whitelisted contact should be forwarded
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          '+941234567890',
        );
        expect(shouldForward, true);
      });

      test('should NOT forward message from non-whitelisted contact', () async {
        // Setup whitelist mode with a contact
        await ContactFilterService.setWhitelistMode(true);
        await ContactFilterService.addWhitelistContact('+941234567890');

        // Test: SMS from non-whitelisted contact should NOT be forwarded
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          '+919876543210',
        );
        expect(shouldForward, false);
      });

      test(
        'should handle international number matching (with/without +)',
        () async {
          // Setup whitelist mode with contact including +
          await ContactFilterService.setWhitelistMode(true);
          await ContactFilterService.addWhitelistContact('+941234567890');

          // Test: SMS from same number without + should be forwarded
          final shouldForward1 =
              await ContactFilterService.shouldForwardMessage('941234567890');
          expect(shouldForward1, true);

          // Test: SMS from same number with + should be forwarded
          final shouldForward2 =
              await ContactFilterService.shouldForwardMessage('+941234567890');
          expect(shouldForward2, true);
        },
      );

      test('should handle bank names and short codes', () async {
        // Setup whitelist mode with bank name and short code
        await ContactFilterService.setWhitelistMode(true);
        await ContactFilterService.addWhitelistContact('HDFC');
        await ContactFilterService.addWhitelistContact('8899');

        // Test: SMS from bank should be forwarded
        final shouldForward1 = await ContactFilterService.shouldForwardMessage(
          'HDFC-BANK',
        );
        expect(shouldForward1, true);

        // Test: SMS from short code should be forwarded
        final shouldForward2 = await ContactFilterService.shouldForwardMessage(
          '8899',
        );
        expect(shouldForward2, true);

        // Test: SMS from non-whitelisted sender should NOT be forwarded
        final shouldForward3 = await ContactFilterService.shouldForwardMessage(
          'ICICI',
        );
        expect(shouldForward3, false);
      });
    });

    group('Blacklist Mode Tests', () {
      test('should NOT forward message from blacklisted contact', () async {
        // Setup blacklist mode with a contact
        await ContactFilterService.setWhitelistMode(false);
        await ContactFilterService.addBlacklistContact('+941234567890');

        // Test: SMS from blacklisted contact should NOT be forwarded
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          '+941234567890',
        );
        expect(shouldForward, false);
      });

      test('should forward message from non-blacklisted contact', () async {
        // Setup blacklist mode with a contact
        await ContactFilterService.setWhitelistMode(false);
        await ContactFilterService.addBlacklistContact('+941234567890');

        // Test: SMS from non-blacklisted contact should be forwarded
        final shouldForward = await ContactFilterService.shouldForwardMessage(
          '+919876543210',
        );
        expect(shouldForward, true);
      });

      test(
        'should handle international number matching in blacklist',
        () async {
          // Setup blacklist mode with contact including +
          await ContactFilterService.setWhitelistMode(false);
          await ContactFilterService.addBlacklistContact('+941234567890');

          // Test: SMS from same number without + should NOT be forwarded
          final shouldForward1 =
              await ContactFilterService.shouldForwardMessage('941234567890');
          expect(shouldForward1, false);

          // Test: SMS from different number should be forwarded
          final shouldForward2 =
              await ContactFilterService.shouldForwardMessage('+919876543210');
          expect(shouldForward2, true);
        },
      );
    });

    group('Contact Storage Tests', () {
      test('should preserve + symbol when storing contacts', () async {
        // Add contact with + symbol
        await ContactFilterService.addWhitelistContact('+941234567890');

        // Retrieve contacts and check if + is preserved
        final contacts = await ContactFilterService.getWhitelistContacts();
        expect(contacts, contains('+941234567890'));
        expect(contacts, isNot(contains('941234567890')));
      });

      test(
        'should not add duplicate contacts (normalized comparison)',
        () async {
          // Add same contact in different formats
          await ContactFilterService.addWhitelistContact('+94 123 456 7890');
          await ContactFilterService.addWhitelistContact('+941234567890');
          await ContactFilterService.addWhitelistContact('+94-123-456-7890');

          // Should only have one contact (the first one added)
          final contacts = await ContactFilterService.getWhitelistContacts();
          expect(contacts.length, 1);
          expect(contacts.first, '+94 123 456 7890');
        },
      );

      test('should remove contacts correctly', () async {
        // Add contact
        await ContactFilterService.addWhitelistContact('+941234567890');

        // Verify it was added
        var contacts = await ContactFilterService.getWhitelistContacts();
        expect(contacts, contains('+941234567890'));

        // Remove contact
        await ContactFilterService.removeWhitelistContact('+941234567890');

        // Verify it was removed
        contacts = await ContactFilterService.getWhitelistContacts();
        expect(contacts, isEmpty);
      });
    });

    group('Normalization Tests', () {
      test('should handle various phone number formats', () async {
        await ContactFilterService.setWhitelistMode(true);
        await ContactFilterService.addWhitelistContact('+94 (123) 456-7890');

        // All these formats should match
        final testFormats = [
          '+94 (123) 456-7890',
          '+941234567890',
          '941234567890',
          '+94-123-456-7890',
          '+94 123 456 7890',
        ];

        for (final format in testFormats) {
          final shouldForward = await ContactFilterService.shouldForwardMessage(
            format,
          );
          expect(shouldForward, true, reason: 'Failed for format: $format');
        }
      });
    });
  });
}
