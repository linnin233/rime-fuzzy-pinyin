#!/usr/bin/env python3
"""将 pinyin_data.py 的 WORD_DICT 转换为 Rime Lua 可用的词典格式"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pinyin_data import WORD_DICT

# 统计每个拼音对应的字符频率，用于减少 lua 词典体积
# 格式: {拼音 = {词1, 词2, ...}}

lines = ["-- 自动生成的模糊纠错词典, 来自 pinyin_data.py", "return {"]
for py, words in sorted(WORD_DICT.items(), key=lambda x: len(x[0])):
    words_str = ", ".join(f'"{w}"' for w in words[:3])
    lines.append(f'  ["{py}"] = {{ {words_str} }},')
lines.append("}")

output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fuzzy_dict.lua")
with open(output_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"Generated {output_path} with {len(WORD_DICT)} entries")
