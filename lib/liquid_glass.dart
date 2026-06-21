import "dart:ui";

import "package:flutter/material.dart";

/// 液态玻璃组件
///
/// 模拟 Apple visionOS / iOS 18 的 Liquid Glass 效果：
/// - 多层背景模糊（高斯模糊 + 饱和度增强）
/// - 半透明材质层
/// - 边缘高光（模拟玻璃边缘的光线折射）
/// - 内部柔和光晕
/// - 微妙的折射渐变
///
/// 不是简单的 `Container` + `color: Colors.white.withOpacity(0.5)`，
/// 而是真正的多层合成，产生"液态"质感。
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
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.tint,
    this.tintOpacity = 0.08,
    this.border,
    this.shadows,
    this.gradient,
    this.alignment,
    this.enableHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveTint =
        tint ?? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF));
    final Color baseOverlay =
        isDark
            ? Color.fromRGBO(255, 255, 255, tintOpacity * 0.6)
            : Color.fromRGBO(255, 255, 255, tintOpacity * 1.2);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 第一层：背景模糊 + 饱和度增强
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.compose(
                  outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  inner: ColorFilter.matrix(
                    <double>[
                      1.12, 0, 0, 0, 0, //
                      0, 1.12, 0, 0, 0, //
                      0, 0, 1.12, 0, 0, //
                      0, 0, 0, 1.0, 0, //
                    ],
                  ),
                ),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 第二层：材质底色（半透明）
            Positioned.fill(child: ColoredBox(color: baseOverlay)),
            // 第三层：折射渐变（模拟玻璃内部光线弯曲）
            if (gradient != null)
              Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(gradient: gradient!)),
              )
            else
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromRGBO(255, 255, 255, isDark ? 0.04 : 0.18),
                        Color.fromRGBO(255, 255, 255, isDark ? 0.01 : 0.06),
                        Color.fromRGBO(255, 255, 255, isDark ? 0.02 : 0.10),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            // 第四层：边缘高光（玻璃边缘的光线反射）
            if (enableHighlight)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border:
                        border ??
                        Border.all(
                          color: Color.fromRGBO(
                            255,
                            255,
                            255,
                            isDark ? 0.10 : 0.35,
                          ),
                          width: 0.6,
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(255, 255, 255, isDark ? 0.06 : 0.5),
                        blurRadius: 1,
                        spreadRadius: 0,
                        offset: const Offset(0, 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            // 第五层：顶部高光线（模拟玻璃顶部反光）
            if (enableHighlight)
              Positioned(
                top: 0,
                left: radius * 0.6,
                right: radius * 0.6,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(255, 255, 255, isDark ? 0.2 : 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            // 阴影层
            if (shadows != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(boxShadow: shadows!),
                ),
              ),
            // 内容
            Align(alignment: alignment ?? Alignment.center, child: child),
          ],
        ),
      ),
    );
  }
}

/// 液态玻璃按钮
///
/// 带按压动画的液态玻璃按钮，按压时有缩放和亮度变化。
class LiquidGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double blurSigma;
  final double radius;
  final EdgeInsets padding;
  final Color? tint;
  final bool enableHighlight;
  final bool expanded;

  const LiquidGlassButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.blurSigma = 24,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.tint,
    this.enableHighlight = true,
    this.expanded = false,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: LiquidGlass(
          blurSigma: widget.blurSigma,
          radius: widget.radius,
          padding: widget.padding,
          tint: widget.tint,
          enableHighlight: widget.enableHighlight,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                size: 20,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
