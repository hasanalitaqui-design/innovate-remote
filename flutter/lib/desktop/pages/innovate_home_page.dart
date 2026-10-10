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

// Palette. Light is the Innovate look; dark keeps the same teal on deep blue-green surfaces. _dark is refreshed at the top of every build.
bool _dark = false;
Color get _teal => Color(0xFF0F6B6B);
Color get _tealDark => Color(0xFF0B5656);
Color get _tealText => _dark ? Color(0xFF5BC8C4) : Color(0xFF0F6B6B);
Color get _tealSoft => _dark ? Color(0xFF16403F) : Color(0xFFE4F1F1);
Color get _bg => _dark ? Color(0xFF0E1717) : Color(0xFFF3F6F6);
Color get _surface => _dark ? Color(0xFF152122) : Colors.white;
Color get _surfaceSoft => _dark ? Color(0xFF1B2B2C) : Color(0xFFF3F8F8);
Color get _tileHover => _dark ? Color(0xFF1B2D2E) : Color(0xFFF2F9F9);
Color get _line => _dark ? Color(0xFF263838) : Color(0xFFE1E9E9);
Color get _fieldLine => _dark ? Color(0xFF35504F) : Color(0xFFC9D8D8);
Color get _ink => _dark ? Color(0xFFE8F1F1) : Color(0xFF0E2323);
Color get _muted => _dark ? Color(0xFF9DB3B3) : Color(0xFF5F7676);
Color get _hint => _dark ? Color(0xFF6F8888) : Color(0xFF93A6A6);
Color get _shadow => _dark ? Color(0x33000000) : Color(0x0D0E2323);

const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

TextStyle get _labelStyle => TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600, letterSpacing: 0.8);
TextStyle get _headingStyle => TextStyle(fontSize: 18, color: _ink, fontWeight: FontWeight.w700, letterSpacing: -0.2);
TextStyle get _subStyle => TextStyle(fontSize: 14, color: _muted, height: 1.4);

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
  InnovateHome({Key? key, this.incomingOnly = false}) : super(key: key);

  // Server mode (Oct 9 2026): this PC only accepts connections - no connect box, no recent list.
  final bool incomingOnly;

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
    await Future.delayed(Duration(milliseconds: 1600));
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
          foregroundColor: _tealText,
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(0),
          minimumSize: MaterialStateProperty.all(Size(0, 48)),
          padding: MaterialStateProperty.all(
              EdgeInsets.symmetric(horizontal: 20)),
          shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          backgroundColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered) ||
                      states.contains(MaterialState.pressed)
                  ? _tealDark
                  : _teal),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          textStyle: MaterialStateProperty.all(
              TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          elevation: MaterialStateProperty.all(0),
          minimumSize: MaterialStateProperty.all(Size(0, 38)),
          padding: MaterialStateProperty.all(
              EdgeInsets.symmetric(horizontal: 16)),
          shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          backgroundColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered) ? _tealSoft : _surface),
          foregroundColor: MaterialStateProperty.all(_ink),
          side: MaterialStateProperty.resolveWith((states) => BorderSide(
              color: states.contains(MaterialState.hovered) ? _teal : _fieldLine,
              width: 1.5)),
          textStyle: MaterialStateProperty.all(
              TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        isDense: false,
        hintStyle: TextStyle(color: _hint, fontWeight: FontWeight.w400),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _fieldLine, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _fieldLine, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _tealText, width: 2)),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 4)),
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
          Text('YOUR ID', style: _labelStyle),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: gFFI.serverModel.serverId,
                  builder: (context, v, _) => SelectableText(
                    v.text,
                    style: TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.5,
                        fontFeatures: _tnum),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Tooltip(
                message: _copied ? 'Copied' : 'Copy my ID',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _copyMyId,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: _tealSoft, borderRadius: BorderRadius.circular(9)),
                    child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 18, color: _tealText),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Divider(height: 1, color: _line),
          SizedBox(height: 12),
          Text('UNATTENDED PASSWORD', style: _labelStyle),
          SizedBox(height: 4),
          Row(
            children: [
              Text('••••••••••',
                  style: TextStyle(fontSize: 16, color: _ink, letterSpacing: 2)),
              Spacer(),
              TextButton(
                onPressed: () =>
                    DesktopSettingPage.switch2page(SettingsTabKey.safety),
                child: Text('Change'),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Expanded(child: OnlineStatusWidget())]),
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
        title: Text('Rename this PC'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctl,
            autofocus: true,
            decoration: InputDecoration(hintText: 'For example: Front desk'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ctl.text),
              child: Text('Save')),
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
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, size: 28, color: _tealText),
            ),
            SizedBox(height: 16),
            Text('No recent connections',
                style: TextStyle(
                    fontSize: 16, color: _ink, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text("PCs you connect to will show up here.",
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
          final cols = box.maxWidth >= 440 ? 2 : 1;      // two columns (more PCs fit); one only in a very narrow window
          return GridView.builder(
            shrinkWrap: stacked,
            physics: stacked ? NeverScrollableScrollPhysics() : null,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
            itemCount: peers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
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
            padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Text('Recent', style: _headingStyle),
                SizedBox(width: 10),
                AnimatedBuilder(
                  animation: gFFI.recentPeersModel,
                  builder: (context, _) {
                    final n = gFFI.recentPeersModel.peers.length;
                    if (n == 0) return SizedBox.shrink();
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _tealSoft,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$n',
                          style: TextStyle(
                              fontSize: 12,
                              color: _teal,
                              fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _line),
          if (stacked) grid else Expanded(child: grid),
        ],
      ),
    );
  }

  // Short and quiet: three steps under the ID card.
  Widget _helpCard(BuildContext context) {
    Widget step(String n, String t) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
              child: Text(n,
                  style: TextStyle(
                      color: _tealText, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            SizedBox(width: 12),
            Expanded(
                child: Text(t,
                    style: TextStyle(fontSize: 14, color: _ink, height: 1.4))),
          ]),
        );
    return _card(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to connect', style: _headingStyle),
          SizedBox(height: 16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect to a PC', style: _headingStyle),
                    SizedBox(height: 2),
                    Text('Enter the ID of the PC you want to control.',
                        style: _subStyle),
                  ],
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _connect(files: true),
                icon: Icon(Icons.folder_open_rounded, size: 18, color: _tealText),
                label: Text('Transfer files'),
              ),
            ],
          ),
          SizedBox(height: 14),
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
                  style: TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                      fontFeatures: _tnum),
                  decoration: InputDecoration(
                    hintText: 'Remote ID',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    prefixIcon: Icon(Icons.desktop_windows_outlined,
                        size: 20, color: _hint),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: _connect,
                child: Row(
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
        SizedBox(height: 16),
        if (stacked)
          _recentCard(context, stacked: true)
        else
          Expanded(child: _recentCard(context)),
      ],
    );
  }

  // Server mode: what this PC is, and what to do with the ID.
  Widget _serverNote(BuildContext context) {
    return _card(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _tealSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.shield_outlined, size: 20, color: _tealText),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This PC accepts connections only',
                    style: TextStyle(
                        fontSize: 15, color: _ink, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                    'Give the ID above and the unattended password to the person who needs to work on this PC. This PC cannot start connections to other PCs.',
                    style: TextStyle(fontSize: 14, color: _muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: _tealText),
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
    _dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: _theme(context),
      child: Material(
        color: _bg,
        child: Column(
          children: [
            InnovateUpdateBanner(),
            Expanded(
              child: widget.incomingOnly
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _leftCard(context),
                              SizedBox(height: 16),
                              _serverNote(context),
                            ],
                          ),
                        ),
                      ),
                    )
                  : LayoutBuilder(builder: (context, box) {
                // narrow window: one column that scrolls; wide window: ID and help on the left, connect and recent on the right
                if (box.maxWidth < 760) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _leftCard(context),
                        SizedBox(height: 16),
                        _rightColumn(context, stacked: true),
                        SizedBox(height: 16),
                        _helpCard(context),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 380,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _leftCard(context),
                              SizedBox(height: 16),
                              _helpCard(context),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
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
  _PeerTile({
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
          duration: Duration(milliseconds: 120),
          padding: EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: _hover ? _tileHover : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? Color(0x800F6B6B) : _line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: _tealSoft, shape: BoxShape.circle),
                child: Text(_firstLetter(name),
                    style: TextStyle(
                        fontSize: 14, color: _tealText, fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, color: _ink, fontWeight: FontWeight.w600)),
                    SizedBox(height: 0),
                    Text(_fmtId(p.id),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12, color: _muted, fontFeatures: _tnum)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                splashRadius: 16,
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: _hover ? _muted : _hint),
                onSelected: (v) {
                  if (v == 'files') {
                    widget.onFiles();
                  } else if (v == 'rename') {
                    widget.onRename();
                  } else {
                    widget.onRemove();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'files', child: Text('Transfer files')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'remove', child: Text('Remove from list')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
