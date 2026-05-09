class Channel {
  final String name;
  final String url;
  final String logo;
  final Map<String, String> headers;

  const Channel({
    required this.name,
    required this.url,
    required this.logo,
    this.headers = const <String, String>{},
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return Channel(
      name: json['name'] ?? 'Unknown Channel',
      url: json['url'] ?? '',
      logo: json['logo'] ?? '',
      headers: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'url': url, 'logo': logo, 'headers': headers};
  }
}
