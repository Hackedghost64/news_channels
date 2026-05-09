import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../providers/channel_provider.dart';
import '../widgets/video_player_widget.dart';

typedef HomePlayerBuilder =
    Widget Function(
      BuildContext context,
      Channel channel,
      String streamUrl,
      VoidCallback onPreviousChannel,
      VoidCallback onNextChannel,
      VoidCallback onShowChannelGuide,
    );

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.playerBuilder});

  final HomePlayerBuilder? playerBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _channelCardWidth = 188;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'home_keyboard');
  final List<FocusNode> _channelFocusNodes = <FocusNode>[];

  bool _showChannelGuide = true;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _syncFocusNodes(int count) {
    if (_channelFocusNodes.length == count) {
      return;
    }

    if (_channelFocusNodes.length < count) {
      for (var index = _channelFocusNodes.length; index < count; index++) {
        _channelFocusNodes.add(FocusNode(debugLabel: 'channel_$index'));
      }
      return;
    }

    final removedNodes = _channelFocusNodes.sublist(count);
    for (final node in removedNodes) {
      node.dispose();
    }
    _channelFocusNodes.removeRange(count, _channelFocusNodes.length);
  }

  void _showGuide(ChannelProvider provider, {bool requestFocus = true}) {
    if (!_showChannelGuide) {
      setState(() {
        _showChannelGuide = true;
      });
    }

    final selectedIndex = provider.selectedIndex;
    if (selectedIndex >= 0) {
      _focusedIndex = selectedIndex;
    }

    if (requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusChannel(_focusedIndex);
      });
    }
  }

  void _hideGuide() {
    if (!_showChannelGuide) {
      return;
    }

    setState(() {
      _showChannelGuide = false;
    });
    _keyboardFocusNode.requestFocus();
  }

  void _focusChannel(int index) {
    if (index < 0 || index >= _channelFocusNodes.length) {
      return;
    }

    _focusedIndex = index;
    _channelFocusNodes[index].requestFocus();
    _scrollToIndex(index);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) {
      return;
    }

    final target = math.max(0.0, index * _channelCardWidth - 24);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, ChannelProvider provider) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      _showGuide(provider);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _hideGuide();
      return KeyEventResult.handled;
    }

    if (_showChannelGuide) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _focusChannel(math.max(0, _focusedIndex - 1));
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        _focusChannel(
          math.min(provider.channels.length - 1, _focusedIndex + 1),
        );
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.space) {
        provider.selectChannelAt(_focusedIndex);
        _hideGuide();
        return KeyEventResult.handled;
      }
    } else {
      if (key == LogicalKeyboardKey.arrowLeft) {
        provider.selectPreviousChannel();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        provider.selectNextChannel();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      _showGuide(provider, requestFocus: false);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyR) {
      provider.loadChannels();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChannelProvider>(
      builder: (context, provider, child) {
        _syncFocusNodes(provider.channels.length);

        return Scaffold(
          body: KeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: (event) => _handleKeyEvent(event, provider),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _keyboardFocusNode.requestFocus,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF171717), Color(0xFF050505)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildBody(provider)),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopBar(
                        provider: provider,
                        onReload: provider.loadChannels,
                        onShowGuide: () => _showGuide(provider),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ChannelGuide(
                        visible:
                            _showChannelGuide && provider.channels.isNotEmpty,
                        channelCount: provider.channels.length,
                        selectedChannel: provider.selectedChannel,
                        selectedIndex: provider.selectedIndex,
                        scrollController: _scrollController,
                        channels: provider.channels,
                        focusNodes: _channelFocusNodes,
                        onChannelFocused: _focusChannel,
                        onChannelSelected: (index) {
                          _focusedIndex = index;
                          provider.selectChannelAt(index);
                          _hideGuide();
                        },
                      ),
                    ),
                    if (kDebugMode)
                      Positioned(
                        top: 88,
                        right: 16,
                        child: _DebugPanel(provider: provider),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ChannelProvider provider) {
    if (provider.isLoading && !provider.hasChannels) {
      return const _CenteredMessage(
        icon: Icons.sync,
        title: 'Loading channels',
        message: 'Fetching the live channel guide.',
        showSpinner: true,
      );
    }

    if (provider.error != null && !provider.hasChannels) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        title: 'Channels unavailable',
        message: provider.error!,
        actionLabel: 'Retry',
        onAction: provider.loadChannels,
      );
    }

    final channel = provider.selectedChannel;
    if (channel == null) {
      return const _CenteredMessage(
        icon: Icons.tv_off,
        title: 'No channel selected',
        message: 'Load channels to start playback.',
      );
    }

    final player =
        widget.playerBuilder?.call(
          context,
          channel,
          provider.resolveStreamUrl(channel),
          provider.selectPreviousChannel,
          provider.selectNextChannel,
          () => _showGuide(provider),
        ) ??
        VideoPlayerWidget(
          channel: channel,
          streamUrl: provider.resolveStreamUrl(channel),
          onPreviousChannel: provider.selectPreviousChannel,
          onNextChannel: provider.selectNextChannel,
          onShowChannelGuide: () => _showGuide(provider),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        Positioned(
          left: 20,
          bottom: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                'Swipe or double tap to switch channels. Press Up for the guide.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.provider,
    required this.onReload,
    required this.onShowGuide,
  });

  final ChannelProvider provider;
  final VoidCallback onReload;
  final VoidCallback onShowGuide;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'News TV',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.selectedChannel?.name ??
                              'Awaiting channel list',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ActionChip(
                icon: Icons.grid_view_rounded,
                label: 'Guide',
                onPressed: onShowGuide,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: provider.isLoading ? Icons.sync : Icons.refresh_rounded,
                label: 'Reload',
                onPressed: onReload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelGuide extends StatelessWidget {
  const _ChannelGuide({
    required this.visible,
    required this.channelCount,
    required this.selectedChannel,
    required this.selectedIndex,
    required this.scrollController,
    required this.channels,
    required this.focusNodes,
    required this.onChannelFocused,
    required this.onChannelSelected,
  });

  final bool visible;
  final int channelCount;
  final Channel? selectedChannel;
  final int selectedIndex;
  final ScrollController scrollController;
  final List<Channel> channels;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onChannelFocused;
  final ValueChanged<int> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.08),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          height: 318,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.96),
                Colors.black.withValues(alpha: 0.84),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedChannel?.name ?? 'Choose a channel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$channelCount live channels available',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _ChannelCard(
                            channel: channels[index],
                            focusNode: focusNodes[index],
                            isSelected: index == selectedIndex,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                onChannelFocused(index);
                              }
                            },
                            onTap: () => onChannelSelected(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({
    required this.channel,
    required this.focusNode,
    required this.isSelected,
    required this.onFocusChange,
    required this.onTap,
  });

  final Channel channel;
  final FocusNode focusNode;
  final bool isSelected;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onTap;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      onFocusChange: (focused) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isFocused = focused;
        });
        widget.onFocusChange(focused);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isFocused
              ? const Color(0xFFB71C1C)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isFocused
                ? Colors.white
                : widget.isSelected
                ? Colors.redAccent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            width: _isFocused ? 2.8 : 1.1,
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: Center(
                    child: widget.channel.logo.isNotEmpty
                        ? Image.network(
                            widget.channel.logo,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.tv,
                                size: 44,
                                color: Colors.white70,
                              );
                            },
                          )
                        : const Icon(Icons.tv, size: 44, color: Colors.white70),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.showSpinner = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showSpinner;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    )
                  else
                    Icon(icon, size: 56, color: Colors.redAccent),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.provider});

  final ChannelProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          initiallyExpanded: false,
          collapsedIconColor: Colors.white70,
          iconColor: Colors.white,
          title: const Text('Debug', style: TextStyle(color: Colors.white)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _DebugRow(
              label: 'Catalog source',
              value: provider.catalogSourceLabel,
            ),
            _DebugRow(
              label: 'Selected index',
              value: '${provider.selectedIndex}',
            ),
            _DebugRow(
              label: 'Raw stream URL',
              value: provider.selectedChannel?.url ?? '-',
            ),
            _DebugRow(
              label: 'Playback URL',
              value: provider.selectedChannel == null
                  ? '-'
                  : provider.resolveStreamUrl(provider.selectedChannel!),
            ),
            if (kIsWeb)
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Use CORS proxy',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Turn this off in Chrome to inspect native stream errors.',
                  style: TextStyle(color: Colors.white70),
                ),
                value: provider.useWebProxy,
                onChanged: provider.setUseWebProxy,
              ),
            if (provider.warning != null)
              _DebugRow(label: 'Warning', value: provider.warning!),
            if (provider.error != null)
              _DebugRow(label: 'Last error', value: provider.error!),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
