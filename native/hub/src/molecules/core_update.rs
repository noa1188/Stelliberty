// 核心更新分子模块

pub mod updater;

pub use updater::{
    DownloadCoreProgress, DownloadCoreRequest, DownloadCoreResponse, GetLatestCoreVersionRequest,
    GetLatestCoreVersionResponse, ReplaceCoreRequest, ReplaceCoreResponse,
};

pub fn init_listeners() {
    log::info!("初始化核心更新监听器");
    updater::init_dart_signal_listeners();
}
