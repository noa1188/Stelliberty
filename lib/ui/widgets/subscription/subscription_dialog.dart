import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:stelliberty/clash/data/subscription_model.dart';
import 'package:stelliberty/utils/logger.dart';
import 'package:stelliberty/ui/widgets/modern_toast.dart';
import 'package:stelliberty/ui/common/modern_switch.dart';
import 'package:stelliberty/i18n/i18n.dart';

// 订阅导入方式枚举
enum SubscriptionImportMethod {
  // 链接导入
  link,

  // 本地文件导入
  localFile,
}

// 订阅对话框组件 - 毛玻璃风格
class SubscriptionDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialUrl;
  final bool? initialAutoUpdate;
  final Duration? initialAutoUpdateInterval;
  final SubscriptionProxyMode? initialProxyMode; // 新增：初始代理模式
  final String confirmText;
  final IconData titleIcon;
  final bool isAddMode; // 新增：是否为添加模式
  final bool isLocalFile; // 新增：是否为本地文件订阅
  final Future<bool> Function(SubscriptionDialogResult)? onConfirm; // 新增：确认回调

  const SubscriptionDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialUrl,
    this.initialAutoUpdate,
    this.initialAutoUpdateInterval,
    this.initialProxyMode,
    this.confirmText = 'Confirm',
    this.titleIcon = Icons.rss_feed,
    this.isAddMode = false, // 默认为编辑模式
    this.isLocalFile = false, // 默认为远程订阅
    this.onConfirm, // 确认回调
  });

  // 显示添加配置对话框
  static Future<void> showAddDialog(
    BuildContext context, {
    required Future<bool> Function(SubscriptionDialogResult) onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubscriptionDialog(
        title: context.translate.subscriptionDialog.addTitle,
        confirmText: context.translate.subscriptionDialog.addButton,
        titleIcon: Icons.add_circle_outline,
        isAddMode: true, // 标记为添加模式
        onConfirm: onConfirm,
      ),
    );
  }

  // 显示编辑订阅对话框
  static Future<SubscriptionDialogResult?> showEditDialog(
    BuildContext context,
    Subscription subscription,
  ) {
    return showDialog<SubscriptionDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubscriptionDialog(
        title: context.translate.subscriptionDialog.editTitle,
        initialName: subscription.name,
        initialUrl: subscription.url,
        initialAutoUpdate: subscription.autoUpdate,
        initialAutoUpdateInterval: subscription.autoUpdateInterval,
        initialProxyMode: subscription.proxyMode,
        confirmText: context.translate.subscriptionDialog.saveButton,
        titleIcon: Icons.edit_outlined,
        isLocalFile: subscription.isLocalFile, // 传递本地文件标识
      ),
    );
  }

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog>
    with TickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _intervalController;
  late bool _autoUpdate;
  late SubscriptionProxyMode _proxyMode; // 代理模式

  // 导入方式选择
  SubscriptionImportMethod _importMethod = SubscriptionImportMethod.link;

  // 选中的文件信息
  File? _selectedFile;
  String? _selectedFileName;

  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isDragging = false; // 拖拽状态

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _intervalController = TextEditingController(
      text: (widget.initialAutoUpdateInterval?.inMinutes ?? 60).toString(),
    );
    _autoUpdate = widget.initialAutoUpdate ?? false;
    _proxyMode = widget.initialProxyMode ?? SubscriptionProxyMode.direct;

    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // 延迟启动动画，确保组件完全渲染后再播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _intervalController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              // 背景遮罩
              Container(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.3),
              ),
              // 对话框内容
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: _buildDialog(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(child: _buildContent()),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.titleIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _handleCancel,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 如果是添加模式，显示导入方式选择
            if (widget.isAddMode) ...[
              _buildImportModeSelector(),
              const SizedBox(height: 20),
            ],

            _buildTextField(
              controller: _nameController,
              label: context.translate.subscriptionDialog.configNameLabel,
              hint: context.translate.subscriptionDialog.configNameHint,
              icon: Icons.label_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.translate.subscriptionDialog.configNameError;
                }
                return null;
              },
            ),

            // 根据导入方式显示不同的输入控件
            // 添加模式：根据 _importMethod 显示
            // 编辑模式：本地文件订阅不显示 URL 字段
            if (widget.isAddMode &&
                    _importMethod == SubscriptionImportMethod.link ||
                !widget.isAddMode && !widget.isLocalFile) ...[
              const SizedBox(height: 20),
              _buildTextField(
                controller: _urlController,
                label:
                    context.translate.subscriptionDialog.subscriptionLinkLabel,
                hint: context.translate.subscriptionDialog.subscriptionLinkHint,
                icon: Icons.link,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.translate.subscriptionDialog.linkError;
                  }

                  final uri = Uri.tryParse(value.trim());
                  if (uri == null) {
                    return context.translate.subscriptionDialog.linkFormatError;
                  }

                  if (uri.scheme != 'http' && uri.scheme != 'https') {
                    return context
                        .translate
                        .subscriptionDialog
                        .linkProtocolError;
                  }

                  if (uri.host.isEmpty) {
                    return context.translate.subscriptionDialog.linkMissingHost;
                  }

                  // 验证域名格式：必须包含点，或者是 localhost/IP
                  final host = uri.host.toLowerCase();
                  if (host != 'localhost' &&
                      host != '127.0.0.1' &&
                      !host.contains('.')) {
                    return context
                        .translate
                        .subscriptionDialog
                        .linkHostFormatError;
                  }

                  if (host.length < 3) {
                    return context
                        .translate
                        .subscriptionDialog
                        .linkHostTooShort;
                  }

                  return null;
                },
              ),
            ] else if (widget.isAddMode &&
                _importMethod == SubscriptionImportMethod.localFile) ...[
              const SizedBox(height: 20),
              _buildFileSelector(),
            ],

            // 只有链接导入才显示自动更新选项
            // 添加模式：只有选择链接导入时显示
            // 编辑模式：只有非本地文件才显示
            if ((widget.isAddMode &&
                    _importMethod == SubscriptionImportMethod.link) ||
                (!widget.isAddMode && !widget.isLocalFile)) ...[
              const SizedBox(height: 20),
              _buildAutoUpdateSection(),
              const SizedBox(height: 20),
              _buildProxyModeSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          ),
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                top: maxLines > 1 ? 16.0 : 0.0,
                bottom: maxLines > 1 ? (maxLines - 1) * 20.0 : 0.0,
              ),
              child: Icon(icon, size: 16),
            ),
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 48, minHeight: 48)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            labelStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoUpdateSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  context.translate.subscriptionDialog.autoUpdateTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: _autoUpdate
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.translate.subscriptionDialog.autoUpdateEnable,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.translate.subscriptionDialog.autoUpdateDesc,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ModernSwitch(
                    value: _autoUpdate,
                    onChanged: (value) {
                      setState(() => _autoUpdate = value);
                    },
                  ),
                ],
              ),
            ),
            if (_autoUpdate) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _intervalController,
                label: context.translate.subscriptionDialog.updateIntervalLabel,
                hint: context.translate.subscriptionDialog.updateIntervalHint,
                icon: Icons.schedule,
                validator: (value) {
                  if (_autoUpdate) {
                    final minutes = int.tryParse(value?.trim() ?? '');
                    if (minutes == null || minutes < 1) {
                      return context
                          .translate
                          .subscriptionDialog
                          .updateIntervalError;
                    }
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 构建代理模式选择区域
  Widget _buildProxyModeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  context.translate.subscriptionDialog.proxyModeTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 三个代理模式选项
            ...SubscriptionProxyMode.values.map((mode) {
              final isSelected = _proxyMode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() => _proxyMode = mode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.1 : 0.2,
                                ),
                              ),
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.08)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getProxyModeDescription(mode),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 获取代理模式描述
  String _getProxyModeDescription(SubscriptionProxyMode mode) {
    final trans = context.translate.subscriptionDialog;
    switch (mode) {
      case SubscriptionProxyMode.direct:
        return trans.proxyModeDirect;
      case SubscriptionProxyMode.system:
        return trans.proxyModeSystem;
      case SubscriptionProxyMode.core:
        return trans.proxyModeCore;
    }
  }

  // 构建导入方式选择器
  Widget _buildImportModeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.import_export,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  context.translate.subscriptionDialog.importMethodTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildImportMethodOption(
                    method: SubscriptionImportMethod.link,
                    icon: Icons.link,
                    title: context.translate.subscriptionDialog.importLink,
                    subtitle:
                        context.translate.subscriptionDialog.importLinkSupport,
                    colorScheme: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImportMethodOption(
                    method: SubscriptionImportMethod.localFile,
                    icon: Icons.folder,
                    title: context.translate.subscriptionDialog.importLocal,
                    subtitle: context
                        .translate
                        .subscriptionDialog
                        .importLocalNoSupport,
                    colorScheme: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportMethodOption({
    required SubscriptionImportMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color colorScheme,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _importMethod == method;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _importMethod = method;
            _autoUpdate = method == SubscriptionImportMethod.link;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: colorScheme, width: 2)
                : Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
                  ),
            color: isSelected
                ? colorScheme.withValues(alpha: 0.08)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? colorScheme
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
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

  // 构建文件选择器
  Widget _buildFileSelector() {
    return DropTarget(
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      onDragDone: (details) async {
        setState(() {
          _isDragging = false;
        });
        final paths = details.files.map((file) => file.path).toList();
        await _handleDroppedFiles(paths);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _selectFile,
          child: Container(
            decoration: BoxDecoration(
              color: _isDragging
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : (_selectedFile != null
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5)
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2)),
                width: _isDragging || _selectedFile != null ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    _isDragging
                        ? Icons.file_download
                        : (_selectedFile != null
                              ? Icons.check_circle
                              : Icons.upload_file),
                    size: 20,
                    color: _isDragging
                        ? Theme.of(context).colorScheme.primary
                        : (_selectedFile != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDragging
                              ? context
                                    .translate
                                    .subscriptionDialog
                                    .dropToImport
                              : (_selectedFile != null
                                    ? context
                                          .translate
                                          .subscriptionDialog
                                          .fileSelectedLabel
                                    : context
                                          .translate
                                          .subscriptionDialog
                                          .selectFileLabel),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: _selectedFile != null || _isDragging
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isDragging
                              ? context.translate.subscriptionDialog.dragSupport
                              : (_selectedFile != null
                                    ? _selectedFileName ??
                                          context
                                              .translate
                                              .subscriptionDialog
                                              .unknownFile
                                    : context
                                          .translate
                                          .subscriptionDialog
                                          .clickOrDrag),
                          style: TextStyle(
                            color: _isDragging
                                ? Theme.of(context).colorScheme.primary
                                : (_selectedFile != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                            fontSize: 12,
                            fontWeight: _selectedFile != null || _isDragging
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isDragging
                        ? Icons.download
                        : (_selectedFile != null
                              ? Icons.edit
                              : Icons.folder_open),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 选择文件
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // 允许选择所有文件类型
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // 验证文件是否存在和可读
        if (await file.exists()) {
          setState(() {
            _selectedFile = file;
            _selectedFileName = fileName;
          });
        } else {
          throw Exception('文件不存在或无法访问');
        }
      }
    } catch (e) {
      // 文件选择失败，不执行任何操作
      Logger.debug('文件选择失败: $e');
    }
  }

  // 处理拖拽文件
  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      // 只处理第一个文件
      final filePath = paths.first;
      final file = File(filePath);

      // 验证文件是否存在
      if (!await file.exists()) {
        Logger.warning('拖拽的文件不存在: $filePath');
        return;
      }

      final fileName = filePath.split(Platform.pathSeparator).last;

      setState(() {
        _selectedFile = file;
        _selectedFileName = fileName;
      });

      Logger.debug('通过拖拽选择文件: $fileName');
    } catch (e) {
      Logger.error('处理拖拽文件失败: $e');
    }
  }

  Widget _buildActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.3),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.isAddMode ? '提示：订阅开启后会自动同步节点' : '提示：保存后配置将立即生效',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _isLoading ? null : _handleCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.6),
                ),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              child: Text(
                context.translate.subscriptionDialog.cancelButton,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.confirmText),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(widget.confirmText),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCancel() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleConfirm() async {
    // 验证表单
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 验证本地导入时是否选择了文件
    if (_importMethod == SubscriptionImportMethod.localFile &&
        _selectedFile == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = SubscriptionDialogResult(
        name: _nameController.text.trim(),
        url: _importMethod == SubscriptionImportMethod.link
            ? _urlController.text.trim()
            : null, // 本地导入时url为null
        autoUpdate: _autoUpdate,
        autoUpdateInterval: Duration(
          minutes: int.tryParse(_intervalController.text.trim()) ?? 60,
        ),
        isLocalImport:
            _importMethod == SubscriptionImportMethod.localFile, // 是否为本地导入
        localFilePath: _selectedFile?.path, // 本地文件路径
        proxyMode: _proxyMode, // 代理模式
      );

      // 如果有确认回调，调用它并等待结果
      if (widget.onConfirm != null) {
        bool success = false;
        String? errorMessage;

        try {
          success = await widget.onConfirm!(result);
        } catch (error) {
          success = false;
          errorMessage = error.toString();
          Logger.error('订阅操作异常: $error');
        }

        if (!mounted) return;

        if (success) {
          // 成功，关闭对话框
          await _animationController.reverse();
          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // 失败，停止加载状态，保持对话框打开
          setState(() => _isLoading = false);

          // 显示错误提示
          if (mounted) {
            final defaultErrorMessage =
                _importMethod == SubscriptionImportMethod.localFile
                ? context.translate.subscriptionDialog.localImportFailed
                : context.translate.subscriptionDialog.remoteImportFailed;

            ModernToast.error(context, errorMessage ?? defaultErrorMessage);
          }
        }
      } else {
        // 没有回调，直接返回结果（编辑模式）
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await _animationController.reverse();
          if (mounted) {
            Navigator.of(context).pop(result);
          }
        }
      }
    } catch (error) {
      Logger.error('对话框确认操作异常: $error');
      if (mounted) {
        setState(() => _isLoading = false);
        ModernToast.error(
          context,
          context.translate.subscriptionDialog.operationError.replaceAll(
            '{error}',
            error.toString(),
          ),
        );
      }
    }
  }
}

// 订阅对话框结果
class SubscriptionDialogResult {
  final String name;
  final String? url; // url现在可以为null（本地导入时）
  final bool autoUpdate;
  final Duration autoUpdateInterval;
  final bool isLocalImport; // 新增：是否为本地导入
  final String? localFilePath; // 新增：本地文件路径
  final SubscriptionProxyMode proxyMode; // 新增：代理模式

  const SubscriptionDialogResult({
    required this.name,
    this.url,
    required this.autoUpdate,
    required this.autoUpdateInterval,
    this.isLocalImport = false,
    this.localFilePath,
    this.proxyMode = SubscriptionProxyMode.direct,
  });
}
