// 延迟测试分子模块

pub mod tester;

pub use tester::{
    BatchDelayTestComplete, BatchDelayTestRequest, DelayTestProgress, SingleDelayTestRequest,
    SingleDelayTestResult,
};

pub fn init_listeners() {
    log::info!("初始化延迟测试监听器");
    tester::init_dart_signal_listeners();
}
