import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dlna_device_dialog.dart';

// 功能菜单项组件
class _FunctionMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode focusNode;

  const _FunctionMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.focusNode,
  });

  @override
  State<_FunctionMenuItem> createState() => _FunctionMenuItemState();
}

class _FunctionMenuItemState extends State<_FunctionMenuItem> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        setState(() {});
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: widget.focusNode.hasFocus
              ? BoxDecoration(
                  border: Border.all(
                    color: Colors.red,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Column(
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 带 hover 效果的按钮组件
class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const HoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class PCPlayerControls extends StatefulWidget {
  final VideoState state;
  final Player player;
  final VoidCallback? onBackPressed;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPause;
  final String videoUrl;
  final bool isLastEpisode;
  final bool isLoadingVideo;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final String? sourceName;
  final Function(bool isFullscreen)? onDLNAButtonPressed;
  final Function(bool isWebFullscreen)? onWebFullscreenChanged;
  final Function(VoidCallback)? onExitWebFullscreenCallbackReady;
  final VoidCallback? onExitFullScreen;
  final bool live;
  final ValueNotifier<double> playbackSpeedListenable;
  final Future<void> Function(double speed) onSetSpeed;

  const PCPlayerControls({
    super.key,
    required this.state,
    required this.player,
    this.onBackPressed,
    this.onNextEpisode,
    this.onPause,
    required this.videoUrl,
    this.isLastEpisode = false,
    this.isLoadingVideo = false,
    this.onCastStarted,
    this.videoTitle,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.sourceName,
    this.onDLNAButtonPressed,
    this.onWebFullscreenChanged,
    this.onExitWebFullscreenCallbackReady,
    this.onExitFullScreen,
    this.live = false,
    required this.playbackSpeedListenable,
    required this.onSetSpeed,
  });

  @override
  State<PCPlayerControls> createState() => _PCPlayerControlsState();
}

class _PCPlayerControlsState extends State<PCPlayerControls> {
  Timer? _hideTimer;
  bool _controlsVisible = true;
  Size? _screenSize;
  Duration? _dragPosition;
  bool _isSeekingViaSwipe = false;
  double _swipeStartX = 0;
  Duration _swipeStartPosition = Duration.zero;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  bool _isFullscreen = false;
  bool _isWebFullscreen = false;
  bool _showSpeedMenu = false;
  bool _showVolumeMenu = false;
  bool _showFunctionMenu = false;
  double _volumeBeforeMute = 1.0;
  Timer? _volumeMenuHideTimer;
  final FocusNode _focusNode = FocusNode();

  // 功能菜单焦点管理
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _volumeFocusNode = FocusNode();
  final FocusNode _speedFocusNode = FocusNode();
  final FocusNode _fullscreenFocusNode = FocusNode();
  final FocusNode _closeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupPlayerListeners();
    // 注册退出网页全屏的回调
    widget.onExitWebFullscreenCallbackReady?.call(exitWebFullscreen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _forceStartHideTimer();
        // 请求焦点以接收键盘事件
        _focusNode.requestFocus();
      }
    });
  }

  void _setupPlayerListeners() {
    _playingSubscription = widget.player.stream.playing.listen((playing) {
      if (!mounted) return;

      if (playing) {
        if (_controlsVisible) {
          _startHideTimer();
        }
      } else {
        _hideTimer?.cancel();
        if (!_controlsVisible) {
          setState(() {
            _controlsVisible = true;
          });
        }
      }
    });

    // 监听播放位置变化，实时更新进度指示器
    _positionSubscription = widget.player.stream.position.listen((_) {
      if (mounted && _controlsVisible && !_isSeekingViaSwipe) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void didUpdateWidget(PCPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 widget 更新时，尝试同步全屏状态
    // 使用 try-catch 避免在不安全的时机访问 InheritedWidget
    try {
      final actualFullscreen = widget.state.isFullscreen();
      if (_isFullscreen != actualFullscreen) {
        // 检测到从全屏退出
        if (_isFullscreen && !actualFullscreen) {
          widget.onExitFullScreen?.call();
        }
        setState(() {
          _isFullscreen = actualFullscreen;
        });
      }
    } catch (e) {
      // 如果无法安全获取状态，保持当前状态不变
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeMenuHideTimer?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _focusNode.dispose();
    _playPauseFocusNode.dispose();
    _volumeFocusNode.dispose();
    _speedFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _closeFocusNode.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // 如果倍速菜单或音量菜单正在显示，不启动隐藏定时器
    if (_showSpeedMenu || _showVolumeMenu) {
      return;
    }
    if (widget.player.state.playing) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

  void _forceStartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    setState(() {
      _controlsVisible = true;
    });
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showVolumeMenuTemporarily() {
    // 取消之前的定时器
    _volumeMenuHideTimer?.cancel();

    // 显示音量条
    setState(() {
      _showVolumeMenu = true;
    });

    // 1秒后自动隐藏
    _volumeMenuHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showVolumeMenu = false;
        });
      }
    });
  }

  void _onBlankAreaTap() {
    // live 模式下不响应空白区域点击
    if (widget.live) {
      return;
    }
    // 单击空白区域切换播放/暂停
    if (widget.player.state.playing) {
      widget.player.pause();
      widget.onPause?.call();
    } else {
      widget.player.play();
    }
    setState(() {});
  }

  void _onBlankAreaDoubleTap() {
    // 双击空白区域切换全屏
    // 如果在网页全屏模式，先切换到真全屏
    if (_isWebFullscreen && !_isFullscreen) {
      _toggleWebFullscreen();
    }
    _toggleFullscreen();
  }

  void _onSeekStart() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = true;
      _dragPosition = null;
    });
    _hideTimer?.cancel();
    _startHideTimer();
  }

  void _onSeekEnd() {
    setState(() {
      _dragPosition = null;
    });
    _startHideTimer();
  }

  void _onSwipeStart(DragStartDetails details) {
    if (!mounted || widget.live) return;

    setState(() {
      _isSeekingViaSwipe = true;
      _swipeStartX = details.globalPosition.dx;
      _swipeStartPosition = widget.player.state.position;
      _controlsVisible = true;
    });

    _hideTimer?.cancel();
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (!mounted || !_isSeekingViaSwipe || _screenSize == null || widget.live) return;

    final screenWidth = _screenSize!.width;
    final swipeDistance = details.globalPosition.dx - _swipeStartX;
    final swipeRatio = swipeDistance / (screenWidth * 0.5);
    final duration = widget.player.state.duration;

    final targetPosition = _swipeStartPosition +
        Duration(
            milliseconds: (duration.inMilliseconds * swipeRatio * 0.1).round());
    final clampedPosition = Duration(
        milliseconds:
            targetPosition.inMilliseconds.clamp(0, duration.inMilliseconds));

    setState(() {
      _dragPosition = clampedPosition;
    });
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (!mounted || !_isSeekingViaSwipe || widget.live) return;

    if (_dragPosition != null) {
      widget.player.seek(_dragPosition!);
    }

    setState(() {
      _isSeekingViaSwipe = false;
      _dragPosition = null;
    });

    _startHideTimer();
  }

  void _toggleFullscreen() {
    // 直接触发全屏切换，不要提前更新本地状态
    // 状态会在 didUpdateWidget 中同步
    if (_isFullscreen) {
      widget.state.exitFullscreen();
    } else {
      widget.state.enterFullscreen();
    }
  }

  void _toggleWebFullscreen() {
    final wasWebFullscreen = _isWebFullscreen;
    setState(() {
      _isWebFullscreen = !_isWebFullscreen;
    });
    // 通知父组件网页全屏状态变化
    widget.onWebFullscreenChanged?.call(_isWebFullscreen);
    // 如果从网页全屏退出，触发回调
    if (wasWebFullscreen && !_isWebFullscreen) {
      widget.onExitFullScreen?.call();
    }
    _onUserInteraction();
  }

  /// 退出网页全屏（公开方法，供外部调用）
  void exitWebFullscreen() {
    if (_isWebFullscreen) {
      setState(() {
        _isWebFullscreen = false;
      });
      // 通知父组件网页全屏状态变化
      widget.onWebFullscreenChanged?.call(false);
      // 触发退出全屏回调
      widget.onExitFullScreen?.call();
      _onUserInteraction();
    }
  }

  Future<void> _showDLNADialog() async {
    if (widget.player.state.playing) {
      if (!widget.live) {
        widget.player.pause();
      }
      widget.onPause?.call();
    }

    // 如果在全屏状态，通知父组件并退出全屏
    if (_isFullscreen) {
      widget.onDLNAButtonPressed?.call(true);
      _toggleFullscreen();
    } else {
      // 非全屏状态，直接显示对话框
      await _showDLNADialogInternal();
    }
  }

  Future<void> _showDLNADialogInternal() async {
    // 获取当前播放位置
    final resumePos = widget.player.state.position;

    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => DLNADeviceDialog(
          currentUrl: widget.videoUrl,
          resumePosition: resumePos,
          videoTitle: widget.videoTitle,
          currentEpisodeIndex: widget.currentEpisodeIndex,
          totalEpisodes: widget.totalEpisodes,
          sourceName: widget.sourceName,
          onCastStarted: widget.onCastStarted,
        ),
      );
    }
  }

  // 处理遥控器事件
  KeyEventResult _handleRemoteKeyEvent(FocusNode node, KeyEvent event) {
    // 只处理按键按下事件
    if (event is KeyDownEvent) {
      // 返回键退出全屏或关闭菜单
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        if (_showFunctionMenu) {
          setState(() {
            _showFunctionMenu = false;
          });
          return KeyEventResult.handled;
        } else if (_isFullscreen) {
          _toggleFullscreen();
          return KeyEventResult.handled;
        } else if (_isWebFullscreen) {
          _toggleWebFullscreen();
          return KeyEventResult.handled;
        } else {
          widget.onBackPressed?.call();
          return KeyEventResult.handled;
        }
      }
      // 确认键（Enter/Select）
      else if (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _onUserInteraction();
        if (_showFunctionMenu) {
          // 如果功能菜单显示，让当前聚焦的按钮执行点击操作
          if (_playPauseFocusNode.hasFocus) {
            if (widget.player.state.playing) {
              widget.player.pause();
              widget.onPause?.call();
            } else {
              widget.player.play();
            }
            setState(() {});
          } else if (_volumeFocusNode.hasFocus) {
            setState(() {
              _showVolumeMenu = !_showVolumeMenu;
              _showFunctionMenu = false;
            });
          } else if (_speedFocusNode.hasFocus) {
            setState(() {
              _showSpeedMenu = !_showSpeedMenu;
              _showFunctionMenu = false;
            });
          } else if (_fullscreenFocusNode.hasFocus) {
            if (_isWebFullscreen) {
              _toggleWebFullscreen();
            } else {
              _toggleFullscreen();
            }
            setState(() {
              _showFunctionMenu = false;
            });
          } else if (_closeFocusNode.hasFocus) {
            setState(() {
              _showFunctionMenu = false;
            });
          }
        } else {
          // 如果功能菜单未显示，切换播放/暂停
          if (widget.player.state.playing) {
            widget.player.pause();
            widget.onPause?.call();
          } else {
            widget.player.play();
          }
          setState(() {});
        }
        return KeyEventResult.handled;
      }
      // 左方向键
      else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_showFunctionMenu) {
          // 在功能菜单中向左导航
          if (_playPauseFocusNode.hasFocus) {
            _closeFocusNode.requestFocus();
          } else if (_volumeFocusNode.hasFocus) {
            _playPauseFocusNode.requestFocus();
          } else if (_speedFocusNode.hasFocus) {
            _volumeFocusNode.requestFocus();
          } else if (_fullscreenFocusNode.hasFocus) {
            _speedFocusNode.requestFocus();
          } else if (_closeFocusNode.hasFocus) {
            _fullscreenFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        } else {
          // 快退 10 秒
          final currentPosition = widget.player.state.position;
          final newPosition = currentPosition - const Duration(seconds: 10);
          final clampedPosition = Duration(
            milliseconds: newPosition.inMilliseconds
                .clamp(0, widget.player.state.duration.inMilliseconds),
          );
          widget.player.seek(clampedPosition);
          // 显示控制栏
          _onUserInteraction();
          return KeyEventResult.handled;
        }
      }
      // 右方向键
      else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_showFunctionMenu) {
          // 在功能菜单中向右导航
          if (_playPauseFocusNode.hasFocus) {
            _volumeFocusNode.requestFocus();
          } else if (_volumeFocusNode.hasFocus) {
            _speedFocusNode.requestFocus();
          } else if (_speedFocusNode.hasFocus) {
            _fullscreenFocusNode.requestFocus();
          } else if (_fullscreenFocusNode.hasFocus) {
            _closeFocusNode.requestFocus();
          } else if (_closeFocusNode.hasFocus) {
            _playPauseFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        } else {
          // 快进 10 秒
          final currentPosition = widget.player.state.position;
          final duration = widget.player.state.duration;
          final newPosition = currentPosition + const Duration(seconds: 10);
          final clampedPosition = Duration(
            milliseconds:
                newPosition.inMilliseconds.clamp(0, duration.inMilliseconds),
          );
          widget.player.seek(clampedPosition);
          // 显示控制栏
          _onUserInteraction();
          return KeyEventResult.handled;
        }
      }
      // 下方向键显示功能菜单
      else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (!_showFunctionMenu) {
          // 显示控制栏和功能菜单
          _onUserInteraction();
          setState(() {
            _showFunctionMenu = true;
          });
        }
        return KeyEventResult.handled;
      }
      // 上方向键关闭功能菜单
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_showFunctionMenu) {
          setState(() {
            _showFunctionMenu = false;
          });
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载视频，只显示加载界面
    if (widget.isLoadingVideo) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                '加载中...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 使用网页全屏或真全屏的样式
    final effectiveFullscreen = _isWebFullscreen || _isFullscreen;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleRemoteKeyEvent,
      child: Stack(
        children: [
          // 背景层 - 处理滑动手势
          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragStart: _onSwipeStart,
              onHorizontalDragUpdate: _onSwipeUpdate,
              onHorizontalDragEnd: _onSwipeEnd,
              onTap: _onBlankAreaTap,
              onDoubleTap: _onBlankAreaDoubleTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 顶部渐变背景 - 从上往下（半透明黑色到完全透明）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                child: Container(
                  height: effectiveFullscreen ? 120 : 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 底部渐变背景 - 从下往上（半透明黑色到完全透明）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                child: Container(
                  height: effectiveFullscreen ? 140 : 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 顶部返回按钮
          Positioned(
            top: effectiveFullscreen ? 8 : 4,
            left: effectiveFullscreen ? 16.0 : 8.0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: HoverButton(
                  onTap: () async {
                    _onUserInteraction();
                    if (_isFullscreen) {
                      _toggleFullscreen();
                    } else if (_isWebFullscreen) {
                      _toggleWebFullscreen();
                    } else {
                      widget.onBackPressed?.call();
                    }
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: effectiveFullscreen ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
          // 顶部投屏按钮
          Positioned(
            top: effectiveFullscreen ? 8 : 4,
            right: effectiveFullscreen ? 16.0 : 8.0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: HoverButton(
                  onTap: () async {
                    _onUserInteraction();
                    await _showDLNADialog();
                  },
                  child: Icon(
                    Icons.cast,
                    color: Colors.white,
                    size: effectiveFullscreen ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
          // 中央播放/暂停按钮 - 暂停时始终显示
          Positioned.fill(
            child: Center(
              child: AnimatedOpacity(
                opacity: (!widget.player.state.playing || _controlsVisible)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: widget.player.state.playing && !_controlsVisible,
                  child: _CenterPlayButton(
                    isPlaying: widget.player.state.playing,
                    isFullscreen: effectiveFullscreen,
                    onTap: () {
                      _onUserInteraction();
                      if (widget.player.state.playing) {
                        widget.player.pause();
                        widget.onPause?.call();
                      } else {
                        widget.player.play();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          // 进度条
          Positioned(
            bottom: effectiveFullscreen ? 58.0 : 42.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomVideoProgressBar(
                    player: widget.player,
                    onDragStart: _onSeekStart,
                    onDragEnd: _onSeekEnd,
                    onDragUpdate: () {
                      if (!_controlsVisible) {
                        setState(() {
                          _controlsVisible = true;
                        });
                      }
                      _hideTimer?.cancel();
                    },
                    onPositionUpdate: (duration) {
                      setState(() {
                        _dragPosition = duration;
                      });
                    },
                    dragPosition: _dragPosition,
                    isSeekingViaSwipe: _isSeekingViaSwipe,
                    live: widget.live,
                  ),
                ),
              ),
            ),
          ),
          // 底部控制栏
          Positioned(
            bottom: effectiveFullscreen ? 4.0 : -6.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: effectiveFullscreen ? 16.0 : 8.0,
                      right: effectiveFullscreen ? 16.0 : 8.0,
                      top: effectiveFullscreen ? 0.0 : 0.0,
                      bottom: effectiveFullscreen ? 8.0 : 8.0,
                    ),
                    child: Row(
                      children: [
                        HoverButton(
                          onTap: () {
                            _onUserInteraction();
                            if (widget.player.state.playing) {
                              widget.player.pause();
                              widget.onPause?.call();
                            } else {
                              widget.player.play();
                            }
                          },
                          child: Icon(
                            widget.player.state.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: effectiveFullscreen ? 28 : 24,
                          ),
                        ),
                        if (!widget.isLastEpisode && !widget.live)
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: HoverButton(
                              onTap: () {
                                _onUserInteraction();
                                widget.onNextEpisode?.call();
                              },
                              child: Icon(
                                Icons.skip_next,
                                color: Colors.white,
                                size: effectiveFullscreen ? 28 : 24,
                              ),
                            ),
                          ),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              final currentVolume = 
                                  widget.player.state.volume;
                              if (currentVolume > 0) {
                                // 静音
                                _volumeBeforeMute = currentVolume;
                                widget.player.setVolume(0);
                              } else {
                                // 恢复音量
                                widget.player.setVolume(_volumeBeforeMute);
                              }
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                _getVolumeIcon(widget.player.state.volume),
                                color: Colors.white,
                                size: effectiveFullscreen ? 22 : 20,
                              ),
                            ),
                          ),
                        ),
                        if (!widget.live)
                          Expanded(
                            child: _buildPositionIndicator(),
                          ),
                        if (!widget.live)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              setState(() {
                                _showSpeedMenu = !_showSpeedMenu;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: effectiveFullscreen ? 22 : 20,
                              ),
                            ),
                          ),
                        if (widget.live) const Spacer(),
                        // 网页全屏按钮（仅在非真全屏时显示）
                        if (!_isFullscreen)
                          HoverButton(
                            onTap: () {
                              _onUserInteraction();
                              _toggleWebFullscreen();
                            },
                            child: Icon(
                              _isWebFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fit_screen,
                              color: Colors.white,
                              size: effectiveFullscreen ? 28 : 24,
                            ),
                          ),
                        // 完全全屏按钮（仅在非网页全屏时显示）
                        if (!_isWebFullscreen)
                          HoverButton(
                            onTap: () {
                              _onUserInteraction();
                              _toggleFullscreen();
                            },
                            child: Icon(
                              _isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                              size: effectiveFullscreen ? 28 : 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 倍速选择弹窗
          if (_showSpeedMenu) _buildSpeedMenu(),
          // 音量调节弹窗
          if (_showVolumeMenu) _buildVolumeMenu(),
          // 功能菜单
          if (_showFunctionMenu) _buildFunctionMenu(),
        ],
      ),
    );
  }

  IconData _getVolumeIcon(double volume) {
    if (volume == 0) {
      return Icons.volume_off;
    } else if (volume < 50) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  Widget _buildSpeedMenu() {
    final speeds = [0.5, 0.75, 1.0, 1.5, 2.0];
    final currentSpeed = widget.player.state.rate;

    // 根据全屏状态调整弹窗大小
    final effectiveFullscreen = _isWebFullscreen || _isFullscreen;
    final menuWidth = effectiveFullscreen ? 120.0 : 90.0;
    final itemHeight = effectiveFullscreen ? 48.0 : 36.0;
    final menuHeight = speeds.length * itemHeight;

    return Positioned(
      right: 20,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: menuWidth,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(effectiveFullscreen ? 8 : 6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(effectiveFullscreen ? 8 : 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: speeds.map((speed) {
                final isSelected = (speed - currentSpeed).abs() < 0.01;
                return _SpeedMenuItem(
                  speed: speed,
                  isSelected: isSelected,
                  isFullscreen: effectiveFullscreen,
                  onTap: () {
                    widget.onSetSpeed(speed);
                    setState(() {
                      _showSpeedMenu = false;
                    });
                    _startHideTimer();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeMenu() {
    final currentVolume = widget.player.state.volume;

    // 根据全屏状态调整弹窗大小 - 更高更瘦
    final effectiveFullscreen = _isWebFullscreen || _isFullscreen;
    final menuWidth = effectiveFullscreen ? 42.0 : 36.0;
    final menuHeight = effectiveFullscreen ? 200.0 : 150.0;

    return Positioned(
      right: 60,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: menuWidth,
          height: menuHeight,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(effectiveFullscreen ? 8 : 6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(effectiveFullscreen ? 8 : 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 音量百分比显示
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '${currentVolume.round()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: effectiveFullscreen ? 14 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 垂直音量滑块
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragStart: (details) {
                            final localY = details.localPosition.dy;
                            final volume = 
                                ((1 - (localY / constraints.maxHeight)) * 100)
                                    .clamp(0.0, 100.0);
                            widget.player.setVolume(volume);
                            setState(() {});
                          },
                          onVerticalDragUpdate: (details) {
                            final localY = details.localPosition.dy;
                            final volume = 
                                ((1 - (localY / constraints.maxHeight)) * 100)
                                    .clamp(0.0, 100.0);
                            widget.player.setVolume(volume);
                            setState(() {});
                          },
                          onTapDown: (details) {
                            final localY = details.localPosition.dy;
                            final volume = 
                                ((1 - (localY / constraints.maxHeight)) * 100)
                                    .clamp(0.0, 100.0);
                            widget.player.setVolume(volume);
                            setState(() {});
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 背景轨道
                              Container(
                                width: effectiveFullscreen ? 5 : 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      effectiveFullscreen ? 2.5 : 2),
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              // 音量指示器
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: currentVolume / 100,
                                  child: Container(
                                    width: effectiveFullscreen ? 5 : 4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          effectiveFullscreen ? 2.5 : 2),
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionMenu() {
    final effectiveFullscreen = _isWebFullscreen || _isFullscreen;

    // 当功能菜单显示时，自动聚焦到第一个按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showFunctionMenu) {
        _playPauseFocusNode.requestFocus();
      }
    });

    return Positioned(
      bottom: effectiveFullscreen ? 80 : 70,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 播放/暂停按钮
            _FunctionMenuItem(
              icon: widget.player.state.playing ? Icons.pause : Icons.play_arrow,
              label: '播放/暂停',
              isSelected: false,
              onTap: () {
                _onUserInteraction();
                if (widget.player.state.playing) {
                  widget.player.pause();
                  widget.onPause?.call();
                } else {
                  widget.player.play();
                }
                setState(() {});
              },
              focusNode: _playPauseFocusNode,
            ),
            // 音量按钮
            _FunctionMenuItem(
              icon: _getVolumeIcon(widget.player.state.volume),
              label: '音量',
              isSelected: false,
              onTap: () {
                _onUserInteraction();
                setState(() {
                  _showVolumeMenu = !_showVolumeMenu;
                  _showFunctionMenu = false;
                });
              },
              focusNode: _volumeFocusNode,
            ),
            // 倍速按钮
            _FunctionMenuItem(
              icon: Icons.speed,
              label: '${widget.player.state.rate}x',
              isSelected: false,
              onTap: () {
                _onUserInteraction();
                setState(() {
                  _showSpeedMenu = !_showSpeedMenu;
                  _showFunctionMenu = false;
                });
              },
              focusNode: _speedFocusNode,
            ),
            // 全屏按钮
            _FunctionMenuItem(
              icon: (_isFullscreen || _isWebFullscreen) ? Icons.fullscreen_exit : Icons.fullscreen,
              label: (_isFullscreen || _isWebFullscreen) ? '退出全屏' : '全屏',
              isSelected: false,
              onTap: () {
                _onUserInteraction();
                if (_isWebFullscreen) {
                  _toggleWebFullscreen();
                } else {
                  _toggleFullscreen();
                }
                setState(() {
                  _showFunctionMenu = false;
                });
              },
              focusNode: _fullscreenFocusNode,
            ),
            // 关闭菜单按钮
            _FunctionMenuItem(
              icon: Icons.close,
              label: '关闭',
              isSelected: false,
              onTap: () {
                _onUserInteraction();
                setState(() {
                  _showFunctionMenu = false;
                });
              },
              focusNode: _closeFocusNode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionIndicator() {
    final position = _dragPosition ?? widget.player.state.position;
    final duration = widget.player.state.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        '${_formatDuration(position)} / ${_formatDuration(duration)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

// 倍速菜单项组件
class _SpeedMenuItem extends StatefulWidget {
  final double speed;
  final bool isSelected;
  final bool isFullscreen;
  final VoidCallback onTap;

  const _SpeedMenuItem({
    required this.speed,
    required this.isSelected,
    required this.isFullscreen,
    required this.onTap,
  });

  @override
  State<_SpeedMenuItem> createState() => _SpeedMenuItemState();
}

class _SpeedMenuItemState extends State<_SpeedMenuItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.isFullscreen ? 48.0 : 36.0,
        alignment: Alignment.center,
        child: Text(
          '${widget.speed}x',
          style: TextStyle(
            color: widget.isSelected ? Colors.red : Colors.white,
            fontSize: widget.isFullscreen ? 14 : 12,
            fontWeight:
                widget.isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class CustomVideoProgressBar extends StatefulWidget {
  final Player player;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragUpdate;
  final Function(Duration)? onPositionUpdate;
  final Duration? dragPosition;
  final bool isSeekingViaSwipe;
  final bool live;

  const CustomVideoProgressBar({
    super.key,
    required this.player,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.onPositionUpdate,
    this.dragPosition,
    this.isSeekingViaSwipe = false,
    this.live = false,
  });

  @override
  State<CustomVideoProgressBar> createState() => _CustomVideoProgressBarState();
}

class _CustomVideoProgressBarState extends State<CustomVideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isSeeking = false; // 新增：标记是否正在 seek
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.player.stream.position.listen((_) {
      if (mounted && !_isDragging && !_isSeeking) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.player.state.duration;
    final position = widget.dragPosition ?? widget.player.state.position;

    double value = 0.0;
    if (duration.inMilliseconds > 0) {
      // live 模式下进度固定在最后
      if (widget.live) {
        value = 1.0;
      } else {
        value = position.inMilliseconds / duration.inMilliseconds;
      }
    }

    if (_isDragging && !widget.live) {
      value = _dragValue;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.live ? null : (details) {
        _isDragging = true;
        widget.onDragStart?.call();
        _updateDragPosition(details.localPosition.dx, context);
      },
      onHorizontalDragUpdate: widget.live ? null : (details) {
        if (_isDragging) {
          widget.onDragUpdate?.call();
          _updateDragPosition(details.localPosition.dx, context);
        }
      },
      onHorizontalDragEnd: widget.live ? null : (details) async {
        if (_isDragging) {
          final seekPosition = Duration(
              milliseconds: (_dragValue * duration.inMilliseconds).round());
          
          setState(() {
            _isDragging = false;
            _isSeeking = true; // 标记开始 seek
          });
          
          await widget.player.seek(seekPosition);
          
          // seek 完成后，延迟一小段时间再允许位置更新，确保播放器状态已同步
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            setState(() {
              _isSeeking = false; // 标记 seek 完成
            });
          }
          
          widget.onDragEnd?.call();
        }
      },
      onTapDown: widget.live ? null : (details) async {
        widget.onDragStart?.call();
        _updateDragPosition(details.localPosition.dx, context);
        final seekPosition = Duration(
            milliseconds: (_dragValue * duration.inMilliseconds).round());
        
        setState(() {
          _isSeeking = true; // 标记开始 seek
        });
        
        await widget.player.seek(seekPosition);
        
        // seek 完成后，延迟一小段时间再允许位置更新，确保播放器状态已同步
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          setState(() {
            _isSeeking = false; // 标记 seek 完成
          });
        }
        
        widget.onDragEnd?.call();
      },
      child: Container(
        height: 24,
        color: Colors.transparent,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progressWidth = constraints.maxWidth;
              final progressValue = value.clamp(0.0, 1.0);
              final thumbPosition = (progressValue * progressWidth)
                  .clamp(8.0, progressWidth - 8.0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 进度条背景
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 9,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // 已播放进度
                  Positioned(
                    left: 0,
                    top: 9,
                    child: Container(
                      width: progressValue * progressWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.red,
                      ),
                    ),
                  ),
                  // 可拖拽的圆形把手
                  Positioned(
                    left: thumbPosition - 8,
                    top: 4,
                    child: AnimatedScale(
                      scale: (_isDragging ||
                              widget.isSeekingViaSwipe)
                          ? 1.25
                          : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateDragPosition(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final width = box.size.width;
    final value = (dx / width).clamp(0.0, 1.0);

    setState(() {
      _dragValue = value;
    });

    final duration = widget.player.state.duration;
    final position = Duration(milliseconds: (value * duration.inMilliseconds).round());

    widget.onPositionUpdate?.call(position);
  }
}

// 中央播放/暂停按钮组件 - 支持 hover 效果
class _CenterPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isFullscreen;
  final VoidCallback onTap;

  const _CenterPlayButton({
    required this.isPlaying,
    required this.isFullscreen,
    required this.onTap,
  });

  @override
  State<_CenterPlayButton> createState() => _CenterPlayButtonState();
}

class _CenterPlayButtonState extends State<_CenterPlayButton> {
  @override
  Widget build(BuildContext context) {
    // 暂停时始终显示背景，播放时不显示背景
    final showBackground = !widget.isPlaying;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆形 - 使用 AnimatedOpacity 实现淡入淡出
          AnimatedOpacity(
            opacity: showBackground ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha: 0.7),
              ),
              child: SizedBox(
                width: widget.isFullscreen ? 64 : 48,
                height: widget.isFullscreen ? 64 : 48,
              ),
            ),
          ),
          // 图标
          Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: widget.isFullscreen ? 64 : 48,
            ),
          ),
        ],
      ),
    );
  }
}
