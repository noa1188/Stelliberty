// 网络接口原子模块

pub mod detector;

// 导出公共接口
pub use detector::{
    GetNetworkInterfaces, NetworkInterfacesInfo, get_hostname, get_network_addresses,
};

// 导出初始化函数（统一命名）
pub use detector::init_dart_signal_listeners as init;
