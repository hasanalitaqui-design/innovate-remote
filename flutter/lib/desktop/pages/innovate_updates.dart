// Innovate Remote - updates (Oct 3 2026).
// InnovateUpdates      : the "Updates" box (Settings > General and Settings > About): this PC's build, the newest build, one-click update.
// InnovateUpdateBanner : a slim teal bar at the top of the main window that appears only when a newer build exists.
// The update itself is done by the same script the nightly task uses (Update-InnovateRemote.ps1), started with
// Windows' own permission prompt, so it can replace the installed app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

const _stateDir = r'C:\ProgramData\Innovate\Remote';
const _latestUrl = 'https://license.taquiai.ai/api/remote/latest';

class _UpdateInfo {
  final int have;
  final int want;
  final String notes;
  const _UpdateInfo(this.have, this.want, this.notes);
  bool get behind => want > have;
}

/// Reads this PC's build and asks the server for the newest one. Throws when the server cannot be reached.
Future<_UpdateInfo> _checkForUpdate() async {
  // the build number is built into the app itself (assets/build_number.txt); the note on disk is only a fallback
  var have = 0;
  try {
    have = int.tryParse((await rootBundle.loadString('assets/build_number.txt')).trim()) ?? 0;
  } catch (e) {
    have = 0;
  }
  if (have == 0) {
    final f = File('$_stateDir\\build.txt');
    have = f.existsSync() ? (int.tryParse(f.readAsStringSync().trim()) ?? 0) : 0;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(Uri.parse(_latestUrl));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    return _UpdateInfo((have), (j['build'] ?? 0) as int, (j['notes'] ?? '') as String);
  } finally {
    client.close();
  }
}

/// Starts the updater with Windows' permission prompt. Returns a message when it cannot start, else null.
Future<String?> _startUpdate() async {
  final script = '$_stateDir\\Update-InnovateRemote.ps1';
  if (!File(script).existsSync()) {
    return 'The update program is not set up on this PC yet. Run the Innovate Remote installer once, then try again.';
  }
  await Process.start(
    'powershell.exe',
    [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-Command',
      "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"$script\"'"
    ],
    mode: ProcessStartMode.detached,
  );
  return null;
}

class InnovateUpdates extends StatefulWidget {
  const InnovateUpdates({Key? key}) : super(key: key);

  @override
  State<InnovateUpdates> createState() => _InnovateUpdatesState();
}

class _InnovateUpdatesState extends State<InnovateUpdates> {
  _UpdateInfo? _info;
  String _msg = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _msg = 'Checking for updates...';
    });
    try {
      final i = await _checkForUpdate();
      _info = i;
      _msg = '';
    } catch (e) {
      _info = null;
      _msg = 'Could not check for updates (no internet connection?).';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _update() async {
    final err = await _startUpdate();
    setState(() => _msg = err ??
        'Updating... Windows will ask for permission. The app closes and opens again when it is done; if it does not, open Innovate Remote from the Start menu.');
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    final behind = i != null && i.behind;
    final String status = i == null
        ? _msg
        : (behind ? 'An update is available.' : 'Innovate Remote is up to date.');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Updates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(i != null && i.have > 0
              ? 'This PC: build ${i.have}'
              : 'This PC: build not recorded yet'),
          if (i != null) Text('Newest: build ${i.want}'),
          if (behind && i.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(i.notes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5C7272))),
            ),
          const SizedBox(height: 8),
          Text(status,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: behind ? const Color(0xFFB3452C) : const Color(0xFF0F6B6B))),
          if (i != null && _msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_msg, style: const TextStyle(fontSize: 12.5)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (behind)
                ElevatedButton(
                  onPressed: _busy ? null : _update,
                  child: const Text('Update now'),
                ),
              if (behind) const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _busy ? null : _check,
                child: const Text('Check again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Slim bar for the top of the main window: only visible when a newer build exists.
class InnovateUpdateBanner extends StatefulWidget {
  const InnovateUpdateBanner({Key? key}) : super(key: key);

  @override
  State<InnovateUpdateBanner> createState() => _InnovateUpdateBannerState();
}

class _InnovateUpdateBannerState extends State<InnovateUpdateBanner> {
  _UpdateInfo? _info;
  String _msg = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final i = await _checkForUpdate();
      if (mounted) setState(() => _info = i);
    } catch (e) {
      // offline: no banner
    }
  }

  Future<void> _update() async {
    final err = await _startUpdate();
    if (mounted) {
      setState(() => _msg = err ?? 'Updating... Windows will ask for permission.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null || !i.behind) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFFE3F1F1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt, size: 18, color: Color(0xFF0F6B6B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _msg.isNotEmpty
                  ? _msg
                  : 'A new version of Innovate Remote is available (build ${i.want}; this PC has build ${i.have}).',
              style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF102A2A),
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (_msg.isEmpty)
            ElevatedButton(
              onPressed: _update,
              child: const Text('Update now'),
            ),
        ],
      ),
    );
  }
}
