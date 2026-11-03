import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WifiPasswordGuideApp());
}

class WifiPasswordGuideApp extends StatelessWidget {
  const WifiPasswordGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wi-Fi Password Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Google blue-ish
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const GuideHomePage(),
    );
  }
}

class GuideHomePage extends StatefulWidget {
  const GuideHomePage({super.key});

  @override
  State<GuideHomePage> createState() => _GuideHomePageState();
}

class _GuideHomePageState extends State<GuideHomePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final TextEditingController _networkNameController = TextEditingController();
  String _lastNetworkName = '';

  final List<String> _stepTitles = [
    'Open Command Prompt',
    'List Wi-Fi Profiles',
    'Reveal Password',
    'Find the Password',
  ];

  @override
  void initState() {
    super.initState();
    _loadLastNetworkName();
  }

  Future<void> _loadLastNetworkName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_network_name') ?? '';
    setState(() {
      _lastNetworkName = saved;
      _networkNameController.text = saved;
    });
  }

  Future<void> _saveNetworkName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_network_name', name);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _revealCommand {
    final name = _networkNameController.text.trim();
    if (name.isEmpty) {
      return 'netsh wlan show profile name="NetworkName" key=clear';
    }
    // Keep quotes if the name contains spaces
    final quotedName = name.contains(' ') ? '"$name"' : name;
    return 'netsh wlan show profile name=$quotedName key=clear';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _networkNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Password Guide'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentStep + 1} of 4',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  _stepTitles[_currentStep],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),

          // Steps content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _buildStep1(isDark),
                _buildStep2(isDark),
                _buildStep3(isDark),
                _buildStep4(isDark),
              ],
            ),
          ),

          // Navigation buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _currentStep < 3
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      child: Text(_currentStep < 3 ? 'Next' : 'Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Step 1: Open Command Prompt or Terminal'),
          const SizedBox(height: 16),
          _infoCard(
            isDark,
            children: [
              const Text(
                '1. Press the Windows key on your keyboard.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. Type  cmd  or  terminal',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                '3. Right-click Command Prompt (or Windows Terminal) and select:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Run as administrator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Running as administrator is recommended so you can see profiles saved by other users or the system.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(bool isDark) {
    const command = 'netsh wlan show profiles';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Step 2: List All Saved Wi-Fi Profiles'),
          const SizedBox(height: 16),
          const Text(
            'Type the following command and press Enter to see a list of all Wi-Fi networks saved on your PC:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _commandCard(command, isDark),
          const SizedBox(height: 20),
          _infoCard(
            isDark,
            children: [
              const Text(
                'You will see a list under "All User Profile" and/or "User Profile".',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Note the exact name of the network you want the password for.',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Step 3: Reveal the Password for a Specific Network'),
          const SizedBox(height: 16),
          const Text(
            'Find the exact name of the network under "All User Profile" or "User Profile", then run the command below.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Text(
            'Wi-Fi Network Name',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _networkNameController,
            decoration: InputDecoration(
              hintText: 'e.g. MyHomeWiFi or Office Network',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.wifi),
            ),
            onChanged: (value) {
              setState(() {});
              _saveNetworkName(value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Command to run:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _commandCard(_revealCommand, isDark),
          const SizedBox(height: 16),
          _infoCard(
            isDark,
            children: [
              const Text(
                '• The key=clear parameter is required to display the password in plain text.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Keep the quotation marks if the network name contains spaces.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Step 4: Find the Password'),
          const SizedBox(height: 16),
          const Text(
            'After running the command in Step 3, scroll down in the Command Prompt output to the Security settings section.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _infoCard(
            isDark,
            children: [
              const Text(
                'Look for the line that says:',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green[900] : Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Text(
                  'Key Content            :  YourPasswordHere',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The value next to "Key Content" is the saved Wi-Fi password.',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionTitle('Troubleshooting'),
          const SizedBox(height: 12),
          _infoCard(
            isDark,
            children: [
              const Text(
                '• Are you on Windows 10 or Windows 11?',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Is the network a work or school (WPA2-Enterprise) account? Those usually do not store a simple password that can be revealed this way.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Make sure you ran Command Prompt as Administrator.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Double-check the exact network name (including capital letters and spaces).',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _commandCard(String command, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'cmd',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _copyToClipboard(command),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            command,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
