import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum SlideDirection { left, right }

enum SlideRegion { inNopeRegion, inLikeRegion }

typedef DraggableCardWrapper = Widget? Function(
  bool isDragging,
  Offset? cardOffset,
  Offset? cardOffsetPercent,
  Widget? child,
)?;

class DraggableCard extends StatefulWidget {
  DraggableCard({
    this.card,
    this.cardBuilder,
    this.isDraggable = true,
    this.onSlideUpdate,
    this.slideTo,
    this.onSlideOutComplete,
    this.onSlideRegionUpdate,
    this.onCardPressed,
    this.leftSwipeAllowed = true,
    this.rightSwipeAllowed = true,
    this.isBackCard = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget? card;
  final DraggableCardWrapper cardBuilder;
  final bool isDraggable;
  final SlideDirection? slideTo;
  final Function(double distance)? onSlideUpdate;
  final Function(SlideRegion? slideRegion)? onSlideRegionUpdate;
  final Function(SlideDirection? direction)? onSlideOutComplete;
  final Function()? onCardPressed;
  final bool leftSwipeAllowed;
  final bool rightSwipeAllowed;
  final EdgeInsets padding;
  final bool isBackCard;

  @override
  _DraggableCardState createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with TickerProviderStateMixin {
  GlobalKey profileCardKey = GlobalKey(debugLabel: 'profile_card_key');
  var cardOffset = Offset.zero;
  var cardOffsetPercent = Offset.zero;

  Offset? dragStart;
  Offset? dragPosition;
  Offset? slideBackStart;
  SlideDirection? slideOutDirection;
  SlideRegion? slideRegion;
  late AnimationController slideBackAnimation;
  Tween<Offset>? slideOutTween;
  late AnimationController slideOutAnimation;
  bool isDragging = false;

  RenderBox? box;
  var topLeft, bottomRight;
  Rect? anchorBounds;

  bool isAnchorInitialized = false;

  @override
  void initState() {
    super.initState();
    slideBackAnimation = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )
      ..addListener(() => setState(() {
            cardOffset = Offset.lerp(
                  slideBackStart,
                  Offset.zero,
                  Curves.easeOut.transform(slideBackAnimation.value),
                ) ??
                Offset.zero;

            final size = context.size;

            if (size == null) return;

            final widthPercent = cardOffset.dx / size.width;
            final heightPercent = cardOffset.dy / size.height;
            cardOffsetPercent = Offset(widthPercent, heightPercent);

            widget.onSlideUpdate?.call(cardOffset.distance);
            widget.onSlideRegionUpdate?.call(slideRegion);
          }))
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            slideBackStart = null;
            dragPosition = null;
          });
        }
      });

    slideOutAnimation = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )
      ..addListener(() {
        setState(() {
          cardOffset =
              slideOutTween?.evaluate(slideOutAnimation) ?? Offset.zero;
          final size = context.size;

          if (size == null) return;

          final widthPercent = cardOffset.dx / size.width;
          final heightPercent = cardOffset.dy / size.height;
          cardOffsetPercent = Offset(widthPercent, heightPercent);

          widget.onSlideUpdate?.call(cardOffset.distance);
          widget.onSlideRegionUpdate?.call(slideRegion);
        });
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            dragPosition = null;
            slideOutTween = null;

            widget.onSlideOutComplete?.call(slideOutDirection);
          });
        }
      });
  }

  @override
  void didUpdateWidget(DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.card?.key != oldWidget.card?.key) {
      cardOffset = Offset.zero;
    }

    if (oldWidget.slideTo == null && widget.slideTo != null) {
      switch (widget.slideTo!) {
        case SlideDirection.left:
          _slideLeft();
          break;
        case SlideDirection.right:
          _slideRight();
          break;
      }
    }
  }

  @override
  void dispose() {
    slideOutAnimation.dispose();
    slideBackAnimation.dispose();
    super.dispose();
  }

  Offset _chooseRandomDragStart() {
    final cardContext = profileCardKey.currentContext;
    final cardTopLeft = (cardContext?.findRenderObject() as RenderBox?)
        ?.localToGlobal(Offset.zero);

    final size = cardContext?.size;
    if (cardTopLeft == null || size == null) return Offset.zero;

    final dragStartY =
        size.height * (Random().nextDouble() < 0.5 ? 0.25 : 0.75) +
            cardTopLeft.dy;
    return Offset(size.width / 2 + cardTopLeft.dx, dragStartY);
  }

  void _slideLeft() async {
    await Future.delayed(Duration(milliseconds: 1)).then((_) {
      final size = context.size ?? Size.zero;

      final screenWidth = size.width;
      dragStart = _chooseRandomDragStart();
      slideOutTween =
          Tween(begin: Offset.zero, end: Offset(-2 * screenWidth, 0.0));
      slideOutAnimation.forward(from: 0.0);
    });
  }

  void _slideRight() async {
    await Future.delayed(Duration(milliseconds: 1)).then((_) {
      final size = context.size;
      if (size == null) return;

      final screenWidth = size.width;
      dragStart = _chooseRandomDragStart();
      slideOutTween =
          Tween(begin: Offset.zero, end: Offset(2 * screenWidth, 0.0));
      slideOutAnimation.forward(from: 0.0);
    });
  }

  void _onPanStart(DragStartDetails details) {
    dragStart = details.globalPosition;

    if (slideBackAnimation.isAnimating) {
      slideBackAnimation.stop(canceled: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = context.size ?? Size.zero;

    final widthPercent = cardOffset.dx / size.width;
    final heightPercent = cardOffset.dy / size.height;

    final isInLeftRegion = widthPercent < -0.45;
    final isInRightRegion = widthPercent > 0.45;

    setState(() {
      cardOffsetPercent = Offset(widthPercent, heightPercent);

      if (!isDragging && cardOffset != Offset.zero) {
        isDragging = true;
      }

      if (isInLeftRegion || isInRightRegion) {
        slideRegion = isInLeftRegion
            ? SlideRegion.inNopeRegion
            : SlideRegion.inLikeRegion;
      } else {
        slideRegion = null;
      }

      dragPosition = details.globalPosition;
      if (dragPosition != null && dragStart != null) {
        cardOffset = dragPosition! - dragStart!;

        widget.onSlideUpdate?.call(cardOffset.distance);
        widget.onSlideRegionUpdate?.call(slideRegion);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final size = context.size ?? Size.zero;

    final dragVector = cardOffset / cardOffset.distance;

    final isInLeftRegion = (cardOffset.dx / size.width) < -0.3;
    final isInRightRegion = (cardOffset.dx / size.width) > 0.3;

    setState(() {
      isDragging = false;

      if (isInLeftRegion) {
        if (widget.leftSwipeAllowed) {
          slideOutTween =
              Tween(begin: cardOffset, end: dragVector * (2 * size.width));
          slideOutAnimation.forward(from: 0.0);

          slideOutDirection = SlideDirection.left;
        } else {
          slideBackStart = cardOffset;
          slideBackAnimation.forward(from: 0.0);
        }

        timer?.cancel();
      } else if (isInRightRegion) {
        if (widget.rightSwipeAllowed) {
          slideOutTween =
              Tween(begin: cardOffset, end: dragVector * (2 * size.width));
          slideOutAnimation.forward(from: 0.0);

          slideOutDirection = SlideDirection.right;
        } else {
          slideBackStart = cardOffset;
          slideBackAnimation.forward(from: 0.0);
        }

        timer?.cancel();
      } else {
        slideBackStart = cardOffset;
        slideBackAnimation.forward(from: 0.0);
      }

      slideRegion = null;

      widget.onSlideRegionUpdate?.call(slideRegion);
    });
  }

  double _rotation(Rect? dragBounds) {
    if (dragStart != null && dragBounds != null) {
      final rotationCornerMultiplier = 1;
      return (pi / 8) *
          (cardOffset.dx / dragBounds.width) *
          rotationCornerMultiplier;
    } else {
      return 0;
    }
  }

  Offset _rotationOrigin(Rect? dragBounds) {
    if (dragStart != null && dragBounds != null) {
      return dragStart! - dragBounds.topLeft;
    } else {
      return Offset.zero;
    }
  }

  Timer? timer;

  @override
  Widget build(BuildContext context) {
    if (!isAnchorInitialized) {
      _initAnchor();
    }

    //Disables dragging card while slide out animation is in progress. Solves
    // issue that fast swipes cause the back card not loading
    if (widget.isBackCard &&
        anchorBounds != null &&
        cardOffset.dx < anchorBounds!.height) {
      cardOffset = Offset.zero;
    }

    var card = widget.card;

    if (widget.cardBuilder != null) {
      card = widget.cardBuilder!(
        isDragging,
        cardOffset,
        cardOffsetPercent,
        card,
      );
    }

    return Transform(
      transform: Matrix4.translationValues(cardOffset.dx, cardOffset.dy, 0.0)
        ..rotateZ(_rotation(anchorBounds)),
      origin: _rotationOrigin(anchorBounds),
      child: Container(
        key: profileCardKey,
        width: anchorBounds?.width,
        height: anchorBounds?.height,
        padding: widget.padding,
        child: RawGestureDetector(
          gestures: {
            HighPriorityPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    HighPriorityPanGestureRecognizer>(
              () => HighPriorityPanGestureRecognizer(),
              (HighPriorityPanGestureRecognizer instance) {
                instance
                  ..onStart = _onPanStart
                  ..onUpdate = _onPanUpdate
                  ..onDown = (details) {
                    timer?.cancel();
                    timer = Timer(Duration(milliseconds: 100), () {});
                  }
                  ..onEnd = (details) {
                    _onPanEnd(details);

                    if (timer?.isActive ?? false) {
                      timer?.cancel();
                      widget.onCardPressed?.call();
                    }
                  };
              },
            ),
          },
          child: card ?? Container(),
        ),
      ),
    );
  }

  _initAnchor() async {
    await Future.delayed(Duration(milliseconds: 3));
    box = context.findRenderObject() as RenderBox?;
    final boxPos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    topLeft = box?.size.topLeft(boxPos);
    bottomRight = box?.size.bottomRight(boxPos);
    anchorBounds = new Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      bottomRight.dx,
      bottomRight.dy,
    );

    setState(() {
      isAnchorInitialized = true;
    });
  }
}

class HighPriorityPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void handleEvent(PointerEvent event) {
    resolve(GestureDisposition.accepted);
    super.handleEvent(event);
  }
}
