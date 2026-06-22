import "dart:math";

import "package:flutter/material.dart";

/// 单个粒子数据模型
class _Particle {
  double x;
  double y;
  double radius;
  double baseOpacity;
  double opacityPhase; // 呼吸相位偏移
  double speedY;       // Y轴上浮速度
  double speedX;       // X轴微漂速度

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.opacityPhase,
    required this.speedY,
    required this.speedX,
  });
}

/// 微光粒子场（Layer 2）
///
/// 在流光背景与液态玻璃卡片之间，渲染 15-25 个半透明白色微光粒子。
/// 粒子特性：
/// - 半径 1~3px 随机
/// - Y 轴缓慢向上漂移，X 轴微小横向漂移
/// - 透明度在 0.05 ~ 0.3 之间做正弦呼吸跳动（每个粒子有独立相位偏移）
/// - 漂出屏幕后从底部重新进入（循环复用）
class ParticleField extends StatefulWidget {
  final int count;

  const ParticleField({
    super.key,
    this.count = 20,
  });

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final Random _random = Random(88); // 固定种子

  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    // 动画周期 8 秒，控制粒子的整体时间推进
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _particles = _generateParticles(widget.count);
  }

  /// 生成随机粒子，位置基于归一化坐标 (0.0 ~ 1.0)
  List<_Particle> _generateParticles(int count) {
    return List.generate(count, (i) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 1.0 + _random.nextDouble() * 2.5, // 1 ~ 3.5px
        baseOpacity: 0.08 + _random.nextDouble() * 0.15, // 0.08 ~ 0.23
        opacityPhase: _random.nextDouble() * 2 * pi,     // 随机呼吸相位
        speedY: 0.003 + _random.nextDouble() * 0.007,   // 极慢上浮
        speedX: (_random.nextDouble() - 0.5) * 0.002,   // 微小横漂
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            if (_lastSize != size && size.width > 0 && size.height > 0) {
              _lastSize = size;
            }
            return CustomPaint(
              size: size,
              painter: _ParticlePainter(
                particles: _particles,
                time: _controller.value,
                screenSize: size,
              ),
            );
          },
        );
      },
    );
  }
}

/// 粒子绘制器
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  final Size screenSize;

  _ParticlePainter({
    required this.particles,
    required this.time,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return;

    for (final p in particles) {
      // 计算当前位置（随时间漂移）
      double currentX = ((p.x + time * p.speedX * 8) % 1.0 + 1.0) % 1.0;
      double currentY = ((p.y - time * p.speedY * 8) % 1.0 + 1.0) % 1.0; // 向上为负

      final double px = currentX * size.width;
      final double py = currentY * size.height;

      // 呼吸透明度：正弦波在 baseOpacity 的基础上波动
      final double opacity = (p.baseOpacity +
          0.08 * sin(time * 2 * pi * 3 + p.opacityPhase))
          .clamp(0.04, 0.32);

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5); // 轻柔发光

      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
