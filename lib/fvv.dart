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
  void operator []=(final String key, final dynamic val) => this[key].value = val;
  dynamic get value => _value;
  set value(final dynamic val) => _value = val is FVVV ? val._value : val;
  @override
  bool operator ==(final other) =>
      identical(this, other) ||
      (other is FVVV &&
          _value == other._value &&
          const MapEquality<String, FVVV>().equals(other.nodes, nodes));
  @override
  int get hashCode => Object.hash(_value, const MapEquality<String, FVVV>().hash(nodes));

  @override
  String toString() => '${_value ?? nodes}';

  bool get isEmpty => switch (_value) {
        null => true,
        final String str => str.isEmpty,
        final List<dynamic> list => list.isEmpty,
        _ => false
      };

  bool get isNotEmpty => !isEmpty;

  bool isType<T>() => _value is T;
  Type get type => _value.runtimeType;

  T? as<T>([final T? defaultValue]) => _value is T ? _value as T : defaultValue;
  T get<T>() => as()!;
  List<T> list<T>(final List<T>? defaultValue) => as(defaultValue) ?? <T>[];

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
  void parseString(final String text) {
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
  }

  void _parseMain(final _TextCtx ctx, final List<FVVV> scopeStack) {
    FVVV? findKey(final String path, final List<FVVV> scopeStack) {
      final paths = path.split('.');
      if (paths.isEmpty) return null;
      FVVV? target;
      for (final index in scopeStack.reversed) {
        target = index;
        for (final idxPath in paths) {
          if (target!.nodes.containsKey(idxPath))
            target = target[idxPath];
          else {
            target = null;
            break;
          }
        }
        if (target != null) return target;
      }
      return null;
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
        if (ctx.match('<', sameLine: sameLine)) {
          desc.clear();
          for (;;) {
            if (ctx.isEof) throw ctx.err.whyEOF();
            if (ctx.match('>', skipBlanks: false)) {
              final target = findKey('$desc', scopeStack);
              if (target != null && target.isType<String>()) {
                desc
                  ..clear()
                  ..write(target.get<String>());
              }
              break;
            }
            if (ctx.match(r'\', skipBlanks: false)) {
              if (ctx.isEof) throw ctx.err.whyEOF();
              if (ctx.match('>', skipBlanks: false))
                desc.write('>');
              else {
                final ch = ctx.next();
                final chc = ch.codeUnitAt(0), tgt = (chc < 1 << 8) ? _escapeTable[chc] : 0;
                if (tgt != 0)
                  desc.writeCharCode(tgt);
                else
                  desc.writeAll([r'\', ch]);
              }
            } else
              desc.write(ctx.next());
          }
        } else {
          if (!skipBlanks) {
            ctx.index = origIdx;
            while (ctx.linesStart.length > origLine) ctx.linesStart.removeLast();
          }
          break;
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
            final ch = ctx.next();
            final chc = ch.codeUnitAt(0), tgt = (chc < 256) ? _escapeTable[chc] : 0;
            if (tgt != 0)
              text.writeCharCode(tgt);
            else
              text.writeAll([r'\', ch]);
          }
        } else
          text.write(ctx.next());
      }
    }

    num? tryParseNumber(String tgtStr) {
      if (tgtStr.isEmpty) return null;
      tgtStr = tgtStr.replaceAll("'", '').replaceAll('’', '');
      if (tgtStr.isEmpty) return null;

      var sign = 1;
      var idx = 0;
      if (tgtStr.startsWith('-')) {
        sign = -1;
        idx++;
      } else if (tgtStr.startsWith('+')) idx++;

      var radix = 10;
      if (idx < tgtStr.length && tgtStr[idx] == '0' && idx + 1 < tgtStr.length)
        switch (tgtStr[idx + 1]) {
          case 'x' || 'X':
            radix = 16;
            idx = idx + 2;
          case 'o' || 'O':
            radix = 8;
            idx = idx + 2;
          case 'b' || 'B':
            radix = 2;
            idx = idx + 2;
          case '0' || '1' || '2' || '3' || '4' || '5' || '6' || '7':
            radix = 8;
            idx++;
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
                : !ctx.isSameLine() || ctx.matchAny([';', '；']))) throw ctx.err.notFound('value');

        final tmpSb = StringBuffer();
        String tmpStr;
        if (ctx.prematchAny(['"', '“', '`'])) {
          parseText(ctx, tmpSb);
          tmpStr = '$tmpSb';
          if (tgtFwv._value == null)
            tgtFwv._value = tmpStr;
          else
            tgtFwv
              ..link = ''
              .._value = '${tgtFwv._value}$tmpStr';
        } else {
          while (!ctx.isEof && !ctx.prematchAny(['<', '+']) && !ctx.prematchAny(['\r', '\n']))
            if (inList ? ctx.prematchAny([',', '，', ']', '］']) : ctx.prematchAny([';', '；']))
              break;
            else
              tmpSb.write(ctx.next());
          tmpStr = '$tmpSb'.trimRight();
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
            (inList ? ctx.matchAny([',', '，']) || ctx.prematchAny([']', '］']) : ctx.matchAny([';', '；'])))
          return;

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
        if (listType == Null) throw ctx.err.notFound('value');
        if (listType != FVVV) {
          tgtList = tgtList
              .map(
                (final item) => item.runtimeType == listType
                    ? item
                    : switch (listType) {
                        const (String) => '$item',
                        const (double) => switch (item) {
                            final int item => item.toDouble(),
                            final bool item => item ? 1.0 : 0.0,
                            _ => item
                          },
                        const (int) => switch (item) { final bool item => item ? 1 : 0, _ => item },
                        const (bool) => item as bool,
                        _ => throw ctx.err.unknown()
                      },
              )
              .toList();
        }
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
        if (ctx.isSameLine() && !ctx.isEof && !ctx.matchAny([';', '；'])) throw ctx.err.notFound('EOL');
      }
      tgtKey.desc = '$idxDesc';
    }

    scopeStack.removeLast();
  }
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
    return linesStart.length == before;
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
