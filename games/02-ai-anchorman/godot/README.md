# Help AI Anchorman

> 整理后的源码目录。Web 导出已移到仓库根目录的 `dist/help-ai-anchorman/`，不会提交到 Git。以下旧导出文件名仅供历史参考。

当前运行方式：在仓库根目录执行 `python3 tools/export_web.py --game help-ai-anchorman --godot /path/to/Godot`，然后执行 `python3 tools/serve.py`，访问 `http://127.0.0.1:8080/dist/help-ai-anchorman/`。

## "Failed to fetch" 错误解决方案

Godot 4 Web 导出后,直接双击 `help_ai_anchorman.html` 打开会报错:

```
TypeError: Failed to fetch
```

### 原因

Godot Web 导出生成 `.wasm` 和 `.pck` 文件,浏览器在 `file://` 协议下出于安全限制无法 fetch 这些文件。必须通过 HTTP 服务器访问。

### 解决方法

在 `help-ai-anchorman` 目录下运行:

```powershell
.\run_web.ps1
```

脚本会自动:
1. 启动本地 HTTP 服务器(端口 8060)
2. 打开浏览器访问游戏页面

### 手动启动

如果不使用脚本,可手动执行:

```powershell
# Python 方式
python -m http.server 8060

# Node.js 方式
npx http-server -p 8060
```

然后在浏览器访问仓库服务器上的 `http://localhost:8060/dist/help-ai-anchorman/index.html`。手动启动服务器时，工作目录必须为仓库根目录。

### 部署到服务器

上传到任意 HTTP 服务器(GitHub Pages、Netlify、Vercel 等)即可正常访问,无需本地服务器。

## 项目结构

- `project.godot` - Godot 项目配置
- `Scenes/` - 场景文件
- `Scripts/` - GDScript 脚本
- `assets/` - 美术资源
- `export_presets.cfg` - 导出预设
- `help_ai_anchorman.html` - Web 导出主页面
- `help_ai_anchorman.wasm` - WebAssembly 引擎
- `help_ai_anchorman.pck` - 游戏资源包
- `help_ai_anchorman.js` - 引擎加载脚本
