import 'package:flutter/material.dart';

/// Lightweight, safe markdown renderer for AI replies.
///
/// Supports: headers (#, ##, ###), bullet (-, *, •), numbered lists (1.),
/// bold (**), italic (* / _), inline code (`), inline links and line breaks.
/// Unsupported constructs degrade gracefully to plain text.
class AiMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? accentColor;
  final TextAlign? textAlign;

  const AiMarkdownText({
    super.key,
    required this.text,
    this.style,
    this.accentColor,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ??
        const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87);
    final lines = _splitLines(text);
    final children = <Widget>[];
    var inCodeBlock = false;
    final codeLines = <String>[];

    for (final raw in lines) {
      final line = raw.isEmpty ? '' : raw.trim();
      if (line.startsWith('```')) {
        if (inCodeBlock) {
          children.add(_codeBlock(codeLines));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeLines.add(raw);
        continue;
      }
      children.add(_buildLine(context, line, base));
    }
    if (inCodeBlock && codeLines.isNotEmpty) {
      children.add(_codeBlock(codeLines));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _codeBlock(List<String> lines) {
    return Container(
      width: double.maxFinite,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: SelectableText(
        lines.join('\n'),
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.4,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, String line, TextStyle base) {
    if (line.isEmpty) return const SizedBox(height: 6);

    // Headers
    final headerMatch = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (headerMatch != null) {
      final level = headerMatch.group(1)!.length;
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(
          line.substring(level + 1),
          style: base.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: level == 1
                ? (base.fontSize ?? 14) + 4
                : level == 2
                    ? (base.fontSize ?? 14) + 2
                    : (base.fontSize ?? 14) + 1,
          ),
        ),
      );
    }

    // Bullet list
    final bulletMatch =
        RegExp(r'^([-*•])\s+(.*)$', caseSensitive: false).firstMatch(line);
    if (bulletMatch != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6, top: 1),
              child: Text('•',
                  style: base.copyWith(
                      color: accentColor, fontWeight: FontWeight.bold)),
            ),
            Expanded(
                child: _inlineRich(trimInnerMd(bulletMatch.group(2)!), base)),
          ],
        ),
      );
    }

    // Numbered list
    final numMatch = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
    if (numMatch != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${numMatch.group(1)}.',
              style: base.copyWith(
                  fontWeight: FontWeight.bold, color: accentColor),
            ),
            const SizedBox(width: 6),
            Expanded(child: _inlineRich(trimInnerMd(numMatch.group(2)!), base)),
          ],
        ),
      );
    }

    return _inlineRich(line, base);
  }

  String trimInnerMd(String s) {
    var out = s;
    if (out.startsWith('**')) out = out.substring(2);
    if (out.endsWith('**')) out = out.substring(0, out.length - 2);
    return out;
  }

  Widget _inlineRich(String text, TextStyle base) {
    final spans = <TextSpan>[];
    _parseInline(text, base, spans);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.start,
    );
  }

  void _parseInline(String text, TextStyle base, List<TextSpan> spans) {
    final bold = RegExp(r'\*\*(.+?)\*\*');
    final italic = RegExp(r'(?<!\*)\*([^*\n]+?)\*(?!\*)');
    final code = RegExp(r'`([^`]+?)`');

    final all = <(Match, String)>[
      for (final m in bold.allMatches(text)) (m, 'bold'),
      for (final m in code.allMatches(text)) (m, 'code'),
      for (final m in italic.allMatches(text)) (m, 'italic'),
    ]..sort((a, b) => a.$1.start.compareTo(b.$1.start));

    if (all.isEmpty) {
      spans.add(TextSpan(text: text, style: base));
      return;
    }

    var cursor = 0;
    final covered = <int>{};
    for (final (match, kind) in all) {
      if (match.start < cursor || covered.contains(match.start)) continue;
      covered.add(match.start);
      if (match.start > cursor) {
        spans.add(
            TextSpan(text: text.substring(cursor, match.start), style: base));
      }
      final content = match.group(1)!;
      spans.add(TextSpan(
        text: content,
        style: kind == 'bold'
            ? base.copyWith(fontWeight: FontWeight.bold)
            : kind == 'italic'
                ? base.copyWith(fontStyle: FontStyle.italic)
                : base.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: base.color?.withValues(alpha: 0.08),
                    fontSize: (base.fontSize ?? 14) - 1,
                  ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
  }

  List<String> _splitLines(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }
}
