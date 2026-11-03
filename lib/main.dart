import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openWifiSettings() async {
  try {
    await const AndroidIntent(action: 'android.settings.WIFI_SETTINGS').launch();
  } catch (_) {
    try {
      await const AndroidIntent(action: 'android.settings.SETTINGS').launch();
    } catch (_) {}
  }
}

void main() {
  runApp(const WifiPasswordApp());
}

// ---------------------------------------------------------------------------
// Model + parser
// ---------------------------------------------------------------------------

class WifiNetwork {
  WifiNetwork({
    required this.ssid,
    required this.password,
    required this.security,
    this.hidden = false,
    DateTime? added,
  }) : added = added ?? DateTime.now();

  final String ssid;
  final String password;
  final String security; // WPA, WEP, SAE, nopass ...
  final bool hidden;
  final DateTime added;

  bool get isOpen =>
      security.toLowerCase() == 'nopass' || security.isEmpty && password.isEmpty;

  String get securityLabel {
    final s = security.toUpperCase();
    if (isOpen) return 'Open (no password)';
    if (s == 'SAE') return 'WPA3';
    if (s.isEmpty) return 'WPA/WPA2';
    if (s == 'WPA') return 'WPA/WPA2';
    return s;
  }

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'password': password,
        'security': security,
        'hidden': hidden,
        'added': added.toIso8601String(),
      };

  factory WifiNetwork.fromJson(Map<String, dynamic> j) => WifiNetwork(
        ssid: j['ssid'] ?? '',
        password: j['password'] ?? '',
        security: j['security'] ?? '',
        hidden: j['hidden'] ?? false,
        added: DateTime.tryParse(j['added'] ?? '') ?? DateTime.now(),
      );

  /// Parses the standard Wi-Fi QR format used by Android, iPhone and routers:
  /// WIFI:T:WPA;S:MyNetwork;P:MyPassword;H:false;;
  /// Handles backslash-escaped characters (\; \, \: \\ \").
  static WifiNetwork? tryParse(String raw) {
    final text = raw.trim();
    if (text.length < 5 || text.substring(0, 5).toUpperCase() != 'WIFI:') {
      return null;
    }
    final body = text.substring(5);
    final fields = <String, String>{};
    final buf = StringBuffer();
    var key = '';
    var readingKey = true;
    var i = 0;
    while (i < body.length) {
      final c = body[i];
      if (!readingKey && c == r'\' && i + 1 < body.length) {
        buf.write(body[i + 1]);
        i += 2;
        continue;
      }
      if (readingKey) {
        if (c == ':') {
          key = buf.toString().trim().toUpperCase();
          buf.clear();
          readingKey = false;
        } else if (c != ';') {
          buf.write(c);
        }
      } else {
        if (c == ';') {
          fields[key] = buf.toString();
          buf.clear();
          readingKey = true;
        } else {
          buf.write(c);
        }
      }
      i++;
    }
    if (!readingKey && key.isNotEmpty) fields[key] = buf.toString();

    var ssid = fields['S'] ?? '';
    if (ssid.isEmpty) return null;
    if (ssid.length >= 2 && ssid.startsWith('"') && ssid.endsWith('"')) {
      ssid = ssid.substring(1, ssid.length - 1);
    }
    var pass = fields['P'] ?? '';
    if (pass.length >= 2 && pass.startsWith('"') && pass.endsWith('"')) {
      pass = pass.substring(1, pass.length - 1);
    }
    return WifiNetwork(
      ssid: ssid,
      password: pass,
      security: fields['T'] ?? '',
      hidden: (fields['H'] ?? '').toLowerCase() == 'true',
    );
  }
}

class Store {
  static const _key = 'saved_networks_v2';

  static Future<List<WifiNetwork>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => WifiNetwork.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<WifiNetwork> nets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(nets.map((n) => n.toJson()).toList()));
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class WifiPasswordApp extends StatelessWidget {
  const WifiPasswordApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1A73E8);
    return MaterialApp(
      title: 'Wi-Fi Password Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home: saved list + actions
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<WifiNetwork> _nets = [];
  bool _loading = true;
  bool _busy = false;
  final Set<String> _revealed = {};
  final MobileScannerController _imageScanner =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void initState() {
    super.initState();
    Store.load().then((n) => setState(() {
          _nets = n;
          _loading = false;
        }));
  }

  @override
  void dispose() {
    _imageScanner.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  Future<void> _fromScreenshot() async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      _toast('Could not open your gallery');
      return;
    }
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final capture = await _imageScanner.analyzeImage(file.path);
      final codes = capture?.barcodes ?? const <Barcode>[];
      if (codes.isEmpty) {
        _showNoQr();
        return;
      }
      _handleRaw(codes.first.rawValue ?? '');
    } catch (e) {
      _showNoQr();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromCamera() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScanPage()),
    );
    if (raw != null) _handleRaw(raw);
  }

  void _showNoQr() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.qr_code_2),
        title: const Text('No QR code found'),
        content: const Text(
            'Make sure the screenshot shows the whole Wi-Fi QR code clearly, '
            'not cropped and not blurry. Tap "How to" for help getting it.'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                _openHelp();
              },
              child: const Text('How to')),
          FilledButton(
              onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  void _handleRaw(String raw) {
    final net = WifiNetwork.tryParse(raw);
    if (net == null) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Not a Wi-Fi QR code'),
          content: SelectableText(
              'This QR code contains:\n\n${raw.isEmpty ? '(nothing readable)' : raw}'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    _showResult(net);
  }

  void _showResult(WifiNetwork net) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => ResultSheet(
        net: net,
        onCopy: _copy,
        onSave: () {
          Navigator.pop(c);
          _save(net);
        },
      ),
    );
  }

  Future<void> _save(WifiNetwork net) async {
    setState(() {
      _nets.removeWhere((n) => n.ssid == net.ssid);
      _nets.insert(0, net);
    });
    await Store.save(_nets);
    _toast('"${net.ssid}" saved');
  }

  Future<void> _delete(WifiNetwork net) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${net.ssid}"?'),
        content: const Text('It will be removed from this app only.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _nets.remove(net));
    await Store.save(_nets);
  }

  void _openHelp() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HowToPage()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Passwords'),
        actions: [
          IconButton(
            tooltip: 'Open Wi-Fi settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: openWifiSettings,
          ),
          IconButton(
            tooltip: 'How to',
            icon: const Icon(Icons.help_outline),
            onPressed: _openHelp,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_nets.isEmpty)
            _EmptyState(onHelp: _openHelp)
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: _nets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = _nets[i];
                final shown = _revealed.contains(n.ssid);
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.wifi, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(n.ssid,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(n),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(n.securityLabel,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: SelectableText(
                              n.isOpen
                                  ? 'No password'
                                  : (shown ? n.password : '•' * 10),
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (!n.isOpen) ...[
                            IconButton(
                              tooltip: shown ? 'Hide' : 'Show',
                              icon: Icon(shown
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(() => shown
                                  ? _revealed.remove(n.ssid)
                                  : _revealed.add(n.ssid)),
                            ),
                            IconButton(
                              tooltip: 'Copy password',
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copy(n.password, 'Password'),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _busy ? null : _fromScreenshot,
                icon: const Icon(Icons.image_outlined),
                label: const Text('From screenshot'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _busy ? null : _fromCamera,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan camera'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onHelp});
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.wifi_password, size: 72, color: cs.primary),
        const SizedBox(height: 16),
        Text('Find a saved Wi-Fi password',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          'Android keeps your Wi-Fi password inside the "Share" QR code. '
          'Take a screenshot of that QR code, then tap "From screenshot" below. '
          'The app reads it and shows the password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline),
            label: const Text('Show me how'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result bottom sheet
// ---------------------------------------------------------------------------

class ResultSheet extends StatelessWidget {
  const ResultSheet(
      {super.key,
      required this.net,
      required this.onCopy,
      required this.onSave});
  final WifiNetwork net;
  final void Function(String text, String what) onCopy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row(String label, String value, {bool big = false}) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  SelectableText(value,
                      style: TextStyle(
                          fontFamily: big ? 'monospace' : null,
                          fontSize: big ? 20 : 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy),
              onPressed: () => onCopy(value, label),
            ),
          ]),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text('Wi-Fi details found',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            row('Network name', net.ssid),
            if (net.isOpen)
              row('Password', 'No password (open network)')
            else
              row('Password', net.password, big: true),
            Text('Security: ${net.securityLabel}${net.hidden ? ' · hidden network' : ''}',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save to my list'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Camera scanner
// ---------------------------------------------------------------------------

class CameraScanPage extends StatefulWidget {
  const CameraScanPage({super.key});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage> {
  final MobileScannerController _ctrl =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Wi-Fi QR code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.isNotEmpty) {
                  _done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
          ),
          IgnorePointer(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Text(
              'Point at the Wi-Fi QR code on another phone or on the router sticker',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How-to page
// ---------------------------------------------------------------------------

class HowToPage extends StatelessWidget {
  const HowToPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to get the password')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FilledButton.icon(
            onPressed: openWifiSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open Wi-Fi settings'),
          ),
          const SizedBox(height: 16),
          const _HowCard(
            icon: Icons.phone_android,
            title: 'Samsung phones',
            steps: [
              'Open Settings → Connections → Wi-Fi.',
              'Tap the gear icon next to the network you want.',
              'Tap "QR code" at the bottom of the screen.',
              'Tap "Save as image" (or take a screenshot).',
              'Come back to this app and tap "From screenshot". Pick that image.',
            ],
          ),
          const _HowCard(
            icon: Icons.android,
            title: 'Other Android phones (Pixel, Huawei, Xiaomi, Oppo...)',
            steps: [
              'Open Settings → Network & internet → Wi-Fi (or Internet).',
              'Tap the network (or its gear icon), then tap "Share".',
              'Confirm with your fingerprint, face or PIN.',
              'A QR code appears. Some phones show the password under it already.',
              'Take a screenshot, then use "From screenshot" in this app.',
            ],
          ),
          const _HowCard(
            icon: Icons.qr_code_scanner,
            title: 'Another phone or the router',
            steps: [
              'On the other phone, open the Wi-Fi Share QR code (steps above).',
              'In this app tap "Scan camera" and point it at that screen.',
              'Many routers also have a Wi-Fi QR code on the sticker underneath. Scan it the same way.',
            ],
          ),
          const _HowCard(
            icon: Icons.phone_iphone,
            title: 'iPhone (iOS 16 or newer)',
            steps: [
              'Open Settings → Wi-Fi.',
              'Tap the blue (i) next to the network.',
              'Tap "Password" and unlock with Face ID / Touch ID / passcode.',
              'The password is shown. Tap it to copy.',
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Why the screenshot step? Android does not let any app read saved '
            'Wi-Fi passwords directly. The Share QR code is the official way the '
            'phone gives the password out, so this app reads it from there. '
            'Everything stays on your phone; the app has no internet access.',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard(
      {required this.icon, required this.title, required this.steps});
  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: cs.primary,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(steps[i],
                            style: const TextStyle(fontSize: 15))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
