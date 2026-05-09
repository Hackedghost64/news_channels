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
  bool _hasStarted = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _startFocusNode = FocusNode();
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChannelProvider>().loadChannels();
        _startFocusNode.requestFocus();
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _startApp() {
    setState(() {
      _hasStarted = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _startFocusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemWidth = 196.0;
    final target = index * itemWidth;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ChannelProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.channels.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
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

          if (!_hasStarted) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv, color: Colors.white, size: 100),
                  const SizedBox(height: 30),
                  const Text('News TV', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 50),
                  Focus(
                    focusNode: _startFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.select || 
                            event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.space) {
                          _startApp();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(builder: (context) {
                      final focused = Focus.of(context).hasFocus;
                      return ElevatedButton(
                        onPressed: _startApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: focused ? Colors.red : Colors.grey[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                          side: BorderSide(color: focused ? Colors.white : Colors.transparent, width: 2),
                        ),
                        child: const Text('WATCH LIVE', style: TextStyle(fontSize: 24)),
                      );
                    }),
                  ),
                ],
              ),
            );
          }

          return KeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp && !_showOverlay) {
                  _toggleOverlay();
                } else if (event.logicalKey == LogicalKeyboardKey.escape || 
                           event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_showOverlay) {
                    _toggleOverlay();
                  }
                }
              }
            },
            child: Stack(
              children: [
                // Video Player Background
                if (provider.selectedChannel != null)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleOverlay,
                      child: VideoPlayerWidget(
                        url: provider.selectedChannel!.url,
                        channelName: provider.selectedChannel!.name,
                      ),
                    ),
                  ),

                // Channel Overlay
                if (_showOverlay)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.95),
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
                            child: Text(
                              provider.selectedChannel?.name ?? 'Select a Channel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 15, color: Colors.black)],
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: provider.channels.length,
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              itemBuilder: (context, index) {
                                final channel = provider.channels[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                                  child: _ChannelCard(
                                    channel: channel,
                                    isSelected: provider.selectedChannel == channel,
                                    autofocus: index == _focusedIndex,
                                    onFocusChange: (focused) {
                                      if (focused) {
                                        _scrollToIndex(index);
                                        _focusedIndex = index;
                                      }
                                    },
                                    onTap: () {
                                      provider.selectChannel(channel);
                                      _toggleOverlay();
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final dynamic channel;
  final bool isSelected;
  final bool autofocus;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.isSelected,
    required this.autofocus,
    required this.onFocusChange,
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
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
        widget.onFocusChange(focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        decoration: BoxDecoration(
          color: _isFocused ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? Colors.red : (widget.isSelected ? Colors.white : Colors.transparent),
            width: 3,
          ),
          boxShadow: _isFocused 
            ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]
            : [],
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
