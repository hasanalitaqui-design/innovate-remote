// Innovate Remote - our own home screen (Oct 3 2026). Built from scratch to the approved design; it only uses the
// app for the data it needs: this PC's ID, the connection status, the recent PCs, and "connect".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/innovate_updates.dart';
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
  // groups of three counted from the right, so every length reads the same way: 36 730 855 / 373 465 605 / 1 428 125 705
  final b = StringBuffer();
  for (var i = 0; i < id.length; i++) {
    if (i > 0 && (id.length - i) % 3 == 0) b.write(' ');
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

  Future<void> _rename(Peer p) async {
    final current = p.alias.isNotEmpty
        ? p.alias
        : (p.hostname.isNotEmpty ? p.hostname : p.id);
    final ctl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename this PC'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'For example: Front desk'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ctl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null) return;
    await bind.mainSetPeerAlias(id: p.id, alias: name.trim());
    bind.mainLoadRecentPeers();
  }

  Widget _peerRow(Peer p) {
    final name = p.alias.isNotEmpty
        ? p.alias
        : (p.hostname.isNotEmpty ? p.hostname : p.id);
    // a tile: icon, name with the ID under it (so a long name never runs into the ID), then the three small buttons
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => connect(context, p.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Row(
            children: [
              const Icon(Icons.desktop_windows_outlined, color: _teal, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, color: _ink, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_fmtId(p.id),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 13, color: _muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Transfer files',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.folder_open, size: 20, color: _muted),
                onPressed: () => connect(context, p.id, isFileTransfer: true),
              ),
              IconButton(
                tooltip: 'Rename this PC in my list',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20, color: _muted),
                onPressed: () => _rename(p),
              ),
              IconButton(
                tooltip: 'Remove from this list',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20, color: _muted),
                onPressed: () async {
                  await bind.mainRemovePeer(id: p.id);
                  bind.mainLoadRecentPeers();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The tiles sit in a grid: 1 column when narrow, 2 on a normal window, 3 when the window is wide.
  // stacked = the narrow, scrolling layout: the list takes only the height it needs.
  Widget _recentCard(BuildContext context, {bool stacked = false}) {
    final grid = AnimatedBuilder(
      animation: gFFI.recentPeersModel,
      builder: (context, _) {
        final peers = gFFI.recentPeersModel.peers;
        if (peers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text(
                "No recent connections yet.\nType a PC's ID above to connect.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _muted, height: 1.5),
              ),
            ),
          );
        }
        return LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 620 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: stacked,
            physics: stacked ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.all(16),
            itemCount: peers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) => _peerRow(peers[i]),
          );
        });
      },
    );
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Recent', style: _headingStyle),
          ),
          const Divider(height: 1, color: _line),
          if (stacked) grid else Expanded(child: grid),
        ],
      ),
    );
  }

  // Fills the space under the ID card: how to connect, and what is private.
  Widget _helpCard(BuildContext context) {
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: _ink, height: 1.35))),
          ]),
        );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to connect', style: _headingStyle),
          const SizedBox(height: 14),
          step('1', 'Type the other PC\'s ID in "Control a remote PC".'),
          step('2', 'Press Connect.'),
          step('3', 'Enter its password, or let it accept the request.'),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.lock_outline, size: 18, color: _teal),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sessions are end to end encrypted. Your screen is never recorded or stored.',
                style: TextStyle(fontSize: 13, color: _muted, height: 1.35),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Clipboard.setData(
                ClipboardData(text: gFFI.serverModel.serverId.text.replaceAll(' ', ''))),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy my ID'),
          ),
        ],
      ),
    );
  }

  Widget _rightColumn(BuildContext context, {bool stacked = false}) {
    return Column(
      mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
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
        if (stacked)
          _recentCard(context, stacked: true)
        else
          Expanded(child: _recentCard(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: Column(
        children: [
          const InnovateUpdateBanner(),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              // narrow window: one column that scrolls; wide window: ID and help on the left, connect and recent on the right
              if (box.maxWidth < 760) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _leftCard(context),
                      const SizedBox(height: 16),
                      _rightColumn(context, stacked: true),
                      const SizedBox(height: 16),
                      _helpCard(context),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _leftCard(context),
                            const SizedBox(height: 16),
                            _helpCard(context),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _rightColumn(context)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
