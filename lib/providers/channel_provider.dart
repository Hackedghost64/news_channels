import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';

class ChannelProvider with ChangeNotifier {
  final ChannelService _channelService = ChannelService();
  
  List<Channel> _channels = [];
  bool _isLoading = false;
  String? _error;
  Channel? _selectedChannel;

  List<Channel> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Channel? get selectedChannel => _selectedChannel;

  Future<void> loadChannels() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _channels = await _channelService.fetchChannels();
      if (_channels.isNotEmpty && _selectedChannel == null) {
        _selectedChannel = _channels.first;
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
}
