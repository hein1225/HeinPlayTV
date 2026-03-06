import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/video_card.dart';
import '../services/api_service.dart';
import '../services/douban_service.dart';
import '../models/search_result.dart';
import '../models/douban_movie.dart';
import '../services/user_data_service.dart';
import '../services/search_service.dart';
import 'player_screen.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';

class PosterInfoScreen extends StatefulWidget {
  final String title;
  final String? year;
  final String? source;
  final String? id;
  final String? stitle;
  final String? stype;

  const PosterInfoScreen({
    super.key,
    required this.title,
    this.year,
    this.source,
    this.id,
    this.stitle,
    this.stype,
  });

  @override
  State<PosterInfoScreen> createState() => _PosterInfoScreenState();
}

class _PosterInfoScreenState extends State<PosterInfoScreen> {
  bool _isLoading = true;
  String _loadingMessage = '正在加载信息...';
  SearchResult? _videoDetail;
  DoubanMovieDetails? _doubanDetails;
  String _videoCover = '';
  String _videoDesc = '';
  String _videoYear = '';
  int _videoDoubanID = 0;
  List<SearchResult> _allSources = [];

  @override
  void initState() {
    super.initState();
    _loadVideoInfo();
  }

  Future<void> _loadVideoInfo() async {
    try {
      // 初始化参数
      String searchTitle = widget.stitle ?? widget.title;
      String videoTitle = widget.title;
      String videoYear = widget.year ?? '';

      // 执行查询
      _allSources = await _fetchSourcesData(searchTitle.isNotEmpty ? searchTitle : videoTitle);
      if (widget.source != null &&
          widget.id != null &&
          !_allSources.any((source) =>
              source.source == widget.source && source.id == widget.id)) {
        _allSources = await _fetchSourceDetail(widget.source!, widget.id!);
      }
      if (_allSources.isEmpty) {
        _showError('未找到匹配结果');
        return;
      }

      // 设置当前详情
      _videoDetail = _allSources.first;
      if (widget.source != null && widget.id != null) {
        final target = _allSources.where(
            (source) => source.source == widget.source && source.id == widget.id);
        _videoDetail = target.isNotEmpty ? target.first : null;
      }
      if (_videoDetail == null) {
        _showError('未找到匹配结果');
        return;
      }

      // 设置视频信息
      _setInfosByDetail(_videoDetail!);

      // 获取豆瓣详情
      if (_videoDoubanID > 0) {
        await _fetchDoubanDetails();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showError('加载失败: $e');
    }
  }

  Future<List<SearchResult>> _fetchSourcesData(String title) async {
    final results = await ApiService.fetchSourcesData(title);
    return results;
  }

  Future<List<SearchResult>> _fetchSourceDetail(String source, String id) async {
    final results = await ApiService.fetchSourceDetail(source, id);
    return results;
  }

  void _setInfosByDetail(SearchResult detail) {
    _videoCover = detail.poster;
    _videoDesc = detail.desc ?? '';
    _videoYear = detail.year;

    // 设置当前豆瓣 ID
    if (detail.doubanId != null && detail.doubanId! > 0) {
      _videoDoubanID = detail.doubanId!;
    } else {
      // 统计出现次数最多的 doubanID
      Map<int, int> doubanIDCount = {};
      for (var result in _allSources) {
        int? tmpDoubanID = result.doubanId;
        if (tmpDoubanID == null || tmpDoubanID == 0) {
          continue;
        }
        doubanIDCount[tmpDoubanID] = (doubanIDCount[tmpDoubanID] ?? 0) + 1;
      }
      _videoDoubanID = doubanIDCount.entries.isEmpty
          ? 0
          : doubanIDCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
    }
  }

  Future<void> _fetchDoubanDetails() async {
    if (_videoDoubanID <= 0) {
      _doubanDetails = null;
      return;
    }

    try {
      final response = await DoubanService.getDoubanDetails(
        context,
        doubanId: _videoDoubanID.toString(),
      );

      if (response.success && response.data != null && mounted) {
        setState(() {
          _doubanDetails = response.data;
          // 如果当前视频描述为空或是"暂无简介"，使用豆瓣的描述
          if ((_videoDesc.isEmpty || _videoDesc == '暂无简介') &&
              response.data!.summary != null &&
              response.data!.summary!.isNotEmpty) {
            _videoDesc = response.data!.summary!;
          }
        });
      }
    } catch (e) {
      print('获取豆瓣详情异常: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
      _loadingMessage = message;
    });
  }

  void _onPlayButtonTap() {
    if (_videoDetail == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          source: _videoDetail!.source,
          id: _videoDetail!.id,
          title: _videoDetail!.title,
          year: _videoDetail!.year,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isTV = DeviceUtils.isTV();

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFf5f5f5),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingMessage,
                    style: FontUtils.poppins(
                      color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                    ),
                  ),
                ],
              ),
            )
          : _videoDetail == null
              ? Center(
                  child: Text(
                    _loadingMessage,
                    style: FontUtils.poppins(
                      color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 海报和基本信息
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 海报
                            Container(
                              width: 180,
                              height: 270,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: _videoCover.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_videoCover),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: isDarkMode
                                    ? const Color(0xFF333333)
                                    : const Color(0xFFe0e0e0),
                              ),
                              child: _videoCover.isEmpty
                                  ? Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 64,
                                        color: isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey[400],
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 24),
                            // 基本信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 标题
                                  Text(
                                    _videoDetail!.title,
                                    style: FontUtils.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF2c3e50),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  // 源名称和年份
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          color: isDarkMode
                                              ? const Color(0xFF333333)
                                              : const Color(0xFFe0e0e0),
                                        ),
                                        child: Text(
                                          _videoDetail!.sourceName,
                                          style: FontUtils.poppins(
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF2c3e50),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (_videoYear.isNotEmpty &&
                                          _videoYear != 'unknown')
                                        Text(
                                          _videoYear,
                                          style: FontUtils.poppins(
                                            fontSize: 16,
                                            color: isDarkMode
                                                ? Colors.grey[300]
                                                : const Color(0xFF7f8c8d),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 分类信息
                                  if (_videoDetail!.class_ != null &&
                                      _videoDetail!.class_!.isNotEmpty)
                                    Text(
                                      _videoDetail!.class_!,
                                      style: FontUtils.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF27ae60),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  // 播放按钮
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _onPlayButtonTap,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF27ae60),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        '播放',
                                        style: FontUtils.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 剧情简介
                      if (_videoDesc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '剧情简介',
                                style: FontUtils.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2c3e50),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _videoDesc,
                                style: FontUtils.poppins(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[300]
                                      : const Color(0xFF7f8c8d),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 豆瓣信息
                      if (_doubanDetails != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '豆瓣信息',
                                style: FontUtils.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2c3e50),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_doubanDetails!.rate != null)
                                Row(
                                  children: [
                                    Text(
                                      '评分: ',
                                      style: FontUtils.poppins(
                                        fontSize: 14,
                                        color: isDarkMode
                                            ? Colors.grey[300]
                                            : const Color(0xFF7f8c8d),
                                      ),
                                    ),
                                    Text(
                                      '${_doubanDetails!.rate}',
                                      style: FontUtils.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFf39c12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(豆瓣评分)',
                                      style: FontUtils.poppins(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.grey[400]
                                            : const Color(0xFF95a5a6),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_doubanDetails!.directors.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '导演: ',
                                        style: FontUtils.poppins(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : const Color(0xFF7f8c8d),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _doubanDetails!.directors.join('、'),
                                          style: FontUtils.poppins(
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.grey[300]
                                                : const Color(0xFF7f8c8d),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_doubanDetails!.actors.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '主演: ',
                                        style: FontUtils.poppins(
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : const Color(0xFF7f8c8d),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _doubanDetails!.actors.join('、'),
                                          style: FontUtils.poppins(
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.grey[300]
                                                : const Color(0xFF7f8c8d),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // 其他播放源
                      if (_allSources.length > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '其他播放源',
                                style: FontUtils.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2c3e50),
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTV ? 4 : 3,
                                  childAspectRatio: 3 / 1,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _allSources.length,
                                itemBuilder: (context, index) {
                                  final source = _allSources[index];
                                  final isCurrentSource = source.source == _videoDetail!.source &&
                                      source.id == _videoDetail!.id;
                                  
                                  return ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _videoDetail = source;
                                        _setInfosByDetail(source);
                                        _fetchDoubanDetails();
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrentSource
                                          ? const Color(0xFF27ae60)
                                          : (isDarkMode
                                              ? const Color(0xFF333333)
                                              : const Color(0xFFe0e0e0)),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      source.sourceName,
                                      style: FontUtils.poppins(
                                        fontSize: 14,
                                        color: isCurrentSource
                                            ? Colors.white
                                            : (isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF2c3e50)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
    );
  }
}
