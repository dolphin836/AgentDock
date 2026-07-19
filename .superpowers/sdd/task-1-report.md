<!-- [skill: go-team-standards · dev-dna · 任务实施报告] Vokie 1:1 Task 1 动效依赖 -->
# Task 1 实施报告

## 状态

GREEN；本地提交信息见 Commit 段。

## 依赖与来源

- Three.js `0.185.1`
  - 包：`three@0.185.1`
  - 上游：`https://github.com/mrdoob/three.js`
  - 获取产物：`build/three.core.min.js`、`build/three.module.min.js`
  - 许可证：MIT，完整文本已写入 `site/vendor/LICENSES.txt`
  - 官方 npm registry tarball：`https://registry.npmjs.org/three/-/three-0.185.1.tgz`
- GSAP `3.15.0`
  - 包：`gsap@3.15.0`
  - 上游：`https://github.com/greensock/GSAP`
  - 获取产物：`dist/gsap.min.js`、`dist/ScrollTrigger.min.js`
  - 许可证：GSAP Standard “No Charge” License
  - 许可证地址：`https://gsap.com/standard-license/`
  - 官方 npm registry tarball：`https://registry.npmjs.org/gsap/-/gsap-3.15.0.tgz`

两项依赖均通过 npm 的 `latest` dist-tag 安装，再从包内复制浏览器产物；网站运行时不访问 CDN。

## RED

先修改 `scripts/check_site.py`，要求四个本地 vendor 文件非空并禁止网站源文件引用常见运行时 CDN。

`python3 scripts/check_site.py` 退出码 `1`，按预期报告缺少：

- `site/vendor/three.module.min.js`
- `site/vendor/gsap.min.js`
- `site/vendor/ScrollTrigger.min.js`
- `site/vendor/LICENSES.txt`

## GREEN 与完整性

- `python3 scripts/check_site.py`：退出码 `0`，`PASS: site contract`
- Three.js 以 ES module 语法执行 `node --input-type=module --check`：退出码 `0`
- GSAP 与 ScrollTrigger 执行 `node --check`：退出码 `0`
- 使用 npm 重新安装精确版本并逐文件 `cmp`：`PASS: vendored files match npm package artifacts`
- `git diff --check HEAD^`：退出码 `0`；`.gitattributes` 对上游 minified 产物关闭文本 diff 并标记 `linguist-generated=true`，避免改写其原始字节来消除上游自带空白
- SHA-256：
  - `three.core.min.js`：`05b2609338c76cd65daf74f3ac515bc9a5045e1b3b33edc07d8c9bd55250fa90`
  - `three.module.min.js`：`86bcee248b64f44bcfc23c331ae74619061957d59cab040171dcb6fb5900beb6`
  - `gsap.min.js`：`92bb9a96476f983d212a2bc4f54c889039c1696dd4461d40a736860938570fbb`
  - `ScrollTrigger.min.js`：`b0b14d67b55b0c43c756ac0b106cfcb09d0879945f6ead64451065b0672916a2`

## 契约边界

本任务不创建导航、Canvas、粒子或空 scene 节点。导航 ID 由 Task 2 激活，Hero 模块与 scene ID 由 Task 3 激活，`motion.js`、Context 和 Journey scene ID 由 Task 4 激活。计划中 Task 3 修改 `motion.js`、Task 4 才创建该文件的顺序冲突，也留到对应任务统一解决。

## Commit

主提交信息：`build(site): vendor motion libraries`。本报告与 vendor 文件、checker 修改包含在该提交中；生成文件 diff 属性以独立修正提交记录。

## 评审修复追加

### Findings

- 补齐 `three.module.min.js` 同包相对导入的 `three.core.min.js`。
- checker 对 `site/vendor/` 五个文件校验固定 SHA-256，不再只检查非空。
- checker 解析所有 HTML 的 `<script src>` / `<link href>`、CSS `@import` / `url()` 与 JavaScript import specifier，拒绝 `http://`、`https://` 和 `//` 运行时资源；普通 `<a>` 下载链接不参与该限制。
- checker 解析 Three.js 相对 import，并要求依赖文件存在。
- `.gitattributes` 对 minified 产物设置 `-diff linguist-generated=true`。

### Review RED

- 旧 vendor 状态运行 checker：退出码 `1`，报告缺少 `site/vendor/three.core.min.js`，并报告 `three.module.min.js` 的 `./three.core.min.js` 相对导入无法解析。
- 更新许可证清单后、更新固定哈希前运行 checker：退出码 `1`，准确报告 `LICENSES.txt` SHA-256 不匹配。
- 临时分别放入 HTML、CSS、JavaScript 远程资源探针：checker 拒绝 5 个运行时资源；同一 HTML 中的 AgentDock HTTPS 下载 `<a>` 未误报。探针验证后已删除，不进入提交。

### Review GREEN

- `three.core.min.js` 从精确 `three@0.185.1` npm 包的 `build/` 目录复制。
- `LICENSES.txt` 追加 core 文件和全部 JavaScript artifact SHA-256。
- checker、四个 JavaScript 语法检查和 `git diff --check` 均退出码 `0`。
- 重新安装精确 `three@0.185.1`、`gsap@3.15.0` 后，四个 JavaScript 文件逐一 `cmp` 一致。
- `git check-attr` 确认四个 minified 文件均为 `diff: unset`、`linguist-generated: true`。
- 新修复提交信息：`fix(site): complete vendored motion dependencies`。

## Concerns

- GSAP 使用其 Standard “No Charge” License，不是开源许可证；发布前应确认网站使用场景符合当前条款。
- 最终复核改用 `registry.npmjs.org` 官方 tarball；官方 SHA-512 integrity
  校验通过，且四个 vendored JavaScript 文件与官方包内字节逐一一致。
