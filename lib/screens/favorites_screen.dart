import 'package:flutter/material.dart';
import '../widgets/favorites_grid.dart';
import '../widgets/custom_refresh_indicator.dart';
import '../widgets/main_layout.dart';
import '../models/video_info.dart';
import '../widgets/video_menu_bottom_sheet.dart';
import '../utils/font_utils.dart';
import '../services/page_cache_service.dart';
import 'player_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      content: _buildContent(),
      currentCategoryIndex: 0,
      onCategoryChanged: (index) {
        // 这里可以处理分类导航的切换
      },
      selectedTopTab: '收藏夹',
      onTopTabChanged: (tab) {
        // 这里可以处理顶部标签的切换
      },
      onHomeTap: () {
        // 点击首页图标返回首页
        Navigator.pop(context);
      },
      onSearchTap: () {
        // 点击搜索图标
        Navigator.pushNamed(context, '/search');
      },
    );
  }

  Widget _buildContent() {
    return StyledRefreshIndicator(
      onRefresh: _refreshFavorites,
      refreshText: '刷新中...',
      primaryColor: const Color(0xFF27AE60),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 4),
            FavoritesGrid(
              onVideoTap: _onVideoTap,
              onGlobalMenuAction: _onGlobalMenuAction,
            ),
          ],
        ),
      ),
    );
  }

  /// 刷新收藏夹数据
  Future<void> _refreshFavorites() async {
    try {
      // 刷新收藏夹缓存
      await PageCacheService().refreshFavorites(context);
      // 通知收藏夹组件刷新UI
      FavoritesGrid.refreshFavorites();
    } catch (e) {
      // 刷新失败，静默处理
    }
  }

  /// 处理视频卡片点击
  void _onVideoTap(VideoInfo videoInfo) {
    _navigateToPlayer(
      PlayerScreen(
        source: videoInfo.source,
        id: videoInfo.id,
        title: videoInfo.title,
        year: videoInfo.year,
      ),
    );
  }

  /// 处理视频菜单操作
  void _onGlobalMenuAction(VideoInfo videoInfo, VideoMenuAction action) {
    switch (action) {
      case VideoMenuAction.play:
        _navigateToPlayer(
          PlayerScreen(
            source: videoInfo.source,
            id: videoInfo.id,
            title: videoInfo.title,
            year: videoInfo.year,
          ),
        );
        break;
      case VideoMenuAction.unfavorite:
        // 取消收藏
        _handleUnfavorite(videoInfo);
        break;
      case VideoMenuAction.doubanDetail:
      case VideoMenuAction.bangumiDetail:
        // 这些操作在组件内部处理
        break;
      default:
        break;
    }
  }

  /// 处理取消收藏
  Future<void> _handleUnfavorite(VideoInfo videoInfo) async {
    try {
      // 先立即从UI中移除该项目
      FavoritesGrid.removeFavoriteFromUI(videoInfo.source, videoInfo.id);

      // 通知UI刷新
      if (mounted) {
        setState(() {});
      }

      // 使用统一的取消收藏方法（包含缓存操作和API调用）
      final cacheService = PageCacheService();
      final result = await cacheService.removeFavorite(
          videoInfo.source, videoInfo.id, context);

      if (!result.success) {
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? '取消收藏失败',
                style: FontUtils.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFe74c3c),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        // API失败时重新刷新缓存以恢复数据
        _refreshFavorites();
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '取消收藏失败: ${e.toString()}',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFe74c3c),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      // 异常时重新刷新缓存以恢复数据
      _refreshFavorites();
    }
  }

  /// 跳转到播放页的通用方法
  Future<void> _navigateToPlayer(Widget playerScreen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => playerScreen),
    );

    // 从播放页返回时刷新收藏夹
    _refreshFavorites();
  }
}
