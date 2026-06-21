import "dart:async";
import "dart:io";

import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffmpeg_session.dart";
import "package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart";
import "package:ffmpeg_kit_flutter_new_audio/log.dart";
import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:ffmpeg_kit_flutter_new_audio/media_information_session.dart";
import "package:ffmpeg_kit_flutter_new_audio/return_code.dart";
import "package:ffmpeg_kit_flutter_new_audio/statistics.dart";
import "package:ffmpeg_kit_flutter_new_audio/stream_information.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:installed_apps/app_info.dart";
import "package:installed_apps/installed_apps.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_handler/share_handler.dart";
import "package:share_plus/share_plus.dart";

import "liquid_glass.dart";
import "media_information_view.dart";
import "path.dart";
import "picked_file_info.dart";
import "target_file_type.dart";
import "tech_app.dart";
import "utils.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TechApp(
      title: "音频转换器",
      // 苹果风格：主色为黑色（亮色）/白色（暗色），不再使用绿色
      primary: const Color(0xFF000000),
      secondary: const Color(0xFF8E8E93),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin {
  late final Directory outputDir;
  late final Directory shareOutputDir;

  bool loading = false;
  PickedFileInfo? inputFileInfo;
  final TargetFileType targetFileType = TargetFileType();
  double? convertProgress;
  FFmpegSession? ffmpegSession;
  bool done = false;
  ShareParams? sharedParams;
  String? finalSize;
  bool voiceOptimization = false;
  String? sharedWithApp;

  // 动画控制器
  late final AnimationController _pageController;
  late final Animation<double> _pageAnimation;

  @override
  void initState() {
    super.initState();
    unawaited(
      getTemporaryDirectory().then((Directory tempDir) {
        outputDir = Directory(p.join(tempDir.path, "output"));
        shareOutputDir = Directory(p.join(tempDir.path, "share_plus"));
        resetOutputDirectory();
      }),
    );
    unawaited(initShareReceiving());

    // 3D 转场动画
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pageAnimation = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _pageController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initShareReceiving() async {
    final handler = ShareHandlerPlatform.instance;
    final SharedMedia? media = await handler.getInitialSharedMedia();
    if (media != null) openShared(media);

    handler.sharedMediaStream.listen(openShared);
  }

  void openShared(SharedMedia media) {
    Path? path;
    try {
      path = Path(uri: media.attachments!.first!.path, sharedInto: true);
      unawaited(openFile(path));
    } catch (e, s) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "打开文件出错",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      path?.deleteIfNecessary();
      return;
    }
  }

  Future<void> openFile(Path path, {bool safIfy = false}) async {
    setState(() => loading = true);

    resetOutputDirectory();
    final MediaInformationSession? session = await getMediaInfo(path);
    if (session == null) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "获取媒体信息出错",
          error: "无法获取读取权限",
        );
      }

      setState(() => loading = false);
      path.deleteIfNecessary();
      return;
    }
    final MediaInformation? information = session.getMediaInformation();

    if (information == null) {
      final String state = FFmpegKitConfig.sessionStateToString(
        await session.getState(),
      );
      final ReturnCode? returnCode = await session.getReturnCode();
      final int duration = await session.getDuration();
      final String? output = await session.getOutput();
      final String? failStackTrace = await session.getFailStackTrace();
      if (mounted) {
        String? outputClean = output;
        if (output != null) {
          final regexp = RegExp(r"^\s*{*\s*(.*?)\s*}*\s*$", dotAll: true);
          final RegExpMatch? match = regexp.firstMatch(output);
          if (match != null) outputClean = match.group(1);
        }
        showErrorDialog(
          context: context,
          title: "获取媒体信息出错",
          error:
              "提供的文件可能不是媒体文件，因此无法从中提取并转换音频。\n"
              "请尝试其他文件。\n\n详细信息：",
          stacktrace:
              "状态: $state\n"
                      "返回码: $returnCode (${returnCode?.getValue()})\n"
                      "耗时: $duration\n"
                      "${outputClean == null ? "" : "输出: $outputClean\n"}"
                      "${failStackTrace == null || failStackTrace.trim().isEmpty ? "" : "堆栈: $failStackTrace\n"}"
                  .trim(),
        );
      }
      setState(() => loading = false);
      path.deleteIfNecessary();
      return;
    }

    if (!information.getStreams().any(
      (StreamInformation streamInfo) => streamInfo.getType() == "audio",
    )) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "文件不包含任何音频",
          error: "请尝试其他文件。",
        );
      }
      setState(() => loading = false);
      path.deleteIfNecessary();
      return;
    }

    setState(() {
      loading = false;
      inputFileInfo = PickedFileInfo(
        path: path,
        mediaInformation: information,
      );
      targetFileType.reset();
      convertProgress = null;
      ffmpegSession = null;
      done = false;
      sharedParams = null;
      finalSize = null;
      sharedWithApp = null;
    });
    // 文件加载完成后重新播放进入动画
    _pageController.reset();
    _pageController.forward();
  }

  void resetOutputDirectory() {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
    if (shareOutputDir.existsSync()) {
      shareOutputDir.deleteSync(recursive: true);
    }
  }

  void _clearFile() {
    setState(() {
      loading = false;
      inputFileInfo = null;
      targetFileType.reset();
      convertProgress = null;
      ffmpegSession = null;
      done = false;
      voiceOptimization = false;
      resetOutputDirectory();
    });
    _pageController.reset();
    _pageController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final thisInputFileInfo = inputFileInfo;
    final thisTargetFileType = targetFileType;
    final thisConvertProgress = convertProgress;
    final thisFfmpegSession = ffmpegSession;
    final thisSharedParams = sharedParams;
    final thisFinalSize = finalSize;
    final thisSharedWithApp = sharedWithApp;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // 移除左上角图标，使用简洁的透明 AppBar
      appBar: AppBar(
        leading: thisInputFileInfo != null
            ? IconButton(
                onPressed: _clearFile,
                icon: const Icon(Icons.chevron_left, size: 28),
                tooltip: "返回",
              )
            : const SizedBox.shrink(),
        title: thisInputFileInfo == null
            ? const Text("音频转换器")
            : Tooltip(
                message: thisInputFileInfo.filename,
                child: Text(
                  thisInputFileInfo.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
      body: Stack(
        children: [
          // 背景渐变层（白色系，营造层次感）
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1C1C1E), const Color(0xFF000000)]
                      : [const Color(0xFFF2F2F7), const Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),
          // 装饰性光晕（液态玻璃背景氛围）
          Positioned(
            top: -100,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x338E8E93),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0x18FFFFFF)
                          : const Color(0x228E8E93),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 主内容
          SafeArea(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "正在读取文件…",
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (Widget child, Animation<double> anim) {
                      // 3D 丝滑转场：Y 轴旋转 + 缩放 + 淡入
                      return AnimatedBuilder(
                        animation: anim,
                        builder: (BuildContext context, Widget? c) {
                          final double t = anim.value;
                          final double angle = (1 - t) * 0.18;
                          final Matrix4 transform =
                              Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..rotateY(-angle)
                                ..scale(0.92 + 0.08 * t);
                          return Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: transform,
                              child: c,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    child: thisInputFileInfo == null
                        ? _buildEmptyState(key: const ValueKey("empty"))
                        : _buildConvertView(
                            key: const ValueKey("convert"),
                            inputFileInfo: thisInputFileInfo,
                            targetFileType: thisTargetFileType,
                            convertProgress: thisConvertProgress,
                            ffmpegSession: thisFfmpegSession,
                            done: done,
                            sharedParams: thisSharedParams,
                            finalSize: thisFinalSize,
                            sharedWithApp: thisSharedWithApp,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // 空状态：选择文件
  Widget _buildEmptyState({Key? key}) {
    return AnimatedBuilder(
      animation: _pageAnimation,
      builder: (BuildContext context, Widget? child) {
        final double t = _pageAnimation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                "音频转换器",
                style: TextTheme.of(context).displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "选择一个音频文件，开始转换",
                style: TextTheme.of(context).bodyMedium?.copyWith(
                  color: const Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 40),
              // 主按钮：液态玻璃质感
              LiquidGlassButton(
                onPressed: () async => _pickFile(),
                expanded: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 22),
                    SizedBox(width: 8),
                    Text("选择文件", style: TextStyle(fontSize: 17)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 提示文字
              Text(
                "或",
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "也可以从其他应用分享音频文件到本应用",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF8E8E93),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final String? uri;
    try {
      uri = await pickFileRead();
    } catch (e, s) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "文件选择器出错",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      return;
    }
    if (uri == null) return; // 用户取消
    try {
      unawaited(openFile(Path(uri: uri, sharedInto: false)));
    } catch (e, s) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "打开文件出错",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      return;
    }
  }

  // 转换视图
  Widget _buildConvertView({
    Key? key,
    required PickedFileInfo inputFileInfo,
    required TargetFileType targetFileType,
    required double? convertProgress,
    required FFmpegSession? ffmpegSession,
    required bool done,
    required ShareParams? sharedParams,
    required String? finalSize,
    required String? sharedWithApp,
  }) {
    return AnimatedBuilder(
      animation: _pageAnimation,
      builder: (BuildContext context, Widget? child) {
        final double t = _pageAnimation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        );
      },
      child: ListView(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // 媒体信息卡片
          MediaInformationView(info: inputFileInfo),
          const SizedBox(height: 24),

          // 滤镜选项
          if (convertProgress == null && !done) ...[
            _buildSectionLabel("滤镜"),
            const SizedBox(height: 10),
            _buildVoiceOptimizationCard(),
            const SizedBox(height: 24),
            _buildSectionLabel("目标格式"),
            const SizedBox(height: 10),
            _buildFormatSelector(targetFileType),
            const SizedBox(height: 24),
            _buildSectionLabel("转换"),
            const SizedBox(height: 12),
            LiquidGlassButton(
              onPressed: () async => _pickDestinationFile(
                inputFileInfo,
                targetFileType,
              ),
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_alt_rounded, size: 20),
                  SizedBox(width: 8),
                  Text("选择保存位置", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "或",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassButton(
              onPressed: () async => _shareToApp(
                inputFileInfo,
                targetFileType,
              ),
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share_rounded, size: 20),
                  SizedBox(width: 8),
                  Text("分享到应用", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],

          // 进度显示
          if (convertProgress != null || done) ...[
            const SizedBox(height: 8),
            _buildSectionLabel("进度"),
            const SizedBox(height: 16),
            _buildProgressCard(
              convertProgress: convertProgress,
              done: done,
              targetFileType: targetFileType,
              finalSize: finalSize,
            ),
          ],

          // 取消按钮
          if (ffmpegSession != null) ...[
            const SizedBox(height: 16),
            LiquidGlassButton(
              onPressed: () async {
                await ffmpegSession.cancel();
                setState(() {
                  this.convertProgress = null;
                  this.ffmpegSession = null;
                  done = false;
                });
              },
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              tint: const Color(0xFFFF3B30),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 20, color: Color(0xFFFF3B30)),
                  SizedBox(width: 8),
                  Text(
                    "取消转换",
                    style: TextStyle(fontSize: 16, color: Color(0xFFFF3B30)),
                  ),
                ],
              ),
            ),
          ],

          // 完成后的分享按钮
          if (sharedParams != null) ...[
            const SizedBox(height: 16),
            LiquidGlassButton(
              onPressed: () => unawaited(share(sharedParams)),
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_rounded, size: 20),
                  SizedBox(width: 8),
                  Text("再次分享", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],

          // 分享成功提示
          if (sharedWithApp != null) ...[
            const SizedBox(height: 16),
            LiquidGlass(
              padding: const EdgeInsets.all(14),
              tint: const Color(0xFF000000),
              tintOpacity: 0.04,
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "已成功分享至：$sharedWithApp",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // 语音优化选项卡片
  Widget _buildVoiceOptimizationCard() {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "语音优化",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  "降低背景噪音，优化人声",
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: voiceOptimization,
            onChanged: (bool value) => setState(() {
              voiceOptimization = value;
            }),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // 格式选择器
  Widget _buildFormatSelector(TargetFileType targetFileType) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          _buildFormatOption(
            targetFileType: targetFileType,
            value: "opus",
            label: "Opus",
            description: "最佳压缩与质量，兼容性良好",
            icon: Icons.graphic_eq_rounded,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: Theme.of(context).dividerTheme.color,
          ),
          _buildFormatOption(
            targetFileType: targetFileType,
            value: "mp3",
            label: "MP3",
            description: "压缩与质量良好，兼容性最佳",
            icon: Icons.music_note_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption({
    required TargetFileType targetFileType,
    required String value,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final bool selected = targetFileType.extension == value;
    return InkWell(
      onTap: () => setState(() {
        targetFileType.extension = value;
      }),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Container(
                      key: const ValueKey("selected"),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      key: const ValueKey("unselected"),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x338E8E93),
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 进度卡片
  Widget _buildProgressCard({
    required double? convertProgress,
    required bool done,
    required TargetFileType targetFileType,
    required String? finalSize,
  }) {
    return LiquidGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!done && convertProgress != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "正在转换为 ${targetFileType.extension.toUpperCase()}…",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "${(convertProgress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 自定义进度条：圆角 + 动画
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // 轨道
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x1A8E8E93),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // 进度
                    FractionallySizedBox(
                      widthFactor: convertProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF000000), Color(0xFF3C3C43)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (done) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "转换完成！",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        finalSize != null
                            ? "已转换为 ${targetFileType.extension.toUpperCase()} · $finalSize"
                            : "已转换为 ${targetFileType.extension.toUpperCase()}",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickDestinationFile(
    PickedFileInfo inputFileInfo,
    TargetFileType targetFileType,
  ) async {
    final String? targetUri;
    try {
      final String filename = inputFileInfo.filename.contains(":")
          ? "audio.${targetFileType.extension}"
          : "${p.withoutExtension(inputFileInfo.filename)}.${targetFileType.extension}";
      targetUri = await pickFileWrite(
        filename,
        targetFileType.getMimeType(),
      );
    } catch (e, s) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "目标位置选择器出错",
          error: e.toString(),
          stacktrace: s.toString(),
        );
      }
      return;
    }
    if (targetUri == null) return;

    final String? writeSafUrl =
        await FFmpegKitConfig.getSafParameterForWrite(targetUri);
    if (writeSafUrl == null) {
      if (context.mounted) {
        showErrorDialog(
          context: context,
          title: "解析目标路径出错",
          error: "writeSafUrl 为空",
        );
      }
      return;
    }

    unawaited(
      doTheConvert(
        inputFileInfo: inputFileInfo,
        targetFileType: targetFileType,
        writeUrl: writeSafUrl,
      ),
    );
  }

  Future<void> _shareToApp(
    PickedFileInfo inputFileInfo,
    TargetFileType targetFileType,
  ) async {
    final String filename =
        "${p.withoutExtension(inputFileInfo.filename)}.${targetFileType.extension}";
    final String targetFilePath = p.join(outputDir.path, filename);
    final bool success = (await doTheConvert(
      inputFileInfo: inputFileInfo,
      targetFileType: targetFileType,
      writeUrl: targetFilePath,
    )).isValueSuccess();
    if (!success) return;

    final params = ShareParams(
      text: "分享 $filename",
      files: [XFile(targetFilePath)],
    );

    await share(params);
    setState(() {
      sharedParams = params;
    });
  }

  Future<void> share(ShareParams thisShared) async {
    final shareResult = await SharePlus.instance.share(thisShared);
    if (shareResult.status == ShareResultStatus.success) {
      final String sharedWith = shareResult.raw;
      final String appID = sharedWith.split("/").first;
      final AppInfo? appInfo = await InstalledApps.getAppInfo(appID);
      if (appInfo == null) return;
      setState(() => sharedWithApp = appInfo.name);
    }
  }

  Future<ReturnCode> doTheConvert({
    required PickedFileInfo inputFileInfo,
    required TargetFileType targetFileType,
    required String writeUrl,
  }) async {
    final String? readUrl = await inputFileInfo.path.getUrl();
    if (readUrl == null) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "解析源文件路径出错",
          error: "readUrl 为空",
        );
      }
      return ReturnCode(1);
    }

    final double? duration = double.tryParse(
      inputFileInfo.mediaInformation.getDuration() ?? "",
    );
    if (duration == null) {
      if (mounted) {
        showErrorDialog(
          context: context,
          title: "解析媒体时长出错",
          error: "时长为空",
        );
      }
      return ReturnCode(1);
    }

    setState(() {
      convertProgress = 0.0;
      ffmpegSession = null;
      done = false;
    });

    final File? arnndnModel;
    if (voiceOptimization) {
      //Source: https://github.com/richardpl/arnndn-models
      //std.rnnn is originally bundled with Xiph RNNoise implementation (https://github.com/xiph/rnnoise/blob/master/src/rnn_data.c)
      //Another good place for info: https://github.com/GregorR/rnnoise-models/tree/master
      arnndnModel = await getFileFromAssets("arnndn-models/std.rnnn");
    } else {
      arnndnModel = null;
    }

    final completer = Completer<ReturnCode>();
    final session = await FFmpegKit.executeAsync(
      '-i "$readUrl"' //input (in double quotes to handle spaces)
      "${arnndnModel == null ? "" : " -filter:a 'arnndn=model=${arnndnModel.path}:mix=1.0' "}" //apply filters to audio streams: the arnndn denoise model
      " ${targetFileType.getAdditionalArguments(
        voiceOptimization: arnndnModel != null,
      )} "
      " -y " //overwrite
      ' "$writeUrl"', //output
      /* completeCallback */ (FFmpegSession session) async {
        print("command: ${session.getCommand()}");
        final ReturnCode? returnCode = await session.getReturnCode();
        if (returnCode?.isValueCancel() ?? false) {
          setState(() {
            convertProgress = null;
            ffmpegSession = null;
            done = false;
          });
        } else if (returnCode?.isValueSuccess() ?? false) {
          inputFileInfo.path.deleteIfNecessary();
          setState(() {
            convertProgress = null;
            ffmpegSession = null;
            done = true;
          });
        } else if (returnCode?.isValueError() ?? false) {
          final String? output = await session.getOutput();
          if (mounted) {
            showErrorDialog(
              context: context,
              title: "转换时出错",
              error: "日志：",
              //ffmpeg likes to use the same line for all the progress notifications,
              // so it uses a Carriage Return to overwrite the current line.
              // This is of course not supported here, so we replace it with a newline
              stacktrace: output?.replaceAll(String.fromCharCode(13), "\n"),
            );
            setState(() {
              convertProgress = null;
              ffmpegSession = null;
              done = false;
            });
          }
        }
        final String? sizeStr = intToSize(
          (await session.getLastReceivedStatistics())?.getSize(),
        );
        setState(() => finalSize = sizeStr);
        completer.complete(returnCode);
      },
      /* logCallback */ (Log log) {
        print(log.getMessage());
      },
      /* statisticsCallback */ (Statistics statistics) {
        setState(() {
          convertProgress = statistics.getTime() / (duration * 1000);
        });
      },
    );
    setState(() {
      ffmpegSession = session;
    });

    return completer.future;
  }

  static Future<String?> pickFileRead() async {
    try {
      return await FFmpegKitConfig.selectDocumentForRead();
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<String?> pickFileWrite(String title, String? type) async {
    try {
      return await FFmpegKitConfig.selectDocumentForWrite(title, type);
    } on PlatformException catch (e) {
      if (e.code == "SELECT_CANCELLED") return null;
      rethrow;
    }
  }

  static Future<MediaInformationSession?> getMediaInfo(
    Path path, [
    int? waitTimeout,
  ]) async {
    final String? url = await path.getUrl();
    if (url == null) return null;
    final List<String> commandArguments = [
      "-hide_banner",
      ...["-v", "error"],
      ...["-print_format", "json"],
      "-show_format",
      "-show_streams",
      "-i",
      url,
    ];
    return FFprobeKit.getMediaInformationFromCommandArguments(
      commandArguments,
      waitTimeout,
    );
  }
}

void showErrorDialog({
  required BuildContext context,
  required String title,
  required String error,
  String? stacktrace,
}) {
  unawaited(
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(20),
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error),
              const SizedBox(height: 8),
              if (stacktrace != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    stacktrace,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontFamily: "monospace",
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("知道了"),
          ),
        ],
      ),
    ),
  );
}
