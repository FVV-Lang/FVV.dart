//====================================================================================================
// Copyright (C) 2016-present ShIroRRen <http://shiror.ren>.                                         =
//                                                                                                   =
// Licensed under the F2DLPR License.                                                                =
//                                                                                                   =
// YOU MAY NOT USE THIS FILE EXCEPT IN COMPLIANCE WITH THE LICENSE.                                  =
// Provided "AS IS", WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,                                   =
// unless required by applicable law or agreed to in writing.                                        =
//                                                                                                   =
// For the F2DLPR License terms and conditions, visit: <http://license.fileto.download>.             =
//====================================================================================================

import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:indent/indent.dart';

class FVVV {
  FVVV({final dynamic value, final Map<String, FVVV>? nodes, this.desc = '', this.link = ''})
      : _value = value,
        nodes = nodes ?? {};
  dynamic _value;
  Map<String, FVVV> nodes;
  String desc, link;

  FVVV operator [](final String key) =>
      key.split('.').fold(this, (final tgt, final path) => tgt.nodes.putIfAbsent(path, FVVV.new));
  void operator []=(final String key, final dynamic tgt) => this[key].value = tgt;
  dynamic get value => _value;
  set value(final dynamic tgt) => _value = tgt is FVVV ? tgt._value : tgt;
  @override
  bool operator ==(final other) =>
      identical(this, other) ||
      (other is FVVV &&
          _value == other._value &&
          const MapEquality<String, FVVV>().equals(nodes, other.nodes));
  @override
  int get hashCode => Object.hash(_value, const MapEquality<String, FVVV>().hash(nodes));

  bool get isEmpty => switch (_value) {
        null => true,
        final String str => str.isEmpty,
        final List<dynamic> list => list.isEmpty,
        _ => false
      };

  bool get isNotEmpty => !isEmpty;

  bool isType<T>() => _value is T;
  Type get type => _value.runtimeType;

  T? as<T>([final T? defaultValue]) => isType<T>() ? _value as T : defaultValue;
  T? asType<T>([final T? defaultValue]) => as(defaultValue);
  T get<T>() => as()!;
  List<T> list<T>(final List<T>? defaultValue) => as(defaultValue) ?? [];

  bool get boolean => as(false)!;
  int get integer => as(0)!;
  double get float => as(0)!;
  String get string => as('')!;
  List<bool> get bools => as([])!;
  List<int> get ints => as([])!;
  List<double> get doubles => as([])!;
  List<String> get strings => as([])!;
  List<FVVV> get fvvvs => as([])!;

  void unlink() {
    link = '';
    nodes.forEach((final _, final value) => value.unlink());
  }

  void parseString(final String text, {final FVVStruct? target}) {
    if (text.trim().isEmpty) return;

    final ctx = _TextCtx(text);
    final scopeStack = <FVVV>[];

    ctx.skipBlanks();
    final hasWrapper = ctx.matchAny(['{', '｛']);
    _parseMain(ctx, scopeStack);

    if (hasWrapper) {
      ctx.skipBlanks();
      if (!ctx.matchAny(['}', '｝'])) throw ctx.err.notFound('wrapper');
    }
    ctx.skipBlanks();
    if (!ctx.isEof) throw ctx.err.whyNotEOF();

    if (target != null) to(target);
  }

  @override
  String toString([
    final int? flag1,
    final int? flag2,
    final int? flag3,
    final int? flag4,
    final int? flag5,
    final int? flag6,
    final int? flag7,
    final int? flag8,
    final int? flag9,
    final int? flag10,
    final int? flag11,
    final int? flag12,
    final int? flag13,
    final int? flag14,
    final int? flag15,
    final int? flag16,
    final int? flag17,
    final int? flag18,
    final int? flag19,
    final int? flag20,
    final int? flag21,
  ]) {
    final flags = [
      flag1,
      flag2,
      flag3,
      flag4,
      flag5,
      flag6,
      flag7,
      flag8,
      flag9,
      flag10,
      flag11,
      flag12,
      flag13,
      flag14,
      flag15,
      flag16,
      flag17,
      flag18,
      flag19,
      flag20,
      flag21,
    ].whereType<int>().fold(FormatOpt.common, (final flags, final idxFlag) => flags | idxFlag);
    final ret = StringBuffer();
    final ctx = _FormatCtx(flags);

    if (ctx.useWrapper) {
      ret.write(ctx.fwvBegin);
      if (!ctx.minify) ret.write(ctx.newline);
    }
    _toStringRoot(ctx, ret, ctx.useWrapper ? 1 : 0);
    if (ctx.useWrapper) {
      if (!ctx.minify) ret.write(ctx.newline);
      ret.write(ctx.fwvEnd);
    }

    return '$ret';
  }

  void to(final FVVStruct target) => target.fields(_ReaderBinder(this));
  void from(final FVVStruct target) => target.fields(_WriterBinder(this..unlink()));

  static final Uint8List _escapeTable = () {
    final table = Uint8List(1 << 8);

    table['b'.codeUnitAt(0)] = '\b'.codeUnitAt(0);
    table['f'.codeUnitAt(0)] = '\f'.codeUnitAt(0);
    table['n'.codeUnitAt(0)] = '\n'.codeUnitAt(0);
    table['r'.codeUnitAt(0)] = '\r'.codeUnitAt(0);
    table['t'.codeUnitAt(0)] = '\t'.codeUnitAt(0);
    table[r'\'.codeUnitAt(0)] = r'\'.codeUnitAt(0);

    return table;
  }();
  static int? _getEscapedChar(final String ch) {
    final chc = ch.codeUnitAt(0);
    return (chc < _escapeTable.length)
        ? _escapeTable[chc] != 0
            ? _escapeTable[chc]
            : null
        : null;
  }

  void _parseMain(final _TextCtx ctx, final List<FVVV> scopeStack) {
    FVVV? findKey(final String path, final List<FVVV> scopeStack) {
      final paths = path.split('.');
      if (paths.isEmpty) return null;

      return scopeStack.reversed
          .map(
            (final index) => paths.fold<FVVV?>(
              index,
              (final target, final idxPath) => target?.nodes[idxPath],
            ),
          )
          .firstWhereOrNull((final target) => target != null);
    }

    String parseName(final _TextCtx ctx) {
      ctx.skipBlanks();
      final name = StringBuffer();
      while (!ctx.isEof && !ctx.prematchAny(['=', ':', '：', '<'])) name.write(ctx.next());
      return name.isEmpty ? '' : '$name'.trimRight();
    }

    void parseDesc(
      final _TextCtx ctx,
      final StringBuffer desc,
      final List<FVVV> scopeStack, {
      final bool skipBlanks = true,
      final bool sameLine = false,
    }) {
      for (;;) {
        final origIdx = ctx.index, origLine = ctx.linesStart.length;
        if (!ctx.match('<', sameLine: sameLine)) {
          if (!skipBlanks) {
            ctx.index = origIdx;
            while (ctx.linesStart.length > origLine) ctx.linesStart.removeLast();
          }
          break;
        }

        desc.clear();
        for (;;) {
          if (ctx.isEof) throw ctx.err.whyEOF();
          if (ctx.match('>', skipBlanks: false)) {
            final target = findKey('$desc', scopeStack);
            if (target != null && target.isType<String>())
              desc
                ..clear()
                ..write(target.get<String>());
            break;
          }
          if (ctx.match(r'\', skipBlanks: false)) {
            if (ctx.isEof) throw ctx.err.whyEOF();
            if (ctx.match('>', skipBlanks: false))
              desc.write('>');
            else {
              final ch = ctx.next(), tgt = _getEscapedChar(ch);
              if (tgt != null)
                desc.writeCharCode(tgt);
              else
                desc
                  ..write(r'\')
                  ..write(ch);
            }
          } else
            desc.write(ctx.next());
        }
      }
    }

    void parseText(final _TextCtx ctx, final StringBuffer text) {
      if (ctx.match('`')) {
        for (;;) {
          if (ctx.isEof) throw ctx.err.whyEOF();
          if (ctx.match('`', skipBlanks: false)) break;
          text.write(ctx.next());
        }
        final tmpStr = '$text'.unindent().trim();
        text
          ..clear()
          ..write(tmpStr);
        return;
      }

      final isFullWidth = ctx.match('“');
      if (!isFullWidth && !ctx.match('"')) throw ctx.err.unknown();
      for (;;) {
        if (ctx.isEof) throw ctx.err.whyEOF();
        if (isFullWidth ? ctx.match('”', skipBlanks: false) : ctx.match('"', skipBlanks: false)) return;
        if (ctx.match(r'\', skipBlanks: false)) {
          if (ctx.isEof) throw ctx.err.whyEOF();
          if (isFullWidth && ctx.match('”', skipBlanks: false))
            text.write('”');
          else if (!isFullWidth && ctx.match('"', skipBlanks: false))
            text.write('"');
          else {
            final ch = ctx.next(), tgt = _getEscapedChar(ch);
            if (tgt != null)
              text.writeCharCode(tgt);
            else
              text
                ..write(r'\')
                ..write(ch);
          }
        } else
          text.write(ctx.next());
      }
    }

    num? tryParseNumber(String tgtStr) {
      tgtStr = tgtStr.replaceAll("'", '').replaceAll('’', '');
      if (tgtStr.isEmpty) return null;

      var sign = 1;
      var idx = 0;
      if (tgtStr.startsWith('-')) {
        sign = -1;
        ++idx;
      } else if (tgtStr.startsWith('+')) ++idx;

      var radix = 10;
      if (idx < tgtStr.length && tgtStr[idx] == '0' && idx + 1 < tgtStr.length)
        switch (tgtStr[idx + 1]) {
          case 'x' || 'X':
            radix = 16;
            idx += 2;
          case 'o' || 'O':
            radix = 8;
            idx += 2;
          case 'b' || 'B':
            radix = 2;
            idx += 2;
          case '0' || '1' || '2' || '3' || '4' || '5' || '6' || '7':
            radix = 8;
            ++idx;
        }

      final digitStr = tgtStr.substring(idx);
      if (digitStr.isEmpty) return null;
      final tgtVal = switch (radix) {
        _ when radix != 10 => int.tryParse(digitStr, radix: radix),
        _ when digitStr.contains('.') || digitStr.contains('e') || digitStr.contains('E') =>
          double.tryParse(digitStr),
        _ => int.tryParse(digitStr)
      };
      return tgtVal != null ? tgtVal * sign : null;
    }

    void parseValue(
      final _TextCtx ctx,
      final List<FVVV> scopeStack,
      final FVVV tgtFwv,
      final StringBuffer idxDesc, {
      final bool inList = false,
    }) {
      for (;;) {
        parseDesc(ctx, idxDesc, scopeStack, skipBlanks: inList, sameLine: !inList);
        if (ctx.isEof ||
            (inList
                ? ctx.matchAny([',', '，']) || ctx.prematchAny([']', '］'])
                : !ctx.isSameLine() || ctx.matchAny([';', '；']) || ctx.prematchAny(['}', '｝'])))
          throw ctx.err.notFound('value');

        final tmpSb = StringBuffer();
        if (ctx.prematchAny(['"', '“', '`'])) {
          parseText(ctx, tmpSb);
          if (tgtFwv._value == null)
            tgtFwv._value = '$tmpSb';
          else
            tgtFwv
              ..link = ''
              .._value = '${tgtFwv._value}$tmpSb';
        } else {
          while (!ctx.isEof && !ctx.prematchAny(['<', '+']) && !ctx.prematchAny(['\r', '\n']))
            if (inList ? ctx.prematchAny([',', '，', ']', '］']) : ctx.prematchAny([';', '；', '}', '｝']))
              break;
            else
              tmpSb.write(ctx.next());
          final tmpStr = '$tmpSb'.trimRight();
          if (tmpStr.isEmpty) throw ctx.err.notFound('value');

          const equality = CaseInsensitiveEquality();
          final isTrue = equality.equals(tmpStr, 'true');
          if (isTrue || equality.equals(tmpStr, 'false')) {
            if (tgtFwv._value == null)
              tgtFwv._value = isTrue;
            else
              tgtFwv
                ..link = ''
                .._value = '${tgtFwv._value}$tmpStr';
          } else {
            final tmpNum = tryParseNumber(tmpStr);
            if (tmpNum != null) {
              if (tgtFwv._value == null)
                tgtFwv._value = tmpNum;
              else
                tgtFwv
                  ..link = ''
                  .._value = '${tgtFwv._value}$tmpStr';
            } else {
              final target = findKey(tmpStr, scopeStack);
              if (target != null) {
                if (tgtFwv._value != null && target._value is List) throw ctx.err.plusList();
                if (tgtFwv._value == null)
                  tgtFwv
                    ..link = tmpStr
                    .._value = target._value;
                else
                  tgtFwv
                    ..link = ''
                    .._value = '${tgtFwv._value}${target._value}';
                tgtFwv.nodes = target.nodes;
              } else
                throw ctx.err.noValue(tmpStr);
            }
          }
        }
        parseDesc(ctx, idxDesc, scopeStack, skipBlanks: false, sameLine: true);
        if (ctx.isEof ||
            !ctx.isSameLine() ||
            (inList
                ? ctx.matchAny([',', '，']) || ctx.prematchAny([']', '］'])
                : ctx.matchAny([';', '；']) || ctx.prematchAny(['}', '｝']))) return;

        if (ctx.match('+'))
          continue;
        else
          throw ctx.err.notFound('+');
      }
    }

    scopeStack.add(this);

    for (;;) {
      final idxDesc = StringBuffer();
      parseDesc(ctx, idxDesc, scopeStack, skipBlanks: false);
      if (!ctx.isSameLine()) idxDesc.clear();

      if (ctx.isEof || ctx.prematchAny(['}', '｝'])) break;

      final name = parseName(ctx);
      if (name.isEmpty) throw ctx.err.notFound('name');
      parseDesc(ctx, idxDesc, scopeStack);
      if (!ctx.matchAny(['=', ':', '：'])) throw ctx.err.notFound('=');
      parseDesc(ctx, idxDesc, scopeStack);

      var goto = false;
      final tgtKey = this[name];
      if (ctx.matchAny(['[', '［'])) {
        var tgtList = <dynamic>[];
        var listType = Null;
        for (;;) {
          final valueDesc = StringBuffer();
          parseDesc(ctx, valueDesc, scopeStack, skipBlanks: false);
          if (!ctx.isSameLine()) valueDesc.clear();

          if (ctx.isEof) throw ctx.err.whyEOF();
          if (ctx.matchAny(['{', '｛'])) {
            listType = FVVV;
            final tmpValue = FVVV().._parseMain(ctx, scopeStack);
            if (!ctx.matchAny(['}', '｝'])) throw ctx.err.notFound('}');
            parseDesc(ctx, valueDesc, scopeStack, skipBlanks: false, sameLine: true);
            tmpValue.desc = '$valueDesc';
            tgtList.add(tmpValue);
            if (ctx.isSameLine() && !ctx.matchAny([',', '，']) && !ctx.prematchAny([']', '］']))
              throw ctx.err.notFound('EOL');
          } else {
            final tgtFwv = FVVV();
            parseValue(ctx, scopeStack, tgtFwv, idxDesc, inList: true);

            if (tgtFwv._value is List)
              tgtList.addAll(tgtFwv._value as List);
            else if (tgtFwv._value != null)
              tgtList.add(tgtFwv._value);
            else
              tgtList.add(tgtFwv);

            if (listType == Null)
              listType = tgtList.last.runtimeType;
            else if (listType != tgtList.last.runtimeType) {
              if (listType == FVVV || tgtList.last.runtimeType == FVVV) throw ctx.err.valuePlusFVVV();
              switch (tgtList.last) {
                case String _:
                  listType = String;
                case double _:
                  if (listType != String) listType = double;
                case int _:
                  if (listType != String && listType != double) listType = int;
              }
            }
          }
          if (ctx.matchAny([']', '］'])) break;
        }
        if (listType != FVVV)
          tgtList = tgtList
              .map(
                (final item) => item.runtimeType == listType
                    ? item
                    // ignore: switch_on_type
                    : switch (listType) {
                        const (String) => '$item',
                        const (double) => switch (item) {
                            final int item => item.toDouble(),
                            final bool item => item ? 1.0 : 0.0,
                            _ => item
                          },
                        const (int) => switch (item) { final bool item => item ? 1 : 0, _ => item },
                        _ => item
                      },
              )
              .toList();
        // ignore: switch_on_type
        tgtKey._value = switch (listType) {
          const (FVVV) => tgtList.cast<FVVV>().toList(),
          const (String) => tgtList.cast<String>().toList(),
          const (double) => tgtList.cast<double>().toList(),
          const (int) => tgtList.cast<int>().toList(),
          const (bool) => tgtList.cast<bool>().toList(),
          _ => throw ctx.err.unknown()
        };
      } else if (ctx.matchAny(['{', '｛'])) {
        tgtKey._parseMain(ctx, scopeStack);
        if (!ctx.matchAny(['}', '｝'])) throw ctx.err.notFound('}');
      } else {
        parseValue(ctx, scopeStack, tgtKey, idxDesc);
        goto = true;
      }

      if (!goto) {
        parseDesc(ctx, idxDesc, scopeStack, skipBlanks: false, sameLine: true);
        if (ctx.isSameLine() && !ctx.isEof && !ctx.matchAny([';', '；']) && !ctx.prematchAny(['}', '｝']))
          throw ctx.err.notFound('EOL');
      }
      tgtKey.desc = '$idxDesc';
    }

    scopeStack.removeLast();
  }

  void _toStringRoot(final _FormatCtx ctx, final StringBuffer ret, final int level) {
    if (nodes.isEmpty) return;

    nodes.entries.forEachIndexed(
      (final idx, final entry) =>
          entry.value._toStringMain(ctx, entry.key, ret, level, idx == nodes.length - 1),
    );
  }

  void _toStringMain(
    final _FormatCtx ctx,
    String name,
    final StringBuffer ret,
    final int level,
    final bool isBack,
  ) {
    String escapeString(final String str, {required final bool isDesc, final bool fullWidth = false}) {
      final ret = StringBuffer();

      if (isDesc)
        ret.write('<');
      else
        ret.write(fullWidth ? '“' : '"');

      str.runes.forEach((final chc) {
        final ch = String.fromCharCode(chc);
        switch (ch) {
          case r'\':
            ret.write(r'\\');
          case '\b':
            ret.write(r'\b');
          case '\f':
            ret.write(r'\f');
          case '\n':
            ret.write(r'\n');
          case '\r':
            ret.write(r'\r');
          case '\t':
            ret.write(r'\t');
          case '"':
            if (!fullWidth && !isDesc)
              ret.write(r'\"');
            else
              ret.write(ch);
          case '”':
            if (fullWidth && !isDesc)
              ret.write(r'\”');
            else
              ret.write(ch);
          case '>':
            if (isDesc)
              ret.write(r'\>');
            else
              ret.write(ch);
          default:
            ret.write(ch);
        }
      });

      if (isDesc)
        ret.write('>');
      else
        ret.write(fullWidth ? '”' : '"');
      return '$ret';
    }

    void toStringValue(
      final _FormatCtx ctx,
      dynamic tgtVal,
      final StringBuffer ret,
      final String indent, [
      final int level = 0,
    ]) {
      switch (tgtVal) {
        case bool _:
          ret.write('$tgtVal');
        case num _:
          if (tgtVal is int && ctx.intBase != 10) {
            if (tgtVal == 0) {
              switch (ctx.intBase) {
                case 16:
                  ret.write('0x0');
                case 8:
                  ret.write('0o0');
                case 2:
                  ret.write('0b0');
              }
              return;
            }

            if (tgtVal < 0) ret.write('-');
            tgtVal = tgtVal.abs();

            switch (ctx.intBase) {
              case 2:
                ret.write('0b');
                ret.write(tgtVal.toRadixString(2));
              case 8:
                ret.write('0o');
                ret.write(tgtVal.toRadixString(8));
              case 16:
                ret.write('0x');
                ret.write(tgtVal.toRadixString(16));
            }
            return;
          }

          final rawNum = '$tgtVal';
          if (ctx.digitSepStep == 0) {
            ret.write(rawNum);
            return;
          }

          final parts = rawNum.split('.');
          var intPart = parts[0];
          var hasSign = false;
          if (intPart.startsWith('-') || intPart.startsWith('+')) {
            hasSign = true;
            intPart = intPart.substring(1);
          }
          final intLen = intPart.length;

          if (intLen <= ctx.digitSepStep) {
            ret.write(rawNum);
            return;
          }

          if (hasSign) ret.write(rawNum[0]);
          intPart.runes.forEachIndexed((final idx, final ch) {
            if (idx > 0 && (intLen - idx) % ctx.digitSepStep == 0) ret.write(ctx.digitSepChar);
            ret.write(ch);
          });

          if (parts.length >= 2)
            ret
              ..write('.')
              ..write(parts[1]);
        case String _:
          if (!ctx.minify &&
              ctx.rawStr &&
              tgtVal.length >= 3 &&
              !tgtVal.contains('`') &&
              tgtVal.trim().contains(RegExp(r'[\r\n]'))) {
            final strIndent = indent + ctx.indentUnit;

            tgtVal = tgtVal.unindent().trim();

            ret
              ..write('`')
              ..write(ctx.newline);
            const LineSplitter().convert(tgtVal).forEach((final line) {
              if (line.isNotEmpty) ret.write(strIndent);
              ret
                ..write(line)
                ..write(ctx.newline);
            });
            ret
              ..write(indent)
              ..write('`');
            return;
          }

          if (level == 0 && ctx.fullWidth && '$ret'[ret.length - 1] == ' ') {
            final tmpRet = '$ret'.substring(0, ret.length - 1);
            ret
              ..clear()
              ..write(tmpRet);
          }
          ret.write(escapeString(tgtVal, isDesc: false, fullWidth: ctx.fullWidth));
        case FVVV _:
          if (ctx.fwwStyle && tgtVal.desc.isNotEmpty) {
            ret.write(escapeString(tgtVal.desc, isDesc: true, fullWidth: ctx.fullWidth));
            if (!ctx.minify && !ctx.fullWidth) ret.write(' ');
          }
          ret.write(ctx.fwvBegin);
          if (!ctx.minify) ret.write(ctx.newline);
          tgtVal._toStringRoot(ctx, ret, level + 1);
          if (!ctx.minify)
            ret
              ..write(ctx.newline)
              ..write(indent);
          ret.write(ctx.fwvEnd);
          if (!ctx.noDescs && !ctx.fwwStyle && tgtVal.desc.isNotEmpty) {
            if (!ctx.minify && !ctx.fullWidth) ret.write(' ');
            ret.write(escapeString(tgtVal.desc, isDesc: true, fullWidth: ctx.fullWidth));
          }
      }
    }

    if (name.isEmpty || (_value is! String && isEmpty && nodes.isEmpty)) return;

    var tgtNode = this;
    if (ctx.flattenPaths) {
      final tmpName = StringBuffer(name);
      while (tgtNode.nodes.length == 1 &&
          (ctx.noDescs || tgtNode.desc.isEmpty) &&
          (ctx.noLinks || tgtNode.link.isEmpty)) {
        final nodePair = tgtNode.nodes.entries.first;

        tmpName
          ..write('.')
          ..write(nodePair.key);
        tgtNode = nodePair.value;
      }
      name = '$tmpName';
    }

    var indent = '';
    if (!ctx.minify && level > 0) {
      indent = ctx.indentUnit * level;
      ret.write(indent);
    }
    ret
      ..write(name)
      ..write(ctx.assignOp);

    if (!ctx.noLinks && tgtNode.link.isNotEmpty)
      ret.write(tgtNode.link);
    else if (tgtNode.nodes.isNotEmpty) {
      if (ctx.fwwStyle && tgtNode.desc.isNotEmpty) {
        ret.write(escapeString(tgtNode.desc, isDesc: true));
        if (!ctx.minify) ret.write(' ');
      }
      if (ctx.fullWidth && '$ret'[ret.length - 1] == ' ') {
        final tmpRet = '$ret'.substring(0, ret.length - 1);
        ret
          ..clear()
          ..write(tmpRet);
      }
      ret.write(ctx.fwvBegin);
      if (!ctx.minify) ret.write(ctx.newline);
      tgtNode._toStringRoot(ctx, ret, level + 1);
      if (!ctx.minify)
        ret
          ..write(ctx.newline)
          ..write(indent);
      ret.write(ctx.fwvEnd);
    } else if (tgtNode._value is! List)
      toStringValue(ctx, tgtNode._value, ret, indent);
    else {
      var multiline = false;
      if (!ctx.minify && !ctx.listSingle) {
        multiline = tgtNode._value is List<FVVV>;
        if (!multiline) {
          var longItems = 0;
          multiline = (tgtNode._value as List).any((final item) {
            switch (item) {
              case final String str:
                if (str.length + 2 >= 16) ++longItems;
              default:
                if ('$item'.length >= 16) ++longItems;
            }
            return longItems >= 6;
          });
        }
      }

      final valueIndent = indent + ctx.indentUnit;
      final valueLevel = level + 1;

      if (ctx.fullWidth && '$ret'[ret.length - 1] == ' ') {
        final tmpRet = '$ret'.substring(0, ret.length - 1);
        ret
          ..clear()
          ..write(tmpRet);
      }
      ret.write(ctx.listBegin);
      if (multiline) ret.write(ctx.newline);

      (tgtNode._value as List).forEachIndexed((final idx, final item) {
        if (multiline) ret.write(valueIndent);
        toStringValue(ctx, item, ret, valueIndent, valueLevel);
        if (multiline ? ctx.forceSep : idx != (tgtNode._value as List).length - 1) {
          ret.write(ctx.itemSep);
          if (!multiline && !ctx.fullWidth && !ctx.minify) ret.write(' ');
        }
        if (multiline) ret.write(ctx.newline);
      });

      if (multiline) ret.write(indent);
      ret.write(ctx.listEnd);
    }

    if (!ctx.noDescs &&
        tgtNode.desc.isNotEmpty &&
        ((tgtNode.nodes.isEmpty && (tgtNode._value is! List<FVVV>)) ||
            tgtNode.link.isNotEmpty ||
            !ctx.fwwStyle)) {
      if (!ctx.minify &&
          (!ctx.fullWidth ||
              tgtNode.link.isNotEmpty ||
              (tgtNode.nodes.isEmpty && tgtNode._value is! List && tgtNode._value is! String) ||
              (tgtNode._value is String && '$ret'[ret.length - 1] == '`'))) ret.write(' ');
      ret.write(escapeString(tgtNode.desc, isDesc: true));
    }

    if (ctx.minify || ctx.forceSep) ret.write(ctx.stmtSep);
    if (!ctx.minify && !isBack) ret.write(ctx.newline);
  }
}

abstract class FormatOpt {
  static const common = 0;

  static const useWrapper = 1 << 0;
  static const minify = 1 << 1;

  static const useCRLF = 1 << 2;
  static const useCR = 1 << 3;

  static const useSpace2 = 1 << 4;
  static const useSpace4 = 1 << 5;

  static const intBinary = 1 << 6;
  static const intOctal = 1 << 7;
  static const intHex = 1 << 8;

  static const digitSep3 = 1 << 9;
  static const digitSep4 = 1 << 10;

  static const useColon = 1 << 11;
  static const fullWidth = 1 << 12;

  static const keepListSingle = 1 << 13;
  static const forceUseSeparator = 1 << 14;
  static const rawMultilineString = 1 << 15;

  static const noDescs = 1 << 16;
  static const noLinks = 1 << 17;
  static const flattenPaths = 1 << 18;
  static const fwwStyle = 1 << 19;
}

// ignore: one_member_abstracts
abstract interface class FVVBinder {
  void field<T>(
    final String key,
    final T Function() getter,
    final void Function(T val) setter, {
    final FVVStruct Function()? factory,
  });
}

// ignore: one_member_abstracts
abstract interface class FVVStruct {
  void fields(final FVVBinder binder);
}

class _TextCtx {
  _TextCtx(this.input) {
    err = _ErrHandler(this);
    if (input.startsWith('\uFEFF')) index = 1;
  }

  final String input;
  var index = 0;
  final linesStart = [0];
  late final _ErrHandler err;

  String preview() => isEof ? '' : input[index];
  bool prematch(final String tgt) => input.startsWith(tgt, index);
  bool prematchAny(final List<String> tgts) => tgts.any(prematch);

  String next() {
    if (isEof) return '';
    final ch = input[index++];
    if (ch == '\r')
      linesStart.add(index);
    else if (ch == '\n') {
      if (index >= 2 && input[index - 2] == '\r')
        linesStart[linesStart.length - 1] = index;
      else
        linesStart.add(index);
    }
    return ch;
  }

  bool match(final String tgt, {final bool skipBlanks = true, final bool sameLine = false}) {
    if (skipBlanks) this.skipBlanks(sameLine: sameLine);
    if (prematch(tgt)) {
      index += tgt.length;
      return true;
    }
    return false;
  }

  bool matchAny(final List<String> tgts, {final bool skipBlanks = true, final bool sameLine = false}) =>
      tgts.any((final tgt) => match(tgt, skipBlanks: skipBlanks, sameLine: sameLine));

  void skipBlanks({final bool sameLine = false}) {
    while (!isEof && RegExp(r'\s').hasMatch(preview()))
      if (sameLine && prematchAny(['\n', '\r']))
        break;
      else
        next();
  }

  bool get isEof => index >= input.length;
  bool isSameLine() {
    final before = linesStart.length;
    skipBlanks();
    return before == linesStart.length;
  }
}

class ParseException implements Exception {
  ParseException(this.message);

  final String message;
  @override
  String toString() => 'ParseException: $message';
}

class _ErrHandler {
  _ErrHandler(this._ctx);

  final _TextCtx _ctx;

  ParseException _makeError(final String msg) =>
      ParseException('${_ctx.linesStart.length}:${_ctx.index - _ctx.linesStart.last + 1}: $msg');

  ParseException unknown() => _makeError('Why??? IDK!!!');
  ParseException whyEOF() => _makeError('Why EOF???');
  ParseException whyNotEOF() => _makeError('Why not EOF???');
  ParseException notFound(final String tgt) =>
      _makeError("Where is the ${tgt.runes.length > 1 ? tgt : "'$tgt'"}?");
  ParseException noValue(final String tgt) => _makeError("Cannot find the value of '$tgt'");
  ParseException plusList() => _makeError('Why plus with list?');
  ParseException valuePlusFVVV() => _makeError('Why value plus with FVVV?');
}

class _FormatCtx {
  _FormatCtx(final int flags) {
    if ((flags & FormatOpt.useWrapper) != 0) useWrapper = true;

    if ((flags & FormatOpt.useCRLF) != 0)
      newline = '\r\n';
    else if ((flags & FormatOpt.useCR) != 0) newline = '\r';

    if ((flags & FormatOpt.useSpace2) != 0)
      indentUnit = '  ';
    else if ((flags & FormatOpt.useSpace4) != 0) indentUnit = '    ';

    if ((flags & FormatOpt.intHex) != 0)
      intBase = 16;
    else if ((flags & FormatOpt.intOctal) != 0)
      intBase = 8;
    else if ((flags & FormatOpt.intBinary) != 0) intBase = 2;

    if ((flags & FormatOpt.digitSep3) != 0)
      digitSepStep = 3;
    else if ((flags & FormatOpt.digitSep4) != 0) digitSepStep = 4;

    fullWidth = (flags & FormatOpt.fullWidth) != 0;
    if (fullWidth) {
      if ((flags & FormatOpt.useColon) != 0) assignOp = '：';
      listBegin = '［';
      listEnd = '］';
      fwvBegin = '｛';
      fwvEnd = '｝';
      itemSep = '，';
      stmtSep = '；';
      if (digitSepStep > 0) digitSepChar = '’';
    } else {
      if ((flags & FormatOpt.useColon) != 0) assignOp = ': ';
      if (digitSepStep > 0) digitSepChar = "'";
    }

    listSingle = (flags & FormatOpt.keepListSingle) != 0;
    forceSep = (flags & FormatOpt.forceUseSeparator) != 0;
    rawStr = (flags & FormatOpt.rawMultilineString) != 0;

    noDescs = (flags & FormatOpt.noDescs) != 0;
    noLinks = (flags & FormatOpt.noLinks) != 0;
    flattenPaths = (flags & FormatOpt.flattenPaths) != 0;
    fwwStyle = (flags & FormatOpt.fwwStyle) != 0;

    minify = (flags & FormatOpt.minify) != 0;
    if (minify) {
      newline = '';
      indentUnit = '';

      assignOp = assignOp.trim();
    }
  }

  var newline = '\n';
  var indentUnit = '\t';
  var assignOp = ' = ';
  var listBegin = '[', listEnd = ']';
  var fwvBegin = '{', fwvEnd = '}';
  var itemSep = ',', stmtSep = ';';

  var intBase = 10;

  var digitSepStep = 0;
  var digitSepChar = '';

  var useWrapper = false;

  var minify = false;

  var fullWidth = false;

  var listSingle = false;
  var forceSep = false;
  var rawStr = false;

  var noDescs = false, noLinks = false;

  var flattenPaths = false;
  var fwwStyle = false;
}

class _ReaderBinder implements FVVBinder {
  _ReaderBinder(this.node);

  final FVVV node;

  @override
  void field<T>(
    final String key,
    final T Function() getter,
    final void Function(T val) setter, {
    final FVVStruct Function()? factory,
  }) {
    final tgtNode = node.nodes[key];
    if (tgtNode == null) return;
    final target = getter();

    if (target is FVVStruct)
      tgtNode.to(target);
    else if (factory != null && target is List<FVVStruct> && tgtNode._value is List<FVVV>) {
      target.clear();
      (tgtNode._value as List<FVVV>)
          .forEach((final item) => target.add(factory()..fields(_ReaderBinder(item))));
    } else
      setter(tgtNode._value as T);
  }
}

class _WriterBinder implements FVVBinder {
  _WriterBinder(this.node);

  final FVVV node;

  @override
  void field<T>(
    final String key,
    final T Function() getter,
    final void Function(T val) setter, {
    final FVVStruct Function()? factory,
  }) {
    final target = getter();
    final tmpNode = FVVV();
    if (target is FVVStruct)
      target.fields(_WriterBinder(tmpNode));
    else if (target is List<FVVStruct>)
      tmpNode._value = target.map((final item) {
        final idxNode = FVVV();
        item.fields(_WriterBinder(idxNode));
        return idxNode;
      }).toList();
    else
      tmpNode._value = target;
    node.nodes[key] = tmpNode;
  }
}
