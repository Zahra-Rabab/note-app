import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;
  bool? _testSucceeded;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await ApiService.getBaseUrl();
    setState(() {
      _urlController.text = url;
      _loaded = true;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final (success, message) = await ApiService.testConnection(_urlController.text);
    setState(() {
      _isTesting = false;
      _testSucceeded = success;
      _testResult = message;
    });
  }

  Future<void> _save() async {
    await ApiService.setBaseUrl(_urlController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backend address saved.')),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest_outlined)),
            ],
            selected: {themeProvider.mode},
            onSelectionChanged: (selection) => themeProvider.setThemeMode(selection.first),
          ),
          const SizedBox(height: 32),

          Text('Backend server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "This is your PC's address on your Wi-Fi network. It changes "
            "sometimes — if fetching stops working, check this first.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!_loaded)
            const Center(child: CircularProgressIndicator())
          else
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://192.168.1.10:5000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                child: _isTesting
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Test Connection'),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _testSucceeded == true ? Icons.check_circle : Icons.error,
                  color: _testSucceeded == true ? Colors.green : Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_testResult!)),
              ],
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text('How to find your PC\'s current IP', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text(
            'On your PC, open PowerShell and run "ipconfig" — use the '
            'IPv4 Address under your Wi-Fi adapter, keep port :5000, and '
            'make sure "python app.py" is running before testing here.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
