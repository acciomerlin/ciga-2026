# CiGA 文件统计与整理结果

> 本文记录第一次汇总时的布局。2026-10-18 已按三个小游戏重新归类；当前目录见 [目录重组记录](REORGANIZATION.md)，下面的旧映射保留作历史记录。

统计日期：2026-10-17。GB 使用十进制（1 GB = 1,000,000,000 字节），GiB 使用二进制。逻辑大小与 Finder、`du` 的磁盘占用可能略有差别。

## 原始目录

| 原目录 | 文件数（包括缓存和 Git 对象） | 逻辑大小 | 磁盘占用 |
| --- | ---: | ---: | ---: |
| ciga | 2,556 | 0.970 GB | 0.977 GB |
| ciga_2 | 78 | 0.039 GB | 0.039 GB |
| ciga-3 | 345 | 0.154 GB | 0.155 GB |
| 合计 | 2,979 | 1.162 GB（1.083 GiB） | 1.171 GB |

原始逻辑大小合计 1,162,394,386 字节。其中 Git 历史 576.16 MB，缓存和临时文件 64.54 MB，ZIP/PCK/WASM 等导出文件 240.42 MB，其余源码、美术、网页和说明约 281.28 MB。部分导出的 HTML/JS 图标文件也归入最后一项。

按 SHA-256 比较，非缓存源码资源中有 59 组相同内容，重复副本总计约 24.55 MB。不同目录中的图片可能被不同页面或游戏按相对路径引用，所以没有按文件名批量删除。

## 合并方式

以当前内容为准整理，而非按 ciga1/2/3 的数字判断新旧：

| 原位置 | 新位置 | 处理 |
| --- | --- | --- |
| ciga 根目录网页与 assets | web/ | 保留原有页面和资源相对路径 |
| ciga/Psalm404-CiGA2026 根网页 | web/anchorman/ | 保留较后期 H5 版本 |
| ciga/Psalm404-CiGA2026/help-ai-anchorman | games/help-ai-anchorman/ | 提取 Godot 源码 |
| 两处“抛个锚”项目 | games/throw-anchor/ | 11 个相同文件合并为一套 |
| ciga-3/anchorshackeshacke | games/anchorshackeshacke/ | 提取 Godot 源码 |
| ciga_2/CiGA2026 根网页 | archive/anchorman-h5-v1/ | 五个文件与后期版本不同，保留完整可运行旧版 |
| ciga_2/output | art/anchorman-iterations/ | 保留美术迭代 |
| ciga-3 根目录网页、图片、vendor | prototypes/ship-web/ | 保留物理、船体、链条实验 |
| ciga 下两个 3D 原型 | prototypes/ | 分别保留独立项目 |

整个源工作区约 271 MB，比原始目录含历史和缓存的逻辑大小减少约 77%。这是新工作区体积的减少；原始目录仍保留，没有释放或删除它们占用的磁盘空间。

两个 Godot Web 游戏重新从源码导出到 `dist/`。`dist/` 不进 Git；本地保留它是为了直接预览。克隆仓库后可通过 `tools/export_web.py` 再生成。`dist/`、导出缓存和新 Git 对象会使本地文件夹总占用高于 271 MB；这不等于上传源码大小。

## 上传边界

- GitHub 仓库为 `acciomerlin/ciga-2026`，私有。
- 不带入三个旧 `.git` 的历史对象，旧提交仍在原目录。
- 排除一份与游戏无关的个人 PDF；新的导出包从清理后的源码生成。
- 船游戏系统字体换成已有的 Noto Sans SC，并附两种 Noto 字体的完整 OFL 授权。
- 最大源文件约 17.77 MB，低于 GitHub 普通 Git 的 100 MiB 文件上限，本次不需要引入 Git LFS。
- 原有代码、美术和第三方素材的版权归属保持原状，未擅自添加整个游戏的开源许可证。

GitHub 大文件规则：<https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github>。

## 验证

- 复制时逐文件校验 SHA-256，重复映射有冲突时停止。
- 源码静态资源引用和 JavaScript 语法检查：`python3 tools/check_workspace.py`。
- Godot 4.7 两个 Web 游戏导出成功。
- 两个游戏执行无界面启动检查；重新导入后的运行日志未发现脚本或资源错误。这不是完整人工通关测试。
- 本地 HTTP 检查覆盖总入口、两个导出游戏、主播 H5、旧版本及船体原型。
- `docs/source-manifest.json` 记录原始文件 SHA-256 和来源映射；整理后改动过的路径、字体和导出设置以当前文件为准。
