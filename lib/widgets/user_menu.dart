import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_data_service.dart';
import '../screens/login_screen.dart';
import '../services/douban_cache_service.dart';
import '../services/page_cache_service.dart';
import '../services/live_service.dart';
import '../services/local_search_cache_service.dart';
import '../services/version_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import 'update_dialog.dart';

class UserMenu extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onClose;

  const UserMenu({
    super.key,
    required this.isDarkMode,
    this.onClose,
  });

  @override
  State<UserMenu> createState() => _UserMenuState();
}

class _UserMenuState extends State<UserMenu> {
  String? _username;
  String _role = 'user';
  String _doubanDataSource = '直连';
  String _doubanImageSource = '直连';
  String _serverUrl = '';
  String _version = '';
  bool _preferSpeedTest = true;
  bool _localSearch = false;
  bool _isLocalMode = false;

  // 焦点节点管理
  final FocusNode _apiWebsiteFocusNode = FocusNode();
  final FocusNode _doubanDataSourceFocusNode = FocusNode();
  final FocusNode _doubanImageSourceFocusNode = FocusNode();
  final FocusNode _preferSpeedTestFocusNode = FocusNode();
  final FocusNode _localSearchFocusNode = FocusNode();
  final FocusNode _clearDoubanCacheFocusNode = FocusNode();
  final FocusNode _checkUpdateFocusNode = FocusNode();
  final FocusNode _logoutFocusNode = FocusNode();
  final FocusNode _versionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final isLocalMode = await UserDataService.getIsLocalMode();
    final username = await UserDataService.getUsername();
    final cookies = await UserDataService.getCookies();
    final doubanDataSource = 
        await UserDataService.getDoubanDataSourceDisplayName();
    final doubanImageSource = 
        await UserDataService.getDoubanImageSourceDisplayName();
    final serverUrl = await UserDataService.getServerUrl();
    final preferSpeedTest = await UserDataService.getPreferSpeedTest();
    final localSearch = await UserDataService.getLocalSearch();

    if (mounted) {
      setState(() {
        _isLocalMode = isLocalMode;
        _username = username;
        _role = _parseRoleFromCookies(cookies);
        _doubanDataSource = doubanDataSource;
        _doubanImageSource = doubanImageSource;
        _serverUrl = serverUrl ?? '';
        _preferSpeedTest = preferSpeedTest;
        _localSearch = localSearch;
      });
    }
  }

  @override
  void dispose() {
    // 释放所有焦点节点资源
    _apiWebsiteFocusNode.dispose();
    _doubanDataSourceFocusNode.dispose();
    _doubanImageSourceFocusNode.dispose();
    _preferSpeedTestFocusNode.dispose();
    _localSearchFocusNode.dispose();
    _clearDoubanCacheFocusNode.dispose();
    _checkUpdateFocusNode.dispose();
    _logoutFocusNode.dispose();
    _versionFocusNode.dispose();
    super.dispose();
  }

  String _parseRoleFromCookies(String? cookies) {
    if (cookies == null || cookies.isEmpty) {
      return 'user';
    }

    try {
      // 解析cookies字符串
      final cookieMap = <String, String>{};
      final cookiePairs = cookies.split(';');

      for (final cookie in cookiePairs) {
        final trimmed = cookie.trim();
        final firstEqualIndex = trimmed.indexOf('=');

        if (firstEqualIndex > 0) {
          final key = trimmed.substring(0, firstEqualIndex);
          final value = trimmed.substring(firstEqualIndex + 1);
          if (key.isNotEmpty && value.isNotEmpty) {
            cookieMap[key] = value;
          }
        }
      }

      final authCookie = cookieMap['auth'];
      if (authCookie == null) {
        return 'user';
      }

      // 处理可能的双重编码
      String decoded = Uri.decodeComponent(authCookie);

      // 如果解码后仍然包含 %，说明是双重编码，需要再次解码
      if (decoded.contains('%')) {
        decoded = Uri.decodeComponent(decoded);
      }

      final authData = json.decode(decoded);
      final role = authData['role'] as String?;

      return role ?? 'user';
    } catch (e) {
      // 解析失败时默认为user
      return 'user';
    }
  }

  Future<void> _handleLogout() async {
    // 清空所有缓存
    LiveService.clearAllCache();
    LocalSearchCacheService().clearCache();
    PageCacheService().clearAllCache();

    // 只清除密码和cookies，保留服务器地址和用户名
    await UserDataService.clearPasswordAndCookies();

    await UserDataService.saveIsLocalMode(false);

    // 跳转到登录页，并移除所有之前的路由（强制销毁所有页面）
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleClearDoubanCache() async {
    try {
      await DoubanCacheService().clearAll();
      // 同时清空 Bangumi 的函数级与内存级缓存
      PageCacheService().clearCache('bangumi_calendar');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除豆瓣缓存')),
        );
        // 清除后关闭菜单
        widget.onClose?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('清除豆瓣缓存失败')),
        );
        // 即便失败也关闭菜单，避免停留
        widget.onClose?.call();
      }
    }
  }

  Future<void> _handleCheckUpdate() async {
    try {
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '正在检查更新...',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final versionInfo = await VersionService.checkForUpdate();

      if (!mounted) return;

      if (versionInfo != null) {
        // 有新版本，显示更新对话框
        await UpdateDialog.show(context, versionInfo);
      } else {
        // 已是最新版本
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '当前已是最新版本',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '检查更新失败: ${e.toString()}',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
      }
    }
  }

  // 菜单项组件 - 支持焦点管理和选框显示
  Widget _buildMenuItem({
    required Widget child,
    required FocusNode focusNode,
    VoidCallback? onTap,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        setState(() {});
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: focusNode.hasFocus
                ? BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTag() {
    String label;
    Color color;

    switch (_role) {
      case 'admin':
        label = '管理员';
        color = const Color(0xFFf59e0b); // 橙黄色
        break;
      case 'owner':
        label = '站长';
        color = const Color(0xFF8b5cf6); // 紫色
        break;
      case 'user':
      default:
        label = '用户';
        color = const Color(0xFF10b981); // 绿色
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: FontUtils.poppins(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOptionSelector({
    required String title,
    required String currentValue,
    required List<String> options,
    required Future<void> Function(String) onChanged,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showOptionDialog(title, currentValue, options, onChanged),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: widget.isDarkMode
                    ? const Color(0xFF9ca3af)
                    : const Color(0xFF6b7280),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: widget.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF1f2937),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentValue,
                      style: FontUtils.poppins(
                        fontSize: 12,
                        color: widget.isDarkMode
                            ? const Color(0xFF9ca3af)
                            : const Color(0xFF6b7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: widget.isDarkMode
                    ? const Color(0xFF9ca3af)
                    : const Color(0xFF6b7280),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionDialog(String title, String currentValue,
      List<String> options, Future<void> Function(String) onChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF2c2c2c) : Colors.white,
          title: Text(
            title,
            style: FontUtils.poppins(
              fontSize: 18,
              color: widget.isDarkMode
                  ? const Color(0xFFffffff)
                  : const Color(0xFF1f2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await onChanged(option);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          currentValue == option
                              ? LucideIcons.check
                              : LucideIcons.circle,
                          size: 20,
                          color: currentValue == option
                              ? const Color(0xFF10b981)
                              : (widget.isDarkMode
                                  ? const Color(0xFF9ca3af)
                                  : const Color(0xFF6b7280)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: FontUtils.poppins(
                              fontSize: 16,
                              color: widget.isDarkMode
                                  ? const Color(0xFFffffff)
                                  : const Color(0xFF1f2937),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildInputOption({
    required String title,
    required String currentValue,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: widget.isDarkMode
                    ? const Color(0xFF9ca3af)
                    : const Color(0xFF6b7280),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: widget.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF1f2937),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentValue.isEmpty ? '未设置' : currentValue,
                      style: FontUtils.poppins(
                        fontSize: 12,
                        color: widget.isDarkMode
                            ? const Color(0xFF9ca3af)
                            : const Color(0xFF6b7280),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: widget.isDarkMode
                    ? const Color(0xFF9ca3af)
                    : const Color(0xFF6b7280),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: widget.isDarkMode
                  ? const Color(0xFF9ca3af)
                  : const Color(0xFF6b7280),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: FontUtils.poppins(
                  fontSize: 16,
                  color: widget.isDarkMode
                      ? const Color(0xFFffffff)
                      : const Color(0xFF1f2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                await onChanged(!value);
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: value
                      ? const Color(0xFF10b981)
                      : (widget.isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFe5e7eb)),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 处理遥控器事件
  KeyEventResult _handleRemoteKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // 返回键关闭菜单
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose?.call();
        return KeyEventResult.handled;
      }
      // 确认键（Enter/Select）
      else if (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        // 触发当前聚焦项的点击事件
        if (_apiWebsiteFocusNode.hasFocus) {
          // API网站选项，无操作
        } else if (_doubanDataSourceFocusNode.hasFocus) {
          _showOptionDialog(
            '豆瓣数据源',
            _doubanDataSource,
            const [
              '直连',
              'Cors Proxy By Zwei',
              '豆瓣 CDN By CMLiussss（腾讯云）',
              '豆瓣 CDN By CMLiussss（阿里云）',
            ],
            (value) async {
              await UserDataService.saveDoubanDataSource(value);
              setState(() {
                _doubanDataSource = value;
              });
            },
          );
        } else if (_doubanImageSourceFocusNode.hasFocus) {
          _showOptionDialog(
            '豆瓣图片源',
            _doubanImageSource,
            const [
              '直连',
              '豆瓣官方精品 CDN',
              '豆瓣 CDN By CMLiussss（腾讯云）',
              '豆瓣 CDN By CMLiussss（阿里云）',
            ],
            (value) async {
              await UserDataService.saveDoubanImageSource(value);
              setState(() {
                _doubanImageSource = value;
              });
            },
          );
        } else if (_preferSpeedTestFocusNode.hasFocus) {
          UserDataService.savePreferSpeedTest(!_preferSpeedTest).then((_) {
            setState(() {
              _preferSpeedTest = !_preferSpeedTest;
            });
          });
        } else if (_localSearchFocusNode.hasFocus) {
          UserDataService.saveLocalSearch(!_localSearch).then((_) {
            setState(() {
              _localSearch = !_localSearch;
            });
          });
        } else if (_clearDoubanCacheFocusNode.hasFocus) {
          _handleClearDoubanCache();
        } else if (_checkUpdateFocusNode.hasFocus) {
          _handleCheckUpdate();
        } else if (_logoutFocusNode.hasFocus) {
          _handleLogout();
        } else if (_versionFocusNode.hasFocus) {
          final url = Uri.parse('https://github.com/hein1225/HeinPlayTV/');
          canLaunchUrl(url).then((canLaunch) {
            if (canLaunch) {
              launchUrl(url, mode: LaunchMode.externalApplication);
            }
          });
        }
        return KeyEventResult.handled;
      }
      // 方向键导航
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // 向上导航
        if (_apiWebsiteFocusNode.hasFocus) {
          _versionFocusNode.requestFocus();
        } else if (_doubanDataSourceFocusNode.hasFocus) {
          _apiWebsiteFocusNode.requestFocus();
        } else if (_doubanImageSourceFocusNode.hasFocus) {
          _doubanDataSourceFocusNode.requestFocus();
        } else if (_preferSpeedTestFocusNode.hasFocus) {
          _doubanImageSourceFocusNode.requestFocus();
        } else if (_localSearchFocusNode.hasFocus) {
          _preferSpeedTestFocusNode.requestFocus();
        } else if (_clearDoubanCacheFocusNode.hasFocus) {
          _localSearchFocusNode.hasFocus ? _localSearchFocusNode.requestFocus() : _preferSpeedTestFocusNode.requestFocus();
        } else if (_checkUpdateFocusNode.hasFocus) {
          _clearDoubanCacheFocusNode.requestFocus();
        } else if (_logoutFocusNode.hasFocus) {
          _checkUpdateFocusNode.requestFocus();
        } else if (_versionFocusNode.hasFocus) {
          _logoutFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // 向下导航
        if (_apiWebsiteFocusNode.hasFocus) {
          _doubanDataSourceFocusNode.requestFocus();
        } else if (_doubanDataSourceFocusNode.hasFocus) {
          _doubanImageSourceFocusNode.requestFocus();
        } else if (_doubanImageSourceFocusNode.hasFocus) {
          _preferSpeedTestFocusNode.requestFocus();
        } else if (_preferSpeedTestFocusNode.hasFocus) {
          _localSearchFocusNode.hasFocus ? _localSearchFocusNode.requestFocus() : _clearDoubanCacheFocusNode.requestFocus();
        } else if (_localSearchFocusNode.hasFocus) {
          _clearDoubanCacheFocusNode.requestFocus();
        } else if (_clearDoubanCacheFocusNode.hasFocus) {
          _checkUpdateFocusNode.requestFocus();
        } else if (_checkUpdateFocusNode.hasFocus) {
          _logoutFocusNode.requestFocus();
        } else if (_logoutFocusNode.hasFocus) {
          _versionFocusNode.requestFocus();
        } else if (_versionFocusNode.hasFocus) {
          _apiWebsiteFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // 当菜单显示时，自动聚焦到第一个选项
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _apiWebsiteFocusNode.requestFocus();
      }
    });

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // 阻止点击菜单内容时关闭
              child: FocusScope(
                onKeyEvent: _handleRemoteKeyEvent,
                child: Container(
                  width: 320, // 增加宽度以适应电视显示
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF2c2c2c)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 用户信息区域
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // 本地模式下不显示"当前模式"标签
                            if (!_isLocalMode)
                              Text(
                                '当前用户',
                                style: FontUtils.poppins(
                                  fontSize: 14,
                                  color: widget.isDarkMode
                                      ? const Color(0xFF9ca3af)
                                      : const Color(0xFF6b7280),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            if (!_isLocalMode) const SizedBox(height: 12),
                            // 用户名或本地模式
                            if (_isLocalMode)
                              Text(
                                '本地模式',
                                style: FontUtils.poppins(
                                  fontSize: 20,
                                  color: widget.isDarkMode
                                      ? const Color(0xFFffffff)
                                      : const Color(0xFF1f2937),
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _username ?? '未知用户',
                                    style: FontUtils.poppins(
                                      fontSize: 20,
                                      color: widget.isDarkMode
                                          ? const Color(0xFFffffff)
                                          : const Color(0xFF1f2937),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 角色标签
                                  _buildRoleTag(),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // API网站选项
                      _buildMenuItem(
                        child: _buildInputOption(
                          title: 'API网站',
                          currentValue: _serverUrl.isEmpty ? '未设置' : _serverUrl,
                          onTap: () {},
                          icon: LucideIcons.globe,
                        ),
                        focusNode: _apiWebsiteFocusNode,
                      ),
                      // 豆瓣数据源选项
                      _buildMenuItem(
                        child: _buildOptionSelector(
                          title: '豆瓣数据源',
                          currentValue: _doubanDataSource,
                          options: const [
                            '直连',
                            'Cors Proxy By Zwei',
                            '豆瓣 CDN By CMLiussss（腾讯云）',
                            '豆瓣 CDN By CMLiussss（阿里云）',
                          ],
                          onChanged: (value) async {
                            await UserDataService.saveDoubanDataSource(value);
                            setState(() {
                              _doubanDataSource = value;
                            });
                          },
                          icon: LucideIcons.database,
                        ),
                        focusNode: _doubanDataSourceFocusNode,
                        onTap: () => _showOptionDialog(
                          '豆瓣数据源',
                          _doubanDataSource,
                          const [
                            '直连',
                            'Cors Proxy By Zwei',
                            '豆瓣 CDN By CMLiussss（腾讯云）',
                            '豆瓣 CDN By CMLiussss（阿里云）',
                          ],
                          (value) async {
                            await UserDataService.saveDoubanDataSource(value);
                            setState(() {
                              _doubanDataSource = value;
                            });
                          },
                        ),
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 豆瓣图片源选项
                      _buildMenuItem(
                        child: _buildOptionSelector(
                          title: '豆瓣图片源',
                          currentValue: _doubanImageSource,
                          options: const [
                            '直连',
                            '豆瓣官方精品 CDN',
                            '豆瓣 CDN By CMLiussss（腾讯云）',
                            '豆瓣 CDN By CMLiussss（阿里云）',
                          ],
                          onChanged: (value) async {
                            await UserDataService.saveDoubanImageSource(value);
                            setState(() {
                              _doubanImageSource = value;
                            });
                          },
                          icon: LucideIcons.image,
                        ),
                        focusNode: _doubanImageSourceFocusNode,
                        onTap: () => _showOptionDialog(
                          '豆瓣图片源',
                          _doubanImageSource,
                          const [
                            '直连',
                            '豆瓣官方精品 CDN',
                            '豆瓣 CDN By CMLiussss（腾讯云）',
                            '豆瓣 CDN By CMLiussss（阿里云）',
                          ],
                          (value) async {
                            await UserDataService.saveDoubanImageSource(value);
                            setState(() {
                              _doubanImageSource = value;
                            });
                          },
                        ),
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 优选测速选项
                      _buildMenuItem(
                        child: _buildToggleOption(
                          title: '优选测速',
                          value: _preferSpeedTest,
                          onChanged: (value) async {
                            await UserDataService.savePreferSpeedTest(value);
                            setState(() {
                              _preferSpeedTest = value;
                            });
                          },
                          icon: LucideIcons.zap,
                        ),
                        focusNode: _preferSpeedTestFocusNode,
                        onTap: () async {
                          await UserDataService.savePreferSpeedTest(!_preferSpeedTest);
                          setState(() {
                            _preferSpeedTest = !_preferSpeedTest;
                          });
                        },
                      ),
                      // 本地搜索选项（本地模式下不显示）
                      if (!_isLocalMode) ...[
                        // 分割线
                        Container(
                          height: 1,
                          color: widget.isDarkMode
                              ? const Color(0xFF374151)
                              : const Color(0xFFe5e7eb),
                        ),
                        _buildMenuItem(
                          child: _buildToggleOption(
                            title: '本地搜索',
                            value: _localSearch,
                            onChanged: (value) async {
                              await UserDataService.saveLocalSearch(value);
                              setState(() {
                                _localSearch = value;
                              });
                            },
                            icon: LucideIcons.search,
                          ),
                          focusNode: _localSearchFocusNode,
                          onTap: () async {
                            await UserDataService.saveLocalSearch(!_localSearch);
                            setState(() {
                              _localSearch = !_localSearch;
                            });
                          },
                        ),
                      ],
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 清除豆瓣缓存按钮
                      _buildMenuItem(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14, // 增加高度
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.trash2,
                                size: 22, // 增加图标大小
                                color: const Color(0xFFf59e0b),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '清除豆瓣缓存',
                                style: FontUtils.poppins(
                                  fontSize: 16,
                                  color: widget.isDarkMode
                                      ? const Color(0xFFffffff)
                                      : const Color(0xFF1f2937),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        focusNode: _clearDoubanCacheFocusNode,
                        onTap: _handleClearDoubanCache,
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 检查更新按钮
                      _buildMenuItem(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14, // 增加高度
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.download,
                                size: 22, // 增加图标大小
                                color: const Color(0xFF3b82f6),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '检查更新',
                                style: FontUtils.poppins(
                                  fontSize: 16,
                                  color: widget.isDarkMode
                                      ? const Color(0xFFffffff)
                                      : const Color(0xFF1f2937),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        focusNode: _checkUpdateFocusNode,
                        onTap: _handleCheckUpdate,
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 登出按钮
                      _buildMenuItem(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14, // 增加高度
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.logOut,
                                size: 22, // 增加图标大小
                                color: Color(0xFFef4444),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '登出',
                                style: FontUtils.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFFef4444),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        focusNode: _logoutFocusNode,
                        onTap: _handleLogout,
                      ),
                      // 分割线
                      Container(
                        height: 1,
                        color: widget.isDarkMode
                            ? const Color(0xFF374151)
                            : const Color(0xFFe5e7eb),
                      ),
                      // 版本号
                      _buildMenuItem(
                        child: GestureDetector(
                          onTap: () async {
                            final url = Uri.parse(
                                'https://github.com/hein1225/HeinPlayTV/');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16, // 增加高度
                            ),
                            child: Center(
                              child: Text(
                                _version.isEmpty ? 'v1.4.3' : 'v$_version',
                                style: FontUtils.poppins(
                                  fontSize: 16, // 增加字体大小
                                  color: widget.isDarkMode
                                      ? const Color(0xFF9ca3af)
                                      : const Color(0xFF6b7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        focusNode: _versionFocusNode,
                        onTap: () async {
                          final url = Uri.parse('https://github.com/hein1225/HeinPlayTV/');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}