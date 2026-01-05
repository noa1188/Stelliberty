// Clash 进程管理分子模块

pub mod process_manager;

#[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
pub mod service_manager;

pub use process_manager::{ClashProcessResult, StartClashProcess, StopClashProcess};

#[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
pub use service_manager::ServiceManager;

pub fn init_listeners() {
    log::info!("初始化 Clash 进程管理监听器");
    process_manager::init_dart_signal_listeners();

    #[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
    service_manager::init_dart_signal_listeners();
}

pub fn cleanup() {
    log::info!("清理 Clash 进程资源");
    process_manager::cleanup();
}
