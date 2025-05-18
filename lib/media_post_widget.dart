import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

/// MediaPost widget that displays either images or videos from a list of URLs.
/// Supports swipe navigation through multiple media items.
/// Calls [onNavigate] callback with a boolean indicating whether it's a single video or not.
class MediaPost extends StatefulWidget {
  final List<String> mediaUrls; // List of media URLs (images/videos)
  final double width; // Width of media display
  final double height; // Height of media display

  /// Callback triggered automatically to notify if it's a single video
  final Function(bool isSingleVideo) onNavigate;

  const MediaPost({
    Key? key,
    required this.mediaUrls,
    required this.width,
    required this.height,
    required this.onNavigate,
  }) : super(key: key);

  @override
  _MediaPostState createState() => _MediaPostState();
}

class _MediaPostState extends State<MediaPost> {
  int _currentIndex = 0; // Current page index for PageView
  final List<_ShotsState?> _videoControllers = [];

  static final List<String> videoExtensions = ['.mp4', '.mov', '.avi', '.mkv'];

  @override
  void initState() {
    super.initState();

    // Initialize list for storing _ShotsState refs for all videos (nullable)
    for (var _ in widget.mediaUrls) {
      _videoControllers.add(null);
    }

    // Notify parent immediately if single video or not
    final isSingleVideo =
        widget.mediaUrls.length == 1 && _isVideo(widget.mediaUrls[0]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNavigate(isSingleVideo);
    });
  }

  bool _isVideo(String url) {
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.endsWith(ext));
  }

  /// Build the media widget for given index, caching _Shots state references for videos
  Widget _buildMediaItem(int index) {
    final mediaUrl = widget.mediaUrls[index];

    if (_isVideo(mediaUrl)) {
      return _Shots(
        key: ValueKey(mediaUrl),
        videoUrl: mediaUrl,
        width: widget.width,
        height: widget.height,
        onControllerCreated: (controllerState) {
          _videoControllers[index] = controllerState;
          // If this is current index, ensure video is playing
          if (index == _currentIndex) {
            controllerState.playVideo();
          } else {
            controllerState.pauseVideo();
          }
        },
      );
    } else {
      return Image.network(mediaUrl, fit: BoxFit.cover);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      // Pause previous video if any
      if (_currentIndex < _videoControllers.length) {
        _videoControllers[_currentIndex]?.pauseVideo();
      }
      _currentIndex = index;
      // Play current video if video
      if (_currentIndex < _videoControllers.length) {
        _videoControllers[_currentIndex]?.playVideo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: PageView.builder(
            itemCount: widget.mediaUrls.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildMediaItem(index);
            },
          ),
        ),
        if (widget.mediaUrls.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.mediaUrls.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index ? Colors.blue : Colors.grey,
                ),
              );
            }),
          ),
      ],
    );
  }
}

/// Internal widget responsible for video playback with mobile and web support.
/// Uses VideoPlayerController + Chewie for cross-platform video handling.
/// Reports its controller state back to parent via onControllerCreated callback.
class _Shots extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;

  /// Callback to report back the internal state for control from parent
  final void Function(_ShotsState controllerState)? onControllerCreated;

  const _Shots({
    Key? key,
    required this.videoUrl,
    required this.width,
    required this.height,
    this.onControllerCreated,
  }) : super(key: key);

  @override
  State<_Shots> createState() => _ShotsState();
}

class _ShotsState extends State<_Shots> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isMuted = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      )
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(1);
        _videoController.play();

        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: true,
            showControls: false,
          );
        });

        // Inform parent controller created & ready
        widget.onControllerCreated?.call(this);
      });
  }

  void toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0 : 1);
    });
  }

  void togglePlayPause() {
    if (!_videoController.value.isInitialized) return;

    setState(() {
      _isPaused = !_isPaused;
      _isPaused ? _videoController.pause() : _videoController.play();
    });
  }

  void handleHold(bool isHolding) {
    if (!_videoController.value.isInitialized || kIsWeb) return;

    setState(() {
      _isPaused = isHolding;
      isHolding ? _videoController.pause() : _videoController.play();
    });
  }

  void handleVisibility(bool isVisible) {
    if (!_videoController.value.isInitialized) return;

    isVisible ? _videoController.play() : _videoController.pause();
  }

  /// Expose play and pause for parent widget control
  void playVideo() {
    if (_videoController.value.isInitialized &&
        _videoController.value.isPlaying == false) {
      _videoController.play();
      setState(() {
        _isPaused = false;
      });
    }
  }

  void pauseVideo() {
    if (_videoController.value.isInitialized &&
        _videoController.value.isPlaying) {
      _videoController.pause();
      setState(() {
        _isPaused = true;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video =
        _chewieController != null && _videoController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const Center(child: CircularProgressIndicator());

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        final visiblePercentage = info.visibleFraction * 100;
        handleVisibility(visiblePercentage > 50);
      },
      child: GestureDetector(
        onTap: toggleMute,
        onLongPressStart: (_) => handleHold(true),
        onLongPressEnd: (_) => handleHold(false),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              kIsWeb
                  ? video
                  : InteractiveViewer(
                    panEnabled: true,
                    minScale: 1,
                    maxScale: 3,
                    child: video,
                  ),
              if (kIsWeb)
                Positioned(
                  top: MediaQuery.of(context).size.height / 2 - 24,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: toggleMute,
                      ),
                      IconButton(
                        icon: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: togglePlayPause,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
