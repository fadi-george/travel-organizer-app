import 'package:flutter/material.dart';

class SwipeActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final EdgeInsets margin;

  const SwipeActionCard({
    super.key,
    required this.child,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _dragExtent = 0;
  static const double _actionButtonWidth = 88;

  bool get _hasSwipeActions => widget.onEdit != null || widget.onDelete != null;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _swipeController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(
        -_actionButtonWidth,
        0,
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReveal =
        velocity < -200 || _dragExtent < -_actionButtonWidth / 2;

    _swipeAnimation = Tween<double>(
      begin: _dragExtent,
      end: shouldReveal ? -_actionButtonWidth : 0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = shouldReveal ? -_actionButtonWidth : 0;
        });
      }
    });
  }

  void _resetSwipe() {
    _swipeAnimation = Tween<double>(
      begin: _dragExtent,
      end: 0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSwipeActions) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Padding(padding: widget.margin, child: widget.child),
      );
    }

    final showActions = _dragExtent < 0 || _swipeController.isAnimating;

    return Padding(
      padding: widget.margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Action buttons - only visible when swiping
          if (showActions)
            Positioned.fill(
              child: Row(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: _actionButtonWidth,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Edit button
                          if (widget.onEdit != null)
                            Padding(
                              padding: EdgeInsets.only(
                                left: 8,
                                right: widget.onDelete != null ? 8 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  _resetSwipe();
                                  widget.onEdit?.call();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          // Delete button
                          if (widget.onDelete != null)
                            GestureDetector(
                              onTap: () {
                                _resetSwipe();
                                widget.onDelete?.call();
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade500,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          AnimatedBuilder(
            animation: _swipeController,
            builder: (context, child) {
              final offset = _swipeController.isAnimating
                  ? _swipeAnimation.value
                  : _dragExtent;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () {
                if (_dragExtent < 0) {
                  _resetSwipe();
                } else {
                  widget.onTap?.call();
                }
              },
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
