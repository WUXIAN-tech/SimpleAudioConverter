import "dart:math";

import "package:flutter/material.dart";

/// 华为沉浸流光背景（Layer 1）
///
/// 底色固定为极深暗青黑 #0D1117，之上叠加 2~3 个缓慢漂移的
/// RadialGradient 弥散光团，在对角线方向做周期性位移，
/// 营造出类似极光/星云的呼吸感。
class AuroraBackground extends StatefulWidget {
  final Widget? child;

  const AuroraBackground({super.key, this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  // 光团 1 动画控制器（紫色调，左上→右下）
  late final AnimationController _orb1Controller;
  // 光团 2 动画控制器（青红色调，右下→左上）
  late final AnimationController _orb2Controller;
  // 光团 3 动画控制器（青色调，辅助氛围）
  late final AnimationController _orb3Controller;

  final Random _random = Random(42); // 固定种子保证每次一致

  @override
  void initState() {
    super.initState();
    // 周期 15 秒，极慢蠕动
    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    // 周期 20 秒，错开相位
    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    // 周期 18 秒
    _orb3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _orb3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_orb1Controller, _orb2Controller, _orb3Controller]),
      builder: (context, child) {
        final double t1 = _orb1Controller.value;
        final double t2 = _orb2Controller.value;
        final double t3 = _orb3Controller.value;

        // 光团 1：暗紫色，从左上到右下对角线漂移
        final Offset orb1Offset = Offset(
          -0.3 + t1 * 0.8,   // x: -30% → +50%
          -0.3 + t1 * 0.6,   // y: -30% → +30%
        );

        // 光团 2：深青红色，从右下到左上对角线漂移
        final Offset orb2Offset = Offset(
          0.7 - t2 * 0.8,    // x: +70% → -10%
          0.6 - t2 * 0.7,    // y: +60% → -10%
        );

        // 光团 3：深青色，辅助氛围
        final Offset orb3Offset = Offset(
          0.2 + t3 * 0.3,    // x: 缓慢水平移动
          -0.2 + t3 * 0.5,   // y: 缓慢垂直移动
        );

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117), // 极深暗青黑底色
          ),
          child: Stack(
            children: [
              // 光团 1：暗紫色 #3A1C71
              Positioned.fill(
                child: Transform.translate(
                  offset: orb1Offset * MediaQuery.of(context).size.shortestSide,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x333A1C71), // 暗紫色 20% 透明度
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // 光团 2：深青红 #D76D77
              Positioned.fill(
                child: Transform.translate(
                  offset: orb2Offset * MediaQuery.of(context).size.shortestSide,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x26D76D77), // 深青红 15% 透明度
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // 光团 3：深青色（辅助）
              Positioned.fill(
                child: Transform.translate(
                  offset: orb3Offset * MediaQuery.of(context).size.shortestSide,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x1A00D4AA), // 深青色 10% 透明度
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              if (child != null) child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
