import 'dart:convert';
import 'package:json_path/json_path.dart';
import 'package:logging/logging.dart';
import 'package:to_json/yaml_parser_base.dart';
import 'package:to_json/yaml_rule_factory.dart';
import 'package:yaml/yaml.dart';

class YamlJsonParser extends Parser {

  final _log = Logger('YamlJsonParser');

  @override
  Future<String> parseUseYaml(
      String content, YamlMap doc, String pageName) async {
    _log.info("jsonStr=$content");
    YamlMap? page = doc[pageName];
    if (page == null) {
      throw "pageName不存在";
    }
    var jsonContent = jsonDecode(content);
    //解析文本拿到结果
    YamlMap onParseResult = page["onParseResult"];
    String json = jsonEncode(_recursionQuery(jsonContent, "", onParseResult));
    _log.fine("json=$json");
    return json;
  }

  dynamic _recursionQuery(
      Map<String, dynamic> json, String pJPath, YamlMap rule, {int? index}) {
    String? dataType;
    for (var element in rule.keys) {
      if (element.toString() == "list" || element.toString() == "object") {
        dataType = element.toString();
        break;
      }
    }
    _log.fine("dataType=$dataType");
    switch (dataType) {
      case "object":
        YamlMap contentRule = rule[dataType];
        _log.fine("contentRule=$contentRule");
        var object = {};
        contentRule.forEach((key, value) {
          dynamic result = _recursionQuery(json, pJPath, value);
          _log.fine("propName=$key;propValue=$result");
          object[key] = result;
        });
        return object;
      case "list":
        YamlMap contentRule = rule[dataType];
        _log.fine("contentRule=$contentRule");

        YamlMap getNodesRule = contentRule["getNodes"];
        String? listJpath = _getJsonPath(getNodesRule);
        _log.fine("listJpath=$listJpath");
        listJpath = listJpath ?? "";
        String queryJPath = _formatJsonPath(pJPath, listJpath, index);

        List<dynamic> jsonList = _jsonPathN(json, queryJPath);
        YamlMap foreachRule = contentRule["foreach"];

        var list = [];
        _log.fine("listList=$jsonList");
        for (int i = 0; i < jsonList.length; i++) {
          var item = {};
          foreachRule.forEach((key, value) {
            _log.fine("propName=$key;value=$value");
            dynamic result =
                _recursionQuery(json, queryJPath, value, index: i);
            _log.fine("propName=$key;propValue=$result");
            item[key] = result;
          });
          list.add(item);
        }
        _log.fine("result=${list.toString()}");
        return list;
      default:
        return _queryOne(json, pJPath, rule, index: index);
    }
  }

  @override
  Future<String> preprocess(String content, YamlMap preprocessNode) async {
    var json = jsonDecode(content);
    return _queryOne(json, "", preprocessNode);
  }

  String? _getJsonPath(YamlMap rule) {
    _log.fine("getJPath:rule=$rule");
    String? jpath = rule["jsonpath"];
    return jpath;
  }

  List<dynamic> _jsonPathN(Map<String, dynamic> json, String jpath) {
    JsonPath jsonPath = JsonPath(jpath);
    _log.fine("jsonPath.read(json)=${jsonPath.read(json)}");
    List<dynamic> jsonList =
        jsonPath.read(json).elementAt(0).value as List<dynamic>;
    return jsonList;
  }

  Object? _jsonPathOne(Map<String, dynamic> json, String jpath) {
    JsonPath jsonPath = JsonPath(jpath);
    return jsonPath.read(json).elementAt(0).value;
  }

  String _formatJsonPath(String pJPath, String curJPath, int? index) {
    if (index == null) {
      return "$pJPath$curJPath";
    } else {
      return "$pJPath[$index]$curJPath";
    }
  }

  /// 查找单个
  /// 分为三步，每一步都返回一个字符串
  String _queryOne(Map<String, dynamic> json, String pJPath, YamlMap yamlMap,
      {int? index}) {
    _log.fine("pJPath=$pJPath");
    String result = "";
    //第一步，定位元素并获取值
    result = _get(json, pJPath, index, yamlMap['get']);
    _log.fine("get=$result");
    result = handleResult(result, yamlMap);
    return result;
  }

  String _get(Map<String, dynamic> json, String pJPath, int? index, YamlMap yamlMap) {
    String? jsonPath = _getJsonPath(yamlMap);
    String defaultValue = yamlMap['default'] ?? "";
    if (jsonPath == null) defaultValue;
    String queryJPath = _formatJsonPath(pJPath, jsonPath!, index);
    _log.fine("_get queryJPath=$queryJPath");
    var result = _jsonPathOne(json, queryJPath);
    //没查找到数据用默认结果
    if (result == null || result.toString().isEmpty) {
      return defaultValue;
    }
    return result.toString();
  }

}
