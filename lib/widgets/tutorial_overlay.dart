import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final String message;
  final GlobalKey targetKey;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final String? nextText;
  final String? skipText;
  final Alignment alignment;
  final EdgeInsets padding;

  const TutorialOverlay({
    super.key,
    required this.message,
    required this.targetKey,
    this.onNext,
    this.onSkip,
    this.nextText,
    this.skipText,
    this.alignment = Alignment.bottomCenter,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 어두운 배경
        Positioned.fill(
          child: GestureDetector(
            onTap: onSkip,
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        // 타겟 위젯 하이라이트
        _buildTargetHighlight(),
        // 안내 메시지
        _buildMessage(context),
      ],
    );
  }

  Widget _buildTargetHighlight() {
    return Builder(
      builder: (context) {
        final RenderBox? renderBox =
            targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return const SizedBox.shrink();
        }

        final size = renderBox.size;
        final offset = renderBox.localToGlobal(Offset.zero);

        return Positioned(
          left: offset.dx - 8,
          top: offset.dy - 8,
          width: size.width + 16,
          height: size.height + 16,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onSkip != null)
                          TextButton(
                            onPressed: onSkip,
                            child: Text(
                              skipText ?? '건너뛰기',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        if (onNext != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(nextText ?? '다음'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
