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

extension _FVVStrBfExt on StringBuffer {
  void removeLastChar() {
    var result = '$this';
    if (result.isEmpty) return;
    result = result.substring(0, result.length - 1);
    clear();
    write(result);
  }
}

class _FVVVDat {
  _FVVVDat({
    final StringBuffer? valueName,
    final String? idxDesc,
    final List<String>? valueNames,
    final List<String>? groupNames,
    final List<List<String>>? lastGroupNames,
    final List<FVVV>? tmpFvvs,
    final bool? inValue,
    final bool? inList,
    final bool? isList,
    final int? groupNum,
    final FVVV? rootKey,
  })  : valueName = valueName ?? StringBuffer(),
        idxDesc = idxDesc ?? '',
        valueNames = valueNames ?? [],
        groupNames = groupNames ?? [],
        lastGroupNames = lastGroupNames ?? [],
        tmpFVVs = tmpFvvs ?? [],
        inValue = inValue ?? false,
        inList = inList ?? false,
        isList = isList ?? false,
        groupNum = groupNum ?? 0,
        rootKey = rootKey ?? FVVV() {
    idxKey = this.rootKey;
  }

  StringBuffer valueName;
  String idxDesc;
  List<String> valueNames;
  List<String> groupNames;
  List<List<String>> lastGroupNames;
  List<FVVV> tmpFVVs;
  bool inValue, inList, isList;
  int groupNum;
  FVVV rootKey;
  late FVVV idxKey;
}

class FVVV {
  FVVV([this.value, final Map<String, FVVV>? sub, this.desc = '', this.link = '']) : sub = sub ?? {};
  dynamic value;
  Map<String, FVVV> sub;
  String desc, link;

  FVVV operator [](final String key) => sub.putIfAbsent(key, FVVV.new);
  void operator []=(final String key, final dynamic val) =>
      sub.containsKey(key) ? sub[key]!.value = val : sub[key] = FVVV(val);
  @override
  bool operator ==(final other) =>
      identical(this, other) || (other is FVVV && value == other.value && sub == other.sub);

  @override
  int get hashCode => (value ?? sub).hashCode;
  @override
  String toString() => '${value ?? sub}';

  T? as<T>([final T? dfltVal]) {
    if (value is T) return value as T;
    if (value is FVVV) return (value as FVVV).as<T>(dfltVal) as T;
    return dfltVal;
  }

  bool asBool([final bool dfltVal = false]) => as<bool>() ?? dfltVal;
  int asInt([final int dfltVal = 0]) => as<int>() ?? dfltVal;
  double asDouble([final double dfltVal = 0]) => as<double>() ?? dfltVal;
  String asString([final String dfltVal = '']) => as<String>() ?? dfltVal;
  List<bool> asBools([final List<bool>? dfltVal]) => (as<List<bool>>() ?? dfltVal ?? []).toList();
  List<int> asInts([final List<int>? dfltVal]) => (as<List<int>>() ?? dfltVal ?? []).toList();
  List<double> asDoubles([final List<double>? dfltVal]) => (as<List<double>>() ?? dfltVal ?? []).toList();
  List<String> asStrings([final List<String>? dfltVal]) => (as<List<String>>() ?? dfltVal ?? []).toList();
  List<FVVV> asFVVVs([final List<FVVV>? dfltVal]) => (as<List<FVVV>>() ?? dfltVal ?? []).toList();
  List<bool> asBoolsRef([final List<bool>? dfltVal]) => as<List<bool>>() ?? dfltVal ?? [];
  List<int> asIntsRef([final List<int>? dfltVal]) => as<List<int>>() ?? dfltVal ?? [];
  List<double> asDoublesRef([final List<double>? dfltVal]) => as<List<double>>() ?? dfltVal ?? [];
  List<String> asStringsRef([final List<String>? dfltVal]) => as<List<String>>() ?? dfltVal ?? [];
  List<FVVV> asFVVVsRef([final List<FVVV>? dfltVal]) => as<List<FVVV>>() ?? dfltVal ?? [];

  bool get isEmpty {
    if (value == null) return true;
    if (value is String) return (value as String).isEmpty;
    if (value is List) return (value as List).isEmpty;
    if (value is FVVV) return (value as FVVV).isEmpty;
    return false;
  }

  bool get isNotEmpty => !isEmpty;

  bool isType<T>() => getType() is T;
  Type getType() => value is FVVV ? (value as FVVV).getType() : value.runtimeType;

  String print([final String type = 'common', final int indentLv = 0]) {
    var isMin = false, isBiglist = false, isNodesc = false;
    switch (type) {
      case 'min':
        isMin = true;
      case 'biglist':
        isBiglist = true;
      case 'nodesc':
        isNodesc = true;
    }
    final result = StringBuffer();
    var printFunc = (final String path, final FVVV node, final int indentLv) {};
    printFunc = (final path, final node, final indentLv) {
      if (path.isEmpty || (node.isEmpty && node.sub.isEmpty)) return;
      final indent = ' ' * indentLv * 2;
      if (node.sub.isNotEmpty && node.link.isEmpty) {
        if (isMin)
          result.write('$path={');
        else
          result.write('$indent$path = {\n');
      }
      if (node.link.isNotEmpty || node.value != null) {
        if (isMin)
          result.write('$path=');
        else
          result.write('$indent$path = ');
        if (node.link.isNotEmpty)
          result.write(node.link);
        else {
          switch (node.value) {
            case final String v:
              result.write('"${v.replaceAll('"', r'\"')}"');
            case List<dynamic> _:
              final listIndent = ' ' * (indentLv + 1) * 2;
              void writeList<T>(
                final List<T> list,
                final void Function(T) printer,
              ) {
                for (final value in list) {
                  if (isBiglist) result.write(listIndent);
                  printer(value);
                  if (isBiglist)
                    result.writeln();
                  else {
                    result.write(',');
                    if (!isMin) result.write(' ');
                  }
                }
              }
              result.write('[');
              if (isBiglist || node.value is List<FVVV>) result.writeln();
              switch (node.value) {
                case final List<String> v:
                  writeList(v, (final value) => result.write('"${value.replaceAll('"', r'\"')}"'));
                case final List<FVVV> v:
                  for (final value in v) {
                    if (!isMin) result.write(listIndent);
                    result.write('{');
                    if (!isMin) result.writeln();
                    result.write(value.print(type, indentLv + 2));
                    if (isMin)
                      result.write(';}');
                    else {
                      result
                        ..writeln()
                        ..write(listIndent)
                        ..write('}');
                    }
                    if (value.desc.isNotEmpty) {
                      if (!isMin) result.write(' ');
                      result.write('<${value.desc.replaceAll('>', r'\>')}>');
                    }
                    if (isMin)
                      result.write(',');
                    else
                      result.writeln();
                  }
                default:
                  writeList(node.value as List, result.write);
              }
              if (isBiglist || node.value is List<FVVV>)
                result.write(indent);
              else if ((node.value as List).isNotEmpty) {
                result.removeLastChar();
                if (!isMin) result.removeLastChar();
              }
              result.write(']');
            default:
              result.write(node.value);
          }
        }
      } else
        node.sub.forEach((final String key, final FVVV value) => printFunc(key, value, indentLv + 1));
      if (node.sub.isNotEmpty && node.link.isEmpty) {
        if (!isMin) result.write(indent);
        result.write('}');
      }
      if (node.desc.isNotEmpty && !isMin && !isNodesc)
        result.write(' <${node.desc.replaceAll('>', r'\>')}>');
      if (isMin)
        result.write(';');
      else
        result.writeln();
    };
    sub.forEach((final String key, final FVVV value) => printFunc(key, value, indentLv));
    return '${result..removeLastChar()}';
  }

  void addFromString(String txt) {
    if (txt.startsWith('\u{FEFF}')) txt = txt.substring(1);
    txt = txt.trim().replaceAll(RegExp(r'\r\n|\r'), '\n');
    if (txt.isEmpty) return;
    if (String.fromCharCode(txt.runes.last) != '}') txt += '\n';

    bool eqOr<T>(final List<T> values) {
      if (values.isEmpty) return false;
      final first = values[0];
      for (var i = 1; i < values.length; i++) if (first == values[i]) return true;
      return false;
    }

    FVVV getKey(final List<String> paths, final FVVV rootKey) {
      var tmpKey = rootKey;
      for (final path in paths) tmpKey = tmpKey[path];
      return tmpKey;
    }

    FVVV? findKey(final String path, final List<_FVVVDat> stackDat) {
      final tmpNames = path.trim().split('.');
      late FVVV? tmpKey;
      for (var idx = stackDat.length - 1; idx >= 0; idx--) {
        final idxDat = stackDat[idx];
        tmpKey = idxDat.idxKey;
        for (final key in tmpNames)
          if (tmpKey?.sub.containsKey(key) ?? false)
            tmpKey = tmpKey![key];
          else {
            tmpKey = idxDat.rootKey;
            for (final key in tmpNames)
              if (tmpKey?.sub.containsKey(key) ?? false)
                tmpKey = tmpKey![key];
              else {
                tmpKey = null;
                break;
              }
            break;
          }
        if (tmpKey != null) return tmpKey;
      }
      return null;
    }

    final tmpDesc = StringBuffer(), value = StringBuffer();
    final values = <String>[];
    var oldFVV = false,
        endGroup = false,
        isRealChar = false,
        inDesc = false,
        inStr = false,
        isStr = false,
        isAllStr = false,
        isEmptyStr = false;
    var idxChar = '', lastChar = '';
    var idx = 0;
    final fvvStack = [_FVVVDat(rootKey: this)];
    for (final rune in txt.runes) {
      idxChar = String.fromCharCode(rune);
      isRealChar = lastChar != r'\';
      final idxDat = fvvStack.last;
      idxDat.idxKey = idxDat.rootKey;
      if ((() {
        if (inDesc) {
          if (idxChar != '>' || !isRealChar) {
            if (idxChar == '>') tmpDesc.removeLastChar();
            if (idxDat.inValue || idxDat.groupNum > 0) tmpDesc.write(idxChar);
            return false;
          } else {
            idxDat.idxDesc = '$tmpDesc';
            tmpDesc.clear();
            inDesc = false;
            return false;
          }
        } else {
          if (!inStr && eqOr([idxChar, ' ', '\t'])) return false;
          if (idxChar == '<') {
            inDesc = true;
            return false;
          }
        }
        if (idxDat.inValue) {
          if (inStr) {
            if (idxChar == '"') {
              if (isRealChar) {
                isEmptyStr = value.isEmpty;
                inStr = false;
                return false;
              } else {
                value
                  ..removeLastChar()
                  ..write(idxChar);
                return false;
              }
            } else {
              value.write(idxChar);
              return false;
            }
          } else {
            if (idxChar == '"') {
              inStr = isStr = isAllStr = true;
              return false;
            } else if (idxChar == '[') {
              idxDat.inList = idxDat.isList = true;
              return false;
            } else if (idxDat.inList && idxChar == '{') {
              fvvStack.add(_FVVVDat());
              return false;
            } else if (idxDat.inList && eqOr([idxChar, ',', ']', '\n'])) {
              if (idxChar == ']') {
                idxDat.inList = false;
                var pos = idxChar.length;
                var inListDesc = false;
                for (;;) {
                  if (() {
                    switch (txt[idx - pos]) {
                      case '<':
                        if (!inListDesc) return true;
                        if (idx - pos < 1 || txt[idx - pos - 1] != r'\') inListDesc = false;
                        return false;
                      case '>':
                        inListDesc = true;
                        return false;
                      case ' ':
                      case '\t':
                        return false;
                      case ',':
                      case '\n':
                      default:
                        return !inListDesc;
                    }
                  }()) break;
                  pos++;
                }
                if (txt[idx - pos] == ',' || txt[idx - pos] == '\n') return false;
              } else if (idxDat.tmpFVVs.isEmpty && value.isEmpty && (!isAllStr || !isEmptyStr))
                return false;
              final valueStr = '$value';
              if ((isAllStr && isStr) ||
                  eqOr([valueStr, 'true', 'false']) ||
                  int.tryParse(valueStr) != null ||
                  double.tryParse(valueStr) != null) {
                values.add(valueStr);
              } else {
                idxDat.idxKey = getKey([valueStr], getKey(idxDat.groupNames, idxDat.idxKey));
                if (idxDat.idxKey.isNotEmpty) {
                  switch (idxDat.idxKey.value) {
                    case final List<FVVV> v:
                      idxDat.tmpFVVs.addAll(v.toList());
                    case final List<dynamic> v:
                      values.addAll(v.map((final v) => '$v'));
                    default:
                      values.add('${idxDat.idxKey.value}');
                  }
                }
              }
              if (idxDat.tmpFVVs.isNotEmpty && idxDat.idxDesc.isNotEmpty) {
                idxDat.tmpFVVs.last.desc = idxDat.idxDesc;
                idxDat.idxDesc = '';
              }
              if (isEmptyStr)
                isEmptyStr = false;
              else
                value.clear();
              isStr = false;
              return false;
            } else if (idxChar == '{') {
              idxDat.groupNames.addAll(idxDat.valueNames);
              idxDat.lastGroupNames.add(idxDat.valueNames.toList());
              idxDat.valueNames.clear();
              idxDat.groupNum++;
              idxDat.inValue = false;
              return false;
            } else if (!idxDat.inList && eqOr([idxChar, ';', '\n'])) {
              idxDat.idxKey = getKey(idxDat.valueNames, getKey(idxDat.groupNames, idxDat.rootKey));
              if (idxDat.isList) {
                if (values.isEmpty && idxDat.tmpFVVs.isEmpty)
                  idxDat.idxKey.value = null;
                else if (idxDat.tmpFVVs.isNotEmpty)
                  idxDat.idxKey.value = idxDat.tmpFVVs.toList();
                else if (isAllStr)
                  idxDat.idxKey.value = values.toList();
                else {
                  final tmpStr = values[0];
                  if (eqOr([tmpStr, 'true', 'false'])) {
                    final tmps = <bool>[];
                    for (final s in values) tmps.add(s == 'true');
                    idxDat.idxKey.value = tmps;
                  } else if (int.tryParse(tmpStr) != null) {
                    final tmps = <int>[];
                    for (final s in values) tmps.add(int.tryParse(s)!);
                    idxDat.idxKey.value = tmps;
                  } else if (double.tryParse(tmpStr) != null) {
                    final tmps = <double>[];
                    for (final s in values) tmps.add(double.tryParse(s)!);
                    idxDat.idxKey.value = tmps;
                  }
                }
              } else {
                final valueStr = '$value';
                if (isAllStr)
                  idxDat.idxKey.value = valueStr;
                else if (eqOr([valueStr, 'true', 'false']))
                  idxDat.idxKey.value = valueStr == 'true';
                else if (int.tryParse(valueStr) != null)
                  idxDat.idxKey.value = int.tryParse(valueStr);
                else if (double.tryParse(valueStr) != null)
                  idxDat.idxKey.value = double.tryParse(valueStr);
                else {
                  final tmpKey = findKey(valueStr, fvvStack);
                  if (tmpKey != null && (tmpKey.isNotEmpty || tmpKey.sub.isNotEmpty)) {
                    if (tmpKey.sub.isEmpty)
                      idxDat.idxKey.value = tmpKey.value;
                    else
                      idxDat.idxKey.sub = tmpKey.sub;
                    idxDat.idxKey.link = valueStr;
                  }
                }
              }
              idxDat.idxKey.desc = idxDat.idxDesc;
              idxDat.idxDesc = '';
              value.clear();
              values.clear();
              idxDat.valueNames.clear();
              idxDat.tmpFVVs.clear();
              idxDat.inValue = isStr = isAllStr = idxDat.isList = false;
              return false;
            } else {
              value.write(idxChar);
              return false;
            }
          }
        } else if (!oldFVV && idxChar == '{' && idxDat.valueName.isEmpty) {
          oldFVV = true;
          return false;
        } else if (idxChar == '=') {
          idxDat.valueNames = '${idxDat.valueName}'.trim().split('.');
          idxDat.valueName.clear();
          idxDat.inValue = true;
          return false;
        } else if (endGroup && eqOr([idxChar, ';', '\n']) && idxDat.groupNum > 0) {
          endGroup = false;
          if (idxDat.idxDesc.isNotEmpty) {
            getKey(idxDat.groupNames, idxDat.rootKey).desc = idxDat.idxDesc;
            idxDat.idxDesc = '';
          }
          for (final _ in idxDat.lastGroupNames.last)
            idxDat.groupNames = idxDat.groupNames.sublist(0, idxDat.groupNames.length - 1);
          idxDat.lastGroupNames = idxDat.lastGroupNames.sublist(
            0,
            idxDat.lastGroupNames.length - 1,
          );
          idxDat.groupNum--;
          return false;
        } else if (idxChar == '}') {
          if (idxDat.groupNum == 0) {
            if (fvvStack.length > 1) {
              final targetFVVV = fvvStack.last.rootKey;
              fvvStack.removeLast();
              fvvStack.last.tmpFVVs.add(targetFVVV);
              return false;
            } else
              return true;
          } else {
            endGroup = true;
            return false;
          }
        } else {
          idxDat.valueName.write(idxChar);
          return false;
        }
      })()) break;
      idx += idxChar.length;
      lastChar = idxChar;
    }
  }
}
