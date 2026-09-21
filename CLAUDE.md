# Paper Reader for Claude Code

> **Version**: 1.2.0
> **Purpose**: Automated arXiv paper reading workflow with AI-powered analysis
> **Language**: All outputs in Chinese (中文)

## Workflow

When a user provides a paper title or arXiv ID, follow these steps:

### 1. Identify Paper & Check Local Cache
- If title given: Search web for arXiv page, extract ID from URL (e.g., `2512.15745` from `https://arxiv.org/abs/2512.15745`)
- If multiple results found: Ask user to choose
- If ID given: Validate and proceed
- **Before downloading**, check local cache:
  - Sanitize title → check if `papers/{sanitized_title}/analysis_report/summary.md` exists
  - If yes: Read and present the summary, inform user "该论文已存在于本地，以下是已有的分析摘要。"
  - If yes: Skip download and summary generation, go directly to Step 5
- If NOT found locally: **proceed directly to download and generate report without asking for user confirmation**

### 2. Download Source
- URL: `https://arxiv.org/src/{arxiv_id}`
- Create directory: `papers/{sanitized_full_title}/`
  - **必须使用论文完整标题**，空格替换为下划线，去除 `/\:*?"<>|` 等非法字符
  - 示例: `JoyAI-Talker_Full-Duplex_Speech_Interactive_Large_Model_Built_for_Empathetic_Voice_Agents`
- Inside paper directory, create two subdirectories:
  - `src/` — for extracted LaTeX source files
  - `analysis_report/` — for AI-generated documents
- Extract `.tar.gz` into the `src/` subdirectory
- Final structure: `papers/{full_title}/src/` (源码) + `papers/{full_title}/analysis_report/` (分析报告)

### 3. Generate Summary (Chinese)
Read LaTeX source and generate `analysis_report/summary.md` covering:
- 背景与动机
- 问题定义
- 核心创新
- 方法论
- 实验结果
- 结论与展望
- 个人评价

**写入方式（强制）**：必须逐章节分段写入，禁止一次性生成完整长文后写入。具体流程：
1. 先用 Write 创建文件并写入标题和第一个章节（如"背景与动机"）
2. 每完成一个章节的分析后，立即用 Edit 追加写入该章节内容
3. 依次完成所有章节，每个章节独立思考、独立写入
4. 这样做的目的是确保每个章节都经过充分思考，避免因一次性生成过长内容导致质量下降

### 4. Push to GitHub
- Repo: `https://github.com/CxsGhost/opencode-paper-reader-arxiv`
- Use HTTPS
- Commit: `Add paper: [Title]`

### 5. Follow-up & Discussion Logging
- Answer questions based on paper content
- Reference original `.tex` source when needed
- Generate additional docs in `analysis_report/` if needed
- **Log every Q&A exchange** to `analysis_report/discussion_log.md` (create if missing):
  ```markdown
  ## 讨论记录 - YYYY-MM-DD

  ### HH:MM

  **用户问：** [用户问题原文]

  **回答：**
  [你的详细回答]
  ```
- Use Chinese for all outputs
- **生成额外文档时**同样遵循分段写入原则：先创建文件写入开头，再逐段追加内容

## Key Constraints
- arXiv only
- HTTPS for Git
- Chinese output
- Download directly if paper not found locally, no confirmation needed
- Always re-read `.tex` source when answering technical questions
- **分段写入原则**：所有 markdown 文档生成必须逐章节、逐段落写入，严禁一次性生成完整长文后整体写入。每个章节独立分析、独立写入，确保内容质量