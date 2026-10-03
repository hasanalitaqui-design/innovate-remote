// Innovate Remote - "Updates" box on the Settings > About page (Oct 3 2026).
// Shows which build this PC runs and which is the newest, and updates in one click.
// The update itself is done by the same script the nightly task uses (Update-InnovateRemote.ps1), started with
// Windows' own permission prompt, so it can replace the installed app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

const _stateDir = r'C:\ProgramData\Innovate\Remote';
const _latestUrl = 'https://license.taquiai.ai/api/remote/latest';

class InnovateUpdates extends StatefulWidget {
  const InnovateUpdates({Key? key}) : super(key: key);

  @override
  State<InnovateUpdates> createState() => _InnovateUpdatesState();
}

class _InnovateUpdatesState extends State<InnovateUpdates> {
  int _have = 0;
  int _want = 0;
  String _notes = '';
  String _msg = '';
  bool _busy = false;
  bool _checked = false;

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
      final f = File('$_stateDir\\build.txt');
      _have = f.existsSync() ? (int.tryParse(f.readAsStringSync().trim()) ?? 0) : 0;
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req = await client.getUrl(Uri.parse(_latestUrl));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      final j = jsonDecode(body) as Map<String, dynamic>;
      _want = (j['build'] ?? 0) as int;
      _notes = (j['notes'] ?? '') as String;
      _checked = true;
      _msg = '';
    } catch (e) {
      _checked = false;
      _msg = 'Could not check for updates (no internet connection?).';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _update() async {
    final script = '$_stateDir\\Update-InnovateRemote.ps1';
    if (!File(script).existsSync()) {
      setState(() => _msg =
          'The update program is not set up on this PC yet. Run the Innovate Remote installer once, then try again.');
      return;
    }
    setState(() => _msg =
        'Updating... Windows will ask for permission. The app closes and opens again when it is done; if it does not, open Innovate Remote from the Start menu.');
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
  }

  @override
  Widget build(BuildContext context) {
    final behind = _checked && _want > _have;
    final String status;
    if (!_checked) {
      status = _msg;
    } else if (behind) {
      status = 'An update is available.';
    } else {
      status = 'Innovate Remote is up to date.';
    }
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
          Text(_have > 0
              ? 'This PC: build $_have'
              : 'This PC: build not recorded yet'),
          if (_checked) Text('Newest: build $_want'),
          if (_checked && behind && _notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_notes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5C7272))),
            ),
          const SizedBox(height: 8),
          Text(status,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: behind ? const Color(0xFFB3452C) : const Color(0xFF0F6B6B))),
          if (_checked && _msg.isNotEmpty)
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
