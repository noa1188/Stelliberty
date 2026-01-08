import 'package:flutter/foundation.dart';
import 'package:stelliberty/clash/state/service_states.dart';
import 'package:stelliberty/clash/manager/service_manager.dart';
import 'package:stelliberty/services/log_print_service.dart';

// Clash 服务模式状态管理
class ServiceProvider extends ChangeNotifier {
  final ServiceManager _manager = ServiceManager.instance;

  // 服务状态
  ServiceState _serviceState = ServiceState.unknown;
  ServiceState get serviceState => _serviceState;

  // 最后的操作结果
  String? _lastOperationError;
  bool? _lastOperationSuccess;

  ServiceState get status => _serviceState;
  bool get isServiceModeInstalled => _serviceState.isServiceModeInstalled;
  bool get isServiceModeRunning => _serviceState.isServiceModeRunning;
  bool get isServiceModeProcessing => _serviceState.isServiceModeProcessing;
  String? get lastOperationError => _lastOperationError;
  bool? get lastOperationSuccess => _lastOperationSuccess;

  // 更新服务状态
  void _updateServiceState(ServiceState newState) {
    if (_serviceState == newState) return;

    final previousState = _serviceState;
    _serviceState = newState;
    Logger.debug('服务状态变化：${previousState.name} -> ${newState.name}');
    notifyListeners();
  }

  // 清除最后的操作结果
  void clearLastOperationResult() {
    _lastOperationError = null;
    _lastOperationSuccess = null;
    notifyListeners();
  }

  // 初始化服务状态
  Future<void> initialize() async {
    await refreshStatus();
  }

  // 刷新服务状态
  Future<void> refreshStatus() async {
    final newState = await _manager.refreshStatus();
    _updateServiceState(newState);
  }

  // 安装服务
  Future<bool> installService() async {
    if (isServiceModeProcessing) return false;

    _updateServiceState(ServiceState.installing);
    _lastOperationSuccess = null;
    _lastOperationError = null;

    final (success, error) = await _manager.installService();

    _lastOperationSuccess = success;
    _lastOperationError = error;

    // 刷新状态
    await refreshStatus();

    return success;
  }

  // 卸载服务
  Future<bool> uninstallService() async {
    if (isServiceModeProcessing) return false;

    _updateServiceState(ServiceState.uninstalling);
    _lastOperationSuccess = null;
    _lastOperationError = null;

    final (success, error) = await _manager.uninstallService();

    _lastOperationSuccess = success;
    _lastOperationError = error;

    if (success) {
      _updateServiceState(ServiceState.notInstalled);
    } else {
      // 失败时刷新状态
      await refreshStatus();
    }

    return success;
  }
}
