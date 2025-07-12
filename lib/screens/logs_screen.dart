import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logging_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<AppLog> _logs = [];
  List<AppLog> _filteredLogs = [];
  String _selectedLevel = 'All';
  bool _isLoading = true;
  bool _autoRefresh = true;

  final List<String> _logLevels = [
    'All',
    'INFO',
    'SUCCESS',
    'WARNING',
    'ERROR',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();

    // Auto refresh every 5 seconds if enabled
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_autoRefresh && mounted) {
        _loadLogs();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await LoggingService.getAllLogs();
      setState(() {
        _logs = logs;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load logs: $e');
    }
  }

  void _applyFilter() {
    if (_selectedLevel == 'All') {
      _filteredLogs = List.from(_logs);
    } else {
      _filteredLogs = _logs
          .where((log) => log.level == _selectedLevel)
          .toList();
    }
    _filteredLogs.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    ); // Latest first
  }

  Future<void> _clearLogs() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Logs',
      'Are you sure you want to clear all logs? This action cannot be undone.',
    );

    if (confirmed) {
      try {
        await LoggingService.clearLogs();
        setState(() {
          _logs.clear();
          _filteredLogs.clear();
        });
        _showSuccessSnackBar('All logs cleared successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to clear logs: $e');
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logData = await LoggingService.exportLogs();
      await Clipboard.setData(ClipboardData(text: logData));
      _showSuccessSnackBar('Logs copied to clipboard');
    } catch (e) {
      _showErrorSnackBar('Failed to export logs: $e');
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
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

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'SUCCESS':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      case 'INFO':
      default:
        return Colors.blue;
    }
  }

  IconData _getLogLevelIcon(String level) {
    switch (level) {
      case 'SUCCESS':
        return Icons.check_circle;
      case 'WARNING':
        return Icons.warning;
      case 'ERROR':
        return Icons.error;
      case 'INFO':
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _autoRefresh = !_autoRefresh;
              });
              if (_autoRefresh) {
                _startAutoRefresh();
              }
            },
            tooltip: _autoRefresh ? 'Pause auto-refresh' : 'Start auto-refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear All Logs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter and Stats Section
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Filter Row
                      Row(
                        children: [
                          const Text(
                            'Filter: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 8.0,
                              children: _logLevels.map((level) {
                                return ChoiceChip(
                                  label: Text(level),
                                  selected: _selectedLevel == level,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedLevel = level;
                                        _applyFilter();
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stats Row
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Total',
                                _logs.length.toString(),
                                Colors.grey,
                              ),
                              _buildStatItem(
                                'Filtered',
                                _filteredLogs.length.toString(),
                                Colors.blue,
                              ),
                              _buildStatItem(
                                'Errors',
                                _logs
                                    .where((l) => l.level == 'ERROR')
                                    .length
                                    .toString(),
                                Colors.red,
                              ),
                              _buildStatItem(
                                'Success',
                                _logs
                                    .where((l) => l.level == 'SUCCESS')
                                    .length
                                    .toString(),
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Logs List
                Expanded(
                  child: _filteredLogs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = _filteredLogs[index];
                            return _buildLogItem(log);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _selectedLevel == 'All'
                ? 'No logs available'
                : 'No $_selectedLevel logs',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Application activity will appear here',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(AppLog log) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getLogLevelColor(log.level),
          radius: 16,
          child: Icon(
            _getLogLevelIcon(log.level),
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          log.message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.details != null && log.details!.isNotEmpty)
              Text(
                log.details!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getLogLevelColor(log.level).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.level,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getLogLevelColor(log.level),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(log.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (log.details != null && log.details!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                log.details!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
