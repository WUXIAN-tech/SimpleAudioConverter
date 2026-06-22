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

import "aurora_background.dart";
import "liquid_glass.dart";
import "media_information_view.dart";
import "particle_field.dart";
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
      primary: const Color(0xFF00D4AA), // 青色主色（暗黑科技感）
      secondary: const Color(0xFF8E8E93),
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

  // 页面进入动画控制器
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

  Future<void> initShareReceiving() async {
    final handler = ShareHandlerPlatform.instance;
    final SharedMedia? media = await handler.getInitialSharedMedia();
    if (media != null) openShared(media);

    handler.sharedMediaStream.listen(openShared);
  }

  void openShared(SharedMedia media) {
    Path? path;
    try {
      final attachment = media.attachments?.firstOrNull;
      if (attachment?.path == null) return;
      path = Path(uri: attachment!.path, sharedInto: true);
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

  // ==================== 四层架构主构建 ====================

  @override
  Widget build(BuildContext context) {
    final thisInputFileInfo = inputFileInfo;
    final thisTargetFileType = targetFileType;
    final thisConvertProgress = convertProgress;
    final thisFfmpegSession = ffmpegSession;
    final thisSharedParams = sharedParams;
    final thisFinalSize = finalSize;
    final thisSharedWithApp = sharedWithApp;

    // 是否正在转换（用于流光走圈边框）
    final bool isConverting =
        thisConvertProgress != null && !done;

    return Scaffold(
      extendBodyBehindAppBar: true,
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
          // ════════════════════════════════════════════════════════
          // Layer 1：华为沉浸流光背景（暗青黑底色 + 动态光团）
          // ════════════════════════════════════════════════════════
          const Positioned.fill(child: AuroraBackground()),

          // ════════════════════════════════════════════════════════
          // Layer 2：微光粒子场（呼吸浮动粒子）
          // ════════════════════════════════════════════════════════
          const Positioned.fill(child: ParticleField(count: 20)),

          // ════════════════════════════════════════════════════════
          // Layer 3 & 4：内容层（液态玻璃卡片 + 极简文字图标）
          // 使用弹性滚动物理，突出玻璃对背景的扭曲效果
          // ════════════════════════════════════════════════════════
          SafeArea(
            child: loading
                ? _buildLoadingOverlay()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> anim) {
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
                            isConverting: isConverting,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 加载中的覆盖层
  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 玻璃卡片包裹加载指示器
          LiquidGlass(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00D4AA),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  "正在读取文件…",
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 空状态：选择文件 ====================

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
      // 可滚动容器，带弹性物理
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),

                // 主标题区域（Layer 4：极简文字）
                Text(
                  "音频转换器",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white.withOpacity(0.95),
                    shadows: const [
                      Shadow(
                        color: Color(0x30FFFFFF),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "选择一个视频或音频文件，开始转换",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.55),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // 核心操作区（Layer 3：大块液态玻璃卡片）
                LiquidGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 选择文件按钮（宽扁胶囊形）
                      LiquidGlassButton(
                        onPressed: () async => _pickFile(),
                        expanded: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 22,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 22),
                            SizedBox(width: 10),
                            Text("选择文件", style: TextStyle(fontSize: 17)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 分隔提示
                      Text(
                        "或",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 分享提示文字
                      Text(
                        "也可以从其他应用分享媒体文件到本应用",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.45),
                          height: 1.6,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
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
    }
  }

  // ==================== 转换视图 ====================

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
    required bool isConverting,
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
      // 弹性滚动，突出玻璃扭曲效果
      child: ListView(
        key: key,
        physics: const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 媒体信息卡片（液态玻璃） ──
          MediaInformationView(info: inputFileInfo),
          const SizedBox(height: 20),

          // ── 滤镜选项区 ──
          if (convertProgress == null && !done) ...[
            _buildSectionLabel("滤镜"),
            const SizedBox(height: 10),
            _buildVoiceOptimizationCard(),
            const SizedBox(height: 20),
            _buildSectionLabel("目标格式"),
            const SizedBox(height: 10),
            _buildFormatSelector(targetFileType),
            const SizedBox(height: 20),
            _buildSectionLabel("转换"),
            const SizedBox(height: 12),

            // 转换按钮组（包裹在大玻璃卡片内）
            LiquidGlass(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // 保存位置按钮
                  LiquidGlassButton(
                    onPressed: () async => _pickDestinationFile(
                      inputFileInfo,
                      targetFileType,
                    ),
                    expanded: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_alt_rounded, size: 21),
                        SizedBox(width: 10),
                        Text("选择保存位置",
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 分隔符
                  Center(
                    child: Text(
                      "或",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.40),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 分享到应用按钮
                  LiquidGlassButton(
                    onPressed: () async => _shareToApp(
                      inputFileInfo,
                      targetFileType,
                    ),
                    expanded: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ios_share_rounded, size: 21),
                        SizedBox(width: 10),
                        Text("分享到应用",
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 进度显示区（带流光走圈边框） ──
          if (convertProgress != null || done) ...[
            const SizedBox(height: 8),
            _buildSectionLabel("进度"),
            const SizedBox(height: 14),
            AnimatedGlassBorder(
              isRunning: isConverting,
              progress: convertProgress ?? 0.0,
              borderRadius: 24,
              borderWidth: 2.0,
              gradientColors: const [
                Color(0xFF00D4AA), // 青色
                Color(0xFF00BFFF), // 天蓝
                Color(0xFF7B68EE), // 淡紫
              ],
              child: _buildProgressCard(
                convertProgress: convertProgress,
                done: done,
                targetFileType: targetFileType,
                finalSize: finalSize,
              ),
            ),
          ],

          // ── 取消转换按钮 ──
          if (ffmpegSession != null) ...[
            const SizedBox(height: 16),
            LiquidGlassButton(
              onPressed: () async {
                await ffmpegSession.cancel();
                setState(() {
                      this.convertProgress = null;
                      this.ffmpegSession = null;
                      this.done = false;
                    });
              },
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 18,
              ),
              tint: const Color(0xFFFF3B30),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 20,
                      color: Color(0xFFFF3B30)),
                  SizedBox(width: 8),
                  Text("取消转换",
                      style:
                          TextStyle(fontSize: 16, color: Color(0xFFFF3B30))),
                ],
              ),
            ),
          ],

          // ── 完成后再次分享 ──
          if (sharedParams != null) ...[
            const SizedBox(height: 16),
            LiquidGlassButton(
              onPressed: () => unawaited(share(sharedParams!)),
              expanded: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 18,
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

          // ── 分享成功提示 ──
          if (sharedWithApp != null) ...[
            const SizedBox(height: 16),
            LiquidGlass(
              padding: const EdgeInsets.all(18),
              tint: const Color(0xFF00D4AA),
              tintOpacity: 0.06,
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20,
                      color: Color(0xFF00D4AA)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "已成功分享至：$sharedWithApp",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xF2FFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  /// 区段标签（极简小字）
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── 语音优化选项卡片 ──
  Widget _buildVoiceOptimizationCard() {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "语音优化",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xF2FFFFFF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "降低背景噪音，优化人声清晰度",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.50),
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
            activeColor: const Color(0xFF00D4AA),
          ),
        ],
      ),
    );
  }

  // ── 格式选择器 ──
  Widget _buildFormatSelector(TargetFileType targetFileType) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
            color: Colors.white.withOpacity(0.08),
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
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                size: 23, color: Colors.white.withOpacity(0.50)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xF2FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.45),
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
                        color: const Color(0xFF00D4AA),
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
                          color: Colors.white.withOpacity(0.20),
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

  // ── 进度卡片 ──
  Widget _buildProgressCard({
    required double? convertProgress,
    required bool done,
    required TargetFileType targetFileType,
    required String? finalSize,
  }) {
    return LiquidGlass(
      padding: const EdgeInsets.all(22),
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
                    color: Color(0xF2FFFFFF),
                  ),
                ),
                Text(
                  "${(convertProgress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00D4AA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // 进度条（青色渐变 + 圆角）
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: convertProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00D4AA),
                              Color(0xFF00BFFF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4AA)
                                  .withOpacity(0.35),
                              blurRadius: 8,
                              spreadRadius: -2,
                            ),
                          ],
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
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Color(0xFF00D4AA),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "转换完成！",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xF2FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        finalSize != null
                            ? "已转换为 ${targetFileType.extension.toUpperCase()} · $finalSize"
                            : "已转换为 ${targetFileType.extension.toUpperCase()}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 业务逻辑方法（保持不变） ====================

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
      arnndnModel = await getFileFromAssets("arnndn-models/std.rnnn");
    } else {
      arnndnModel = null;
    }

    final completer = Completer<ReturnCode>();
    final session = await FFmpegKit.executeAsync(
      '-i "$readUrl"'
      "${arnndnModel == null ? "" : " -filter:a 'arnndn=model=${arnndnModel.path}:mix=1.0' "}"
      " ${targetFileType.getAdditionalArguments(
        voiceOptimization: arnndnModel != null,
      )} "
      " -y "
      ' "$writeUrl"',
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
              stacktrace:
                  output?.replaceAll(String.fromCharCode(13), "\n"),
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
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xF2FFFFFF)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error,
                style: const TextStyle(color: Color(0xF2FFFFFF)),
              ),
              const SizedBox(height: 8),
              if (stacktrace != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    stacktrace,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontFamily: "monospace",
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "知道了",
              style: TextStyle(color: Color(0xFF00D4AA)),
            ),
          ),
        ],
      ),
    ),
  );
}
