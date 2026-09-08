import 'package:flutter/material.dart';

import '../../services/haptics.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class DropOption {
  const DropOption(this.value, this.label, {this.icon});
  final String value;
  final String label;
  final String? icon;

  String get display => icon == null ? label : '$icon $label';
}

/// The compact filter control used on Learn and Words.
///
/// All dropdowns in a row are equal width (`Expanded`), so labels stay
/// consistent across devices and the row never wraps. Multi-select menus stay
/// open while options are ticked and the list behind updates live, which is the
/// behaviour the web build's custom `<details>` widget was written for.
class FilterDropdown extends StatefulWidget {
  const FilterDropdown({
    super.key,
    required this.name,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = true,
    this.resetLabel,
  });

  /// Plain-language filter name, shown when nothing is selected.
  final String name;
  final List<DropOption> options;

  /// Selected values. For single-select this holds at most one.
  final List<String> selected;

  /// Receives the new selection.
  final ValueChanged<List<String>> onChanged;
  final bool multi;

  /// Label of the "All …" reset row. Null hides the row.
  final String? resetLabel;

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  final LayerLink _link = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  String get _summary {
    if (!widget.multi) {
      final String? v = widget.selected.isEmpty ? null : widget.selected.first;
      final DropOption? o = _find(v);
      return o?.display ?? widget.name;
    }
    if (widget.selected.isEmpty) return widget.name;
    if (widget.selected.length == 1) {
      return _find(widget.selected.first)?.display ?? widget.name;
    }
    return '${widget.name} · ${widget.selected.length}';
  }

  DropOption? _find(String? v) {
    if (v == null) return null;
    for (final DropOption o in widget.options) {
      if (o.value == v) return o;
    }
    return null;
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _close() {
    _removeOverlay();
    if (mounted) setState(() {});
  }

  void _open() {
    final RenderBox? box =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final AppTokens t = context.tokens;
    final Size size = box.size;
    final Offset origin = box.localToGlobal(Offset.zero);
    final double screenWidth = MediaQuery.sizeOf(context).width;

    // Right-anchor when the menu would otherwise spill off-screen.
    final double menuWidth = size.width < 200 ? 220 : size.width;
    final bool alignRight = origin.dx + menuWidth > screenWidth - 8;

    _entry = OverlayEntry(
      builder: (BuildContext ctx) => Stack(
        children: <Widget>[
          // Outside tap closes, exactly like the web build's document listener.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: alignRight ? Alignment.bottomRight : Alignment.bottomLeft,
            followerAnchor: alignRight ? Alignment.topRight : Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Align(
              alignment: alignRight ? Alignment.topRight : Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: size.width,
                    maxWidth: 280,
                    maxHeight: 320,
                  ),
                  decoration: BoxDecoration(
                    // Sepia's card background is the paper colour so a floating
                    // menu is never see-through over the grain.
                    color: t.cardBg,
                    border: Border.all(color: t.line, width: 2),
                    borderRadius: t.cardRadius,
                    boxShadow: t.shadow.isEmpty
                        ? const <BoxShadow>[
                            BoxShadow(color: Color(0x33000000), blurRadius: 12),
                          ]
                        : t.shadow,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: _menuList(t),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  Widget _menuList(AppTokens t) {
    final List<Widget> rows = <Widget>[];
    if (widget.multi && widget.resetLabel != null) {
      rows.add(_row(t, widget.resetLabel!, widget.selected.isEmpty, () {
        widget.onChanged(<String>[]);
      }));
    }
    for (final DropOption o in widget.options) {
      final bool sel = widget.selected.contains(o.value);
      rows.add(_row(t, o.display, sel, () {
        if (widget.multi) {
          final List<String> next = List<String>.of(widget.selected);
          sel ? next.remove(o.value) : next.add(o.value);
          widget.onChanged(next);
        } else {
          widget.onChanged(<String>[o.value]);
          _close();
        }
      }));
    }
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _row(AppTokens t, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        Haptics.tap();
        onTap();
        // Rebuild the open menu so the tick appears without closing it.
        _entry?.markNeedsBuild();
        if (mounted) setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 15,
              child: selected
                  ? Text('✓',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: t.accent == t.red ? t.blue : t.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13))
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: t.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens t = context.tokens;
    final bool active = widget.multi && widget.selected.isNotEmpty;
    final Color borderColor =
        (active || _isOpen) ? (t.accent == t.red ? t.blue : t.accent) : t.line;

    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: '${widget.name}: $_summary',
        child: InkWell(
          key: _anchorKey,
          borderRadius: t.cardRadius,
          onTap: () {
            Haptics.tap();
            _toggle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: t.paper,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: t.cardRadius,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.keyboard_arrow_down, size: 14, color: t.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single-line row of equal-width dropdowns.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
