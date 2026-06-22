import "package:flutter/material.dart";

/// 暗黑科技感应用容器
///
/// 强制暗黑模式，底色为 #0D1117（极深暗青黑），
/// 配合 AuroraBackground 流光 + ParticleField 粒子 + LiquidGlass 玻璃，
/// 构建华为式沉浸流光视觉体系。
class TechApp extends MaterialApp {
  final Color primary;
  final Color secondary;
  final String? fontFamily;
  final double? fontSizeFactor;

  TechApp({
    required super.title,
    required this.primary,
    required this.secondary,
    required super.home,
    super.debugShowCheckedModeBanner = false,
    this.fontFamily,
    this.fontSizeFactor,
    super.routes,
    super.key,
  }) : super(
         // 强制暗黑模式，不跟随系统切换
         themeMode: ThemeMode.dark,
         theme: _buildDarkTheme(primary, secondary, fontFamily, fontSizeFactor),
         darkTheme: _buildDarkTheme(primary, secondary, fontFamily, fontSizeFactor),
         builder: (BuildContext context, Widget? child) {
           return Theme(
             data: Theme.of(context).copyWith(
               textTheme: Theme.of(context).textTheme.apply(
                 fontSizeFactor: fontSizeFactor ?? 1.0,
                 fontFamily: fontFamily,
               ),
               scrollbarTheme: Theme.of(context).scrollbarTheme.copyWith(
                 radius: const Radius.circular(8),
                 thumbVisibility: const WidgetStatePropertyAll(true),
                 trackVisibility: const WidgetStatePropertyAll(false),
                 thumbColor: WidgetStateProperty.all(const Color(0x55FFFFFF)),
               ),
               splashColor: Colors.transparent,
               highlightColor: Colors.transparent,
               splashFactory: NoSplash.splashFactory,
               checkboxTheme: CheckboxThemeData(
                 fillColor: WidgetStateMapper<Color?>({
                   WidgetState.selected: primary,
                   WidgetState.any: Colors.transparent,
                 }),
                 checkColor: const WidgetStatePropertyAll(Colors.white),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadiusGeometry.circular(6),
                 ),
                 side: const BorderSide(
                   color: Color(0x55FFFFFF),
                   width: 1.5,
                 ),
               ),
               listTileTheme: ListTileThemeData(
                 horizontalTitleGap: 0,
                 titleTextStyle: const TextStyle(
                   fontSize: 15,
                   fontWeight: FontWeight.w400,
                   color: Color(0xF2FFFFFF),
                 ),
                 controlAffinity: ListTileControlAffinity.leading,
                 contentPadding: EdgeInsets.zero,
                 dense: true,
               ),
               dividerTheme: const DividerThemeData(
                 color: Color(0x22FFFFFF),
                 thickness: 0.5,
                 space: 0.5,
               ),
             ),
             child: child!,
           );
         },
       );

  static ThemeData _buildDarkTheme(
    Color primary,
    Color secondary,
    String? fontFamily,
    double? fontSizeFactor,
  ) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D1117), // 极深暗青黑
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D4AA),     // 青色主色
        secondary: Color(0xFF8E8E93),   // 灰色次要色
        surface: Color(0xFF161B22),     // 卡片表面略亮于底色
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFF2F2F7),   // 文字高对比度白
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xF2FFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xF2FFFFFF),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.1,
          color: Color(0xF2FFFFFF),
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.15,
          color: Color(0xF2FFFFFF),
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: Color(0xF2FFFFFF),
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Color(0xF2FFFFFF),
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Color(0xF2FFFFFF),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          color: Color(0xF2FFFFFF),
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
          height: 1.4,
          color: Color(0xF2FFFFFF),
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w300, // 副标题更细
          letterSpacing: -0.1,
          height: 1.35,
          color: Color(0x99FFFFFF), // 副标题 60% 白色
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: Color(0xF2FFFFFF),
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: Color(0x99FFFFFF), // 提示语 60% 白色
        ),
      ),
    );
  }
}
