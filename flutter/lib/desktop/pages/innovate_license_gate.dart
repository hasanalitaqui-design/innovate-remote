// REMOTE licence agreement gate (Nov 15 2026): the agreement must be read to the very end and accepted once per computer, per software and per agreement version.
// The acceptance is a small file in %LOCALAPPDATA%\Innovate\Accepted\REMOTE.json bound to THIS computer (a hash of the Windows machine id, the app name and the agreement version),
// the same file format and hash as the setup program, PDF, CODE, SHEETS and WORKFLOW. The text is in innovate_license_text.dart (made by legal/sync_eula.py in the Innovate repo).
// Declining closes the REMOTE window. (The Windows service that accepts connections is installed under the firm's licence and keeps running.)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

import 'innovate_license_text.dart';

class InnovateLicense {
  static const String app = 'REMOTE';

  static String _dir() {
    final env = Platform.environment['INNOVATE_ACCEPT_DIR'];
    if (env != null && env.isNotEmpty) return env;
    final root = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE'] ?? ''}\\AppData\\Local';
    return '$root\\Innovate\\Accepted';
  }

  static String recordPath() => '${_dir()}\\$app.json';

  static Future<String> machineId() async {
    try {
      final r = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
        '/reg:64'
      ]);
      final m = RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)', caseSensitive: false)
          .firstMatch(r.stdout.toString());
      if (m != null) return m.group(1)!.toLowerCase();
    } catch (_) {}
    return (Platform.environment['COMPUTERNAME'] ?? 'unknown-pc').toLowerCase();
  }

  static String token(String machineId) => crypto.sha256
      .convert(utf8.encode('$machineId|$app|$kLicenseVersion'))
      .toString();

  static Future<bool> isAccepted() async {
    try {
      final j = jsonDecode(await File(recordPath()).readAsString());
      return j['version'] == kLicenseVersion &&
          j['token'] == token(await machineId());
    } catch (_) {
      return false;
    }
  }

  static Future<void> writeRecord() async {
    await Directory(_dir()).create(recursive: true);
    final now = DateTime.now();
    final rec = {
      'app': app,
      'version': kLicenseVersion,
      'accepted_at': now.toIso8601String(),
      'user': Platform.environment['USERNAME'] ?? '',
      'computer': Platform.environment['COMPUTERNAME'] ?? '',
      'token': token(await machineId()),
    };
    final tmp = File('${recordPath()}.tmp');
    await tmp.writeAsString(jsonEncode(rec));
    final dest = File(recordPath());
    if (await dest.exists()) await dest.delete();
    await tmp.rename(recordPath());
  }

  static bool _showing = false;

  // Shows the agreement (not dismissible) when this PC has no valid acceptance. Accept writes the record; Decline closes the app.
  static Future<void> ensure(BuildContext context) async {
    if (_showing) return;
    if (await isAccepted()) return;
    if (!context.mounted) return;
    _showing = true;
    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AgreementDialog(),
      );
      if (ok == true) {
        await writeRecord();
      } else {
        exit(0);
      }
    } finally {
      _showing = false;
    }
  }
}

class _AgreementDialog extends StatefulWidget {
  const _AgreementDialog();

  @override
  State<_AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<_AgreementDialog> {
  final ScrollController _sc = ScrollController();
  bool _read = false;

  void _check() {
    if (_read || !_sc.hasClients) return;
    final p = _sc.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 6) {
      setState(() => _read = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _sc.addListener(_check);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = math.min(880.0, size.width * (size.width < 700 ? 0.94 : 0.78));
    final h = size.height * 0.92;
    const teal = Color(0xFF008080);
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: w,
          height: h,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 16, 22, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Software License Agreement',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                          'Please read the whole agreement. You can accept only after you reach the end.',
                          style:
                              TextStyle(fontSize: 12.5, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  controller: _sc,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _sc,
                    padding: const EdgeInsets.fromLTRB(22, 12, 28, 12),
                    child: SelectableText(licenseTextFor('REMOTE'),
                        style: const TextStyle(fontSize: 13.5, height: 1.55)),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          _read
                              ? 'Thank you. You can accept now.'
                              : 'Scroll to the end of the agreement to enable Accept.',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _read ? teal : Colors.black54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: teal),
                      onPressed:
                          _read ? () => Navigator.of(context).pop(true) : null,
                      child: const Text('I accept'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
