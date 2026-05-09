import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../widgets/video_player_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showOverlay = true;
  final FocusNode _listFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ChannelProvider>().loadChannels());
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: Consumer<ChannelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.channels.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null && provider.channels.isEmpty) {
              return Center(
                child: Text(
                  'call divyam the error is : [${provider.error}]',
                  style: const TextStyle(color: Colors.red, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Stack(
              children: [
                // Video Player Background
                if (provider.selectedChannel != null)
                  Positioned.fill(
                    child: VideoPlayerWidget(
                      url: provider.selectedChannel!.url,
                      channelName: provider.selectedChannel!.name,
                    ),
                  ),

                // Channel Overlay
                if (_showOverlay)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Text(
                              provider.selectedChannel?.name ?? 'Select a Channel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: provider.channels.length,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              itemBuilder: (context, index) {
                                final channel = provider.channels[index];
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _ChannelCard(
                                    channel: channel,
                                    isSelected: provider.selectedChannel == channel,
                                    onTap: () {
                                      provider.selectChannel(channel);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Interaction Layer to show/hide overlay
                GestureDetector(
                  onTap: _toggleOverlay,
                  behavior: HitTestBehavior.translucent,
                  child: Container(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final dynamic channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        decoration: BoxDecoration(
          color: _isFocused ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isFocused ? Colors.red : (widget.isSelected ? Colors.white : Colors.transparent),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: widget.channel.logo.isNotEmpty
                  ? Image.network(
                      widget.channel.logo,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.tv, size: 50, color: Colors.white),
                    )
                  : const Icon(Icons.tv, size: 50, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.channel.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
