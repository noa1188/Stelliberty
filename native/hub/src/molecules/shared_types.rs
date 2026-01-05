// 分子层共享类型定义
// 用于存放跨分子共享的类型契约，避免分子之间相互依赖

use rinf::SignalPiece;
use serde::{Deserialize, Serialize};

// 覆写格式
#[derive(Deserialize, Serialize, SignalPiece, Clone, Copy, Debug)]
pub enum OverrideFormat {
    Yaml = 0,
    Javascript = 1,
}

// 覆写配置
#[derive(Debug, Deserialize, Serialize, SignalPiece, Clone)]
pub struct OverrideConfig {
    pub id: String,
    pub name: String,
    pub format: OverrideFormat,
    pub content: String,
}
