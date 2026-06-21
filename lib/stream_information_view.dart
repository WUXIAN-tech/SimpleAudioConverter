import "package:ffmpeg_kit_flutter_new_audio/stream_information.dart";
import "package:flutter/material.dart";

import "utils.dart";

class StreamInformationView extends StatelessWidget {
  final StreamInformation info;

  const StreamInformationView({required this.info, super.key});

  @override
  Widget build(BuildContext context) {
    final int? bitrateNum = int.tryParse(info.getBitrate() ?? "");
    final String? bitrate = bitrateNum == null
        ? null
        : "${(bitrateNum / 1000.0).toStringAsFixed(0)} Kbps";

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "流 ${info.getIndex()} 信息：",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              TableRow(children: tr("类型：", info.getType(), context)),
              TableRow(children: tr("编码：", info.getCodec(), context)),
              TableRow(children: tr("格式：", info.getFormat(), context)),
              TableRow(children: tr("声道布局：", info.getChannelLayout(), context)),
              TableRow(children: tr("比特率：", bitrate, context)),
              TableRow(children: tr("采样率：", info.getSampleRate(), context)),
            ],
          ),
        ],
      ),
    );
  }
}
