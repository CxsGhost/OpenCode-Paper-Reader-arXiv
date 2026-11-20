## 讨论记录 - 2026-11-20

### 16:13

**用户问：** 帮我读这篇论文：WSM: Decay-Free Learning Rate Schedule via Checkpoint Merging for LLM Pre-training

**回答：**

已阅读 [arXiv:2507.17634v2](https://arxiv.org/abs/2507.17634v2) 的全部 LaTeX 正文章节与附录，并检查了关键图。完整分析保存在 [summary.md](summary.md)。以下实验均为作者报告，未独立复现。

这篇论文的核心是：训练主线在 warmup 后保持恒定学习率，用近期 checkpoint 的参数合并产生具有退火效果的评测/交付模型。WSM 即 Warmup-Stable and Merge。

**1. 它具体改变了什么？**

WSD 在恒定学习率阶段之后，再用一段训练逐渐降低学习率；WSM 则持续使用恒定学习率，定期保存同一训练轨迹的 checkpoint，取最近若干个做均值或加权平均。合并模型用于评测与交付，主线继续按原权重和优化器状态训练。它允许在同一条轨迹上事后尝试不同窗口和权重，适合训练终点可能延长的场景。Decay-Free 指学习率不衰减，实验中的 AdamW weight decay 仍为 0.1。

来源：§3.2–3.3、算法 1；`src/sections/method.tex` 第 65–136 行。

**2. 为什么合并能模拟衰减？**

设参数更新满足 $\theta_{i+1}=\theta_i-g_i$，其中 $g_i$ 包含学习率。对 checkpoint 使用非负且和为 1 的权重 $c_j$，就有：

$$
\hat\theta_{n+k}=\sum_{j=0}^{k}c_j\theta_{n+j}
=\theta_n-\sum_{i=1}^{k}w_i g_{n+i-1},\qquad
w_i=\sum_{j=i}^{k}c_j.
$$

早期更新被更多后续 checkpoint 共享，因此平均后早期更新权重大、晚期更新权重小。平均四个连续 checkpoint，就使三个区间更新的系数成为 $3/4,1/2,1/4$。目标衰减系数单调不增且位于 [0,1] 时，反推合并权重为：

$$
c_0=1-w_1,\qquad c_j=w_j-w_{j+1}\;(1\le j<k),\qquad c_k=w_k.
$$

这精确描述的是已发生轨迹上历史更新的重加权。真正降低学习率重新训练，会改变后续梯度与 AdamW 状态；论文没有证明两条训练轨迹或终点完全相同。图 2 的 1-sqrt 具体写为 $1-\sqrt{t}$，并非 $1/\sqrt{t}$。

来源：§3.1，式 (1)–(5)、定理 3.1；附录 B；`src/figs/decay_style_comparison.pdf`。

**3. 实验效果有多大？**

主模型为 Ling-mini MoE，总参数 16.3B、激活约 1.43B。两条分支从同一个已经训练 10.2T token 的 checkpoint 出发，用高质量数据继续训练；正文将主要对照描述为额外 400B token。默认每 25B token 保存一次 checkpoint。

| 作者报告的综合指标 | WSD | WSM | 绝对分差 |
|---|---:|---:|---:|
| Base，均值合并 | 62.67 | 63.95 | +1.28 |
| Base，1-sqrt 合并 | 62.67 | 64.06 | +1.39 |
| 相同设置 SFT 后 | 62.90 | 64.07 | +1.17 |

这些表格选取各方法平均 benchmark 分最高的 checkpoint，SFT 则选 5 个 epoch 中平均分最高的 epoch。图 3 还将 WSM 延长到 500B token，WSD 对照止于 400B；均值 WSM 的最高点位于延长区间，表格没有标明所选 checkpoint 的确切 token 数。图中 400B 位置 WSM 也高于 WSD，但表格精确分差不应直接作为严格等 token 预算的收益。

收益也并非覆盖所有任务。例如 SFT 后代码类别从 58.23 降至 57.95，Base GSM8K 从 83.6 降至 82.6。摘要宣传的 MATH/HumanEval/MMLU-Pro 增益与附录固定最优 checkpoint 表的口径不能直接混用，报告中保留了各自来源。

来源：表 1–3；附录 E；`src/sections/method.tex` 第 139–209 行、`src/sections/exp.tex` 第 35–53 行、`src/figs/main.pdf`。

**4. 最值得带走的训练结论是什么？**

作者认为窗口覆盖的训练时长比单独增加 checkpoint 数更关键。固定名义 80B 窗口时，每 10B 合并 8 个的综合分为 63.78，每 40B 合并 2 个为 62.77，单点为 60.33；但最密的 5B×16 为 63.63，所以不能说越密越好。均值与 1-sqrt 合并在该实验中优于 EMA，窗口增大收益递减。先合并再衰减或先衰减再合并，在所测设置中未得到额外最终收益。

我的评价是：这篇论文提供了一个有工程价值的训练与交付流程，让恒定学习率主线持续运行，并用合并窗口管理输出模型的退火效果。对自己的训练，最直接的验证方式是固定训练终点、数据与评测，比较原始 checkpoint、均值合并和 WSD，再改变窗口时长。这是基于论文的实验设计建议，不是通用最优超参数。

复现仍有明显缺口：实验集中于一种 MoE；缺少多种子统计；高质量数据与 SFT 配方未充分公开；峰值学习率正文为 $4.78\times10^{-4}$，附录为 $3.74\times10^{-4}$。因此应把它看作值得验证的方法，而不把理论重排或作者分数视为普遍性能保证。

来源：§4.3–4.4、表 3–5、附录 A；`src/sections/exp.tex`、`src/sections/appendix.tex`；窗口图为 `src/figs/window.pdf`。
