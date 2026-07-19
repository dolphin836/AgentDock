<!-- [skill: go-team-standards · dev-dna · 任务实施报告] Vokie 1:1 Task 1 动效依赖 -->
# Task 1 实施报告

## 状态

GREEN；本地提交信息见 Commit 段。

## 依赖与来源

- Three.js `0.185.1`
  - 包：`three@0.185.1`
  - 上游：`https://github.com/mrdoob/three.js`
  - 获取产物：`build/three.module.min.js`
  - 许可证：MIT，完整文本已写入 `site/vendor/LICENSES.txt`
  - 实际 npm registry tarball：`https://registry.npmmirror.com/three/-/three-0.185.1.tgz`
- GSAP `3.15.0`
  - 包：`gsap@3.15.0`
  - 上游：`https://github.com/greensock/GSAP`
  - 获取产物：`dist/gsap.min.js`、`dist/ScrollTrigger.min.js`
  - 许可证：GSAP Standard “No Charge” License
  - 许可证地址：`https://gsap.com/standard-license/`
  - 实际 npm registry tarball：`https://registry.npmmirror.com/gsap/-/gsap-3.15.0.tgz`

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
- `git diff --check HEAD^`：退出码 `0`；`.gitattributes` 将上游 minified 产物标记为生成文件，避免改写其原始字节来消除上游自带空白
- SHA-256：
  - `three.module.min.js`：`86bcee248b64f44bcfc23c331ae74619061957d59cab040171dcb6fb5900beb6`
  - `gsap.min.js`：`92bb9a96476f983d212a2bc4f54c889039c1696dd4461d40a736860938570fbb`
  - `ScrollTrigger.min.js`：`b0b14d67b55b0c43c756ac0b106cfcb09d0879945f6ead64451065b0672916a2`

## 契约边界

本任务不创建导航、Canvas、粒子或空 scene 节点。导航 ID 由 Task 2 激活，Hero 模块与 scene ID 由 Task 3 激活，`motion.js`、Context 和 Journey scene ID 由 Task 4 激活。计划中 Task 3 修改 `motion.js`、Task 4 才创建该文件的顺序冲突，也留到对应任务统一解决。

## Commit

主提交信息：`build(site): vendor motion libraries`。本报告与 vendor 文件、checker 修改包含在该提交中；生成文件 diff 属性以独立修正提交记录。

## Concerns

- GSAP 使用其 Standard “No Charge” License，不是开源许可证；发布前应确认网站使用场景符合当前条款。
- 当前 npm 配置从 `registry.npmmirror.com` 获取 tarball；完整性由 npm 的 SHA-512 校验和二次精确版本逐文件比较确认。
