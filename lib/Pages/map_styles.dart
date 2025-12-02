import 'package:flutter/services.dart' show rootBundle;

class MapStyles {
  static Future<String> getStyle(String path) async {
    return await rootBundle.loadString(path);
  }
}
