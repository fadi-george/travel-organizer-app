import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../utils/country_images.dart';

class TripCard extends StatefulWidget {
  final Trip trip;
  final String? primaryCountry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isCompact;
  final int index;

  const TripCard({
    super.key,
    required this.trip,
    this.primaryCountry,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isCompact = false,
    this.index = 0,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _dragExtent = 0;
  static const double _actionButtonWidth = 70;

  double get _swipeWidth => _actionButtonWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Staggered delay: 250ms per card index
    Future.delayed(Duration(milliseconds: 250 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });

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
    _controller.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _swipeController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(-_swipeWidth, 0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReveal = velocity < -200 || _dragExtent < -_swipeWidth / 2;

    _swipeAnimation = Tween<double>(
      begin: _dragExtent,
      end: shouldReveal ? -_swipeWidth : 0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = shouldReveal ? -_swipeWidth : 0;
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

  String get _imageUrl {
    if (widget.trip.imageUrl != null) return widget.trip.imageUrl!;
    return CountryImages.getImageUrl(widget.primaryCountry);
  }

  bool get _hasSwipeActions => widget.onEdit != null || widget.onDelete != null;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _hasSwipeActions
            ? _buildSwipeableCard(context)
            : (widget.isCompact
                  ? _buildCompactCard(context)
                  : _buildFullCard(context)),
      ),
    );
  }

  Widget _buildSwipeableCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Action buttons background
        Positioned.fill(
          child: Container(
            margin: EdgeInsets.only(
              bottom: widget.isCompact ? 12 : 32,
              top: widget.isCompact ? 0 : 8,
              left: widget.isCompact ? 0 : 4,
              right: widget.isCompact ? 0 : 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.isCompact ? 16 : 20),
            ),
            child: Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: _actionButtonWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Edit button
                      if (widget.onEdit != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              _resetSwipe();
                              widget.onEdit?.call();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.purple.shade500,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                                size: 22,
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Card content
        AnimatedBuilder(
          animation: _swipeController,
          builder: (context, child) {
            final offset = _swipeController.isAnimating
                ? _swipeAnimation.value
                : _dragExtent;
            return Transform.translate(offset: Offset(offset, 0), child: child);
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
            child: widget.isCompact
                ? _buildCompactCardContent(context)
                : _buildFullCardContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(color: Colors.transparent);
  }

  Widget _buildFullCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _buildFullCardContent(context),
    );
  }

  Widget _buildFullCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 32),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: _imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.trip.daysUntilTrip != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.trip.isUpcoming
                              ? const Color(0xFFFF7043)
                              : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.trip.daysUntilTrip!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      widget.trip.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.trip.formattedDateRange,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.trip.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.trip.notes!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _buildCompactCardContent(context),
    );
  }

  Widget _buildCompactCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: CachedNetworkImage(
                  imageUrl: _imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trip.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.trip.formattedDateRange,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  if (widget.trip.daysUntilTrip != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.trip.daysUntilTrip!,
                      style: TextStyle(
                        color: widget.trip.isPast
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5)
                            : const Color(0xFFFF7043),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
