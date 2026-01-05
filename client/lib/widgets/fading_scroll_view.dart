import 'package:flutter/material.dart';

/// A horizontal scroll view with dynamic fade edges that indicate more content.
/// Fades appear/disappear based on scroll position.
class FadingScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double fadeWidth;
  final ScrollController? controller;

  const FadingScrollView({
    super.key,
    required this.child,
    this.padding,
    this.fadeWidth = 0.12,
    this.controller,
  });

  @override
  State<FadingScrollView> createState() => _FadingScrollViewState();
}

class _FadingScrollViewState extends State<FadingScrollView> {
  late ScrollController _scrollController;
  bool _ownsController = false;
  bool _showLeftFade = false;
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FadingScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _scrollController.removeListener(_onScroll);
      if (_ownsController) {
        _scrollController.dispose();
      }
      if (widget.controller != null) {
        _scrollController = widget.controller!;
        _ownsController = false;
      } else {
        _scrollController = ScrollController();
        _ownsController = true;
      }
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    _updateFadeState();
  }

  void _updateFadeState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Check if content even needs scrolling
    final canScroll = position.maxScrollExtent > 0;
    final atStart = position.pixels <= 0;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;

    final newShowLeft = canScroll && !atStart;
    final newShowRight = canScroll && !atEnd;

    if (_showLeftFade != newShowLeft || _showRightFade != newShowRight) {
      setState(() {
        _showLeftFade = newShowLeft;
        _showRightFade = newShowRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check initial scroll state after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFadeState());

    final fadeWidth = widget.fadeWidth.clamp(0.0, 0.5);
    final leftStop = _showLeftFade ? fadeWidth : 0.0;
    final rightStop = _showRightFade ? (1.0 - fadeWidth) : 1.0;

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _showLeftFade ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _showRightFade ? Colors.transparent : Colors.black,
          ],
          stops: [0.0, leftStop, rightStop, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

