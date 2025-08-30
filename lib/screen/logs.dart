import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/log_service.dart';
import '../storage/logs/log_entry.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LogService _logService = LogService();
  List<LogEntry> _logs = [];
  String _selectedLevel = 'ALL';
  String _selectedTag = 'ALL';
  bool _isLoading = true;
  final List<String> _logLevels = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR'];
  List<String> _availableTags = ['ALL'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await _logService.getAllLogs();
      final tags = _extractUniqueTags(logs);

      setState(() {
        _logs = logs;
        _availableTags = ['ALL', ...tags];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading logs: $e')));
      }
    }
  }

  List<String> _extractUniqueTags(List<LogEntry> logs) {
    final tags = logs.map((log) => log.tag).toSet().toList();
    tags.sort();
    return tags;
  }

  List<LogEntry> _getFilteredLogs() {
    List<LogEntry> filteredLogs = _logs;

    if (_selectedLevel != 'ALL') {
      filteredLogs = filteredLogs
          .where((log) => log.level == _selectedLevel)
          .toList();
    }

    if (_selectedTag != 'ALL') {
      filteredLogs = filteredLogs
          .where((log) => log.tag == _selectedTag)
          .toList();
    }

    // Sort by timestamp descending (newest first)
    filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return filteredLogs;
  }

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'DEBUG':
        return Colors.blue;
      case 'INFO':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getLogLevelIcon(String level) {
    switch (level) {
      case 'DEBUG':
        return Icons.bug_report;
      case 'INFO':
        return Icons.info;
      case 'WARNING':
        return Icons.warning;
      case 'ERROR':
        return Icons.error;
      default:
        return Icons.circle;
    }
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getLogLevelIcon(log.level),
                color: _getLogLevelColor(log.level),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Log Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Level', log.level),
                _buildDetailRow('Tag', log.tag),
                _buildDetailRow('Timestamp', log.timestamp.toString()),
                _buildDetailRow('Message', log.message),
                if (log.stackTrace != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.stackTrace!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: log.toString()));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Logs'),
          content: const Text(
            'Are you sure you want to clear all logs? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _logService.clearAllLogs();
        await _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing logs: $e')));
        }
      }
    }
  }

  Future<void> _showLogStatistics() async {
    try {
      final stats = await _logService.getLogStatistics();

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Log Statistics'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Logs: ${stats['total']}'),
                  Text('Android Logs: ${stats['android_logs']}'),
                  Text('Flutter Logs: ${stats['flutter_logs']}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Log Sources:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...((stats['log_sources'] as List<dynamic>).map(
                    (source) => Text('• $source'),
                  )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting statistics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showLogStatistics,
            tooltip: 'Log Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh Logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear All Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _logLevels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Row(
                          children: [
                            if (level != 'ALL') ...[
                              Icon(
                                _getLogLevelIcon(level),
                                size: 16,
                                color: _getLogLevelColor(level),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(level),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTag,
                    decoration: const InputDecoration(
                      labelText: 'Tag',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _availableTags.map((tag) {
                      return DropdownMenuItem(value: tag, child: Text(tag));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTag = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Log Count and Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Showing ${filteredLogs.length} of ${_logs.length} logs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    child: filteredLogs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 80),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.article_outlined,
                                      size: 64,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No logs found',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Logs will appear here when the service runs',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: filteredLogs.length,
                            itemBuilder: (context, index) {
                              final log = filteredLogs[index];
                              final accent = _getLogLevelColor(log.level);
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: accent, width: 4),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      _getLogLevelIcon(log.level),
                                      color: accent,
                                      size: 20,
                                    ),
                                    title: Text(
                                      log.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: accent.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: accent.withOpacity(
                                                    0.3,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                log.level,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: accent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                log.tag,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          log.timestamp
                                              .toLocal()
                                              .toString()
                                              .split('.')
                                              .first,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showLogDetails(log),
                                    trailing: log.stackTrace != null
                                        ? const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
