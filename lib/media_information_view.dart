import "package:ffmpeg_kit_flutter_new_audio/media_information.dart";
import "package:flutter/material.dart";

import "liquid_glass.dart";
import "picked_file_info.dart";
import "stream_information_view.dart";
import "utils.dart";

class MediaInformationView extends StatefulWidget {
  final PickedFileInfo info;

  const MediaInformationView({required this.info, super.key});

  @override
  State<MediaInformationView> createState() => _MediaInformationViewState();
}

class _MediaInformationViewState extends State<MediaInformationView>
    with SingleTickerProviderStateMixin {
  MediaInformation get info => widget.info.mediaInformation;

  String get filename => widget.info.filename;

  bool open = false;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => open = !open);
    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? bitrateNum = int.tryParse(info.getBitrate() ?? "");
    final String? bitrate = bitrateNum == null
        ? null
        : "${(bitrateNum / 1000.0).toStringAsFixed(0)} Kbps";

    final double? durationNum = double.tryParse(info.getDuration() ?? "");
    final String? duration = durationNum == null ? null : formatSeconds(durationNum);

    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  open
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 22,
                  color: const Color(0xFF8E8E93),
                ),
                const SizedBox(width: 4),
                Text(
                  "媒体信息",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 文件名
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: tr("文件名：  ", filename, context, inRow: true),
                        ),
                        const SizedBox(height: 8),
                        Table(
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(children: tr("格式：", info.getFormat(), context)),
                            TableRow(children: tr("大小：", strToSize(info.getSize()), context)),
                            TableRow(children: tr("时长：", duration, context)),
                            TableRow(children: tr("比特率：", bitrate, context)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final stream in info.getStreams())
                          StreamInformationView(info: stream),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String formatSeconds(double totalSeconds) {
    final double hours = totalSeconds / 3600;
    final double minutes = (totalSeconds % 3600) / 60;
    final double seconds = totalSeconds % 60;
    final double milliseconds = (totalSeconds * 1000) % 1000;

    final int iHours = hours.floor();
    final int iMinutes = minutes.floor();
    final int iSeconds = seconds.floor();
    final int iMilliseconds = milliseconds.floor();

    return "$iHours:${iMinutes.toString().padLeft(2, "0")}:${iSeconds.toString().padLeft(2, "0")}.${iMilliseconds.toString().padLeft(3, "0")}";
  }
}
