import 'package:flutter/foundation.dart';

class Channel {
  final String name;
  final String url;
  final String logo;

  Channel({
    required this.name,
    required this.url,
    required this.logo,
  });

  String get streamUrl {
    if (kIsWeb && url.isNotEmpty) {
      // Use a CORS proxy for web debugging
      return 'https://corsproxy.io/?' + Uri.encodeComponent(url);
    }
    return url;
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] ?? 'Unknown Channel',
      url: json['url'] ?? '',
      logo: json['logo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'logo': logo,
    };
  }
}
