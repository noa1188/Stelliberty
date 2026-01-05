// 订阅管理分子模块

pub mod downloader;
pub mod parser;

pub use downloader::{
    DownloadSubscriptionRequest, DownloadSubscriptionResponse, ProxyMode, SubscriptionInfoData,
};
pub use parser::ProxyParser;

pub fn init_listeners() {
    log::info!("初始化订阅管理监听器");
    downloader::init_dart_signal_listeners();
}
