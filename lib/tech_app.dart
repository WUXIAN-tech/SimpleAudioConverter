import "package:flutter/material.dart";

/// 苹果风格应用容器
///
/// 现代简约白色系主题，去除绿色元素，采用 SF Pro 风格字体配置。
/// 主题色为黑色（亮色模式）/白色（暗色模式），背景为纯白/纯黑，
/// 强调留白与层次感，配合 [LiquidGlass] 实现液态玻璃质感。
class TechApp extends MaterialApp {
  final Color primary;
  final Color secondary;
  final String? fontFamily;
  final double? fontSizeFactor;

  TechApp({
    required super.title,
    required this.primary,
    required this.secondary,
    required super.themeMode,
    required super.home,
    super.debugShowCheckedModeBanner = false,
    this.fontFamily,
    this.fontSizeFactor,
    super.routes,
    super.key,
  }) : super(
         theme: ThemeData(
           useMaterial3: true,
           brightness: Brightness.light,
           scaffoldBackgroundColor: const Color(0xFFF2F2F7),
           colorScheme: ColorScheme.light(
             primary: primary,
             secondary: secondary,
             surface: const Color(0xFFFFFFFF),
             onPrimary: Colors.white,
             onSecondary: Colors.white,
             onSurface: Colors.black,
           ),
           appBarTheme: const AppBarTheme(
             backgroundColor: Colors.transparent,
             foregroundColor: Colors.black,
             elevation: 0,
             scrolledUnderElevation: 0,
             centerTitle: true,
             titleTextStyle: TextStyle(
               color: Colors.black,
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
             ),
             displayMedium: TextStyle(
               fontSize: 28,
               fontWeight: FontWeight.w700,
               letterSpacing: -0.4,
               height: 1.15,
             ),
             headlineLarge: TextStyle(
               fontSize: 24,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.3,
             ),
             headlineMedium: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.2,
             ),
             titleLarge: TextStyle(
               fontSize: 17,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.2,
             ),
             titleMedium: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w500,
               letterSpacing: -0.1,
             ),
             bodyLarge: TextStyle(
               fontSize: 17,
               fontWeight: FontWeight.w400,
               letterSpacing: -0.2,
               height: 1.4,
             ),
             bodyMedium: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w400,
               letterSpacing: -0.1,
               height: 1.35,
             ),
             labelLarge: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.1,
             ),
           ),
         ),
         darkTheme: ThemeData(
           useMaterial3: true,
           brightness: Brightness.dark,
           scaffoldBackgroundColor: const Color(0xFF000000),
           colorScheme: ColorScheme.dark(
             primary: primary,
             secondary: secondary,
             surface: const Color(0xFF1C1C1E),
             onPrimary: Colors.white,
             onSecondary: Colors.white,
             onSurface: Colors.white,
           ),
           appBarTheme: const AppBarTheme(
             backgroundColor: Colors.transparent,
             foregroundColor: Colors.white,
             elevation: 0,
             scrolledUnderElevation: 0,
             centerTitle: true,
             titleTextStyle: TextStyle(
               color: Colors.white,
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
             ),
             displayMedium: TextStyle(
               fontSize: 28,
               fontWeight: FontWeight.w700,
               letterSpacing: -0.4,
               height: 1.15,
             ),
             headlineLarge: TextStyle(
               fontSize: 24,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.3,
             ),
             headlineMedium: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.2,
             ),
             titleLarge: TextStyle(
               fontSize: 17,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.2,
             ),
             titleMedium: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w500,
               letterSpacing: -0.1,
             ),
             bodyLarge: TextStyle(
               fontSize: 17,
               fontWeight: FontWeight.w400,
               letterSpacing: -0.2,
               height: 1.4,
             ),
             bodyMedium: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w400,
               letterSpacing: -0.1,
               height: 1.35,
             ),
             labelLarge: TextStyle(
               fontSize: 15,
               fontWeight: FontWeight.w600,
               letterSpacing: -0.1,
             ),
           ),
         ),
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
                 thumbColor: WidgetStateProperty.all(
                   Theme.of(context).brightness == Brightness.dark
                       ? const Color(0x55FFFFFF)
                       : const Color(0x55000000),
                 ),
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
                 side: BorderSide(
                   color: Theme.of(context).brightness == Brightness.dark
                       ? const Color(0x55FFFFFF)
                       : const Color(0x55000000),
                   width: 1.5,
                 ),
               ),
               listTileTheme: ListTileThemeData(
                 horizontalTitleGap: 0,
                 titleTextStyle: TextTheme.of(
                   context,
                 ).titleMedium?.copyWith(fontWeight: FontWeight.w400),
                 controlAffinity: ListTileControlAffinity.leading,
                 contentPadding: EdgeInsets.zero,
                 dense: true,
               ),
               dividerTheme: DividerThemeData(
                 color: Theme.of(context).brightness == Brightness.dark
                     ? const Color(0x22FFFFFF)
                     : const Color(0x22000000),
                 thickness: 0.5,
                 space: 0.5,
               ),
             ),
             child: child!,
           );
         },
       );
}
