// Clash 配置管理分子模块

pub mod generator;
pub mod injector;
pub mod runtime_params;

pub use generator::{GenerateRuntimeConfigRequest, GenerateRuntimeConfigResponse};
pub use injector::inject_runtime_params;
pub use runtime_params::RuntimeConfigParams;

pub fn init_listeners() {
    log::info!("初始化 Clash 配置管理监听器");
    generator::init_dart_signal_listeners();
}
