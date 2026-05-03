# Rime 乱序拼音自动纠错

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Rime 输入法插件，自动识别并纠错双手打字时产生的乱序拼音输入。

**比如**: 输入 `wxoianig` → 候选词出现 **我想你** (woxiangni)

## 效果

| 手滑输入 | 纠错为 | 候选词 |
|----------|--------|--------|
| `wxoianig` | woxiangni | 我想你 |
| `niaoh` | nihao | 你好 |
| `jinaitn` | jintian | 今天 |
| `zognghu` | zhongguo | 中国 |
| `rugo` | ruguo | 如果 |
| `jnjii` | jingji | 经济 |

正常输入完全不受影响，只在检测到乱序时追加纠错候选词。

## 原理

三层评分组合匹配：

| 维度 | 算法 | 说明 |
|------|------|------|
| 字符多重集 | Sørensen-Dice | 容忍任意乱序 |
| 顺序保留度 | LCS (最长公共子序列) | 惩罚过度乱序 |
| 长度适配 | 指数衰减 | 偏好长度接近 |

当输入无法切分为合法拼音音节时触发匹配，在 254 条常用词库中搜索最佳匹配作为候选词。

## 安装

### 前置条件

- **Rime 输入法** (ibus-rime 或 fcitx5-rime)
- **雾凇拼音** (rime_ice) 已安装

```bash
git clone https://github.com/linnin233/rime-fuzzy-pinyin.git
cd rime-fuzzy-pinyin
bash install.sh
```

### 手动安装

```bash
# 1. 复制 Lua 文件到 Rime 配置目录
cp rime/fuzzy_corrector.lua ~/.config/ibus/rime/lua/
cp rime/fuzzy_dict.lua ~/.config/ibus/rime/lua/

# 2. 复制 Schema
cp rime/rime_ice_fuzzy.schema.yaml ~/.config/ibus/rime/

# 3. 注册新方案 (在 default.custom.yaml 中添加)
#    手动编辑或执行:
echo 'patch:
  schema_list:
    - schema: rime_ice
    - schema: rime_ice_fuzzy' > ~/.config/ibus/rime/default.custom.yaml

# 4. 重新部署
rime_deployer --build ~/.config/ibus/rime ~/.config/ibus/rime/build

# 5. 重启 Rime
ibus restart
```

### 启用

按 **Ctrl+\`** (反引号) 打开 Rime 方案选单，选择 **「雾凇拼音·乱序纠错」**。

## 文件结构

```
rime-fuzzy-pinyin/
├── rime/
│   ├── fuzzy_corrector.lua        # 核心匹配翻译器
│   ├── fuzzy_dict.lua             # 拼音→中文词典 (254 条)
│   └── rime_ice_fuzzy.schema.yaml # 基于雾凇拼音的修改版 Schema
├── python/
│   ├── matcher.py                 # Python 版模糊匹配引擎 (独立测试用)
│   ├── pinyin_data.py             # 拼音音节和词库数据
│   └── generate_lua_dict.py       # 词典生成器
└── install.sh                     # 一键安装脚本
```

## 配置

在 `rime_ice_fuzzy.schema.yaml` 底部可调整参数：

```yaml
fuzzy_corrector:
  min_score: 0.65        # 最低匹配分 (0~1)，越低越激进
  min_input_len: 4       # 最短触发长度
  max_candidates: 8      # 最多候选词数量
```

## 致谢

- 雾凇拼音 [rime-ice](https://github.com/iDvel/rime-ice)

## License

MIT
