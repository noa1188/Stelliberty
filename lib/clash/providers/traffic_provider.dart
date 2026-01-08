import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:stelliberty/clash/model/traffic_data_model.dart';
import 'package:stelliberty/clash/manager/manager.dart';
import 'package:stelliberty/services/log_print_service.dart';

// 流量统计状态管理
// 订阅流量数据流，管理累计流量和波形图历史
class TrafficProvider extends ChangeNotifier {
  final ClashManager _clashManager = ClashManager.instance;
  StreamSubscription<TrafficData>? _trafficSubscription;

  // 累计流量统计
  int _totalUpload = 0;
  int _totalDownload = 0;
  DateTime? _lastTimestamp;

  // 缓存最后一次的流量数据
  TrafficData? _lastTrafficData;

  // 波形图历史数据
  final List<double> _uploadHistory = List.generate(30, (_) => 0.0);
  final List<double> _downloadHistory = List.generate(30, (_) => 0.0);

  // Getters
  int get totalUpload => _totalUpload;
  int get totalDownload => _totalDownload;
  TrafficData? get lastTrafficData => _lastTrafficData;
  List<double> get uploadHistory => UnmodifiableListView(_uploadHistory);
  List<double> get downloadHistory => UnmodifiableListView(_downloadHistory);

  TrafficProvider() {
    _subscribeToTrafficStream();
  }

  // 订阅流量数据流
  void _subscribeToTrafficStream() {
    _trafficSubscription = _clashManager.trafficStream?.listen(
      (trafficData) {
        _handleTrafficData(trafficData);
      },
      onError: (error) {
        Logger.error('流量数据流错误：$error');
      },
    );
  }

  // 处理流量数据
  void _handleTrafficData(TrafficData data) {
    // 累计流量统计（基于时间间隔估算）
    final now = data.timestamp;
    if (_lastTimestamp != null) {
      final interval = now.difference(_lastTimestamp!).inMilliseconds / 1000.0;
      // 使用当前速度和时间间隔估算流量增量
      if (interval > 0 && interval < 10) {
        _totalUpload += (data.upload * interval).round();
        _totalDownload += (data.download * interval).round();
      }
    }
    _lastTimestamp = now;

    // 更新波形图历史数据
    _uploadHistory.removeAt(0);
    _uploadHistory.add(data.upload / 1024.0); // KB/s
    _downloadHistory.removeAt(0);
    _downloadHistory.add(data.download / 1024.0); // KB/s

    // 缓存最后的数据（带累计流量）
    _lastTrafficData = data.copyWithTotal(
      totalUpload: _totalUpload,
      totalDownload: _totalDownload,
    );

    notifyListeners();
  }

  // 重置累计流量
  void resetTotalTraffic() {
    _totalUpload = 0;
    _totalDownload = 0;
    _lastTimestamp = null;
    _lastTrafficData = null;
    _uploadHistory.fillRange(0, _uploadHistory.length, 0);
    _downloadHistory.fillRange(0, _downloadHistory.length, 0);
    Logger.info('累计流量已重置');
    notifyListeners();
  }

  @override
  void dispose() {
    _trafficSubscription?.cancel();
    super.dispose();
  }
}
