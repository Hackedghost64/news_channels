import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class ChannelService {
  static const String _url = 'https://raw.githubusercontent.com/Hackedghost64/news_channels/main/channels.json';

  Future<List<Channel>> fetchChannels() async {
    try {
      final response = await http.get(Uri.parse(_url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load channels: ${response.statusCode}');
      }
    } catch (e) {
      // In a real app, we might want to log this or return a cached version
      print('Error fetching channels: $e');
      rethrow;
    }
  }
}
