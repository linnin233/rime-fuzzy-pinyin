#!/bin/bash
set -e

echo "=== Rime 乱序拼音自动纠错 安装脚本 ==="
echo ""

# 检测 Rime 配置目录
RIME_DIR=""
if [ -d "$HOME/.config/ibus/rime" ]; then
    RIME_DIR="$HOME/.config/ibus/rime"
elif [ -d "$HOME/.local/share/fcitx5/rime" ]; then
    RIME_DIR="$HOME/.local/share/fcitx5/rime"
else
    echo "未找到 Rime 配置目录，请确认已安装 ibus-rime 或 fcitx5-rime。"
    exit 1
fi

echo "Rime 配置目录: $RIME_DIR"

# 检查雾凇拼音是否存在
if [ ! -f "$RIME_DIR/rime_ice.schema.yaml" ]; then
    echo "警告: 未找到 rime_ice.schema.yaml (雾凇拼音)。"
    echo "本插件基于雾凇拼音，请先安装: https://github.com/iDvel/rime-ice"
    echo ""
fi

# 1. 复制 Lua 文件
echo "[1/4] 复制 Lua 文件..."
mkdir -p "$RIME_DIR/lua"
cp "$(dirname "$0")/rime/fuzzy_corrector.lua" "$RIME_DIR/lua/"
cp "$(dirname "$0")/rime/fuzzy_dict.lua" "$RIME_DIR/lua/"
echo "  ✓ fuzzy_corrector.lua → $RIME_DIR/lua/"
echo "  ✓ fuzzy_dict.lua → $RIME_DIR/lua/"

# 2. 复制 Schema
echo "[2/4] 复制 Schema..."
cp "$(dirname "$0")/rime/rime_ice_fuzzy.schema.yaml" "$RIME_DIR/"
echo "  ✓ rime_ice_fuzzy.schema.yaml → $RIME_DIR/"

# 3. 注册方案
echo "[3/4] 注册方案..."
DEFAULT_CUSTOM="$RIME_DIR/default.custom.yaml"
if [ -f "$DEFAULT_CUSTOM" ]; then
    if ! grep -q "rime_ice_fuzzy" "$DEFAULT_CUSTOM"; then
        # 备份并添加
        cp "$DEFAULT_CUSTOM" "$DEFAULT_CUSTOM.bak"
        python3 -c "
import yaml, sys
with open('$DEFAULT_CUSTOM') as f:
    data = yaml.safe_load(f) or {}
if 'patch' not in data:
    data['patch'] = {}
if 'schema_list' not in data['patch']:
    data['patch']['schema_list'] = []
schemas = [s['schema'] if isinstance(s, dict) else s for s in data['patch']['schema_list']]
if 'rime_ice_fuzzy' not in schemas:
    data['patch']['schema_list'].append({'schema': 'rime_ice_fuzzy'})
    with open('$DEFAULT_CUSTOM', 'w') as f:
        yaml.dump(data, f, allow_unicode=True, default_flow_style=False)
    print('  ✓ 已添加 rime_ice_fuzzy 到方案列表')
" 2>/dev/null || {
            echo "  ⚠ Python yaml 不可用，请手动在 $DEFAULT_CUSTOM 的 schema_list 中添加: rime_ice_fuzzy"
        }
    else
        echo "  ✓ rime_ice_fuzzy 已在方案列表中"
    fi
else
    cat > "$DEFAULT_CUSTOM" << 'EOF'
patch:
  schema_list:
    - schema: rime_ice_fuzzy
  "switcher/hotkeys":
    - "Control+grave"
EOF
    echo "  ✓ 创建 default.custom.yaml 并注册方案"
fi

# 4. 部署
echo "[4/4] 重新部署 Rime..."
rime_deployer --build "$RIME_DIR" "$RIME_DIR/build" 2>/dev/null
echo "  ✓ 部署完成"

# 重启
if pgrep -f ibus-daemon > /dev/null 2>&1; then
    ibus restart 2>/dev/null
    echo "  ✓ 已重启 IBus"
elif pgrep -f fcitx5 > /dev/null 2>&1; then
    fcitx5 -r 2>/dev/null
    echo "  ✓ 已重启 Fcitx5"
fi

echo ""
echo "=== 安装完成 ==="
echo "按 Ctrl+\` 打开方案选单，选择「雾凇拼音·乱序纠错」即可启用。"
echo ""
echo "测试: 输入 wxoianig 看看候选词里有没有「我想你」"
