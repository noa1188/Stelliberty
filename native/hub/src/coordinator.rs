// L2 协调层模块入口

pub mod clash_coordinator;
pub mod system_coordinator;

pub use clash_coordinator::ClashCoordinator;
pub use system_coordinator::SystemCoordinator;

pub fn init_all() {
    log::info!("初始化协调层");
    clash_coordinator::init();
    system_coordinator::init();
}

pub fn cleanup() {
    log::info!("清理协调层资源");
    clash_coordinator::cleanup();
}
