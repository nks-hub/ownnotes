import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class AttachmentPreviewImage extends StatefulWidget {
  const AttachmentPreviewImage({
    required this.load,
    required this.onRetry,
    required this.placeholder,
    this.width,
    this.height,
    this.alt,
    super.key,
  });

  final Future<List<int>> Function() load;
  final VoidCallback onRetry;
  final Widget placeholder;
  final double? width;
  final double? height;
  final String? alt;

  @override
  State<AttachmentPreviewImage> createState() => _AttachmentPreviewImageState();
}

class _AttachmentPreviewImageState extends State<AttachmentPreviewImage> {
  late Future<List<int>> _bytes = widget.load();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<List<int>>(
      future: _bytes,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasData: true, :final data?) => Image.memory(
          Uint8List.fromList(data),
          width: widget.width,
          height: widget.height,
          semanticLabel: widget.alt,
          errorBuilder: (_, _, _) => widget.placeholder,
        ),
        AsyncSnapshot(connectionState: ConnectionState.done, hasError: true) =>
          TextButton.icon(
            onPressed: () {
              widget.onRetry();
              setState(() {
                _bytes = widget.load();
              });
            },
            icon: const Icon(Icons.refresh),
            label: Text('${l.imageUnavailable}. ${l.retry}'),
          ),
        _ => const SizedBox.square(
          dimension: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }
}
