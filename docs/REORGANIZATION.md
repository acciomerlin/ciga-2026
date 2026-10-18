# 按三个小游戏重新归类

2026-10-18：沿用根目录 README 的游戏顺序，把源码、不同实现和开发过程放回各自游戏下面。不重做 UI，不修改玩法，不删除原型、美术迭代或历史版本。三个原始目录也不改动。

## 1. 现在从哪里找

| 游戏 | 当前实现 | 开发过程 |
| --- | --- | --- |
| [01 · 有人要吐了，，](../games/01-ship/) | `godot/` | `prototypes/web/`、`docs/history/` |
| [02 · Help AI Anchorman](../games/02-ai-anchorman/) | `godot/`，另有 `web/` H5 实现 | `history/web-v1/`、`art/iterations/` |
| [03 · 梅人说不能做跑酷](../games/03-anchor-drift/) | `web/` | `prototypes/` 下的网页、Godot 跑酷和两份 3D 河道白盒 |

总入口单独放在 [site](../site/)。统计、校验、截图仍在 `docs/`，导出和服务器仍在 `tools/`。没有为了整齐而合并不同版本、重命名美术文件，或挪动 Godot 项目内部的场景和资源。

## 2. 旧目录对照

| 重组前 | 重组后 |
| --- | --- |
| `games/anchorshackeshacke/` | `games/01-ship/godot/` |
| `prototypes/ship-web/` | `games/01-ship/prototypes/web/` |
| `docs/history/README_GAME1_INTEGRATION.md` | `games/01-ship/docs/history/README_GAME1_INTEGRATION.md` |
| `games/help-ai-anchorman/` | `games/02-ai-anchorman/godot/` |
| `web/anchorman/` | `games/02-ai-anchorman/web/` |
| `archive/anchorman-h5-v1/` | `games/02-ai-anchorman/history/web-v1/` |
| `art/anchorman-iterations/` | `games/02-ai-anchorman/art/iterations/` |
| `web/index.html`、`game.js`、`styles.css`、河流素材 | `games/03-anchor-drift/web/` |
| `web/perspective.*`、`web/three-anchor.*` | `games/03-anchor-drift/prototypes/web/` |
| `games/throw-anchor/` | `games/03-anchor-drift/prototypes/anchor-runner-godot/` |
| `prototypes/godot-anchor-3d/` | `games/03-anchor-drift/prototypes/anchor-river-3d/` |
| `prototypes/anchor-river-whitebox-4.3/` | `games/03-anchor-drift/prototypes/anchor-river-whitebox-4.3/` |
| `web/anchor-plus3.html`、入口样式和入口图片 | `site/index.html`、`site/anchor-plus3.css`、`site/assets/anchor-plus3/` |

完整机器可读对照在 [directory-map.json](directory-map.json)。[来源清单](source-manifest.json) 的 `destination` 已同步为现路径，`initial_destination` 保留第一次整理时的位置；原始来源与 SHA-256 不变。

## 3. 移动时修正的路径

- 根目录入口改为跳到 `site/index.html`；菜单的第三个游戏链接指向新的河流游戏目录。
- 两个 Godot Web 导出预设、导出脚本及主播 PowerShell 启动脚本适配新增的目录层级。导出参数和根目录 `dist/` 下的地址保持不变。
- 透视和 Three.js 网页原型的资源引用改为访问同一游戏的 `web/assets/`；只是换相对路径，没有增删图像或改交互逻辑。
- README、第三方声明和原型运行说明同步现路径。历史接入记录中的旧路径保留原文，不当成现行运行说明。

## 4. 保留原状的边界

源代码里原本有部分不存在的图像引用，例如 Three.js 原型的 `computer-lab-cutouts/`；河流游戏也有部分可选图像的旧文件名。这次只保留并记录，没有生成替代图、改玩法或假称已经修好。Three.js 原型原来的远程模块依赖也没有升级或替换。

此前的测试记录 [verification.json](verification.json) 是第一次整理时的快照，其中 URL 属于旧布局。本次核验另存为 [reorganization-verification.json](reorganization-verification.json)，不覆盖旧证据。试玩检查用于核对目录移动后的入口和操作，不等于完整通关或原型完成度验收。

在仓库根目录运行：

```bash
python3 tools/check_workspace.py
python3 -m unittest discover -s tools/tests -v
```

[返回项目介绍](../README.md) · [第一次统计与整理](CONSOLIDATION.md)
