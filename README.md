# WinUtil · 中文本地化版

[![Version](https://img.shields.io/github/v/release/ISO-N/winutil-chinese?color=%230567ff&label=Latest%20Release&style=for-the-badge)](https://github.com/ISO-N/winutil-chinese/releases/latest)
![Downloads](https://img.shields.io/github/downloads/ISO-N/winutil-chinese/winutil.ps1?label=Total%20Downloads&style=for-the-badge)
[![Discord](https://dcbadge.limes.pink/api/server/https://discord.gg/RUbZUZyByQ?theme=default-inverted&style=for-the-badge)](https://discord.gg/RUbZUZyByQ)

Windows 系统任务的精选合集：**安装**常用软件、**精简**系统、**排障**导出配置、配置 **Windows 更新**。每次全新安装 Windows 后都可以跑一遍。

![Title Screen](docs/src/assets/branding/title-screen.png)

---

## 与上游项目的区别

本仓库是 [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) 的分支，作者与版权归属仍属上游。主要差异如下：

| | 上游 ChrisTitusTech/winutil | 本仓库 ISO-N/winutil-chinese |
|---|---|---|
| 界面语言 | 仅英文 | 英文 / 简体中文，由 `-Language` 选择 |
| 默认分支 | `main` | `main`（`dev` 为开发分支） |
| 编译产物发布 | `pre-release.yaml` 手动触发，按日期打 tag 发布 Release | `publish-latest-release.yaml` 在 `main` 每次变更时编译，并覆盖 Release 页面上的 `winutil.ps1` |
| 编译校验 CI | 仅监听 `main` | 监听 `main` 与 `dev` |
| 本地化文档 | 无 | [docs/src/content/docs/guides/localization.mdx](docs/src/content/docs/guides/localization.mdx) |

### 新增的本地化能力

- 语言目录 `locales/en-US.json` 与 `locales/zh-CN.json`，以**英文原文为键**；翻译缺失时逐条回退英文，不影响可用性。
- `Get-WinUtilLocalizedText` 负责查表：静态文案无需改动调用点，动态文案在调用点用模板键查询。
- `Set-WinUtilXamlLocale` 统一替换 XAML 中的静态文案，TabItem 的逻辑键保持原样。
- `tools/extract-locale-strings.ps1` 从 XAML、config 与脚本中抽取可翻译字符串，并校验各语言目录的一致性。
- `Compile.ps1` 把语言目录内嵌为 `$WinUtilLocales`，并以 UTF-8 with BOM 写出 `winutil.ps1`。

除上述内容外，tweaks、preset、包管理器、Win11 Creator 等系统行为与上游保持一致。

---

## 快速开始

> **必须以管理员身份运行**，脚本会进行系统级修改。

### 如何打开管理员终端

- **开始菜单：** 右键开始 → *Windows PowerShell（管理员）* 或 *终端（管理员）*
- **搜索：** 按 `Windows` 键，输入 `PowerShell` 或 `终端`，然后 `Ctrl + Shift + Enter`

### 方式一：下载已编译的发布版（推荐）

Release 页面上的 `winutil.ps1` 会在 `main` 每次变更后自动更新，不需要挑具体版本号：

```ps1
irm https://github.com/ISO-N/winutil-chinese/releases/latest/download/winutil.ps1 | iex
```

> **请用 PowerShell 7（`pwsh`）执行这一行。** GitHub 以 `application/octet-stream`（不带 charset）发送该文件，Windows PowerShell 5.1 的 `irm` 会按字节解码，中文会变成乱码；实测 5.1 下它还会把文件头的 BOM 当成命令的一部分而直接报错。

### 方式二：从源码编译运行

`winutil.ps1` 是编译产物，不入库，需要自行编译：

```ps1
git clone https://github.com/ISO-N/winutil-chinese.git
cd winutil-chinese
.\Compile.ps1
.\winutil.ps1
```

编译产物带 UTF-8 BOM，所以**从磁盘直接运行**在 Windows PowerShell 5.1 与 PowerShell 7 下都能正确显示中文；只有 `irm | iex` 这种管道执行不能有 BOM，因此发布到 Release 的副本会被去掉 BOM。

### 选择界面语言

```ps1
# 默认为 auto：跟随系统界面语言，匹配不到时回退英文
.\winutil.ps1 -Language zh-CN
.\winutil.ps1 -Language en-US
```

一键安装走的是 `irm | iex`，无法直接传参数，因此默认按系统界面语言显示。若系统界面语言不是中文，强制使用中文界面：

```ps1
& ([ScriptBlock]::Create((irm https://github.com/ISO-N/winutil-chinese/releases/latest/download/winutil.ps1))) -Language zh-CN
```

---

## 自动化 / 预设

不手动勾选，直接套用预置配置：

```powershell
& ([ScriptBlock]::Create((irm https://github.com/ISO-N/winutil-chinese/releases/latest/download/winutil.ps1))) -Preset Standard
```

| 预设 | 说明 |
|---|---|
| `Standard` | 面向多数用户的均衡默认值 |
| `Minimal` | 尽量少改动的最小集合 |
| `Advanced` | 面向高级用户的深度调整 |

每个预设的具体内容见 [config/preset.json](config/preset.json)。

---

## 构建与开发

- 编译：`.\Compile.ps1`；编译并直接启动：`.\Compile.ps1 -Run`
- 测试：`Invoke-Pester -Path 'pester/*.Tests.ps1' -Output Detailed -CI`（需 Pester 5.8.0）
- 新增或修改界面文案后，运行 `tools/extract-locale-strings.ps1` 更新 `locales/en-US.json` 并校验翻译目录
- 贡献指南见 [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)（上游原文，未改动）

---

## 相关资源

- 上游项目：https://github.com/ChrisTitusTech/winutil
- 官方文档：https://winutil.christitus.com/
- 视频教程：https://www.youtube.com/watch?v=6UQZ5oQg8XA
- ChrisTitus.com 文章：https://christitus.com/windows-tool/
- 已知问题：https://winutil.christitus.com/knownissues/
- 本仓库问题反馈：https://github.com/ISO-N/winutil-chinese/issues
- 本地化说明：[docs/src/content/docs/guides/localization.mdx](docs/src/content/docs/guides/localization.mdx)

---

## 支持上游

- 给上游点个 ⭐ 表示支持：https://github.com/ChrisTitusTech/winutil
- 更快的 .NET 实现（付费）：https://www.cttstore.com/windows-toolbox

## 赞助者

以下赞助者为上游项目提供每月支持；该区块由上游 `sponsors.yaml` 自动生成，本仓库未做同步。

<!-- sponsors --><a href="https://github.com/dwelfusius"><img src="https:&#x2F;&#x2F;github.com&#x2F;dwelfusius.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/mews-se"><img src="https:&#x2F;&#x2F;github.com&#x2F;mews-se.png" width="60px" alt="User avatar: Martin" /></a><a href="https://github.com/jdiegmueller"><img src="https:&#x2F;&#x2F;github.com&#x2F;jdiegmueller.png" width="60px" alt="User avatar: Jason A. Diegmueller" /></a><a href="https://github.com/robertsandrock"><img src="https:&#x2F;&#x2F;github.com&#x2F;robertsandrock.png" width="60px" alt="User avatar: RMS" /></a><a href="https://github.com/paulsheets"><img src="https:&#x2F;&#x2F;github.com&#x2F;paulsheets.png" width="60px" alt="User avatar: Paul" /></a><a href="https://github.com/djones369"><img src="https:&#x2F;&#x2F;github.com&#x2F;djones369.png" width="60px" alt="User avatar: Dave J  (WhamGeek)" /></a><a href="https://github.com/anthonymendez"><img src="https:&#x2F;&#x2F;github.com&#x2F;anthonymendez.png" width="60px" alt="User avatar: Anthony Mendez" /></a><a href="https://github.com/FatBastard0"><img src="https:&#x2F;&#x2F;github.com&#x2F;FatBastard0.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/DursleyGuy"><img src="https:&#x2F;&#x2F;github.com&#x2F;DursleyGuy.png" width="60px" alt="User avatar: DursleyGuy" /></a><a href="https://github.com/DwayneTheRockLobster1"><img src="https:&#x2F;&#x2F;github.com&#x2F;DwayneTheRockLobster1.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/KieraKujisawa"><img src="https:&#x2F;&#x2F;github.com&#x2F;KieraKujisawa.png" width="60px" alt="User avatar: Kiera Meredith" /></a><a href="https://github.com/seanh1995"><img src="https:&#x2F;&#x2F;github.com&#x2F;seanh1995.png" width="60px" alt="User avatar: Sean (ANGRYxScotsman)" /></a><a href="https://github.com/F-L-Perez"><img src="https:&#x2F;&#x2F;github.com&#x2F;F-L-Perez.png" width="60px" alt="User avatar: Fra · ppe" /></a><a href="https://github.com/josencarnacao"><img src="https:&#x2F;&#x2F;github.com&#x2F;josencarnacao.png" width="60px" alt="User avatar: José Encarnação" /></a><!-- sponsors -->

*<sub>Sponsors with a recurring subscription also get access to the .NET alternative.</sub>

---

## 贡献者

[![Contributors](https://contrib.rocks/image?repo=ISO-N/winutil-chinese)](https://github.com/ISO-N/winutil-chinese/graphs/contributors)

感谢所有为上游与本仓库投入时间与精力的人。
