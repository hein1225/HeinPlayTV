import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

/// 设备类型工具类
class DeviceUtils {
  // 平板的最小宽度阈值（dp）
  static const double tabletMinWidth = 600.0;

  /// 判断当前设备是否是平板
  ///
  /// 通过屏幕宽度判断，宽度 >= 600dp 视为平板
  static bool isTablet(BuildContext context) {
    if (isPC() || isTV()) {
      return true;
    }
    final double width = MediaQuery.of(context).size.width;
    return width >= tabletMinWidth;
  }

  /// 判断当前设备是否是平板竖屏
  ///
  /// 逻辑：isTablet 且宽高比小于等于 1.2
  static bool isPortraitTablet(BuildContext context) {
    if (!isTablet(context)) {
      return false;
    }
    if (isPC() || isTV()) {
      return false;
    }

    final Size size = MediaQuery.of(context).size;
    final double aspectRatio = size.width / size.height;
    return aspectRatio <= 1.2;
  }

  /// 判断当前平台是否是 Windows
  static bool isWindows() {
    return Platform.isWindows;
  }

  /// 判断当前平台是否是 macOS
  static bool isMacOS() {
    return Platform.isMacOS;
  }

  /// 判断当前平台是否是 PC（Windows 或 macOS）
  static bool isPC() {
    return isWindows() || isMacOS();
  }

  /// 判断当前设备是否是 TV
  ///
  /// 通过平台和屏幕尺寸判断
  static bool isTV() {
    // 目前只针对Android TV平台
    // 使用屏幕尺寸和平台来判断
    if (!Platform.isAndroid) {
      return false;
    }
    // 这里我们通过屏幕尺寸来判断是否可能是TV设备
    // TV设备通常有更大的屏幕
    try {
      final mediaQuery = MediaQueryData.fromWindow(WidgetsBinding.instance.window);
      final screenWidth = mediaQuery.size.width;
      final screenHeight = mediaQuery.size.height;
      final diagonalInches = sqrt(pow(screenWidth, 2) + pow(screenHeight, 2)) / mediaQuery.devicePixelRatio / 160;
      // 假设屏幕对角线大于30英寸的Android设备可能是TV
      return diagonalInches > 30;
    } catch (e) {
      // 如果无法获取屏幕信息，返回false
      return false;
    }
  }

  /// 根据屏幕宽度动态计算平板模式下的列数（6～8列）
  ///
  /// 宽度范围：
  /// - < 1000: 6列
  /// - 1000-1200: 7列
  /// - >= 1200: 8列
  /// - TV设备: 9-12列
  static int getTabletColumnCount(BuildContext context) {
    if (isTV()) {
      final double width = MediaQuery.of(context).size.width;
      if (width < 1200) {
        return 9;
      } else if (width < 1600) {
        return 10;
      } else {
        return 12;
      }
    }

    if (!isTablet(context)) {
      return 3; // 手机模式固定3列
    }

    final double width = MediaQuery.of(context).size.width;

    if (width < 1000) {
      return 6;
    } else if (width < 1200) {
      return 7;
    } else {
      return 8;
    }
  }

  /// 根据屏幕宽度动态计算横向滚动列表的可见卡片数（5.75、6.75、7.75）
  ///
  /// 用于 continue_watching_section 和 recommendation_section
  /// 宽度范围：
  /// - < 1000: 5.75列
  /// - 1000-1200: 6.75列
  /// - >= 1200: 7.75列
  /// - TV设备: 8.75-10.75列
  static double getHorizontalVisibleCards(BuildContext context, double mobileCardCount) {
    if (isTV()) {
      final double width = MediaQuery.of(context).size.width;
      if (width < 1200) {
        return 8.75;
      } else if (width < 1600) {
        return 9.75;
      } else {
        return 10.75;
      }
    }

    if (!isTablet(context)) {
      return mobileCardCount; // 手机模式使用传入的卡片数
    }

    final double width = MediaQuery.of(context).size.width;

    if (width < 1000) {
      return 5.75;
    } else if (width < 1200) {
      return 6.75;
    } else {
      return 7.75;
    }
  }

  /// 根据屏幕宽度动态计算直播频道列表的列数
  static int getLiveChannelColumnCount(BuildContext context) {
    if (isTV()) {
      final double width = MediaQuery.of(context).size.width;
      if (width < 1200) {
        return 6;
      } else if (width < 1600) {
        return 7;
      } else {
        return 8;
      }
    }

    if (!isTablet(context)) {
      return 2; // 手机模式固定2列
    }
    final double width = MediaQuery.of(context).size.width;

    if (width < 1000) {
      return 3;
    } else if (width < 1200) {
      return 4;
    } else {
      return 5;
    }
  }
}
