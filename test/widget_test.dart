import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:news_tv/models/channel.dart';
import 'package:news_tv/models/channel_catalog.dart';
import 'package:news_tv/providers/channel_provider.dart';
import 'package:news_tv/screens/home_screen.dart';
import 'package:news_tv/services/channel_service.dart';

class _FakeChannelRepository implements ChannelRepository {
  @override
  Future<ChannelCatalog> fetchChannels() async {
    return ChannelCatalog(
      channels: const [
        Channel(
          name: 'Channel One',
          url: 'https://example.com/one.m3u8',
          logo: '',
        ),
        Channel(
          name: 'Channel Two',
          url: 'https://example.com/two.m3u8',
          logo: '',
        ),
      ],
      source: ChannelDataSource.asset,
    );
  }
}

void main() {
  testWidgets('home screen renders channels and switches selection', (
    WidgetTester tester,
  ) async {
    final provider = ChannelProvider(channelService: _FakeChannelRepository());
    await provider.loadChannels();

    await tester.pumpWidget(
      ChangeNotifierProvider<ChannelProvider>.value(
        value: provider,
        child: MaterialApp(
          home: HomeScreen(
            playerBuilder:
                (
                  context,
                  channel,
                  streamUrl,
                  onPreviousChannel,
                  onNextChannel,
                  onShowChannelGuide,
                ) {
                  return ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        'Playing ${channel.name}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Channel One'), findsWidgets);
    expect(find.text('Playing Channel One'), findsOneWidget);

    await tester.tap(find.text('Channel Two').first);
    await tester.pumpAndSettle();

    expect(find.text('Playing Channel Two'), findsOneWidget);
    expect(provider.selectedChannel?.name, 'Channel Two');
  });
}
