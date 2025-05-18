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

  /// Callback triggered when user wants to navigate, passing true if it's a single video.
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

  /// Builds the video player widget using the internal _Shots widget
  Widget _buildVideoPlayer(String videoUrl) {
    return _Shots(
      videoUrl: videoUrl,
      width: widget.width,
      height: widget.height,
    );
  }

  /// Returns a widget depending on the media type (image or video)
  Widget _buildMediaItem(int index) {
    final mediaUrl = widget.mediaUrls[index];

    // If the media URL ends with '.mp4' treat it as a video
    if (mediaUrl.toLowerCase().endsWith('.mp4')) {
      return _buildVideoPlayer(mediaUrl);
    } else {
      // Otherwise, treat it as an image
      return Image.network(mediaUrl, fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if there is exactly one media and it's a video
    final isSingleVideo = widget.mediaUrls.length == 1 &&
        widget.mediaUrls[0].toLowerCase().endsWith('.mp4');

    return Column(
      children: [
        // Media display area with swipe gesture to switch between media
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: PageView.builder(
            itemCount: widget.mediaUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildMediaItem(index);
            },
          ),
        ),

        // Dots indicator shown only if more than one media
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

        // Button that triggers the navigation callback,
        // passing true if single video, false otherwise.
        ElevatedButton(
          onPressed: () => widget.onNavigate(isSingleVideo),
          child: Text('Navigate'),
        ),
      ],
    );
  }
}

/// Internal widget responsible for video playback with mobile and web support.
/// Uses VideoPlayerController + Chewie for cross-platform video handling.
class _Shots extends StatefulWidget {
  final String videoUrl; // URL of the video to play
  final double width; // Width to display video
  final double height; // Height to display video

  const _Shots({
    Key? key,
    required this.videoUrl,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<_Shots> createState() => _ShotsState();
}

class _ShotsState extends State<_Shots> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isMuted = false; // Track mute state
  bool _isPaused = false; // Track play/pause state

  @override
  void initState() {
    super.initState();

    // Initialize video controller with network video URL
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        // Set video looping and volume once initialized
        _videoController.setLooping(true);
        _videoController.setVolume(1); // Start unmuted
        _videoController.play();

        // Initialize Chewie controller for enhanced video controls (cross-platform)
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: true,
            showControls: false, // Hide default controls for custom UI
          );
        });
      });
  }

  /// Toggle mute/unmute video
  void toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0 : 1);
    });
  }

  /// Toggle between play and pause
  void togglePlayPause() {
    if (!_videoController.value.isInitialized) return;

    setState(() {
      _isPaused = !_isPaused;
      _isPaused ? _videoController.pause() : _videoController.play();
    });
  }

  /// Handle long press hold to pause/play video (mobile only)
  void handleHold(bool isHolding) {
    if (!_videoController.value.isInitialized || kIsWeb) return;

    setState(() {
      _isPaused = isHolding;
      isHolding ? _videoController.pause() : _videoController.play();
    });
  }

  /// Pause video if visibility below 50%, play otherwise
  void handleVisibility(bool isVisible) {
    if (!_videoController.value.isInitialized) return;

    isVisible ? _videoController.play() : _videoController.pause();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show Chewie player if video initialized, else show loading spinner
    final video =
        _chewieController != null && _videoController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const Center(child: CircularProgressIndicator());

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      // Pause video when less than 50% visible to user
      onVisibilityChanged: (info) {
        final visiblePercentage = info.visibleFraction * 100;
        handleVisibility(visiblePercentage > 50);
      },
      child: GestureDetector(
        // Tap to toggle mute/unmute on all platforms
        onTap: toggleMute,
        // Long press gestures to pause/play on mobile only
        onLongPressStart: (_) => handleHold(true),
        onLongPressEnd: (_) => handleHold(false),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Use InteractiveViewer on mobile to allow zoom & pan,
              // show video directly on web without zoom
              kIsWeb
                  ? video
                  : InteractiveViewer(
                      panEnabled: true,
                      minScale: 1,
                      maxScale: 3,
                      child: video,
                    ),

              // On web only, show mute and play/pause buttons overlay
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
