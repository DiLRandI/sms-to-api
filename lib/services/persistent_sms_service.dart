import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'api_service.dart';
import 'contact_filter_service.dart';
import 'logging_service.dart';

class PersistentSmsService {
  static const String _lastProcessedTimestampKey = 'last_processed_timestamp';
  static const String _processedMessageIdsKey = 'processed_message_ids';
  static const String _serviceStateKey = 'sms_service_state';

  // Save service state to persistent storage
  static Future<void> saveServiceState({
    required DateTime lastProcessedTimestamp,
    required Set<String> processedMessageIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save timestamp
      await prefs.setInt(
        _lastProcessedTimestampKey,
        lastProcessedTimestamp.millisecondsSinceEpoch,
      );

      // Save processed IDs (limit to last 500 to prevent storage bloat)
      final idsList = processedMessageIds.toList();
      if (idsList.length > 500) {
        idsList.removeRange(0, idsList.length - 500);
      }
      await prefs.setStringList(_processedMessageIdsKey, idsList);

      // Save service metadata
      final serviceState = {
        'last_saved': DateTime.now().toIso8601String(),
        'message_count': idsList.length,
      };
      await prefs.setString(_serviceStateKey, json.encode(serviceState));
    } catch (e) {
      await LoggingService.error(
        'Failed to save SMS service state: $e',
        'Persistent state save failed',
      );
    }
  }

  // Load service state from persistent storage
  static Future<Map<String, dynamic>> loadServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load timestamp (default to 1 hour ago to avoid processing too many old messages)
      final timestampMs =
          prefs.getInt(_lastProcessedTimestampKey) ??
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch;
      final lastProcessedTimestamp = DateTime.fromMillisecondsSinceEpoch(
        timestampMs,
      );

      // Load processed IDs
      final processedIds = prefs.getStringList(_processedMessageIdsKey) ?? [];

      await LoggingService.info(
        'SMS service state loaded',
        'Last processed: ${lastProcessedTimestamp.toIso8601String()}, IDs: ${processedIds.length}',
      );

      return {
        'lastProcessedTimestamp': lastProcessedTimestamp,
        'processedMessageIds': processedIds.toSet(),
      };
    } catch (e) {
      await LoggingService.error(
        'Failed to load SMS service state: $e',
        'Using default state',
      );

      // Return default state
      return {
        'lastProcessedTimestamp': DateTime.now().subtract(
          const Duration(hours: 1),
        ),
        'processedMessageIds': <String>{},
      };
    }
  }

  // Check for new SMS with improved logic
  static Future<void> checkForNewSmsWithPersistence() async {
    try {
      // Load persistent state
      final state = await loadServiceState();
      DateTime lastProcessedTimestamp = state['lastProcessedTimestamp'];
      Set<String> processedMessageIds = state['processedMessageIds'];

      final SmsQuery query = SmsQuery();

      // Query more messages to ensure we don't miss any
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100, // Check more messages
      );

      // Find truly new messages
      final newMessages = messages.where((message) {
        if (message.date == null || message.id == null) return false;

        final messageTime = message.date!;
        final messageId = message.id.toString();

        // Message is new if:
        // 1. It's newer than our last processed timestamp
        // 2. AND we haven't processed this specific message ID
        final isNewerThanTimestamp = messageTime.isAfter(
          lastProcessedTimestamp,
        );
        final notProcessedBefore = !processedMessageIds.contains(messageId);

        return isNewerThanTimestamp && notProcessedBefore;
      }).toList();

      if (newMessages.isEmpty) {
        // Update timestamp even if no new messages to prevent reprocessing
        await saveServiceState(
          lastProcessedTimestamp: DateTime.now(),
          processedMessageIds: processedMessageIds,
        );
        return;
      }

      await LoggingService.info(
        'Found ${newMessages.length} new SMS messages',
        'Processing messages...',
      );

      final ApiService apiService = ApiService();
      int forwardedCount = 0;
      int filteredCount = 0;
      DateTime latestMessageTime = lastProcessedTimestamp;

      // Process each new message
      for (final message in newMessages) {
        try {
          final sender = message.address ?? 'Unknown';
          final messageBody = message.body ?? '';
          final messageTime = message.date!;
          final messageId = message.id.toString();

          // Update latest message time
          if (messageTime.isAfter(latestMessageTime)) {
            latestMessageTime = messageTime;
          }

          // Check contact filter
          final shouldForward = await ContactFilterService.shouldForwardMessage(
            sender,
          );

          if (!shouldForward) {
            filteredCount++;
            await LoggingService.info('SMS filtered out', 'Sender: $sender');
          } else {
            // Forward SMS to API
            final success = await apiService.forwardSms(
              sender: sender,
              message: messageBody,
              timestamp: messageTime,
            );

            if (success) {
              forwardedCount++;
              await LoggingService.success(
                'SMS forwarded successfully',
                'From: $sender',
              );
            } else {
              await LoggingService.error(
                'Failed to forward SMS',
                'Sender: $sender',
              );
            }
          }

          // Mark message as processed
          processedMessageIds.add(messageId);
        } catch (e) {
          await LoggingService.error(
            'Error processing individual SMS: $e',
            'Message from: ${message.address}',
          );
        }
      }

      // Save updated state
      await saveServiceState(
        lastProcessedTimestamp: latestMessageTime,
        processedMessageIds: processedMessageIds,
      );

      await LoggingService.success(
        'SMS processing completed',
        'Forwarded: $forwardedCount, Filtered: $filteredCount',
      );
    } catch (e) {
      await LoggingService.error(
        'SMS check failed: $e',
        'Error during message processing',
      );
    }
  }

  // Reset service state (useful for debugging or fresh starts)
  static Future<void> resetServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastProcessedTimestampKey);
      await prefs.remove(_processedMessageIdsKey);
      await prefs.remove(_serviceStateKey);

      await LoggingService.info(
        'SMS service state reset',
        'All persistent data cleared',
      );
    } catch (e) {
      await LoggingService.error(
        'Failed to reset SMS service state: $e',
        'State reset failed',
      );
    }
  }
}
