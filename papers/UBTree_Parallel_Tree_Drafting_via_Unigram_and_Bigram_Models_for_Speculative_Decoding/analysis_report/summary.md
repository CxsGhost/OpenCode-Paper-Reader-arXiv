# UBTree 论文阅读报告

- **完整标题**：UBTree: Parallel Tree Drafting via Unigram and Bigram Models for Speculative Decoding
- **作者与机构**：Chumeng Liang 等；Inclusion AI、UIUC、Purdue University。
- **arXiv**：[2609.39972](https://arxiv.org/abs/2609.39972)；实际分析版本为 [v2](https://arxiv.org/abs/2609.39972v2)，修订于 2026-10-28，初稿发表于 2026-09-30。
- **阅读日期**：2026-11-20。依据 v2 的 LaTeX 正文、全部输入章节与附录；以下数值均为作者报告，本次未训练或复现实验。
- **来源校验**：[v2 源码包](https://arxiv.org/src/2609.39972v2)，430,811 字节，SHA-256：`a878663578c6be08a38bc9ee2d5af9cb8930730fac9a951491594fe79ae19ed3`。

## 1. 背景与动机

推测解码让小草稿模型一次提出多个未来 token，再由目标模型批量验证，以减少昂贵的目标模型调用。并行草稿模型进一步消除逐 token 提案的串行延迟，但各位置独立预测容易混合互不兼容的续写；目标分布熵较高时，单一路径也难覆盖所有合理选择。

树形草稿保留多条候选路径，可以提高覆盖率。但逐层自回归修正会增加延迟，而针对单路径训练的草稿模型也未必能给备选分支排好序。UBTree 的核心是：**把并行候选生成、相邻候选依赖评分和有限预算构树分开，并用更丰富的目标分布监督训练选择器。**（第 1–2 节；`src/inputs/intro.tex`、`prelim.tex`。）

## 2. 问题定义与评价目标

给定已验证前缀，用草稿模型生成深度为 $\gamma$ 的候选树，希望在控制提案与验证成本的同时，提高每轮输出 token 数 $\tau$。论文式 (1) 写为：

$$
L_{\mathrm{spec}}=\frac{T_{\mathrm{draft}}+T_{\mathrm{verify}}}{\tau},
\qquad \eta=\frac{L_{\mathrm{target}}}{L_{\mathrm{spec}}}.
$$

$T_{\mathrm{draft}}$ 包含提案及构树，$T_{\mathrm{verify}}$ 包含验证与提交，$L_{\mathrm{target}}$ 是纯自回归解码的每 token 延迟。$\tau$ 包含目标模型产生的额外 token；15 个未来位置加 anchor 的最大接受长度为 16。接受长度增加不必然意味着加速比提高。

“无损”来自验证流程：目标模型在每个真实路径前缀下采样，沿匹配子节点继续，首次不匹配的目标样本作为 bonus token 保留。它保证目标输出分布，而不要求不同执行方式在相同随机种子下逐字一致。（第 2 节、附录 A；`src/inputs/prelim.tex:6`、`appendix-tree.tex:107`。）

## 3. 核心创新与模型方法

流程为：**目标前缀特征 → unigram proposer 并行提候选 → bigram selector 并行评相邻边 → 逐层构树与全局剪枝 → 目标模型一次验证。**

**候选生成。** 使用 DFlash backbone，在每个未来位置输出独立分布 $q_i=\operatorname{softmax}(u_i)$ 和隐状态 $h_i$，各取 top-$K$ token。这里的 unigram 指给定上下文后的逐位置独立预测，不是脱离上下文的词频表。学术实验使用 15 个未来位置、推理 $K=64$。

**依赖评分。** 延用 DFlash 2 的低秩相邻评分形式，并改造 token 表示和深度校准，见式 (2)、(4)–(6)：

$$
\delta_i(a,b)=\bigl(P(h_i)\odot\phi(a)\bigr)^\top\psi(b),
\qquad s_i(a,b)=e^{\rho_i}u_i(b)+e^{\kappa_i}\delta_i(a,b).
$$

$a,b$ 是相邻位置候选，$P$ 将 $h_i$ 投影到低秩空间，$\odot$ 为逐元素乘法。$\phi,\psi$ 分别由冻结的目标 token embedding 经两套无偏置、带 SiLU 的 MLP 生成；推理前可预计算为查找表。$e^{\rho_i},e^{\kappa_i}$ 为按深度学习的正权重，初始均为 1，控制两类分数的相对权重及分布集中度。

所有 $K+(\gamma-1)K^2$ 条相邻候选边可一次并行评分，无需随树深度反复调用神经修正头。**并行的是各阶段内部的神经计算；proposer、selector 有先后依赖，构树仍逐层进行。** Bigram 只近似相邻 token 依赖，不能等价于完整路径条件建模。（第 3.1 节；`src/inputs/method.tex:15`。）

**有限预算构树。** 对每个前驱的后继候选归一化，累加路径 log 概率；每一深度在全部扩展中保留至多 $W=12$ 个节点，再从候选超树全局选出 $B=64$ 个非根节点。深度 bonus $\zeta=0$，同分时优先祖先以保持前缀闭合。这里 $W$ 是每层总宽度，$B$ 不含 anchor；有限宽度搜索并不保证从全部 $K^\gamma$ 路径找到全局最优树。同一 token 经不同父节点到达时仍是不同树节点。（附录 A、算法 1；`src/inputs/appendix-tree.tex`。）

## 4. 训练策略、数据与损失

### 4.1 两阶段训练

学术实验用 OpenPerfectBlend 的 prompt，让对应目标模型以 $T_{\mathrm{train}}=1$ 再生成响应，通过 SpecForge 训练。温度同时改变训练轨迹和 KL 教师分布；这里“高温”主要相对于贪心训练，默认并非 $T>1$。

| 阶段 | 训练对象与目标 | 披露配置 |
|---|---|---|
| proposer 训练 | DFlash proposer，用响应 token 的 CE 学候选分布 | block size 16，6 epochs；该阶段学习率未在本文列出 |
| proposer–selector 联合训练 | 联合更新 proposer 与 selector，组合分布的 forward KL + proposer 辅助 CE | 2 epochs；backbone 学习率 $2\times10^{-5}$，selector 为 $6\times10^{-4}$ |
| 共享目标部件 | 使用冻结的目标 embedding 与 LM head | 选择器两套 MLP 可训练，秩 256、MLP 隐层宽度 1024 |

训练候选支持集大小为 **256**，推理每位置候选数为 **64**，不要混用。对同一目标模型，在 $T_{\mathrm{infer}}=0$ 和 1 下复用同一个 $T_{\mathrm{train}}=1$ checkpoint。（第 4.1 节；附录 B.1；`src/inputs/exp.tex:218`、`appendix-setup.tex:6`。）

### 4.2 候选集内重归一化 KL

式 (7)–(8) 在 proposer 候选集 $\mathcal C_i$ 上定义：

$$
\widetilde p_i(v)=\frac{e^{z_i(v)/T_{\mathrm{train}}}}{\sum_{b\in\mathcal C_i}e^{z_i(b)/T_{\mathrm{train}}}},\qquad
\widetilde q_i(v)=\frac{e^{s_i(y^*_{i-1},v)}}{\sum_{b\in\mathcal C_i}e^{s_i(y^*_{i-1},b)}},
$$

$$
\mathcal L_i=\sum_{v\in\mathcal C_i}\widetilde p_i(v)\log\frac{\widetilde p_i(v)}{\widetilde q_i(v)}-0.1\log q_i(y_i^*\mid x_{\le t}).
$$

$z_i$ 是目标 logits，$y^*$ 为再生成训练轨迹，选择器以前一个轨迹 token $y^*_{i-1}$ 为条件。KL 让多个合理候选得到软监督，CE 维护 proposer 的候选分布。**该目标是轨迹条件下、截断候选集内的逐位置蒸馏；没有直接计算完整树的分布或优化整棵树的期望接受长度。** 候选集外概率质量在重归一化时被舍弃。（第 3.2 节；`src/inputs/method.tex:67`。）

### 4.3 生产配置与复现缺口

Ling 实验使用 250 万样本、150 亿 token、64K 上下文的 SFT 语料。Ling3-Flash 的 UBTree 从训练至第 3 epoch 的 DFlash checkpoint 出发，再联合训练 2 epochs；学习率同上。Qwen3.8-27B 从官方 DFlash 2 checkpoint 出发，将两种方法的 selector 分别微调 2 epochs，学习率 $3\times10^{-4}$，不能把此配方写成统一的“6+2”。第 4.2 节关于响应再生成的表述提及 Qwen3.8-27B，不宜自行假定所有 Ling 轨迹均由 Ling 自身生成。（`src/inputs/exp.tex:300`。）

本文未完整列出学术训练实际样本/token 数、训练 batch size、优化器与调度、训练算力/耗时及全部 backbone 细节。论文给出了可借鉴的训练设计，完整复现仍需发布实现和配置补齐。

## 5. 实验设置与主要结果

### 5.1 学术模型：解码延迟加速

使用单张 NVIDIA Hopper GPU、batch size 1、Transformers、BF16，并将 draft 后处理放入单个 CUDA Graph。七项任务为 GSM8K、MATH-500、AIME、HumanEval、MBPP、LiveCodeBench、MT-Bench；前述任务除 AIME 为 30、MT-Bench 为 80 个双轮对话外，各取固定 seed-0 的 128 样本。最多生成 2,048 token，每配置测一次；加速为每个 benchmark 的平均 AR TPOT / 平均推测 TPOT，再跨 benchmark 平均。

表 1 的 **thinking disabled** 结果如下，$\tau$ 包括目标产生的额外 token：

| 目标模型 | 推理温度 | DARTree 平均加速 | UBTree 平均加速 | DARTree $\tau$ | UBTree $\tau$ |
|---|---:|---:|---:|---:|---:|
| Qwen3-4B | 0 | 6.31× | 6.88× | 10.13 | 10.23 |
| Qwen3-4B | 1 | 5.29× | 6.00× | 8.57 | 9.01 |
| Qwen3-8B | 0 | 6.46× | 6.94× | 10.23 | 10.21 |
| Qwen3-8B | 1 | 5.17× | 5.84× | 8.37 | 8.70 |

UBTree 在 28 个模型–温度–任务组合中速度均超过 DARTree，平均加速比相对提升约 7.4%–13.4%；**接受长度并非每项都更高**。Qwen3-4B 开启 thinking 后，两个温度下平均加速分别为 6.10×、5.30×，对应 DDTree 为 4.87×、4.08×；该组未比较 DARTree，不能扩展“28 项”结论。

来源类别也需区分：表 1 的 Domino 带 $\dagger$，是转引其原论文；DDTree/DARTree 是 UBTree 作者基于相应 checkpoint 重评，均非本次本地实测。DARTree 还被限制最大草稿深度以对齐比较。（第 4.1 节、表 1、附录 B.2；`src/inputs/exp.tex:125`、`appendix-setup.tex:34`。）

### 5.2 并发、生产与长上下文

| 场景与来源 | 作者报告结果 | 指标边界 |
|---|---|---|
| SGLang，$T_{\mathrm{infer}}=1$、并发 32；表 2 | Qwen3-4B 为 6,560.4 token/s、相对 AR 1.98×；8B 为 5,851.4 token/s、2.11× | 聚合输出吞吐；各负载搜索不同树预算，不是上述单请求 TPOT |
| Ling3-Tiny / Ling3-Flash / Qwen3.8-27B；表 3 | 平均加速 3.04× / 3.27× / 4.78× | 21 个模型–任务比较中接受长度全胜，速度赢 19 个；Qwen3.8 的 GSM8K、HumanEval 速度略逊 DSpark |
| Ling3-Flash、LongBench-v2；附录 C.2 | 401 个请求，最长 260K prompt；整体 $\tau=6.300$，DSpark 为 4.676 | 接受长度提升约 34.7%，并非端到端延迟或任务准确率 |
| Ling3-Flash、SWE-bench；附录 C.2 | 30 案例的 1,482 个固定请求回放；整体 $\tau=5.450$，DSpark 为 4.277 | 接受长度提升约 27.4%，并非 issue 解决率提升 |

生产模型中 Ling3-Tiny 使用 TP=1，Ling3-Flash 与 Qwen3.8-27B 使用 TP=4；Ling 的总验证节点含 anchor 分别为 49、32。长上下文实验为并发 1、贪心、关闭 thinking，UBTree 用 31 个非根节点；SWE-bench 回放固定消息、工具调用和工具结果，每请求生成上限 256 token。（第 4.2–4.3 节、附录 B.3/C.2；`src/inputs/exp.tex:228`、`appendix-setup.tex:60`、`appendix-experiments.tex:30`。）

## 6. 消融证据与结论

表 4 在 Qwen3-4B、关闭 thinking 下给出的证据应分开阅读：

- **结构与轨迹温度**：贪心推理时，从 DFlash 2 selector + Tree 换成 UBTree selector，平均加速 5.95× → 6.57×、$\tau$ 8.82 → 9.86；再使用 $T_{\mathrm{train}}=1$，达到 6.88×、10.23。该结构消融同时改变 deep codebook 和深度校准，不能分别归因。
- **温度扫描**：测试 0.8、1.0、1.1、1.2，温度 1 的平均接受长度最好；温度并非越高越好。每个温度都重新生成轨迹、训练 proposer，并改变 KL 教师温度，因此该实验没有单独隔离软标签温度的影响。
- **损失比较**：固定架构与训练温度，贪心下 selector CE → KL 仅使速度 6.84× → 6.88×、$\tau$ 10.08 → 10.23；温度 1 推理为 5.99× → 6.00×、8.93 → 9.01。CE 会跳过标签落在支持集外的位置，KL 则监督全部有效位置，监督覆盖也不同。没有重复测量与误差条，不能据此宣称 KL 单独带来很大的速度收益。
- **辅助 CE**：去掉 proposer CE 后，贪心下 $\tau$ 10.23 → 10.14；温度 1 下仍为 9.01，速度甚至从 6.00× 到 6.01×。正文“两个温度均下降”的措辞应以表中数值为边界。

延迟剖析进一步说明加速来源：GSM8K、Qwen3-4B 贪心测试中，draft 后处理从 DARTree 的 3.36 ms/轮降至 1.38 ms/轮，验证时间约 20.9 ms，$\tau$ 为 12.50 → 12.58，TPOT 为 2.41 → 2.21 ms。作者将后处理中的投影、选候选、selector 与构树联合计时，因此不能把 58.8% 的缩减全部解释为某个独立算子更快。（表 4、附录 B.4/C.1；`src/inputs/exp.tex:320`、`appendix-setup.tex:74`、`appendix-experiments.tex:4`。）

作者结论是：面向树验证，应同时优化候选依赖评分与合理备选分支的训练监督。未来工作主要是按每轮不确定性、硬件和服务负载动态选择树预算。（第 6 节与附录 D；`src/inputs/conclusion.tex`、`appendix-related-work.tex:1`。）

## 7. 个人评价与实践启发

**最有价值的设计**是把候选覆盖、依赖评分和昂贵的目标验证预算分别处理：草稿神经计算保留并行，bigram 以较低成本减少不兼容组合，树验证再容纳多条合理续写。训练上的启发是让 proposer 维持候选能力，再用候选集内软监督改善组合排序；数据轨迹温度也应围绕最终验证机制选择。

**证据的强弱有区别。** 整套方案在多种模型和实现中有一致的速度优势，但接受长度、解码 TPOT、服务吞吐是三个不同指标，LongBench/SWE-bench 也没有在此证明任务能力提升。将思路迁移到其他模型时，可检验“软监督是否改善有限候选集内的分支排序”，不能先假定某个温度或 KL 会复现相同收益。

**部署限制明确。** 并发提高后计算余量变小，多分支验证的成本更突出。当前所谓 adaptive tree 是按模型和并发档位搜索并固定 $B/W$，并未逐轮根据分数动态决策，也不保证预算最优。再加上 bigram 的依赖近似、训练配置缺口及学术实验每配置仅测一次，应把论文结论理解为所测配置下的经验结果。

### 原文定位索引

- 架构、评分与训练公式：第 2–3 节，`src/inputs/prelim.tex`、`src/inputs/method.tex`；式 (1)–(8)。
- 学术/生产结果与消融：第 4 节、表 1–4，`src/inputs/exp.tex`。
- 构树与无损验证：附录 A、算法 1，`src/inputs/appendix-tree.tex`；训练/评测协议见附录 B，`src/inputs/appendix-setup.tex`。
- 延迟与长上下文：附录 C，`src/inputs/appendix-experiments.tex`；局限与后续工作见第 6 节、附录 D，`src/inputs/conclusion.tex`、`src/inputs/appendix-related-work.tex`。
