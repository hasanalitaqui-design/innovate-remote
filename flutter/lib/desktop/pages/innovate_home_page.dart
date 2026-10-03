// Innovate Remote - our own home screen (Oct 3 2026). Built from scratch to the approved design; it only uses the
// app for the data it needs: this PC's ID, the connection status, the recent PCs, and "connect".
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const _teal = Color(0xFF0F6B6B);
const _bg = Color(0xFFF1F5F5);
const _line = Color(0xFFD5E0E0);
const _ink = Color(0xFF102A2A);
const _muted = Color(0xFF5C7272);

const _labelStyle = TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w500);
const _headingStyle = TextStyle(fontSize: 19, color: _ink, fontWeight: FontWeight.w700);

String _fmtId(String id) {
  final b = StringBuffer();
  for (var i = 0; i < id.length; i++) {
    if (id.length >= 9 && (i == 3 || i == 6)) b.write(' ');   // 373 465 605 / 142 812 5705
    b.write(id[i]);
  }
  return b.toString();
}

class InnovateHome extends StatefulWidget {
  const InnovateHome({Key? key}) : super(key: key);

  @override
  State<InnovateHome> createState() => _InnovateHomeState();
}

class _InnovateHomeState extends State<InnovateHome> {
  final TextEditingController _id = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    bind.mainLoadRecentPeers();
  }

  @override
  void dispose() {
    _id.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _connect({bool files = false}) {
    final id = _id.text.replaceAll(' ', '');
    if (id.isEmpty) return;
    connect(context, id, isFileTransfer: files);
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _leftCard(BuildContext context) {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, height: 72, color: _teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your ID', style: _labelStyle),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: gFFI.serverModel.serverId,
                      builder: (context, v, _) => SelectableText(
                        v.text,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text('Unattended password', style: _labelStyle),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('••••••••••',
                  style: TextStyle(fontSize: 20, color: _ink, letterSpacing: 2)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    DesktopSettingPage.switch2page(SettingsTabKey.safety),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 14),
          const OnlineStatusWidget(),
        ],
      ),
    );
  }

  Widget _peerRow(Peer p) {
    final name = p.alias.isNotEmpty
        ? p.alias
        : (p.hostname.isNotEmpty ? p.hostname : p.id);
    return InkWell(
      onTap: () => connect(context, p.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.desktop_windows_outlined, color: _teal, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, color: _ink, fontWeight: FontWeight.w600)),
            ),
            Text(_fmtId(p.id),
                style: const TextStyle(fontSize: 14, color: _muted)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Transfer files',
              icon: const Icon(Icons.folder_open, size: 20, color: _muted),
              onPressed: () => connect(context, p.id, isFileTransfer: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentCard(BuildContext context) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Recent', style: _headingStyle),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: AnimatedBuilder(
              animation: gFFI.recentPeersModel,
              builder: (context, _) {
                final peers = gFFI.recentPeersModel.peers;
                if (peers.isEmpty) {
                  return const Center(
                    child: Text(
                      "No recent connections yet.\nType a PC's ID above to connect.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: _muted, height: 1.5),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: peers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _line),
                  itemBuilder: (_, i) => _peerRow(peers[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Control a remote PC', style: _headingStyle),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _id,
                      focusNode: _focus,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [IDTextInputFormatter()],
                      style: const TextStyle(fontSize: 22, height: 1.3),
                      decoration: const InputDecoration(
                        hintText: 'Enter remote ID',
                        filled: false,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _connect,
                      child: const Text('Connect',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _connect(files: true),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Transfer files'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _recentCard(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 360, child: _leftCard(context)),
            const SizedBox(width: 16),
            Expanded(child: _rightColumn(context)),
          ],
        ),
      ),
    );
  }
}
