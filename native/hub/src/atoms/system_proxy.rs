// 系统代理原子模块

pub mod manager;

// 导出公共接口
pub use manager::{disable_proxy, enable_proxy, get_proxy_info};

// 导出初始化函数（统一命名）
pub use manager::init_dart_signal_listeners as init;
