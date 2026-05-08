import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class MediaPreviewWidget extends StatefulWidget {
  final String? path;
  final String? url;
  final Uint8List? bytes;
  final bool isVideo;

  const MediaPreviewWidget({
    super.key,
    this.path,
    this.url,
    this.bytes,
    required this.isVideo,
  });

  @override
  State<MediaPreviewWidget> createState() => _MediaPreviewWidgetState();
}

class _MediaPreviewWidgetState extends State<MediaPreviewWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.bytes != null && kIsWeb) {
        // Handle bytes on web by creating a Blob URL
        // Using dynamic to avoid direct dart:html dependency if possible,
        // but we can also use conditional imports. 
        // For simplicity in this environment, we'll use a data URI fallback 
        // if it's small, or just note that web bytes needs path-based preview 
        // or a blob helper.
        // Actually, let's use the Uri.dataFromBytes for now, 
        // or check if path is available (file_picker usually provides a blob URL in .path on web)
        if (widget.path != null && widget.path!.startsWith('blob:')) {
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.path!));
        } else {
          // Fallback to data URI if path is null or not a blob
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.dataFromBytes(widget.bytes!, mimeType: 'video/mp4')
          );
        }
      } else if (widget.path != null) {
        if (kIsWeb) {
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.path!));
        } else {
          _videoPlayerController = VideoPlayerController.file(File(widget.path!));
        }
      } else if (widget.url != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      }

      if (_videoPlayerController != null) {
        await _videoPlayerController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          placeholder: const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing video preview: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isVideo) {
      if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
        return Chewie(controller: _chewieController!);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else {
      if (widget.bytes != null) {
        return Image.memory(widget.bytes!, fit: BoxFit.cover);
      }
      if (widget.path != null) {
        return kIsWeb 
          ? Image.network(widget.path!, fit: BoxFit.cover)
          : Image.file(File(widget.path!), fit: BoxFit.cover);
      } else if (widget.url != null) {
        return Image.network(widget.url!, fit: BoxFit.cover);
      }
    }
    return const Icon(Icons.broken_image);
  }
}
