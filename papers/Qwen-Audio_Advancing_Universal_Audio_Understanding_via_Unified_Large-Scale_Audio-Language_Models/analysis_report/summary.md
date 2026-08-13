# Qwen-Audio: Advancing Universal Audio Understanding via Unified Large-Scale Audio-Language Models

> arXiv ID: 2311.07919
> 作者: Yunfei Chu, Jin Xu, Xiaohuan Zhou, Qian Yang, Shiliang Zhang, Zhijie Yan, Chang Zhou, Jingren Zhou
> 机构: Alibaba Group
> 项目地址: https://github.com/QwenLM/Qwen-Audio

---

## 背景与动机

大语言模型（LLM）在通用人工智能方面取得了巨大进展，但缺乏感知非文本模态（如音频）的能力。语音作为重要模态，包含丰富的情感、语调、意图等信息，以及自然声音和音乐等多种类型。现有的音频-语言指令跟随模型存在以下局限：

1. **缺乏统一的预训练音频模型**：现有模型（如 SpeechNet、SpeechT5、Whisper、Pengi）仅能处理特定类型的音频（人声或自然声音），无法覆盖所有音频类型
2. **交互能力有限**：大多数工作仅支持有限范围的音频交互能力
3. **工具调用方式的局限**：AudioGPT、HuggingGPT 等通过调用外部工具的方式无法获取韵律、情感等关键信息

## 问题定义

如何构建一个统一的大规模音频-语言模型，能够同时处理多种音频类型（人类语音、自然声音、音乐、歌曲）和多种任务（30+），并解决多任务联合训练中因标注格式差异导致的一对多干扰问题。

## 核心创新

### 1. 统一多任务训练框架（Hierarchical Tags）
设计了一套层级化标签序列作为解码器的条件输入，包括：
- **Transcription Tag**：区分转录类任务 (`<|startoftranscripts|>`) 和分析类任务 (`<|startofanalysis|>`)
- **Audio Language Tag**：指示音频中的语言（8种语言，非语音用 `<|unknown|>`）
- **Task Tag**：5类任务标签 — transcribe、translate、caption、analysis、question-answer
- **Text Language Tag**：指定输出文本语言
- **Timestamps Tag**：是否预测时间戳
- **Output Instruction**：进一步指定子任务和输出格式

通过共享标签促进知识共享，通过特定标签避免干扰。

### 2. 词级时间戳预测任务（SRWT）
提出 Speech Recognition with Word-level Timestamps 任务：在转录过程中交错预测每个词的起止时间戳。该任务不仅提升了语音识别性能，还改善了超越语音信号的音频问答和 grounding 能力。

### 3. 单一编码器统一所有音频类型
使用单个 Whisper-large-v2 音频编码器处理所有类型的音频，无需针对不同音频类型切换模型。

## 方法论

### 模型架构
- **音频编码器**：基于 Whisper-large-v2（640M 参数），32层 Transformer + 2层卷积下采样，16kHz 采样率，80通道梅尔频谱图，加入步长为2的池化层（每帧对应约40ms音频）
- **大语言模型**：Qwen-7B（7.7B 参数），32层 Transformer 解码器，隐藏维度 4096
- **训练目标**：最大化下一个文本 token 概率 $P_\theta(x_t | x_{<t}, \text{Encoder}_\phi(a))$

### 训练过程（两阶段）

**第一阶段 — 多任务预训练（Qwen-Audio）**：
- 冻结 LLM，仅优化音频编码器
- 覆盖 30+ 任务、8种语言
- 数据涵盖：语音（ASR、翻译、情感识别等18类）、声音（字幕、分类、检测等5类）、音乐/歌曲（歌手识别、情感、乐器分类等9类）
- 学习率 5e-5，500k 步，batch size 120

**第二阶段 — 监督微调（Qwen-Audio-Chat）**：
- 冻结音频编码器，仅优化 LLM
- 使用 ChatML 格式，支持多轮对话和多音频输入
- 通过 "Audio id:" 标记不同音频
- 混合音频指令数据和纯文本指令数据，总计约 20k 条
- 学习率 1e-5，8k 步

## 实验结果

### 主要性能（无需任务特定微调）

| 任务 | 数据集 | Qwen-Audio | 前最佳 | 提升 |
|------|--------|-----------|--------|------|
| ASR (英文) | LibriSpeech test-clean/other | 2.0 / 4.2 WER | 2.1 / 4.9 | ✓ |
| ASR (中文) | Aishell1 test | **1.3 WER** (SOTA) | 1.9 | 大幅领先 |
| S2TT | CoVoST2 (7方向平均) | 显著优于基线 | - | 各方向均大幅领先 |
| AAC | Clotho | 0.288 SPIDEr | 0.271 | ✓ |
| ASC | CochlScene | **0.795** (SOTA) | 0.669 | +12.6% |
| AQA | ClothoAQA | **0.749** (SOTA) | 0.645 | +10.4% |
| VSC | VocalSound | **0.9289** (SOTA) | 0.6035 | +32.5% |
| MNA | NSynth Instrument | 0.7882 | 0.5007 | +28.8% |

### SRWT 消融实验
- 加入 SRWT 后 ASR 性能提升（Aishell1: 1.71→1.29 WER）
- 音频 QA 任务也获得提升（ClothoAQA binary: 0.7418→0.7491，MusicAVQA: 0.7027→0.7211）

## 结论与展望

Qwen-Audio 系列实现了通用音频理解能力，核心贡献在于：
1. 提出统一多任务框架解决标注格式差异问题
2. 发现 SRWT 任务对多种音频理解能力的正迁移效果
3. 无需任务特定微调即在多个基准上超越前人工作
4. Qwen-Audio-Chat 支持多轮对话和多音频输入的灵活交互
5. 模型完全开源

## 个人评价

**优势：**
- 统一性强：单一模型覆盖语音、声音、音乐三大类，30+任务，这在音频领域是一个重要突破
- 层级标签设计精巧，有效解决了多任务干扰问题，比简单的 dataset ID 方式更具扩展性
- SRWT 的发现有启发性：细粒度的时间对齐训练能泛化到语义级别的音频理解
- 实验全面扎实，12个数据集覆盖8类任务，4个 SOTA

**不足：**
- 两阶段训练策略（第一阶段冻结 LLM，第二阶段冻结编码器）可能不是最优的，端到端联合训练可能释放更多潜力
- 仅支持音频理解，不支持音频生成
- SFT 数据仅 20k 条，规模较小，Chat 版本的泛化能力可能有限
- 论文未讨论长音频处理能力（Whisper 限制30秒窗口）

**影响力：**
这篇工作奠定了音频大模型多任务统一训练的范式基础，后续的 Qwen2-Audio 在此基础上进一步发展。其层级标签框架和 SRWT 任务设计对音频多模态社区有重要参考价值。
