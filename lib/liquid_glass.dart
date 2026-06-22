import "dart:math";

import "package:flutter/material.dart";

/// 液态玻璃容器（Layer 3 核心）
///
/// 精确参数公式（暗黑科技感）：
///   1. 裁剪圆角：ClipRRect(borderRadius: BorderRadius.circular(24))
///   2. 模糊滤镜：BackdropFilter(sigmaX: 30, sigmaY: 30)
///   3. 玻璃填充：Colors.white.withOpacity(0.06)
///   4. 高光边框：Border.all(Colors.white.withOpacity(0.15), width: 1.0)
///   5. 悬浮阴影：BoxShadow(blurRadius: 40, spreadRadius: -5)
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? tint;
  final double tintOpacity;
  final Border? border;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final Alignment? alignment;
  final bool enableHighlight;

  const LiquidGlass({
    required this.child,
    super.key,
    this.blurSigma = 30,
    this.radius = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    this.margin = EdgeInsets.zero,
    this.tint,
    this.tintOpacity = 0.06,
    this.border,
    this.shadows,
    this.gradient,
    this.alignment,
    this.enableHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 第一层：背景高斯模糊
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 第二层：玻璃材质底色（极低白色透明度）
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(tintOpacity),
                ),
              ),
            ),
            // 第三层：内部折射渐变（模拟光线在玻璃内部的折射）
            if (gradient != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient!),
                ),
              )
            else
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.01),
                        Colors.white.withOpacity(0.03),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            // 第四层：灵魂高光边框（模拟玻璃切面反光）
            if (enableHighlight)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border:
                        border ??
                        Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.0,
                        ),
                  ),
                ),
              ),
            // 第五层：顶部高光线（模拟玻璃上边缘反光）
            if (enableHighlight)
              Positioned(
                top: 0,
                left: radius * 0.5,
                right: radius * 0.5,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x33FFFFFF), // 白色 20% 高光
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            // 第六层：悬浮阴影
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: shadows ??
                      [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 40,
                          spreadRadius: -5,
                        ),
                      ],
                ),
              ),
            ),
            // 内容区
            Padding(
              padding: padding,
              child:
                  Align(alignment: alignment ?? Alignment.center, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// 流光走圈边框动画
///
/// 在液态玻璃卡片的边缘绘制一条渐变色亮光，
/// 沿着圆角矩形顺时针跑圈，用于 Loading / 转换进度状态。
///
/// 使用方式：
/// ```dart
/// AnimatedGlassBorder(
///   isRunning: convertProgress != null && !done,
///   progress: convertProgress ?? 0.0,
///   borderRadius: 24,
///   borderWidth: 2.0,
///   gradientColors: [Color(0xFF00D4AA), Color(0xFF00BFFF)],
///   child: LiquidGlass(...),
/// )
/// ```
class AnimatedGlassBorder extends StatefulWidget {
  final Widget child;
  final bool isRunning;
  final double progress; // 0.0 ~ 1.0
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;
  final Duration duration;

  const AnimatedGlassBorder({
    required this.child,
    super.key,
    this.isRunning = false,
    this.progress = 0.0,
    this.borderRadius = 24,
    this.borderWidth = 2.0,
    this.gradientColors = const [
      Color(0xFF00D4AA), // 青色
      Color(0xFF00BFFF), // 天蓝
      Color(0xFF7B68EE), // 淡紫
    ],
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<AnimatedGlassBorder> createState() => _AnimatedGlassBorderState();
}

class _AnimatedGlassBorderState extends State<AnimatedGlassBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedGlassBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRunning && _controller.isAnimating) {
      _controller.stop();
      setState(() {}); // 停止时刷新一次，移除边框
    }
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
        if (!widget.isRunning) return widget.child;

        return CustomPaint(
          painter: _GlowingBorderPainter(
            angle: _controller.value * 2 * pi,
            progress: widget.progress,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
            gradientColors: widget.gradientColors,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 流光走圈边框绘制器
class _GlowingBorderPainter extends CustomPainter {
  final double angle;
  final double progress;
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;

  _GlowingBorderPainter({
    required this.angle,
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderWidth / 2,
        borderWidth / 2,
        size.width - borderWidth,
        size.height - borderWidth,
      ),
      Radius.circular(borderRadius),
    );

    // 创建扫过的路径（弧段长度由进度或固定角度决定）
    final sweepAngle = max(0.5, pi * 0.8); // 固定弧段约 144 度
    final path = Path()..addArc(rect.toRect(), angle, sweepAngle);

    // 渐变画笔 + 发光效果
    final sweepShader = SweepGradient(
      center: Offset(size.width / 2, size.height / 2),
      startAngle: angle - pi / 2,
      endAngle: angle - pi / 2 + pi * 2,
      tileMode: TileMode.clamp,
      colors: gradientColors,
    ).createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..shader = sweepShader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0); // 外发光

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowingBorderPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.progress != progress;
}

/// 液态玻璃按钮（iOS 级微物理触觉反馈）
///
/// 按下时 100ms 内缩放到 0.95 倍；
/// 松开时以 Curves.easeOutCubic 在 200ms 内平滑回弹至 1.0。
/// 按钮默认更宽更高（胶囊形），配合背景流光产生高级扭曲感。
class LiquidGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double blurSigma;
  final double radius;
  final EdgeInsets padding;
  final Color? tint;
  final bool enableHighlight;
  final bool expanded;
  final bool isActive; // 用于 toggle 类按钮的高亮状态

  const LiquidGlassButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.blurSigma = 24,
    this.radius = 20,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 28, vertical: 18), // 加宽加高
    this.tint,
    this.enableHighlight = true,
    this.expanded = false,
    this.isActive = false,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // 按下动画：100ms 快速缩放
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // 缩放曲线：按下到 0.95
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // 透明度微降
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _controller.forward(); // 按下：100ms → 0.95
  }

  void _onPointerUp(PointerUpEvent _) {
    _rebound();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _rebound();
  }

  /// 回弹：使用弹性曲线 200ms 平滑回 1.0
  void _rebound() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);

    // 先完成当前 forward 动画，再 reverse 用弹性曲线回弹
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTint = widget.tint ??
        (widget.isActive ? const Color(0x1A00D4AA) : null);

    final button = Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: LiquidGlass(
                  blurSigma: widget.blurSigma,
                  radius: widget.radius,
                  padding: widget.padding,
                  tint: effectiveTint,
                  tintOpacity: widget.isActive ? 0.10 : 0.06,
                  enableHighlight: widget.enableHighlight,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        _isPressed ? 0.18 : 0.12,
                      ),
                      blurRadius: _isPressed ? 30 : 40,
                      spreadRadius: -5,
                    ),
                  ],
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF), // 主文字 95% 白色
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    child: IconTheme(
                      data: const IconThemeData(
                        color: Color(0xF2FFFFFF),
                        size: 21,
                        shadows: [
                          Shadow(
                            color: Color(0x30FFFFFF),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
