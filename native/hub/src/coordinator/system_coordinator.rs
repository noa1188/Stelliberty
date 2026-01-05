// 系统协调器：编排所有系统相关操作

use crate::atoms::{network_interfaces, system_proxy};
use crate::molecules::system_operations;

pub struct SystemCoordinator;

impl Default for SystemCoordinator {
    fn default() -> Self {
        Self
    }
}

impl SystemCoordinator {
    pub fn new() -> Self {
        Self
    }
}

// 初始化系统协调器
pub fn init() {
    log::info!("初始化系统协调器");

    // 初始化原子层监听器
    system_proxy::init();
    network_interfaces::init();

    // 初始化分子层监听器
    system_operations::init_listeners();
}
