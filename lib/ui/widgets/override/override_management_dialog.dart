import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:stelliberty/clash/data/override_model.dart';
import 'package:stelliberty/clash/services/override_service.dart';
import 'package:stelliberty/utils/logger.dart';
import 'package:stelliberty/i18n/i18n.dart';
import 'package:stelliberty/ui/widgets/modern_toast.dart';
import 'package:stelliberty/ui/common/modern_dialog.dart';

// 规则覆写管理对话框
class OverrideManagementDialog extends StatefulWidget {
  final List<OverrideConfig> initialOverrides;
  final Function(List<OverrideConfig>) onSave;
  final OverrideService overrideService;

  const OverrideManagementDialog({
    super.key,
    required this.initialOverrides,
    required this.onSave,
    required this.overrideService,
  });

  static Future<void> show(
    BuildContext context, {
    required List<OverrideConfig> initialOverrides,
    required Function(List<OverrideConfig>) onSave,
    required OverrideService overrideService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OverrideManagementDialog(
        initialOverrides: initialOverrides,
        onSave: onSave,
        overrideService: overrideService,
      ),
    );
  }

  @override
  State<OverrideManagementDialog> createState() =>
      _OverrideManagementDialogState();
}

class _OverrideManagementDialogState extends State<OverrideManagementDialog> {
  late List<OverrideConfig> _overrides;

  @override
  void initState() {
    super.initState();
    _overrides = List.from(widget.initialOverrides);
  }

  @override
  Widget build(BuildContext context) {
    return ModernDialog(
      title: context.translate.overrideDialog.title,
      titleIcon: Icons.rule,
      maxWidth: 700,
      maxHeightRatio: 0.8,
      content: _buildContent(),
      actionsRight: [
        DialogActionButton(
          label: context.translate.common.cancel,
          isPrimary: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogActionButton(
          label: context.translate.common.save,
          isPrimary: true,
          onPressed: _handleSave,
        ),
      ],
      onClose: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 添加按钮栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showAddOverrideDialog(OverrideType.remote),
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: Text(context.translate.overrideDialog.addRemote),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showAddOverrideDialog(OverrideType.local),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(context.translate.overrideDialog.addLocal),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 覆写列表
        Expanded(
          child: _overrides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        context.translate.overrideDialog.emptyTitle,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate.overrideDialog.emptyHint,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _overrides.length,
                  buildDefaultDragHandles: false, // 禁用默认拖动句柄
                  proxyDecorator: (child, index, animation) {
                    // 保持卡片大小不变
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 96,
                      ),
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      // 调整 newIndex（因为移除元素后索引会变化）
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }

                      final item = _overrides.removeAt(oldIndex);
                      _overrides.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    return ReorderableDragStartListener(
                      key: ValueKey(_overrides[index].id),
                      index: index,
                      child: _buildOverrideItem(_overrides[index], index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOverrideItem(OverrideConfig override, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEditOverrideDialog(override, index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 拖动手柄
                Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
                const SizedBox(width: 12),

                // 类型图标
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: override.type == OverrideType.remote
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    override.type == OverrideType.remote
                        ? Icons.cloud
                        : Icons.folder,
                    color: override.type == OverrideType.remote
                        ? Colors.blue
                        : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        override.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 格式标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: override.format == OverrideFormat.yaml
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              override.format.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: override.format == OverrideFormat.yaml
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 路径/URL
                          Expanded(
                            child: Text(
                              override.type == OverrideType.remote
                                  ? (override.url ?? '')
                                  : (override.localPath ?? ''),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 更多菜单
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditOverrideDialog(override, index);
                        break;
                      case 'delete':
                        _deleteOverride(index);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text(context.translate.overrideDialog.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            context.translate.overrideDialog.delete,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddOverrideDialog(OverrideType type) async {
    final result = await AddOverrideDialog.show(
      context,
      type: type,
      overrideService: widget.overrideService,
    );
    if (result != null) {
      setState(() {
        _overrides.add(result);
      });
    }
  }

  void _showEditOverrideDialog(OverrideConfig override, int index) async {
    final result = await AddOverrideDialog.show(
      context,
      type: override.type,
      editingOverride: override,
      overrideService: widget.overrideService,
    );
    if (result != null) {
      setState(() {
        _overrides[index] = result;
      });
    }
  }

  void _deleteOverride(int index) {
    setState(() {
      _overrides.removeAt(index);
    });
  }

  void _handleSave() {
    widget.onSave(_overrides);
    Navigator.of(context).pop();
  }
}

// 添加/编辑覆写对话框
class AddOverrideDialog extends StatefulWidget {
  final OverrideType type;
  final OverrideConfig? editingOverride;
  final OverrideService overrideService;

  const AddOverrideDialog({
    super.key,
    required this.type,
    this.editingOverride,
    required this.overrideService,
  });

  static Future<OverrideConfig?> show(
    BuildContext context, {
    required OverrideType type,
    OverrideConfig? editingOverride,
    required OverrideService overrideService,
  }) {
    return showDialog<OverrideConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddOverrideDialog(
        type: type,
        editingOverride: editingOverride,
        overrideService: overrideService,
      ),
    );
  }

  @override
  State<AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<AddOverrideDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late OverrideFormat _format;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isDragging = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.editingOverride?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.editingOverride?.url ?? '',
    );
    _format = widget.editingOverride?.format ?? OverrideFormat.yaml;

    if (widget.editingOverride?.localPath != null) {
      _selectedFileName = widget.editingOverride!.localPath!.split('/').last;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingOverride != null;
    return ModernDialog(
      title: isEditing
          ? context.translate.overrideDialog.editOverrideTitle
          : context.translate.overrideDialog.addOverrideTitle,
      titleIcon: isEditing ? Icons.edit : Icons.add_circle_outline,
      maxWidth: 520,
      content: _buildContent(),
      actionsRight: [
        DialogActionButton(
          label: context.translate.common.cancel,
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
        DialogActionButton(
          label: isEditing
              ? context.translate.common.save
              : context.translate.common.add,
          isPrimary: true,
          isLoading: _isLoading,
          onPressed: _handleConfirm,
        ),
      ],
      onClose: _isLoading ? null : () => Navigator.of(context).pop(),
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
            _buildTextField(
              controller: _nameController,
              label: context.translate.overrideDialog.nameLabel,
              hint: context.translate.overrideDialog.nameHint,
              icon: Icons.label_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.translate.overrideDialog.nameError;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 格式选择
            _buildFormatSelector(),
            const SizedBox(height: 20),

            // 根据类型显示不同输入
            if (widget.type == OverrideType.remote)
              _buildTextField(
                controller: _urlController,
                label: context.translate.overrideDialog.remoteLinkLabel,
                hint: context.translate.overrideDialog.remoteLinkHint,
                icon: Icons.link,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.translate.overrideDialog.remoteLinkError;
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return context
                        .translate
                        .overrideDialog
                        .remoteLinkFormatError;
                  }
                  return null;
                },
              )
            else
              _buildFileSelector(),
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
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.code,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.translate.overrideDialog.formatTitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildFormatOption(OverrideFormat.yaml)),
                const SizedBox(width: 12),
                Expanded(child: _buildFormatOption(OverrideFormat.js)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(OverrideFormat format) {
    final isSelected = _format == format;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _format = format),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
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

  Widget _buildFileSelector() {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) {
          final file = File(details.files.first.path);
          if (await file.exists()) {
            setState(() {
              _selectedFile = file;
              _selectedFileName = details.files.first.name;
            });
          }
        }
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
                    color: _isDragging || _selectedFile != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDragging
                              ? context.translate.overrideDialog.dropFile
                              : (_selectedFile != null
                                    ? context
                                          .translate
                                          .overrideDialog
                                          .fileSelected
                                    : context
                                          .translate
                                          .overrideDialog
                                          .selectLocalFile),
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
                          _selectedFile != null
                              ? _selectedFileName ??
                                    context
                                        .translate
                                        .subscriptionDialog
                                        .unknownFile
                              : context
                                    .translate
                                    .overrideDialog
                                    .clickOrDragFile,
                          style: TextStyle(
                            color: _selectedFile != null || _isDragging
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _selectedFile != null ? Icons.edit : Icons.folder_open,
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

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (await file.exists()) {
          setState(() {
            _selectedFile = file;
            _selectedFileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      Logger.debug('文件选择失败: $e');
    }
  }

  bool _isLoading = false;

  void _handleConfirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.type == OverrideType.local && _selectedFile == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 创建覆写配置
      final override =
          widget.editingOverride?.copyWith(
            name: _nameController.text.trim(),
            format: _format,
            url: widget.type == OverrideType.remote
                ? _urlController.text.trim()
                : null,
            localPath: widget.type == OverrideType.local
                ? _selectedFile?.path
                : null,
            lastUpdate: DateTime.now(),
          ) ??
          OverrideConfig.create(
            name: _nameController.text.trim(),
            type: widget.type,
            format: _format,
            url: widget.type == OverrideType.remote
                ? _urlController.text.trim()
                : null,
            localPath: widget.type == OverrideType.local
                ? _selectedFile?.path
                : null,
          );

      // 下载或复制文件
      String content;
      if (widget.type == OverrideType.remote) {
        content = await widget.overrideService.downloadRemoteOverride(override);
      } else {
        content = await widget.overrideService.saveLocalOverride(
          override,
          _selectedFile!.path,
        );
      }

      // 更新覆写配置，添加内容
      final updatedOverride = override.copyWith(content: content);

      // 关闭对话框并返回结果
      if (mounted) {
        Navigator.of(context).pop(updatedOverride);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // 显示错误提示
      if (mounted) {
        ModernToast.error(
          context,
          context.translate.overrideDialog.saveError.replaceAll(
            '{error}',
            e.toString(),
          ),
        );
      }
    }
  }
}
