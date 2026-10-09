// Innovate Remote - our own home screen (Oct 3 2026), restyled Oct 9 2026 (Taqui: "make it PRO").
// It only uses the app for the data it needs: this PC's ID, the connection status, the recent PCs, and "connect".
// Look: Inter, an 8-point spacing grid, white cards with a soft shadow, one teal accent, hover states.
import 'dart:ui' show FontFeature;

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
const _tealDark = Color(0xFF0B5656);
const _tealSoft = Color(0xFFE4F1F1);
const _bg = Color(0xFFF3F6F6);
const _line = Color(0xFFE1E9E9);
const _fieldLine = Color(0xFFC9D8D8);
const _ink = Color(0xFF0E2323);
const _muted = Color(0xFF5F7676);
const _hint = Color(0xFF93A6A6);

const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

const _labelStyle = TextStyle(
    fontSize: 12,
    color: _muted,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8);
const _headingStyle = TextStyle(
    fontSize: 18,
    color: _ink,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2);
const _subStyle = TextStyle(fontSize: 14, color: _muted, height: 1.4);

String _fmtId(String id) {
  // groups of three counted from the right, so every length reads the same way: 36 730 855 / 373 465 605 / 1 428 125 705
  final b = StringBuffer();
  for (var i = 0; i < id.length; i++) {
    if (i > 0 && (id.length - i) % 3 == 0) b.write(' ');
    b.write(id[i]);
  }
  return b.toString();
}

String _firstLetter(String name) {
  if (name.isEmpty) return '?';
  return String.fromCharCodes(name.runes.take(1)).toUpperCase();
}

class InnovateHome extends StatefulWidget {
  const InnovateHome({Key? key}) : super(key: key);

  @override
  State<InnovateHome> createState() => _InnovateHomeState();
}

class _InnovateHomeState extends State<InnovateHome> {
  final TextEditingController _id = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _copied = false;

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

  Future<void> _copyMyId() async {
    await Clipboard.setData(
        ClipboardData(text: gFFI.serverModel.serverId.text.replaceAll(' ', '')));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  // Buttons, links and fields inside this screen: teal, rounded, quiet.
  ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: _bg,
      dividerColor: _line,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _teal,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(0),
          minimumSize: MaterialStateProperty.all(const Size(0, 56)),
          padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24)),
          shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          backgroundColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered) ||
                      states.contains(MaterialState.pressed)
                  ? _tealDark
                  : _teal),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          textStyle: MaterialStateProperty.all(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(0),
          minimumSize: MaterialStateProperty.all(const Size(0, 44)),
          padding: MaterialStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16)),
          shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          backgroundColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered) ? _tealSoft : Colors.white),
          foregroundColor: MaterialStateProperty.all(_ink),
          side: MaterialStateProperty.resolveWith((states) => BorderSide(
              color: states.contains(MaterialState.hovered) ? _teal : _fieldLine,
              width: 1.5)),
          textStyle: MaterialStateProperty.all(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        hintStyle: const TextStyle(color: _hint, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _fieldLine, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _fieldLine, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _teal, width: 2)),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0E2323), blurRadius: 16, offset: Offset(0, 4)),
        ],
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
          const Text('YOUR ID', style: _labelStyle),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: gFFI.serverModel.serverId,
                  builder: (context, v, _) => SelectableText(
                    v.text,
                    style: const TextStyle(
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.5,
                        fontFeatures: _tnum),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: _copied ? 'Copied' : 'Copy my ID',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _copyMyId,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: _tealSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 20, color: _teal),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 20),
          const Text('UNATTENDED PASSWORD', style: _labelStyle),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('••••••••••',
                  style: TextStyle(fontSize: 20, color: _ink, letterSpacing: 3)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    DesktopSettingPage.switch2page(SettingsTabKey.safety),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F8F8),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [Expanded(child: OnlineStatusWidget())]),
          ),
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
    return _PeerTile(
      peer: p,
      onOpen: () => connect(context, p.id),
      onFiles: () => connect(context, p.id, isFileTransfer: true),
      onRename: () => _rename(p),
      onRemove: () async {
        await bind.mainRemovePeer(id: p.id);
        bind.mainLoadRecentPeers();
      },
    );
  }

  Widget _emptyRecent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  const BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
              child: const Icon(Icons.history_rounded, size: 28, color: _teal),
            ),
            const SizedBox(height: 16),
            const Text('No recent connections',
                style: TextStyle(
                    fontSize: 16, color: _ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text("PCs you connect to will show up here.",
                textAlign: TextAlign.center, style: _subStyle),
          ],
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
        if (peers.isEmpty) return _emptyRecent();
        return LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: stacked,
            physics: stacked ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.all(16),
            itemCount: peers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 72,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Text('Recent', style: _headingStyle),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: gFFI.recentPeersModel,
                  builder: (context, _) {
                    final n = gFFI.recentPeersModel.peers.length;
                    if (n == 0) return const SizedBox.shrink();
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _tealSoft,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$n',
                          style: const TextStyle(
                              fontSize: 12,
                              color: _teal,
                              fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (stacked) grid else Expanded(child: grid),
        ],
      ),
    );
  }

  // Short and quiet: three steps under the ID card.
  Widget _helpCard(BuildContext context) {
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
              child: Text(n,
                  style: const TextStyle(
                      color: _teal, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t,
                    style: const TextStyle(fontSize: 14, color: _ink, height: 1.4))),
          ]),
        );
    return _card(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to connect', style: _headingStyle),
          const SizedBox(height: 16),
          step('1', "Type the other PC's ID and press Connect."),
          step('2', 'Enter its password, or let it accept the request.'),
          step('3', 'Work on it as if you were sitting there.'),
        ],
      ),
    );
  }

  Widget _connectCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connect to a PC', style: _headingStyle),
          const SizedBox(height: 4),
          const Text('Enter the ID of the PC you want to control.',
              style: _subStyle),
          const SizedBox(height: 20),
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
                  style: const TextStyle(
                      fontSize: 22,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                      fontFeatures: _tnum),
                  decoration: const InputDecoration(
                    hintText: 'Remote ID',
                    prefixIcon: Icon(Icons.desktop_windows_outlined,
                        size: 22, color: _hint),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _connect,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Connect'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _connect(files: true),
                icon: const Icon(Icons.folder_open_rounded, size: 18, color: _teal),
                label: const Text('Transfer files'),
              ),
            ],
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
        _connectCard(context),
        const SizedBox(height: 24),
        if (stacked)
          _recentCard(context, stacked: true)
        else
          Expanded(child: _recentCard(context)),
      ],
    );
  }

  Widget _footer() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: _teal),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'End-to-end encrypted. Your screen is never recorded or stored.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(context),
      child: Material(
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
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 380,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _leftCard(context),
                              const SizedBox(height: 24),
                              _helpCard(context),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: _rightColumn(context)),
                    ],
                  ),
                );
              }),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }
}

// One recent PC: initial in a soft circle, name with the ID under it; the small actions appear when the mouse is over the tile.
class _PeerTile extends StatefulWidget {
  const _PeerTile({
    Key? key,
    required this.peer,
    required this.onOpen,
    required this.onFiles,
    required this.onRename,
    required this.onRemove,
  }) : super(key: key);

  final Peer peer;
  final VoidCallback onOpen;
  final VoidCallback onFiles;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  State<_PeerTile> createState() => _PeerTileState();
}

class _PeerTileState extends State<_PeerTile> {
  bool _hover = false;

  Widget _action(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: _muted,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.peer;
    final name = p.alias.isNotEmpty
        ? p.alias
        : (p.hostname.isNotEmpty ? p.hostname : p.id);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFF2F9F9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? const Color(0x800F6B6B) : _line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
                child: Text(_firstLetter(name),
                    style: const TextStyle(
                        fontSize: 16, color: _teal, fontWeight: FontWeight.w700)),
              ),
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
                            fontSize: 15, color: _ink, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_fmtId(p.id),
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 13, color: _muted, fontFeatures: _tnum)),
                  ],
                ),
              ),
              if (_hover) ...[
                _action(Icons.folder_open_rounded, 'Transfer files', widget.onFiles),
                _action(Icons.edit_outlined, 'Rename this PC in my list', widget.onRename),
                _action(Icons.close_rounded, 'Remove from this list', widget.onRemove),
              ] else
                const Icon(Icons.chevron_right_rounded, size: 22, color: _hint),
            ],
          ),
        ),
      ),
    );
  }
}
