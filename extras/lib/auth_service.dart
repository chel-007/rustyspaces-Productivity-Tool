import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static Future<String?> silentAuth() async {
    try {
      final response = await http.post(Uri.parse('/auth/silent'));
      if (response.statusCode == 200) {
        return json.decode(response.body);

        print(response.body);
      }
    } catch (e) {
      print('Authentication failed: $e');
    }
    return null;
  }
}
