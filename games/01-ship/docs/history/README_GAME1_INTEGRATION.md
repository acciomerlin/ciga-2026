> 历史记录：本文保留整理前的路径与操作。当前目录和运行方式以仓库根目录 README.md 为准。

# Anchorshackeshacke 接入序号 1 小游戏说明

这个包是从 `/Users/acciomac/Desktop/ciga-3/anchorshackeshacke` 导出的 Godot Web 版本，已经复制到当前 `ciga` 文件夹里。

## 已放好的文件

Web 导出包目录：

```text
/Users/acciomac/Desktop/ciga/anchorshackeshacke-game1/
```

压缩包备份：

```text
/Users/acciomac/Desktop/ciga/anchorshackeshacke-game1-web.zip
```

包内入口有两个，内容一致：

```text
anchorshackeshacke-game1/index.html
anchorshackeshacke-game1/anchorshackeshacke.html
```

推荐给序号 1 入口接：

```text
./anchorshackeshacke-game1/
```

## 接到序号 1

打开：

```text
/Users/acciomac/Desktop/ciga/anchor-plus3.html
```

找到序号 1 这一段：

```html
<a
  class="entry-number"
  href="./index.html"
  aria-label="进入小游戏 1"
  aria-describedby="entry-caption-1"
  >1</a
>
```

把 `href` 改成：

```html
href="./anchorshackeshacke-game1/"
```

也就是：

```html
<a
  class="entry-number"
  href="./anchorshackeshacke-game1/"
  aria-label="进入小游戏 1"
  aria-describedby="entry-caption-1"
  >1</a
>
```

标题文案可以继续用原来的：

```html
<span id="entry-caption-1" class="entry-caption">恶搞-有人要吐了，，</span>
```

## 本地测试方式

Godot Web 导出不能直接双击 HTML 用 `file://` 打开，否则容易出现 `fail to fetch`。需要用本地 HTTP 服务。

在终端执行：

```bash
cd /Users/acciomac/Desktop/ciga
python3 -m http.server 8080
```

然后浏览器打开：

```text
http://127.0.0.1:8080/anchor-plus3.html
```

点击序号 `1`，应该进入：

```text
http://127.0.0.1:8080/anchorshackeshacke-game1/
```

也可以直接打开：

```text
http://127.0.0.1:8080/anchorshackeshacke-game1/
```

## 注意事项

- `anchorshackeshacke-game1/` 里的 `.html`、`.js`、`.pck`、`.wasm`、worklet 文件必须保持在同一个目录。
- 如果部署到线上，上传整个 `anchorshackeshacke-game1/` 文件夹即可。
- 如果线上服务器对 `.wasm` MIME 有要求，确保 `.wasm` 返回 `application/wasm`。
- 当前这版是 300 沙石压力测试版：每区块 150 个沙石，屏幕附近通常约 300 个。

## 重新打包时

如果之后在 `/Users/acciomac/Desktop/ciga-3/anchorshackeshacke` 里改了 Godot 项目，需要重新导出 Web，然后把这些文件复制到：

```text
/Users/acciomac/Desktop/ciga/anchorshackeshacke-game1/
```

需要覆盖的核心文件：

```text
anchorshackeshacke.html
anchorshackeshacke.js
anchorshackeshacke.pck
anchorshackeshacke.wasm
anchorshackeshacke.audio.worklet.js
anchorshackeshacke.audio.position.worklet.js
anchorshackeshacke.icon.png
anchorshackeshacke.apple-touch-icon.png
anchorshackeshacke.png
```

覆盖后再复制一份入口：

```bash
cp anchorshackeshacke.html index.html
```
