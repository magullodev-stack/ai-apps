import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders application content while preserving ordinary text and upgrading
/// unambiguous scientific notation to professional mathematical typography.
///
/// Explicit inline TeX can be delimited with \\(...\\) or \\[...\\].
/// Common Unicode superscripts/subscripts such as x², m/s² or H₂SO₄ are
/// recognized locally so content producers do not need to know about Flutter.
class AiAppsContentText extends StatelessWidget {
  const AiAppsContentText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final segments = _AiAppsContentParser.parse(text);

    if (segments.length == 1 && segments.single is _PlainSegment) {
      return Text(
        text,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: effectiveStyle,
        children: [
          for (final segment in segments)
            if (segment is _PlainSegment)
              TextSpan(text: segment.source)
            else if (segment case final _MathSegment math)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  math.tex,
                  mathStyle: MathStyle.text,
                  textStyle: effectiveStyle,
                  onErrorFallback: (_) => Text(
                    math.source,
                    style: effectiveStyle,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

sealed class _ContentSegment {
  const _ContentSegment(this.source);

  final String source;
}

final class _PlainSegment extends _ContentSegment {
  const _PlainSegment(super.source);
}

final class _MathSegment extends _ContentSegment {
  const _MathSegment(super.source, this.tex);

  final String tex;
}

abstract final class _AiAppsContentParser {
  static final RegExp _explicitMath = RegExp(
    r'\\\((.+?)\\\)|\\\[(.+?)\\\]',
    dotAll: true,
  );

  static final RegExp _unicodeScientific = RegExp(
    r'[A-Za-z0-9]+(?:[A-Za-z0-9/·×⋅.+−-]*[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎][A-Za-z0-9/·×⋅.+−⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎-]*)',
  );

  static const Map<String, String> _superscripts = {
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '⁺': '+',
    '⁻': '-',
    '⁼': '=',
    '⁽': '(',
    '⁾': ')',
  };

  static const Map<String, String> _subscripts = {
    '₀': '0',
    '₁': '1',
    '₂': '2',
    '₃': '3',
    '₄': '4',
    '₅': '5',
    '₆': '6',
    '₇': '7',
    '₈': '8',
    '₉': '9',
    '₊': '+',
    '₋': '-',
    '₌': '=',
    '₍': '(',
    '₎': ')',
  };

  static List<_ContentSegment> parse(String source) {
    if (source.isEmpty) {
      return const [_PlainSegment('')];
    }

    final result = <_ContentSegment>[];
    var cursor = 0;

    for (final match in _explicitMath.allMatches(source)) {
      if (match.start > cursor) {
        _appendAutomatic(result, source.substring(cursor, match.start));
      }

      final tex = match.group(1) ?? match.group(2) ?? '';
      result.add(_MathSegment(match.group(0)!, tex));
      cursor = match.end;
    }

    if (cursor < source.length) {
      _appendAutomatic(result, source.substring(cursor));
    }

    return result.isEmpty ? [_PlainSegment(source)] : result;
  }

  static void _appendAutomatic(
    List<_ContentSegment> target,
    String source,
  ) {
    var cursor = 0;

    for (final match in _unicodeScientific.allMatches(source)) {
      if (match.start > cursor) {
        target.add(_PlainSegment(source.substring(cursor, match.start)));
      }

      final raw = match.group(0)!;
      target.add(_MathSegment(raw, _unicodeToTex(raw)));
      cursor = match.end;
    }

    if (cursor < source.length) {
      target.add(_PlainSegment(source.substring(cursor)));
    }
  }

  static String _unicodeToTex(String source) {
    final output = StringBuffer();

    for (var index = 0; index < source.length;) {
      final char = source[index];

      if (_superscripts.containsKey(char)) {
        final value = StringBuffer();
        while (index < source.length &&
            _superscripts.containsKey(source[index])) {
          value.write(_superscripts[source[index]]);
          index++;
        }
        output.write('^{${value.toString()}}');
        continue;
      }

      if (_subscripts.containsKey(char)) {
        final value = StringBuffer();
        while (index < source.length &&
            _subscripts.containsKey(source[index])) {
          value.write(_subscripts[source[index]]);
          index++;
        }
        output.write('_{${value.toString()}}');
        continue;
      }

      switch (char) {
        case '×':
          output.write(r'\times ');
          break;
        case '⋅':
        case '·':
          output.write(r'\cdot ');
          break;
        case '−':
          output.write('-');
          break;
        default:
          output.write(char);
          break;
      }
      index++;
    }

    return output.toString();
  }
}
