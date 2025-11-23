import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:stelliberty/storage/preferences.dart';
import 'package:stelliberty/i18n/i18n.dart';
import 'logger.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

// 窗口状态管理器，负责窗口尺寸、位置及最大化状态的持久化
class WindowStateManager {
  // 默认窗口配置
  static const _defaultSize = Size(900, 660);
  static const _minSize = Size(900, 660);

  // 缓存窗口状态，避免重复读取
  static _WindowState? _cachedState;

  // 获取窗口状态（带缓存）
  static _WindowState _getState() {
    _cachedState ??= _WindowState.fromAppConfig();
    return _cachedState!;
  }

  // 清除状态缓存，保存新状态后调用
  static void clearCache() {
    _cachedState = null;
  }

  // 应用启动时恢复窗口状态，从本地存储读取上次保存的几何信息
  static Future<void> loadAndApplyState({bool forceSilent = false}) async {
    try {
      // 设置窗口最小尺寸
      await windowManager.setMinimumSize(_minSize);
      await windowManager.setTitle(
        LocaleSettings.instance.currentTranslations.common.appName,
      );

      // 预计算所需值
      final state = _getState();
      final silentStart =
          forceSilent || AppPreferences.instance.getSilentStartEnabled();

      Size windowSize = state.size;
      bool shouldCenter = true;

      // 最大化状态下使用屏幕可见区域尺寸（考虑 DPI 缩放和任务栏）
      if (state.isMaximized) {
        try {
          // 获取所有显示器信息
          final displays = await screenRetriever.getAllDisplays();

          // 查找包含窗口位置的显示器（多显示器支持）
          Display? targetDisplay;
          if (state.hasPosition) {
            final savedPosition = state.position!;
            for (final display in displays) {
              final visiblePos = display.visiblePosition ?? const Offset(0, 0);
              final visibleSize = display.visibleSize ?? display.size;

              // 判断位置是否在当前显示器可见区域
              if (savedPosition.dx >= visiblePos.dx &&
                  savedPosition.dx < visiblePos.dx + visibleSize.width &&
                  savedPosition.dy >= visiblePos.dy &&
                  savedPosition.dy < visiblePos.dy + visibleSize.height) {
                targetDisplay = display;
                break;
              }
            }
          }

          // 未找到合适显示器时使用主显示器
          targetDisplay ??= await screenRetriever.getPrimaryDisplay();

          windowSize = targetDisplay.visibleSize ?? targetDisplay.size;
          shouldCenter = false;

          Logger.info(
            "窗口状态: 最大化=true, 目标显示器=${targetDisplay.name ?? 'Unknown'}, "
            "可见区域=${windowSize.width}x${windowSize.height}, 缩放=${targetDisplay.scaleFactor}",
          );
        } catch (e) {
          Logger.warning("获取屏幕尺寸失败，使用保存的尺寸：$e");
          Logger.info(
            "窗口状态: 最大化=true, 尺寸=${windowSize.width}x${windowSize.height}",
          );
        }
      } else {
        Logger.info(
          "窗口状态: 最大化=false, 尺寸=${windowSize.width}x${windowSize.height}",
        );
      }

      // 设置窗口尺寸和位置
      await windowManager.setSize(windowSize);
      if (shouldCenter) {
        await windowManager.center();
      }

      // 等待窗口初始化完成
      await windowManager.waitUntilReadyToShow();

      // 渲染完成后再显示窗口
      if (!silentStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            if (state.isMaximized) {
              await windowManager.maximize();
            }
            appWindow.show();
          } catch (e) {
            Logger.error("显示窗口失败：$e");
          }
        });
      } else {
        Logger.info("静默启动模式：窗口将不会显示");
      }
    } catch (e) {
      Logger.error("加载窗口状态失败：$e");
      await windowManager.setSize(_defaultSize);
      await windowManager.waitUntilReadyToShow();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        appWindow.show();
      });
    }
  }

  // 保存窗口状态到本地存储，应用关闭时调用
  static Future<void> saveStateOnClose() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      await AppPreferences.instance.setIsMaximized(isMaximized);

      // 非最大化时保存尺寸和位置
      if (!isMaximized) {
        await _saveWindowGeometry();
      }

      clearCache();
      Logger.info("窗口状态已保存: isMaximized=$isMaximized");
    } catch (e) {
      Logger.error("保存窗口状态失败：$e");
    }
  }

  // 保存窗口几何信息（尺寸和位置）到本地存储
  static Future<void> _saveWindowGeometry() async {
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();

    await Future.wait([
      AppPreferences.instance.setWindowSize(size),
      AppPreferences.instance.setWindowPosition(position),
    ]);
  }

  // 处理窗口最大化/还原切换
  static Future<void> handleMaximizeRestore() async {
    try {
      final isMaximized = await windowManager.isMaximized();

      if (isMaximized) {
        await _restoreWindow();
      } else {
        await _maximizeWindow();
      }
    } catch (e) {
      Logger.error("窗口操作失败：$e");
    }
  }

  // 还原窗口到之前保存的尺寸和位置
  static Future<void> _restoreWindow() async {
    clearCache();
    final state = _getState();

    await windowManager.unmaximize();

    // 渲染完成后设置精确尺寸和位置
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await windowManager.setSize(state.size);

        if (state.hasPosition) {
          await windowManager.setPosition(state.position!);
        }
      } catch (e) {
        Logger.error("还原位置失败：$e");
      }
    });
  }

  // 最大化窗口，先保存当前状态
  static Future<void> _maximizeWindow() async {
    Size? backupSize;
    Offset? backupPosition;

    try {
      backupSize = await windowManager.getSize();
      backupPosition = await windowManager.getPosition();
    } catch (e) {
      Logger.warning("获取当前窗口状态失败：$e");
    }

    try {
      await _saveWindowGeometry();
      clearCache();
    } catch (e) {
      Logger.error("保存窗口状态失败，使用内存备份：$e");
      if (backupSize != null) {
        _cachedState = _WindowState(
          isMaximized: false,
          size: backupSize,
          position: backupPosition,
        );
      }
    }

    await windowManager.maximize();
  }
}

// 窗口状态数据类
class _WindowState {
  final bool isMaximized;
  final Size size;
  final Offset? position;

  const _WindowState({
    required this.isMaximized,
    required this.size,
    this.position,
  });

  // 从配置构造窗口状态对象
  factory _WindowState.fromAppConfig() {
    return _WindowState(
      isMaximized: AppPreferences.instance.getIsMaximized(),
      size:
          AppPreferences.instance.getWindowSize() ??
          WindowStateManager._defaultSize,
      position: AppPreferences.instance.getWindowPosition(),
    );
  }

  bool get hasPosition => position != null;

  @override
  String toString() {
    return '窗口状态（最大化：$isMaximized，尺寸：$size，位置：$position）';
  }
}
