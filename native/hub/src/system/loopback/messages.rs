// Windows 回环豁免管理消息协议
//
// 目的：定义 Dart 与 Rust 之间的回环管理通信接口

use super::api;
use rinf::{DartSignal, RustSignal};
use serde::{Deserialize, Serialize};

// Dart → Rust：获取所有应用容器
#[derive(Deserialize, DartSignal)]
pub struct GetAppContainers;

// Dart → Rust：设置回环豁免
#[derive(Deserialize, DartSignal)]
pub struct SetLoopback {
    pub package_family_name: String,
    pub enabled: bool,
}

// Dart → Rust：保存配置（使用 SID 字符串）
#[derive(Deserialize, DartSignal)]
pub struct SaveLoopbackConfiguration {
    pub sid_strings: Vec<String>,
}

// Rust → Dart：应用容器列表（用于初始化）
#[derive(Serialize, RustSignal)]
pub struct AppContainersList {
    pub containers: Vec<String>,
}

// Rust → Dart：单个应用容器信息
#[derive(Serialize, RustSignal)]
pub struct AppContainerInfo {
    pub app_container_name: String,
    pub display_name: String,
    pub package_family_name: String,
    pub sid: Vec<u8>,
    pub sid_string: String,
    pub is_loopback_enabled: bool,
}

// Rust → Dart：设置回环豁免结果
#[derive(Serialize, RustSignal)]
pub struct SetLoopbackResult {
    pub success: bool,
    pub message: String,
}

// Rust → Dart：应用容器流传输完成信号
#[derive(Serialize, RustSignal)]
pub struct AppContainersComplete;

// Rust → Dart：保存配置结果
#[derive(Serialize, RustSignal)]
pub struct SaveLoopbackConfigurationResult {
    pub success: bool,
    pub message: String,
}

impl GetAppContainers {
    // 处理获取应用容器请求
    //
    // 目的：枚举所有 UWP 应用并返回其回环状态
    pub fn handle(&self) {
        log::info!("处理获取应用容器请求");
        match api::enumerate_app_containers() {
            Ok(containers) => {
                log::info!("发送{}个容器信息到 Dart", containers.len());
                AppContainersList { containers: vec![] }.send_signal_to_dart();

                for c in containers {
                    AppContainerInfo {
                        app_container_name: c.app_container_name,
                        display_name: c.display_name,
                        package_family_name: c.package_family_name,
                        sid: c.sid,
                        sid_string: c.sid_string,
                        is_loopback_enabled: c.is_loopback_enabled,
                    }
                    .send_signal_to_dart();
                }

                // 发送流传输完成信号
                AppContainersComplete.send_signal_to_dart();
                log::info!("应用容器流传输完成");
            }
            Err(e) => {
                log::error!("获取应用容器失败：{}", e);
                AppContainersList { containers: vec![] }.send_signal_to_dart();
                // 即使失败也发送完成信号，避免 Dart 端无限等待
                AppContainersComplete.send_signal_to_dart();
            }
        }
    }
}

impl SetLoopback {
    // 处理设置回环豁免请求
    //
    // 目的：为单个应用启用或禁用回环豁免
    pub fn handle(self) {
        log::info!(
            "处理设置回环豁免请求：{} - {}",
            self.package_family_name,
            self.enabled
        );
        match api::set_loopback_exemption(&self.package_family_name, self.enabled) {
            Ok(()) => {
                log::info!("回环豁免设置成功");
                SetLoopbackResult {
                    success: true,
                    message: "回环豁免设置成功".to_string(),
                }
                .send_signal_to_dart();
            }
            Err(e) => {
                log::error!("回环豁免设置失败：{}", e);
                SetLoopbackResult {
                    success: false,
                    message: e,
                }
                .send_signal_to_dart();
            }
        }
    }
}

impl SaveLoopbackConfiguration {
    // 处理保存配置请求
    //
    // 目的：批量设置多个应用的回环豁免状态
    pub fn handle(self) {
        log::info!("处理保存配置请求，期望启用{}个容器", self.sid_strings.len());

        // 获取所有容器
        let containers = match api::enumerate_app_containers() {
            Ok(c) => c,
            Err(e) => {
                log::error!("枚举容器失败：{}", e);
                SaveLoopbackConfigurationResult {
                    success: false,
                    message: format!("无法枚举容器：{}", e),
                }
                .send_signal_to_dart();
                return;
            }
        };

        // 性能优化：使用 HashSet 进行 O(1) 查找，避免 O(n²) 复杂度
        use std::collections::HashSet;
        let enabled_sids: HashSet<&str> = self.sid_strings.iter().map(|s| s.as_str()).collect();

        let mut errors = Vec::new();
        let mut success_count = 0;

        // 对每个容器，检查是否应该启用（现在是 O(1) 查找）
        for container in containers {
            let should_enable = enabled_sids.contains(container.sid_string.as_str());

            if container.is_loopback_enabled != should_enable {
                log::info!(
                    "修改容器：{}(SID：{}) | {} -> {}",
                    container.display_name,
                    container.sid_string,
                    container.is_loopback_enabled,
                    should_enable
                );

                if let Err(e) = api::set_loopback_exemption_by_sid(&container.sid, should_enable) {
                    log::error!("设置容器失败：{} - {}", container.display_name, e);
                    errors.push(format!("{}：{}", container.display_name, e));
                } else {
                    success_count += 1;
                }
            }
        }

        log::info!(
            "配置保存完成 | 修改：{} | 错误：{}",
            success_count,
            errors.len()
        );

        if errors.is_empty() {
            SaveLoopbackConfigurationResult {
                success: true,
                message: format!("配置保存成功（修改：{}个容器）", success_count),
            }
            .send_signal_to_dart();
        } else {
            SaveLoopbackConfigurationResult {
                success: false,
                message: format!(
                    "部分操作失败（成功：{}，失败：{}）：\n{}",
                    success_count,
                    errors.len(),
                    errors.join("\n")
                ),
            }
            .send_signal_to_dart();
        }
    }
}
