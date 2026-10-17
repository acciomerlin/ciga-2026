# CiGA 2026 游戏工作区

把 `ciga`、`ciga_2`、`ciga-3` 中的游戏、网页原型和美术素材整理到一个仓库。各游戏仍是独立 Godot 项目；没有把不同玩法的脚本强行合并。

## 目录

```text
games/
  anchorshackeshacke/        # 船、沙石、抛锚、晕船玩法，来自 ciga-3
  help-ai-anchorman/         # 主播游戏 Godot 版本
  throw-anchor/             # 抛个锚；两份完全相同的源码合并为一份
web/
  anchor-plus3.html          # 三个小游戏的总入口
  index.html                # 第三个小游戏：年代/河流网页版本
  anchorman/                # 主播游戏 H5 后期版本
prototypes/
  ship-web/                 # 船体、物理和链条实验，保留相对资源路径
  godot-anchor-3d/
  anchor-river-whitebox-4.3/
art/anchorman-iterations/   # ciga_2 的美术迭代和切图
archive/anchorman-h5-v1/    # ciga_2 的早期 H5 版本，保留不同内容
docs/                      # 容量统计、迁移清单与历史说明
tools/                     # 导出和本地运行工具
dist/                      # 本地生成的 Web 游戏，不提交 Git
```

## 本地运行

已存在 `dist/` 时，在仓库根目录执行：

```bash
python3 tools/serve.py
```

打开 <http://127.0.0.1:8080/>。不能直接双击 Godot 导出的 HTML；浏览器必须通过 HTTP 加载 `.wasm` 和 `.pck`。

从 GitHub 克隆后，先安装 Godot 4.7 与对应版本 Web 导出模板，再生成两个 Godot 游戏：

```bash
python3 tools/export_web.py --godot /path/to/Godot
python3 tools/serve.py
```

macOS 示例：`--godot /Applications/Godot.app/Contents/MacOS/Godot`。Web 模板需与引擎版本完全匹配。没有模板时，`web/index.html`、`web/anchorman/`、归档和网页原型仍可直接通过本地服务器访问。

用 Godot 编辑时分别导入 `games/*/project.godot`。`throw-anchor` 原项目使用 Godot 4.6；其两个 3D 原型分别以各自配置和 README 为准。

## 整理规则

- 原始三个文件夹和原 Git 历史均保留在原处。本仓库以整理后的当前源码建立新的历史，避免带入数百 MB 的旧对象。
- 不提交 `.git/` 嵌套仓库、`.godot/` 缓存、临时文件、ZIP 和 Godot Web 导出。导出内容放 `dist/`，后续发布包适合放 GitHub Releases。
- `throw-anchor` 两份相同源码合并；主播 H5 的早期和后期版本有差异，分别保留。
- 运行中的资源路径尽量保持原样。重复图片不做有损压缩；完全相同的文件在 Git 对象库中天然共享。
- 一份与游戏无关的个人 PDF 不进入本仓库。船游戏的系统字体改用项目已有的 Noto Sans SC；字体授权见 `licenses/`。
- 每个迁移文件的来源、原始 SHA-256 与目标路径记录在 `docs/source-manifest.json`。整理中修改过的少量路径和配置，以当前文件内容为准。

## 上传 GitHub

建议仓库名 `ciga-2026-workspace`，可见性为私有。当前没有为整个游戏添加新的开源许可证；原有代码、美术、素材和依赖的权利归属不因整理而改变。第三方依赖见 `THIRD_PARTY_NOTICES.md`。

仓库准备好后，使用自己的 GitHub 账号创建同名空仓库，再设置远端并推送：

```bash
git remote add origin git@github.com:YOUR_ACCOUNT/ciga-2026-workspace.git
git push -u origin main
```

不要将 `dist/`、原始 ZIP 或个人文档强制加入提交。
