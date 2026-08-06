# 音频多模态联合训练：数据与 DataLoader 设计参考

> 基于 JoyAI-Talker 论文的技术分析，供框架设计与开发参考

---

## 1. 数据格式设计

### 1.1 两种模态的数据流

系统中存在两条并行的输入路径，最终汇合于同一个 LLM：

```
语音路径: Raw Audio → Mel Spectrogram → Speech Encoder → Adapter(MLP) → [embeddings, dim=d]
文本路径: Raw Text  → Tokenizer → Embedding Table → [embeddings, dim=d]
                                                              ↓
                                    合并为统一的 embedding 序列 → LLM Transformer
```

**关键原则**：无论来源如何，到达 LLM 第一层时，所有 embedding 维度一致（dim=d），LLM 无需区分模态来源。

### 1.2 语音数据格式（Chat-style Q&A）

所有语音任务统一使用对话格式：

```json
{
  "type": "speech",
  "audio": "path/to/audio.wav",
  "messages": [
    {"role": "user", "content": "<audio_placeholder> 请转录这段语音"},
    {"role": "assistant", "content": "今天天气真好，我们去公园散步吧。"}
  ]
}
```

不同任务通过 prompt 区分：

| 任务 | User Prompt 示例 | Assistant Answer |
|------|-----------------|------------------|
| ASR | `<audio> 请转录这段语音` | 文本转录 |
| 语音翻译 | `<audio> 将这段英文翻译为中文` | 翻译文本 |
| 语音QA | `<audio> 说话人在讨论什么话题？` | 回答文本 |
| 音频描述 | `<audio> 描述这段音频的内容和说话人特征` | 描述文本 |
| 多轮对话 | `<audio> [多轮上下文]` | 回复文本 |
| 语音续写 | `<audio> [隐含续写指令]` | LLM 生成的连贯续写 |

### 1.3 文本数据格式（Raw Continuous Text）

文本数据以原始续写形式输入，**不使用 chat 格式**：

```json
{
  "type": "text",
  "content": "Large language models have revolutionized natural language processing..."
}
```

**设计理由**：
- Chat 格式适合学习"理解指令→生成回复"的能力
- Raw text 适合维持语言建模的基础认知能力（推理、知识、逻辑）
- 如果文本也用 chat 格式，模型会过拟合对话模式，损失通用语言建模能力

---

## 2. Sequence Packing 策略

### 2.1 为什么需要 Packing

训练序列长度固定（8K/64K），但单个样本长度差异极大：
- 一条 ASR 样本可能只有 200 tokens
- 一段长对话可能有 4000 tokens
- 不 packing → 大量 padding → GPU 利用率极低

### 2.2 音频感知的 Best-Fit Packing

```
目标序列长度: 8192 tokens

打包前的样本池:
  [语音样本A: 1500 tokens] [文本样本B: 3200 tokens] [语音样本C: 800 tokens]
  [文本样本D: 2600 tokens] [语音样本E: 1200 tokens] [文本样本F: 4800 tokens]

打包结果:
  seq_0: [语音A: 1500] [文本D: 2600] [语音C: 800]  padding: 3292  ← 不够优
  seq_0: [语音A: 1500] [文本B: 3200] [语音E: 1200] padding: 2292  ← 更优

音频感知优化: 考虑音频经 encoder 后实际产生的 token 数（12.5Hz × 时长），
            以及 encoder 内部的 padding 浪费（如对齐到 chunk 边界）
```

### 2.3 Block-Diagonal Attention Mask

打包后的多个样本必须互不可见：

```
seq: [样本A tokens][样本B tokens][样本C tokens]

Attention Mask:
     A    B    C
A  [ 1    0    0 ]
B  [ 0    1    0 ]
C  [ 0    0    1 ]

每个样本只能 attend 到自己，防止跨样本信息泄露。
```

---

## 3. DataLoader 架构设计

### 3.1 整体流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        DataLoader Pipeline                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐     ┌──────────────┐     ┌───────────────────┐   │
│  │ 数据采样  │ ──→ │  Tokenize &  │ ──→ │  Sequence Packing │   │
│  │ (按配比)  │     │  预处理      │     │  (best-fit)       │   │
│  └──────────┘     └──────────────┘     └───────────────────┘   │
│                                                 │               │
│                                                 ▼               │
│                                        ┌───────────────┐        │
│                                        │  Batch 构建    │        │
│                                        │  + 元数据标注  │        │
│                                        └───────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Batch 数据结构

```python
@dataclass
class MultiModalBatch:
    # 文本 token 序列（音频位置填充占位符 token，如 <audio_pad>）
    input_ids: Tensor          # [batch_size, seq_len]
    
    # 音频原始特征（该 batch 内所有音频段，gather 后的）
    audio_features: Tensor     # [num_audio_segments, max_audio_frames, mel_dim]
    audio_lengths: Tensor      # [num_audio_segments]  每段音频的实际帧数
    
    # 音频位置映射：每段音频在哪条序列的哪个位置
    audio_segment_map: List[Tuple[int, int, int]]  # [(batch_idx, start_pos, end_pos), ...]
    
    # 注意力掩码（block-diagonal）
    attention_mask: Tensor     # [batch_size, seq_len, seq_len] 或稀疏表示
    
    # Loss 掩码：只在 assistant response 位置为 1
    loss_mask: Tensor          # [batch_size, seq_len]
    
    # 标签
    labels: Tensor             # [batch_size, seq_len]  非 loss 位置为 -100
```

### 3.3 前向传播：Gather → 分路处理 → Scatter

```python
class MultiModalModel(nn.Module):
    def __init__(self):
        self.text_embedding = nn.Embedding(vocab_size, d_model)
        self.audio_encoder = AudioEncoder(...)       # 预训练的语音编码器
        self.audio_adapter = nn.Sequential(          # MLP 投影层
            nn.Linear(encoder_dim, d_model),
            nn.GELU(),
            nn.Linear(d_model, d_model),
        )
        self.llm = TransformerDecoder(...)           # LLM 主干
    
    def forward(self, batch: MultiModalBatch):
        B, L = batch.input_ids.shape
        
        # ====== Step 1: 文本路径（batched embedding lookup）======
        # 所有位置先过 embedding table（音频占位符位置的值后续会被覆盖）
        embeds = self.text_embedding(batch.input_ids)  # [B, L, d]
        
        # ====== Step 2: 音频路径（gather → batched encoder → scatter）======
        if batch.audio_features is not None:
            # Gather: 所有音频段已在 dataloader 中收集好
            # Batched encoder forward（一次性处理所有音频段）
            audio_embeds = self.audio_encoder(
                batch.audio_features,       # [N_segments, T, mel_dim]
                batch.audio_lengths
            )  # [N_segments, T', encoder_dim]
            
            # Batched adapter forward
            audio_embeds = self.audio_adapter(audio_embeds)  # [N_segments, T', d]
            
            # Scatter: 回填到对应位置
            for i, (b_idx, start, end) in enumerate(batch.audio_segment_map):
                seg_len = end - start
                embeds[b_idx, start:end] = audio_embeds[i, :seg_len]
        
        # ====== Step 3: 统一 LLM forward ======
        logits = self.llm(embeds, attention_mask=batch.attention_mask)
        
        # ====== Step 4: Loss 计算（仅 assistant response 位置）======
        loss = cross_entropy(logits, batch.labels, reduction='none')
        loss = (loss * batch.loss_mask).sum() / batch.loss_mask.sum()
        
        return loss
```

### 3.4 Scatter 的高效实现

实际工程中不会用 Python for 循环做 scatter，而是用向量化操作：

```python
# 高效 scatter 实现（替代 for 循环）
def scatter_audio_embeddings(embeds, audio_embeds, position_indices):
    """
    embeds:          [B, L, d]  — 完整 embedding tensor
    audio_embeds:    [N_segments, max_T', d]  — encoder 输出
    position_indices: [total_audio_tokens] — 展平后的目标位置索引
    
    使用 index_copy_ 或 scatter_ 进行向量化回填
    """
    # 将 embeds 展平为 [B*L, d]
    flat_embeds = embeds.view(-1, embeds.size(-1))
    # 将 audio_embeds 展平为 [total_audio_tokens, d]（去除 padding）
    flat_audio = pack_audio_tokens(audio_embeds, audio_lengths)
    # 向量化写入
    flat_embeds.index_copy_(0, position_indices, flat_audio)
    return flat_embeds.view_as(embeds)
```

---

## 4. 数据采样与配比

### 4.1 配比控制

```python
class ModalitySampler:
    """
    控制语音/文本数据的全局采样比例。
    不是 batch 级别的硬性约束，而是全局统计上的目标比例。
    """
    def __init__(self, speech_ratio=0.3, text_ratio=0.7):
        self.speech_ratio = speech_ratio
        self.text_ratio = text_ratio
    
    def sample(self, speech_pool, text_pool, num_samples):
        n_speech = int(num_samples * self.speech_ratio)
        n_text = num_samples - n_speech
        samples = random.sample(speech_pool, n_speech) + \
                  random.sample(text_pool, n_text)
        random.shuffle(samples)
        return samples
```

**注意**：经过 packing 后，单个 batch 内的实际比例可能波动，但在大量 step 的统计均值上接近目标比例。不需要严格保证每个 batch 都精确达标。

### 4.2 各阶段数据配比建议

| 训练阶段 | 文本比例 | 语音比例 | 语音任务构成 |
|---------|---------|---------|------------|
| Mid-training Step1 | ~70% | ~30% | ASR 为主，少量 QA/翻译 |
| Mid-training Step2 | ~60% | ~40% | 多任务均衡 |
| Context Extension | ~50% | ~50% | 上采样长对话和拼接多轮 |
| SFT | ~40% | ~60% | 上采样合成 S2T 数据 |
| DPO | 按 prompt 池比例 | 按 prompt 池比例 | Speech-only 偏好对 |

---

## 5. 损失掩码 (Loss Mask) 设计

### 5.1 掩码规则

```
序列示例:
[BOS] [system prompt] [user: <audio_tokens> 请转录] [assistant: 今天天气真好] [EOS]
  ↓       ↓                    ↓                          ↓                ↓
mask=0  mask=0              mask=0                      mask=1           mask=1

计算 loss 的位置: 仅 assistant response tokens
不计算 loss 的位置: 
  - 所有 user 输入（包括文本 prompt 和音频 embedding 位置）
  - system prompt
  - 工具调用结果 / API 响应
  - 特殊 token (BOS/EOS/分隔符)
  - packing padding
```

### 5.2 对文本数据的特殊处理

Raw continuous text 没有 user/assistant 角色区分，采用标准因果语言建模：

```
序列: [BOS] The quick brown fox jumps over the lazy dog [EOS]
mask:   0     1     1     1    1    1     1    1   1   1    1

除 BOS 外全部计算 loss（标准 next-token prediction）
```

---

## 6. 训练阶段的参数冻结控制

### 6.1 冻结策略实现

```python
def configure_trainable_params(model, stage: str):
    """根据训练阶段设置可训练参数"""
    
    if stage == "mid_training_step1":
        # 仅训练 adapter
        model.audio_encoder.requires_grad_(False)
        model.llm.requires_grad_(False)
        model.text_embedding.requires_grad_(False)
        model.audio_adapter.requires_grad_(True)   # 唯一可训练模块
        
    elif stage == "mid_training_step2":
        # 全部解冻
        model.requires_grad_(True)
        
    elif stage in ("context_extension", "sft", "dpo"):
        # 全部解冻
        model.requires_grad_(True)
```

### 6.2 Step 1 中文本数据的处理

在 Step 1（仅训练 adapter）阶段，LLM 和 Encoder 都冻结：
- 文本数据经过 LLM 但不产生有效梯度（LLM frozen）
- 此时文本数据**可以不参与训练**，或仅用于监控 loss 变化（验证认知能力未漂移）
- 语音数据的梯度只流向 adapter 参数

Step 2 开始后，文本数据才真正发挥"锚定 LLM 认知"的作用。

---

## 7. 分布式训练中的音频编码器处理

### 7.1 Context Parallelism 下的 Encoder 分布

当使用 Context Parallelism（CP）处理 64K 长序列时：

```
64K 序列按 CP ranks 切分:
rank_0: [0 ~ 16K tokens]     → 本地音频切片 → local encoder forward
rank_1: [16K ~ 32K tokens]   → 本地音频切片 → local encoder forward  
rank_2: [32K ~ 48K tokens]   → 本地音频切片 → local encoder forward
rank_3: [48K ~ 64K tokens]   → 本地音频切片 → local encoder forward
                                      ↓
                        differentiable all-gather 重建完整 embedding
                        （保留梯度流，支持 encoder 反向传播）
```

**优点**：
- 每个 rank 只处理局部音频，编码成本按 CP 度线性降低
- 避免 encoder 成为长序列训练的瓶颈
- all-gather 可微分，encoder 仍能正常接收梯度

---

## 8. 工程实现建议清单

| 模块 | 关键设计点 |
|------|-----------|
| **DataLoader** | 混合采样 → tokenize → packing → batch 构建 + 元数据 |
| **Packing** | Best-fit 算法，同时考虑 token 长度和音频 padding 浪费 |
| **Attention Mask** | Block-diagonal，packed 样本间互不可见 |
| **Embedding 层** | 先全部过 text embedding，再 scatter 覆盖音频位置 |
| **Encoder** | Batch 处理所有音频段，支持 CP 分片 |
| **Scatter** | 向量化实现（index_copy_），避免 Python for 循环 |
| **Loss Mask** | 仅 assistant response 计算 loss；文本数据走标准 CLM |
| **冻结控制** | Step1 仅 adapter → Step2+ 全参数 |
| **配比** | 全局统计配比，不要求单 batch 精确 |
| **Packing 效率** | 目标：相比无 packing 提升 2× 吞吐 |

---

## 9. 参考代码结构

```
multimodal_trainer/
├── data/
│   ├── datasets/
│   │   ├── speech_dataset.py      # 语音数据加载（返回 audio + messages）
│   │   └── text_dataset.py        # 文本数据加载（返回 raw text）
│   ├── sampler.py                 # 多模态配比采样器
│   ├── packing.py                 # Best-fit packing + block-diagonal mask 生成
│   └── collator.py                # Collate → MultiModalBatch 构建
├── models/
│   ├── audio_encoder.py           # 语音编码器（预训练初始化）
│   ├── adapter.py                 # MLP 投影层
│   ├── multimodal_embedding.py    # 统一 embedding 层（text lookup + audio scatter）
│   └── model.py                   # 完整模型（encoder + adapter + LLM）
├── training/
│   ├── trainer.py                 # 训练循环
│   ├── freeze_strategy.py         # 各阶段冻结策略
│   └── loss.py                    # Masked cross-entropy loss
└── configs/
    ├── mid_training_step1.yaml
    ├── mid_training_step2.yaml
    ├── context_extension.yaml
    ├── sft.yaml
    └── dpo.yaml
```
