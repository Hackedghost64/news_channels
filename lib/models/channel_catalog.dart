import 'channel.dart';

enum ChannelDataSource { remote, asset }

class ChannelCatalog {
  const ChannelCatalog({
    required this.channels,
    required this.source,
    this.warning,
  });

  final List<Channel> channels;
  final ChannelDataSource source;
  final String? warning;
}
