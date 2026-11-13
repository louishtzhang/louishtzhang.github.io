---
name: preview-website
description: 编译整个 louishtzhang.github.io 个人主页（Jekyll + Academic Pages）并在浏览器中预览：按需重编 LaTeX 简历 PDF，用 Homebrew Ruby 3.2 启动 jekyll serve，检查输出文件和页面，然后在 Cursor 浏览器打开 http://127.0.0.1:4000。Use when the user asks to build, compile, preview, or serve the website locally (编译网站、本地预览、启动浏览器预览).
---

# 编译并预览网站

## 流程

1. 在仓库根目录运行脚本。它会一直运行（预览服务器），用 Shell 工具时设 `block_until_ms` 约 60000，让它自动转入后台：

   ```bash
   bash .cursor/skills/preview-website/scripts/preview.sh
   ```

2. 等终端输出出现 `==> Preview ready: http://127.0.0.1:4000/`（通常 10 秒内）。如果先出现 `MISSING`、`HTTP xxx`、`Files that should not be published` 或 `LaTeX failed`，脚本会停掉服务器并以退出码 1 结束：按输出修复后重跑。
3. 用 cursor-ide-browser 的 `browser_navigate` 打开 `http://127.0.0.1:4000/`，设 `position: "active"` 让用户看到。用户正在改某个页面时，直接打开对应地址：`/Research/`、`/cv/`、`/cv-cn/`。
4. 告诉用户预览已启动。之后改动页面文件约 3 秒会自动重新编译，刷新浏览器即可；改了 `_config.yml` 则需要重跑脚本（脚本会自动替换旧服务器）。

用户要求关闭预览时：`lsof -ti:4000 -sTCP:LISTEN | xargs kill`

只编译、不预览（例如提交前检查）：加 `--no-serve`，成功时最后一行是 `==> OK: N files in _site/`。

## 脚本做了什么

1. **简历 PDF**：`_pages/CV_pdf/` 中 `.tex` 比 `.pdf` 新时才重编。`main.tex` 用 pdflatex（`latexmk -pdf`），`main-cn.tex` 用 XeLaTeX（`latexmk -xelatex`，依赖 macOS 自带的 Songti SC 和 Times New Roman）。失败时看同目录的 `.log`。
2. **Ruby 环境**：用 `/usr/local/opt/ruby@3.2`，gem 装在 `vendor/bundle/ruby/3.2.0`。缺 gem 时自动 `bundle install`，并带上 eventmachine 等原生扩展需要的 x86_64 编译参数。
3. **编译并启动服务器**：先停掉占用 4000 端口的旧服务器，再后台运行 `jekyll serve --port 4000`，它会完整编译一次网站到 `_site/`（github-pages 231，Jekyll 3.9.5）。
4. **检查**：`_site/` 里必须有首页、Research、CV、中文简历、404、两份简历 PDF 和 `files/supplement.pdf`；不得有 `.tex`、LaTeX 中间文件、`.sh`、`.gem` 或 `.cursor/`；四个页面和三个 PDF 必须返回 HTTP 200。

## 注意事项

- 不要用系统 Ruby 2.6（`/usr/bin/ruby`）。它太旧，而且 `vendor/bundle/ruby/2.6.0` 里的原生扩展是 arm64 版本，在这台 Intel 机器上加载不了。
- 必须设置 `BUNDLE_VERSION=system`（脚本已设）。否则若 `Gemfile.lock` 记录的是 Bundler 1.17.2，Bundler 4 会自动切换过去，在 Ruby 3.2 上报 `undefined method 'untaint'`。
- `.bundle/config` 里记录了 eventmachine 编译用的 OpenSSL 路径（`~/opt/anaconda3`），重装 gem 时需要它，不要删。
- 不要用 `jekyll serve --skip-initial-build`：它沿用旧的 `_site/`，页面里的链接可能仍指向线上域名而不是 localhost。
- `_site/`、`vendor/`、LaTeX 中间文件都被 `.gitignore` 忽略，不要提交。线上网站由 GitHub Pages 在推送后自行编译，本地编译只用于检查和预览。
