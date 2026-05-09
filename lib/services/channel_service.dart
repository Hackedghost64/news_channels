import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/channel_catalog.dart';

abstract class ChannelRepository {
  Future<ChannelCatalog> fetchChannels();
}

class ChannelService implements ChannelRepository {
  ChannelService({
    http.Client? client,
    AssetBundle? bundle,
    String? remoteUrl,
    this.localAssetPath = 'channels.json',
  }) : _client = client ?? http.Client(),
       _bundle = bundle ?? rootBundle,
       _remoteUrl = remoteUrl ?? _defaultRemoteUrl;

  static const String _defaultRemoteUrl =
      'https://raw.githubusercontent.com/Hackedghost64/news_channels/main/channels.json';

  final http.Client _client;
  final AssetBundle _bundle;
  final String _remoteUrl;
  final String localAssetPath;

  @override
  Future<ChannelCatalog> fetchChannels() async {
    try {
      final response = await _client
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return ChannelCatalog(
          channels: _parseChannels(response.body),
          source: ChannelDataSource.remote,
        );
      }

      throw Exception(
        'Failed to load remote channels: HTTP ${response.statusCode}',
      );
    } catch (remoteError, stackTrace) {
      debugPrint('REMOTE_CHANNEL_LOAD_ERROR: $remoteError');
      debugPrintStack(stackTrace: stackTrace);

      try {
        final jsonString = await _bundle.loadString(localAssetPath);
        return ChannelCatalog(
          channels: _parseChannels(jsonString),
          source: ChannelDataSource.asset,
          warning: 'Using bundled channels because remote loading failed.',
        );
      } catch (assetError, assetStackTrace) {
        debugPrint('ASSET_CHANNEL_LOAD_ERROR: $assetError');
        debugPrintStack(stackTrace: assetStackTrace);

        throw Exception(
          'Could not load channels from remote or asset. Remote: $remoteError. Asset: $assetError',
        );
      }
    }
  }

  List<Channel> _parseChannels(String jsonString) {
    final data = json.decode(jsonString);

    if (data is! List) {
      throw const FormatException('Channel payload must be a JSON array.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(Channel.fromJson)
        .where((channel) => channel.url.isNotEmpty)
        .toList(growable: false);
  }
}
