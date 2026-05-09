import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/channel_catalog.dart';
import '../services/channel_service.dart';

class ChannelProvider with ChangeNotifier {
  ChannelProvider({ChannelRepository? channelService})
    : _channelService = channelService ?? ChannelService();

  static const String _webProxyPrefix = 'https://corsproxy.io/?';

  final ChannelRepository _channelService;
  List<Channel> _channels = [];
  bool _isLoading = false;
  String? _error;
  Channel? _selectedChannel;
  ChannelDataSource _catalogSource = ChannelDataSource.asset;
  String? _warning;
  bool _useWebProxy = kIsWeb && !kDebugMode;

  List<Channel> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Channel? get selectedChannel => _selectedChannel;
  ChannelDataSource get catalogSource => _catalogSource;
  String? get warning => _warning;
  bool get useWebProxy => _useWebProxy;
  int get selectedIndex => _selectedChannel == null
      ? -1
      : _channels.indexWhere((channel) => channel.url == _selectedChannel!.url);
  bool get hasChannels => _channels.isNotEmpty;
  bool get canSelectPrevious => selectedIndex > 0;
  bool get canSelectNext =>
      selectedIndex >= 0 && selectedIndex < _channels.length - 1;

  String get catalogSourceLabel => switch (_catalogSource) {
    ChannelDataSource.remote => 'Remote',
    ChannelDataSource.asset => 'Bundled',
  };

  String resolveStreamUrl(Channel channel) {
    if (!kIsWeb || channel.url.isEmpty || !_useWebProxy) {
      return channel.url;
    }

    return '$_webProxyPrefix${Uri.encodeComponent(channel.url)}';
  }

  Future<void> loadChannels() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    _warning = null;
    notifyListeners();

    try {
      final currentUrl = _selectedChannel?.url;
      final catalog = await _channelService.fetchChannels();

      _channels = catalog.channels;
      _catalogSource = catalog.source;
      _warning = catalog.warning;

      if (_channels.isNotEmpty && _selectedChannel == null) {
        _selectedChannel = _channels.first;
      } else if (currentUrl != null) {
        final currentIndex = _channels.indexWhere(
          (channel) => channel.url == currentUrl,
        );
        _selectedChannel = currentIndex == -1
            ? (_channels.isEmpty ? null : _channels.first)
            : _channels[currentIndex];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectChannel(Channel channel) {
    _selectedChannel = channel;
    notifyListeners();
  }

  void selectChannelAt(int index) {
    if (index < 0 || index >= _channels.length) {
      return;
    }

    _selectedChannel = _channels[index];
    notifyListeners();
  }

  void selectNextChannel() {
    if (!canSelectNext) {
      return;
    }

    selectChannelAt(selectedIndex + 1);
  }

  void selectPreviousChannel() {
    if (!canSelectPrevious) {
      return;
    }

    selectChannelAt(selectedIndex - 1);
  }

  void setUseWebProxy(bool value) {
    if (!kIsWeb || _useWebProxy == value) {
      return;
    }

    _useWebProxy = value;
    notifyListeners();
  }
}
