-- ============================================================
-- 乱序拼音模糊纠错翻译器 (Fuzzy Pinyin Translator)
--
-- 不修改输入！当输入为脏拼音时，在候选词中追加纠错结果。
-- 例如: 输入 "wxoianig" → 候选词中出现 "我想你 (woxiangni)"
-- ============================================================

local M = {}

-- 加载词典
local fuzzy_dict = require("fuzzy_dict")

-- ============================================================
-- 工具函数
-- ============================================================

local function char_counter(s)
    local cnt = {}
    for i = 1, #s do
        local c = s:sub(i, i)
        cnt[c] = (cnt[c] or 0) + 1
    end
    return cnt
end

local function char_dice(s1, s2)
    if s1 == "" and s2 == "" then return 1.0 end
    if s1 == "" or s2 == "" then return 0.0 end
    local c1 = char_counter(s1)
    local c2 = char_counter(s2)
    local overlap = 0
    for c, n1 in pairs(c1) do
        local n2 = c2[c] or 0
        overlap = overlap + (n1 < n2 and n1 or n2)
    end
    return 2.0 * overlap / (#s1 + #s2)
end

local function lcs_length(s1, s2)
    if s1 == "" or s2 == "" then return 0 end
    if #s1 < #s2 then s1, s2 = s2, s1 end
    local m, n = #s1, #s2
    local prev = {}
    local curr = {}
    for j = 0, n do prev[j] = 0 end
    for i = 1, m do
        curr[0] = 0
        for j = 1, n do
            if s1:sub(i, i) == s2:sub(j, j) then
                curr[j] = prev[j - 1] + 1
            else
                curr[j] = (prev[j] > curr[j - 1]) and prev[j] or curr[j - 1]
            end
        end
        prev, curr = curr, prev
    end
    return prev[n]
end

local function lcs_ratio(s1, s2)
    if s1 == "" and s2 == "" then return 1.0 end
    if s1 == "" or s2 == "" then return 0.0 end
    return 2.0 * lcs_length(s1, s2) / (#s1 + #s2)
end

local function length_bonus(len1, len2)
    local diff = len1 - len2
    if diff < 0 then diff = -diff end
    local max_len = len1 > len2 and len1 or len2
    if max_len == 0 then return 1.0 end
    local ratio = 1.0 - (diff / max_len) ^ 0.7
    return ratio > 0 and ratio or 0
end

local function fuzzy_score(s1, s2)
    local dice = char_dice(s1, s2)
    if dice < 0.28 then return 0 end
    local lcs = lcs_ratio(s1, s2)
    local len_bonus = length_bonus(#s1, #s2)
    return 0.50 * dice + 0.30 * lcs + 0.20 * len_bonus
end

-- ============================================================
-- 合法拼音音节集合
-- ============================================================

local valid_syllables = {
    ["a"]=1,["ai"]=1,["an"]=1,["ang"]=1,["ao"]=1,
    ["ba"]=1,["bai"]=1,["ban"]=1,["bang"]=1,["bao"]=1,["bei"]=1,["ben"]=1,["beng"]=1,["bi"]=1,["bian"]=1,
    ["biao"]=1,["bie"]=1,["bin"]=1,["bing"]=1,["bo"]=1,["bu"]=1,
    ["ca"]=1,["cai"]=1,["can"]=1,["cang"]=1,["cao"]=1,["ce"]=1,["cen"]=1,["ceng"]=1,["cha"]=1,["chai"]=1,
    ["chan"]=1,["chang"]=1,["chao"]=1,["che"]=1,["chen"]=1,["cheng"]=1,["chi"]=1,["chong"]=1,["chou"]=1,
    ["chu"]=1,["chuai"]=1,["chuan"]=1,["chuang"]=1,["chui"]=1,["chun"]=1,["chuo"]=1,["ci"]=1,["cong"]=1,
    ["cou"]=1,["cu"]=1,["cuan"]=1,["cui"]=1,["cun"]=1,["cuo"]=1,
    ["da"]=1,["dai"]=1,["dan"]=1,["dang"]=1,["dao"]=1,["de"]=1,["dei"]=1,["den"]=1,["deng"]=1,["di"]=1,
    ["dian"]=1,["diao"]=1,["die"]=1,["ding"]=1,["diu"]=1,["dong"]=1,["dou"]=1,["du"]=1,["duan"]=1,
    ["dui"]=1,["dun"]=1,["duo"]=1,
    ["e"]=1,["ei"]=1,["en"]=1,["eng"]=1,["er"]=1,
    ["fa"]=1,["fan"]=1,["fang"]=1,["fei"]=1,["fen"]=1,["feng"]=1,["fo"]=1,["fou"]=1,["fu"]=1,
    ["ga"]=1,["gai"]=1,["gan"]=1,["gang"]=1,["gao"]=1,["ge"]=1,["gei"]=1,["gen"]=1,["geng"]=1,["gong"]=1,
    ["gou"]=1,["gu"]=1,["gua"]=1,["guai"]=1,["guan"]=1,["guang"]=1,["gui"]=1,["gun"]=1,["guo"]=1,
    ["ha"]=1,["hai"]=1,["han"]=1,["hang"]=1,["hao"]=1,["he"]=1,["hei"]=1,["hen"]=1,["heng"]=1,["hong"]=1,
    ["hou"]=1,["hu"]=1,["hua"]=1,["huai"]=1,["huan"]=1,["huang"]=1,["hui"]=1,["hun"]=1,["huo"]=1,
    ["ji"]=1,["jia"]=1,["jian"]=1,["jiang"]=1,["jiao"]=1,["jie"]=1,["jin"]=1,["jing"]=1,["jiong"]=1,
    ["jiu"]=1,["ju"]=1,["juan"]=1,["jue"]=1,["jun"]=1,
    ["ka"]=1,["kai"]=1,["kan"]=1,["kang"]=1,["kao"]=1,["ke"]=1,["kei"]=1,["ken"]=1,["keng"]=1,["kong"]=1,
    ["kou"]=1,["ku"]=1,["kua"]=1,["kuai"]=1,["kuan"]=1,["kuang"]=1,["kui"]=1,["kun"]=1,["kuo"]=1,
    ["la"]=1,["lai"]=1,["lan"]=1,["lang"]=1,["lao"]=1,["le"]=1,["lei"]=1,["leng"]=1,["li"]=1,["lia"]=1,
    ["lian"]=1,["liang"]=1,["liao"]=1,["lie"]=1,["lin"]=1,["ling"]=1,["liu"]=1,["long"]=1,["lou"]=1,
    ["lu"]=1,["luan"]=1,["lun"]=1,["luo"]=1,["lv"]=1,["lve"]=1,
    ["ma"]=1,["mai"]=1,["man"]=1,["mang"]=1,["mao"]=1,["me"]=1,["mei"]=1,["men"]=1,["meng"]=1,["mi"]=1,
    ["mian"]=1,["miao"]=1,["mie"]=1,["min"]=1,["ming"]=1,["miu"]=1,["mo"]=1,["mou"]=1,["mu"]=1,
    ["na"]=1,["nai"]=1,["nan"]=1,["nang"]=1,["nao"]=1,["ne"]=1,["nei"]=1,["nen"]=1,["neng"]=1,["ni"]=1,
    ["nian"]=1,["niang"]=1,["niao"]=1,["nie"]=1,["nin"]=1,["ning"]=1,["niu"]=1,["nong"]=1,["nou"]=1,
    ["nu"]=1,["nuan"]=1,["nuo"]=1,["nv"]=1,["nve"]=1,
    ["o"]=1,["ou"]=1,
    ["pa"]=1,["pai"]=1,["pan"]=1,["pang"]=1,["pao"]=1,["pei"]=1,["pen"]=1,["peng"]=1,["pi"]=1,["pian"]=1,
    ["piao"]=1,["pie"]=1,["pin"]=1,["ping"]=1,["po"]=1,["pou"]=1,["pu"]=1,
    ["qi"]=1,["qia"]=1,["qian"]=1,["qiang"]=1,["qiao"]=1,["qie"]=1,["qin"]=1,["qing"]=1,["qiong"]=1,
    ["qiu"]=1,["qu"]=1,["quan"]=1,["que"]=1,["qun"]=1,
    ["ran"]=1,["rang"]=1,["rao"]=1,["re"]=1,["ren"]=1,["reng"]=1,["ri"]=1,["rong"]=1,["rou"]=1,["ru"]=1,
    ["ruan"]=1,["rui"]=1,["run"]=1,["ruo"]=1,
    ["sa"]=1,["sai"]=1,["san"]=1,["sang"]=1,["sao"]=1,["se"]=1,["sen"]=1,["seng"]=1,["sha"]=1,["shai"]=1,
    ["shan"]=1,["shang"]=1,["shao"]=1,["she"]=1,["shei"]=1,["shen"]=1,["sheng"]=1,["shi"]=1,["shou"]=1,
    ["shu"]=1,["shua"]=1,["shuai"]=1,["shuan"]=1,["shuang"]=1,["shui"]=1,["shun"]=1,["shuo"]=1,["si"]=1,
    ["song"]=1,["sou"]=1,["su"]=1,["suan"]=1,["sui"]=1,["sun"]=1,["suo"]=1,
    ["ta"]=1,["tai"]=1,["tan"]=1,["tang"]=1,["tao"]=1,["te"]=1,["teng"]=1,["ti"]=1,["tian"]=1,["tiao"]=1,
    ["tie"]=1,["ting"]=1,["tong"]=1,["tou"]=1,["tu"]=1,["tuan"]=1,["tui"]=1,["tun"]=1,["tuo"]=1,
    ["wa"]=1,["wai"]=1,["wan"]=1,["wang"]=1,["wei"]=1,["wen"]=1,["weng"]=1,["wo"]=1,["wu"]=1,
    ["xi"]=1,["xia"]=1,["xian"]=1,["xiang"]=1,["xiao"]=1,["xie"]=1,["xin"]=1,["xing"]=1,["xiong"]=1,
    ["xiu"]=1,["xu"]=1,["xuan"]=1,["xue"]=1,["xun"]=1,
    ["ya"]=1,["yan"]=1,["yang"]=1,["yao"]=1,["ye"]=1,["yi"]=1,["yin"]=1,["ying"]=1,["yo"]=1,["yong"]=1,
    ["you"]=1,["yu"]=1,["yuan"]=1,["yue"]=1,["yun"]=1,
    ["za"]=1,["zai"]=1,["zan"]=1,["zang"]=1,["zao"]=1,["ze"]=1,["zei"]=1,["zen"]=1,["zeng"]=1,["zha"]=1,
    ["zhai"]=1,["zhan"]=1,["zhang"]=1,["zhao"]=1,["zhe"]=1,["zhei"]=1,["zhen"]=1,["zheng"]=1,["zhi"]=1,
    ["zhong"]=1,["zhou"]=1,["zhu"]=1,["zhua"]=1,["zhuai"]=1,["zhuan"]=1,["zhuang"]=1,["zhui"]=1,
    ["zhun"]=1,["zhuo"]=1,["zi"]=1,["zong"]=1,["zou"]=1,["zu"]=1,["zuan"]=1,["zui"]=1,["zun"]=1,["zuo"]=1,
}

-- ============================================================
-- 检测输入是否全部分割为合法音节
-- ============================================================

local function is_clean_pinyin(s)
    if s == "" then return true end
    local n = #s
    if n > 30 then return false end

    local function dfs(start)
        if start > n then return true end
        for len = 1, 6 do
            if start + len - 1 > n then break end
            local seg = s:sub(start, start + len - 1)
            if valid_syllables[seg] then
                if dfs(start + len) then return true end
            end
        end
        return false
    end

    return dfs(1)
end

-- ============================================================
-- 翻译器主函数
-- ============================================================

local MIN_SCORE = 0.65    -- 最低模糊匹配分 (比 processor 低, 因为不替换输入)
local MIN_INPUT_LEN = 4   -- 最短触发长度
local MAX_CANDIDATES = 8  -- 最多产出候选词数

function M.init(env)
    local config = env.engine.schema.config
    local ns = env.name_space:gsub("^*", "")
    M.min_score = config:get_double(ns .. "/min_score") or MIN_SCORE
    M.min_input_len = config:get_int(ns .. "/min_input_len") or MIN_INPUT_LEN
    M.max_candidates = config:get_int(ns .. "/max_candidates") or MAX_CANDIDATES
end

function M.func(input, seg, env)
    local text = input:gsub(" ", "")  -- 去掉空格分隔符

    -- 只处理纯小写字母且足够长的输入
    if #text < M.min_input_len then return end
    if text:match("[^a-z]") then return end

    -- 已经是合法拼音，不干预
    if is_clean_pinyin(text) then return end

    -- 收集匹配
    local matches = {}
    for py, words in pairs(fuzzy_dict) do
        if math.abs(#text - #py) <= math.max(3, #text * 0.45) then
            local score = fuzzy_score(text, py)
            if score >= M.min_score then
                matches[#matches + 1] = {py = py, words = words, score = score}
            end
        end
    end

    -- 按分数排序，取前 N
    table.sort(matches, function(a, b) return a.score > b.score end)
    local count = 0
    for _, m in ipairs(matches) do
        if count >= M.max_candidates then break end
        for _, word in ipairs(m.words) do
            if count >= M.max_candidates then break end
            -- comment 显示纠正后的拼音，便于理解
            local cand = Candidate("fuzzy", seg.start, seg._end, word, " ~" .. m.py)
            cand.quality = m.score * 10000
            yield(cand)
            count = count + 1
        end
    end
end

return M
