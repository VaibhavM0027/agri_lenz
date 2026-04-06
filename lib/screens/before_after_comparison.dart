import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Interactive before/after image comparison with draggable slider
class BeforeAfterComparison extends StatefulWidget {
  const BeforeAfterComparison({
    super.key,
    required this.beforeImage,
    required this.afterImage,
    this.beforeLabel = 'Before Treatment',
    this.afterLabel = 'After Treatment',
  });

  final Uint8List beforeImage;
  final Uint8List afterImage;
  final String beforeLabel;
  final String afterLabel;

  @override
  State<BeforeAfterComparison> createState() => _BeforeAfterComparisonState();
}

class _BeforeAfterComparisonState extends State<BeforeAfterComparison> {
  double _sliderPosition = 0.5; // 0.0 to 1.0
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Before / After Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reset_tv),
            tooltip: 'Reset slider',
            onPressed: () {
              setState(() => _sliderPosition = 0.5);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Comparison area
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (_) {
                setState(() => _isDragging = true);
              },
              onHorizontalDragUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final dx = details.localPosition.dx;
                final width = box.size.width;
                
                setState(() {
                  _sliderPosition = (dx / width).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
              },
              child: Stack(
                children: [
                  // AFTER image (background - full width)
                  Positioned.fill(
                    child: Image.memory(
                      widget.afterImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  
                  // BEFORE image (clipped based on slider position)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _SliderClipper(_sliderPosition),
                      child: Image.memory(
                        widget.beforeImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                  // Slider line
                  Positioned(
                    left: _sliderPosition * MediaQuery.of(context).size.width - 2,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.compare_arrows,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Labels
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _LabelBadge(
                      label: widget.beforeLabel,
                      isVisible: _sliderPosition > 0.15,
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: _LabelBadge(
                      label: widget.afterLabel,
                      isVisible: _sliderPosition < 0.85,
                      isAfter: true,
                    ),
                  ),
                  
                  // Drag instruction
                  if (!_isDragging)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Drag to compare',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Slider indicator at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.beforeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _sliderPosition,
                    onChanged: (value) {
                      setState(() => _sliderPosition = value);
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  widget.afterLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  _SliderClipper(this.position);
  
  final double position;
  
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }
  
  @override
  bool shouldReclip(_SliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({
    required this.label,
    required this.isVisible,
    this.isAfter = false,
  });

  final String label;
  final bool isVisible;
  final bool isAfter;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAfter 
              ? Colors.green.withValues(alpha: 0.9)
              : Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
