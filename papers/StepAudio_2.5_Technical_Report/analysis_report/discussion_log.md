# 讨论记录

## 讨论记录 - 2026-08-27

### 14:00

**用户问：** 请总结StepAudio 2.5 Technical Report论文中有关语音多模态预训练相关的详细内容，到一个文档。用户在做全双工多模态模型的预训练模态对齐项目，是小白，需要包含数据、训练等相关细节。

**回答：**
已生成完整文档 `speech_multimodal_pretraining_guide.md`，包含九个章节：
1. 整体架构（Audio-Encoder → Adaptor → LLM-Decoder）
2. 数据引擎（自动化数据生产流水线）
3. 预训练分阶段策略（核心重点：对齐→Warmup→主训练→Cooldown）
4. 音频编码器与 Adaptor 细节
5. 下游特化训练（ASR/TTS/Realtime 各自的 SFT 和 RLHF）
6. Speech Tokens 与词汇表扩展
7. 训练超参数与工程细节汇总
8. 关键设计决策总结与实践建议
9. 参考模型与开源资源

每章都附有"对你项目的启示"小节，将论文中的设计选择翻译为可操作的建议。

### 14:15

**用户问：** 他的训练解冻策略是什么样子的，先单独adapter然后呢？全解冻encoder和adapter？解冻llm吗？Encoder从始至终不训，只让llm去单方面适配encoder，那不会把llm训烂丧失语言能力吗？audio和text的数据配比是咋做的？

**回答：**
1. Audio Encoder 全程冻结，从未解冻。解冻顺序为：仅Adaptor → 全部解冻LLM+Adaptor（分层学习率）→ 统一学习率训练。
2. LLM不会训烂，靠七层防护机制：Adaptor缓冲、文本:语音=1:1配比、MoE Router小学习率、分层学习率、MoE辅助损失退火、高质量Cooldown、动态复习调度。
3. 核心数据配比为 800B文本 + 800B语音 = 1:1。
4. 如果用Dense模型（非MoE），建议文本占比提高到60-70%，或用LoRA先做初步适配。

已将完整的解冻策略表和防退化机制分析补充到文档的"三（补充）"章节中。

## 讨论记录 - 2026-09-15

### 10:30

**用户问：** 我目前仅使用文本预训练数据和ASR数据，没有TTS数据，做模态对齐的话，最后训出来的Thinker，能给后面的Talker用吗？因为模型只学会了理解输入audio token，但是输出依然是text token。TTS数据也没法训似乎？因为输出音频token，是怎么输出呢？（参照Ling-Live模型方案设计文档提问）

**回答：**

用户的困惑源于把两种不同的架构范式混淆了——StepAudio 2.5 让 LLM 直接输出 speech tokens（需要扩展词汇表+TTS数据），而 Ling-Live 方案是**双通路设计**，Backbone 永远只输出文本 token + 控制 token，音频生成由独立的 Talker 模块负责。

**核心结论：**

1. **只用文本+ASR训出的Thinker，完全可以给Talker用。** Ling-Live方案中0-in（输入对齐）和0-out（输出对齐）是并行的、互不依赖的。Talker依赖的不是Backbone"会输出音频token"的能力，而是Backbone的**hidden state质量**。一个在文本+ASR上训好的Backbone，其hidden state已经包含丰富语义信息（意思、情绪、语气、上下文），这正是Talker需要的输入。

2. **Backbone只输出text token——这不是问题，是设计意图。** 方案文档1.2.3节明确写道："Backbone只生成控制token和文本token，不直接生成多码本音频token。音频token由独立Talker和MTP分支产生。" 这与StepAudio 2.5/Qwen3-Omni"一个LLM既输出文本又输出语音token"的范式不同，更像MiniCPM-o/VITA的路线：大模型负责"想"，小模型负责"说"。

3. **TTS数据的训练方式：** 在Ling-Live架构中，TTS训练不涉及Backbone输出音频token。它训的是Talker支路——Backbone（冻结）提供hidden state hᵢ → Projector映射到Talker隐空间 → Talker自回归生成主码本token（25Hz） → MTP补齐残差码本。监督信号来自目标音频经离线codec tokenizer产生的codec token序列。简言之：**Backbone提供"说什么"，Talker学习"怎么说"。**

**信息流对比：**

```
Ling-Live方案：
  Encoder → Adapter → Backbone → text token (给用户)
                              └→ hidden state → Projector → Talker → codec tokens → 波形

StepAudio 2.5方案：
  Encoder → Adaptor → LLM → text token / speech token（统一输出空间）
```

**与训练阶段的对应：**
- Stage 0-in + 1-a（Thinker训练）：文本+ASR数据，训练Backbone理解音频、生成文本和高质量hidden state → 完全正确的路线
- Stage 0-out + 1-b（Talker训练）：TTS数据，训练Projector+Talker+MTP将hidden state转为codec tokens → 等codec tokenizer ready后独立进行，与Thinker训练并行

### 11:00

**用户问：** 模态对齐之后的大规模联合预训练（Stage 1-a），Backbone 是否要全部解冻？包括 embedding 和 lm_head？学习率怎么设？

**回答：**

Stage 1-a 要解冻 Backbone（包括 lm_head），但学习率策略与 StepAudio 2.5 不同。StepAudio 给 embedding/lm_head 用大学习率是因为它扩展了词汇表、新增了 speech tokens 需要快速学习。而 Ling-Live 方案中 Backbone 的 embedding 和 lm_head 职责没有变化——embedding 还是编码文本 token，lm_head 还是预测文本 token，不存在新增 token 的情况。

因此学习率策略更简单：Adapter 稍大（因为解冻 Backbone 后隐空间会漂移，Adapter 需要跟着调整）+ Backbone 整体（含 embedding、lm_head）统一标准学习率 + MoE Router 较小（保护专家分工）。

### 11:10

**用户问：** 除了 ASR 数据，Stage 1-a 加入 S2TT、副语言理解和 Audio Caption 数据有帮助吗？

**回答：**

有帮助，各自作用不同：
- **ASR**：基础转录能力
- **S2TT（语音翻译）**：迫使模型理解语义而非表面音素映射，跨语言监督让 hidden state 语义表征更深
- **副语言理解**：让 hidden state 编码情绪、语气、犹豫等信息——这些最终通过 Projector 传给 Talker，决定了 Talker 生成语音的表现力上限
- **Audio Caption**：最高层次语义抽象，倒逼 hidden state 捕获场景级信息

尤其副语言数据对 Ling-Live 方案特别关键。因为 `uᵢ = LayerNorm(Projector(hᵢ) + TextEmbeddingTalker(yᵢ))` 中，hᵢ 的信息丰富度直接决定 Talker 的表现力上限。如果 hᵢ 只有"说了哪些字"的信息，Talker 能合成语音但缺乏情感表达。

配比建议：ASR 作为主任务保持大头，其他作为辅助任务混入。方案数据表的量级比例（ASR 92B >> S2TT 14B > 副语言 12B > Caption 5B）已合理。

### 11:20

**用户问：** StepAudio 直接把 codebook 训到 LLM 里，我们单独拉了一个 Talker 预测 codebook，从端到端角度是不是他们速度更快？

**回答：**

不一定，分析下来 Ling-Live 方案在延迟上可能更优。

StepAudio 2.5 的大 LLM 要在同一个自回归循环里生成 text token 和 speech token，200ms 语音约需 40 个 codec token，每步都经过全量参数 forward pass，形成串行瓶颈。

Ling-Live 方案中，生成 codec token 的是 0.5B 小模型（单步更快），且 Backbone 和 Talker 可以**流水线并行**——Backbone 生成文本的同时 Talker 在用之前的 hidden state 生成音频。方案 1.2.5 的时间分解：Backbone 20-60ms + Talker 20-40ms + Codec Decoder 10-30ms = 60-150ms，卡在 200ms 周期内。

StepAudio 的真正优势在于**简单性**（一个模型、一套训练），不在速度。Ling-Live 换来的是更低延迟和更灵活部署（可异构），代价是训练流程更复杂。

### 11:30

**用户问：** 后台的 Agent 大模型和谁交互？Thinker 控制它吗？如何控制？结果怎么回收？会不会造成延迟？

**回答：**

Backbone（Thinker）通过纯 text token 控制后台，全程不涉及音频 token。

**下发任务**：Backbone 生成 `</delegate>` 控制 token + JSON 文本（任务描述、上下文摘要等）。后台只接收模型无关的文本契约，不依赖 hidden state 或 KV cache。

**结果回收**：后台通过 Event Bus 返回文本事件（started/progress/ready/error），注入到后续 micro-turn 的 Session State 中。Backbone 在下一个 200ms turn 看到事件后决定何时织回回答。

**不会阻塞**：200ms micro-turn 时钟永不停转。后台未返回时，Backbone 每 200ms 仍然执行决策——可能输出 `</silence>` 或 `</backchannel>`（如"我帮你查一下"）。等后台 `ready` 事件到达后，Backbone 生成 `</result>` + 文本内容，hidden state 传给 Talker 发声。这些交互行为在 Stage 3 的委派 episode 数据中训练习得。

### 11:40

**用户问：** Backbone 是以 200ms 为单位给 Talker hidden state 吗？给多长？

**回答：**

不是固定长度，是按 text token 粒度给的。每个 200ms turn，Backbone 生成 0-4 个 text token，每个 token 对应一个 hidden state hᵢ。Backbone（文本轴）和 Talker（声学轴，固定 25Hz）运行在两个不同的时间轴上。

对齐方式采用 TAIL 式 cross-attention，而非固定比例硬交错，以适应中英文与不同语速下每 token 发音时长的变化。Backbone 通过 lookahead 缓冲区（领先 Talker 约 1-2s）与 Talker 解耦：Backbone 持续产出 hidden state 流，Talker 按 25Hz 匀速消费。缓冲区满时 Backbone 暂停文本生成（backpressure），缓冲区快空时优先补文本。

### 11:50

**用户问：** Talker 承担的任务很重吧？接收的信息太杂，模型才 0.5B，怎么处理这些复杂信息？

**回答：**

Talker 的任务其实不重——它**不需要理解任何信息，只负责发声**。所有"听、想、判断时机、生成内容、控制后台"的智能都在 Backbone 侧。Talker 收到的 uᵢ 中，yᵢ 告诉它念哪个字，Projector(hᵢ) 告诉它怎么念（语气、情绪、节奏已被 Backbone 压缩好）。对话历史、后台事件、用户意图等复杂信息 Talker 都看不到，全被 Backbone 消化后只传递最终的"发声指令"。

0.5B 做条件语音生成是业界验证过的规模（MiniCPM-o 0.5B Streaming TTS、CosyVoice 2 ~0.3B LLM-based TTS 等）。语音合成不需要大模型，难的是"决定说什么"而非"怎么发声"。真正要关注的是 Projector 的信息压缩质量——能否把 hᵢ 里的韵律、情感信息忠实传递给 Talker。

**核心结论**：Backbone 是大脑，Talker 是声带。Backbone 输出 `</response>` 或 `</backchannel>` 时 Talker 才工作，输出 `</silence>` 时 Talker 空转不发声。所有交互智能都在 Backbone 一侧。
