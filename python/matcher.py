"""
乱序拼音模糊匹配引擎 v0.2
Fuzzy disordered pinyin matching engine.

核心思路:
1. 字符多重集相似度 (Sørensen-Dice) — 容忍任意乱序
2. 最长公共子序列 (LCS) — 惩罚过度乱序
3. 长度适配 — 偏好长度接近的候选
4. 音节切分回退 — 超长输入先切分再逐音节匹配
"""

from collections import Counter
from pinyin_data import WORD_DICT, PY_SYLLABLES


def lcs_length(s1: str, s2: str) -> int:
    """计算最长公共子序列长度 (空间优化版)"""
    if not s1 or not s2:
        return 0
    if len(s1) < len(s2):
        s1, s2 = s2, s1
    m, n = len(s1), len(s2)
    prev = [0] * (n + 1)
    curr = [0] * (n + 1)
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if s1[i - 1] == s2[j - 1]:
                curr[j] = prev[j - 1] + 1
            else:
                curr[j] = max(prev[j], curr[j - 1])
        prev, curr = curr, prev
    return prev[n]


def char_dice(s1: str, s2: str) -> float:
    """
    字符多重集 Sørensen-Dice 系数。
    完全忽略顺序，仅比较字符组成。
    """
    if not s1 and not s2:
        return 1.0
    if not s1 or not s2:
        return 0.0
    c1 = Counter(s1)
    c2 = Counter(s2)
    overlap = sum(min(c1[ch], c2.get(ch, 0)) for ch in c1)
    return 2.0 * overlap / (len(s1) + len(s2))


def lcs_ratio(s1: str, s2: str) -> float:
    """基于 LCS 的顺序保留度。"""
    if not s1 and not s2:
        return 1.0
    if not s1 or not s2:
        return 0.0
    return 2.0 * lcs_length(s1, s2) / (len(s1) + len(s2))


def length_bonus(input_len: int, target_len: int) -> float:
    """
    长度适配因子：偏好长度接近的候选。
    差值 <= 1 → 1.0,  差值为 len/2 → ~0.5
    """
    diff = abs(input_len - target_len)
    max_len = max(input_len, target_len)
    if max_len == 0:
        return 1.0
    return max(0.0, 1.0 - (diff / max_len) ** 0.7)


def fuzzy_score(
    input_str: str,
    target_str: str,
    dice_w: float = 0.50,
    lcs_w: float = 0.30,
    len_w: float = 0.20,
) -> float:
    """
    综合模糊匹配评分。
    - dice_w: 字符多重集权重（高 → 更容忍乱序）
    - lcs_w: 顺序保留度权重
    - len_w: 长度适配权重
    
    值域 [0, 1]。
    """
    dice = char_dice(input_str, target_str)
    lcs = lcs_ratio(input_str, target_str)
    length = length_bonus(len(input_str), len(target_str))
    return dice_w * dice + lcs_w * lcs + len_w * length


# ---- 音节切分回退（处理词典未覆盖的输入）----

# 预计算音节长度范围
_SYLLABLE_MIN_LEN = min(len(s) for s in PY_SYLLABLES)
_SYLLABLE_MAX_LEN = max(len(s) for s in PY_SYLLABLES)


def segment_syllables(raw: str) -> list[list[str]]:
    """
    将输入串尝试切分为合法拼音音节序列（返回所有可能切分）。
    使用回溯 DFS。
    """
    results = []
    n = len(raw)

    def dfs(start: int, path: list[str]):
        if start >= n:
            results.append(path[:])
            return
        for end in range(start + _SYLLABLE_MIN_LEN, min(start + _SYLLABLE_MAX_LEN, n) + 1):
            seg = raw[start:end]
            if seg in PY_SYLLABLES:
                path.append(seg)
                dfs(end, path)
                path.pop()

    dfs(0, [])
    return results


def best_syllable_match(raw: str) -> tuple[str, list[str], float] | None:
    """
    对超长/未知输入，尝试切分为音节后用模糊匹配拟合每个音节。
    返回 (拼接拼音, 中文候选拼接, 平均分) 或 None。
    """
    segs_list = segment_syllables(raw)
    if not segs_list:
        return None

    best_result = None
    best_score = 0.0

    for segs in segs_list:
        total_score = 0.0
        words = []
        for seg in segs:
            # 在词典中查找该音节的字
            candidates = WORD_DICT.get(seg, [])
            if not candidates:
                # 拼音音节在字典里但无对应词, 跳过
                total_score = -1
                break
            words.append(candidates[0])  # 取最常用字
            total_score += 1.0  # 精确匹配音节, 分数 = 1

        if total_score < 0:
            continue

        avg_score = total_score / len(segs)
        combined_word = "".join(words)
        combined_py = "".join(segs)

        if avg_score > best_score:
            best_score = avg_score
            best_result = (combined_py, [combined_word], avg_score)

    return best_result


# ---- 主搜索 ----

def search(
    raw_input: str,
    top_k: int = 10,
    min_score: float = 0.35,
    enable_segmentation: bool = True,
) -> list[tuple[str, list[str], float]]:
    """
    在词典中搜索最佳匹配。
    
    参数:
        raw_input: 用户原始拼音串 (纯小写字母, 如 "wxoianig")
        top_k: 返回前 k 个
        min_score: 最低阈值
        enable_segmentation: 是否启用音节切分回退
    
    返回:
        [(pinyin_string, [中文候选], score), ...]  按分数降序
    """
    results: list[tuple[str, list[str], float]] = []
    in_len = len(raw_input)

    for py_key, words in WORD_DICT.items():
        # 快速过滤: 长度差过大
        if abs(in_len - len(py_key)) > max(3, in_len * 0.45):
            continue
        # 字符集快速过滤
        if char_dice(raw_input, py_key) < 0.28:
            continue

        score = fuzzy_score(raw_input, py_key)
        if score >= min_score:
            results.append((py_key, words, score))

    results.sort(key=lambda x: x[2], reverse=True)

    # 音节切分回退
    if enable_segmentation and in_len > 5:
        seg_result = best_syllable_match(raw_input)
        if seg_result:
            py_key, words, score = seg_result
            # 插入到合适位置
            inserted = False
            for i, (_, _, s) in enumerate(results):
                if score > s:
                    results.insert(i, seg_result)
                    inserted = True
                    break
            if not inserted and score >= min_score:
                results.append(seg_result)

    return results[:top_k]


# ---- 工具函数 ----

def print_results(results: list[tuple[str, list[str], float]], input_str: str):
    """格式化输出搜索结果。"""
    if not results:
        print("  (无匹配)")
        return
    for py_key, words, score in results:
        bar = "█" * int(score * 10) + "░" * (10 - int(score * 10))
        words_str = " / ".join(words[:5])  # 最多显示5个候选
        if len(words) > 5:
            words_str += f" ...(+{len(words)-5})"
        print(f"  [{bar}] {score:.3f}  {py_key:16s} → {words_str}")


def main():
    """命令行交云测试与演示。"""
    print("=" * 60)
    print("  乱序拼音模糊匹配引擎 v0.2")
    print("  支持: 字符乱序 │ 字符缺失/多余 │ 长串音节切分")
    print("=" * 60)

    test_cases = [
        ("wxoianig", "★★★ 乱序: 我想你 (woxiangni)"),
        ("zjian", "简写/缺字: 再见 (zaijian)"),
        ("jinaitn", "乱序: 今天 (jintian)"),
        ("niaoh", "乱序+缺字: 你好 (nihao)"),
        ("zognghu", "缺o: 中国 (zhongguo)"),
        ("shii", "多i: 是 (shi)"),
        ("ixnaginn", "重度乱序: 我想你 (woxiangni)"),
        ("wonjinnaitxnaigsiangkna", "极限乱序长串"),
    ]

    for inp, desc in test_cases:
        print(f"\n▶ [{desc}]")
        print(f"  输入: \"{inp}\"")
        results = search(inp)
        print_results(results, inp)

    print("\n" + "-" * 60)
    print("  交互模式 - 输入拼音测试 (q 退出)")
    while True:
        try:
            user_input = input("\n> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            break
        if user_input in ("q", "quit", "exit"):
            break
        if not user_input:
            continue
        if not all("a" <= c <= "z" for c in user_input):
            print("  请输入纯小写字母拼音。")
            continue
        results = search(user_input)
        print_results(results, user_input)


if __name__ == "__main__":
    main()
