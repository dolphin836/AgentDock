#!/bin/bash
# 打包 AgentDock.app + DMG:
#   构建 release → 组装 .app(Info.plist/图标/资源 bundle)→ ad-hoc 签名 → DMG
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.2.0"
# 通用二进制:Intel 机器上纯 arm64 的 App 能安装但无法启动(无提示),必须双架构
BIN=".build/apple/Products/Release"
APP="dist/AgentDock.app"
DMG="dist/AgentDock-$VERSION.dmg"

echo "[1/5] 构建 release(universal: arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64 >/dev/null

echo "[2/5] 组装 AgentDock.app…"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/AgentDock" "$APP/Contents/MacOS/AgentDock"
cp -R "$BIN/AgentDock_AgentDockCore.bundle" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AgentDock</string>
    <key>CFBundleIdentifier</key><string>dev.agentdock.AgentDock</string>
    <key>CFBundleName</key><string>AgentDock</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>AgentDock 点击会话跳转时,用自动化选中 Terminal/iTerm2 的对应标签页。</string>
</dict>
</plist>
PLIST

echo "[3/5] 生成图标 icns…"
ICONSET="dist/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z $SIZE $SIZE assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z $DOUBLE $DOUBLE assets/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "[4/6] 签名(ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "[5/6] 构建 pkg 安装器(分步安装向导)…"
PKGROOT="dist/pkg"
mkdir -p "$PKGROOT/scripts" "$PKGROOT/resources"

# 安装完成后以当前登录用户身份预配置 + 启动 App:
# 先用无头模式按默认值配好(语言随系统 / 开机自启 / 自动注册已装的 agent),
# 再启动 App —— 首次向导据「已预配置」标记精简为只做权限授权。
# 预配置以 launchctl asuser 进入用户的 GUI 会话域,UserDefaults / LaunchAgent 才落到对的地方。
cat > "$PKGROOT/scripts/postinstall" <<'POST'
#!/bin/bash
CONSOLE_USER=$(stat -f%Su /dev/console 2>/dev/null || true)
BIN="/Applications/AgentDock.app/Contents/MacOS/AgentDock"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  UID_NUM=$(id -u "$CONSOLE_USER")
  if [ -x "$BIN" ]; then
    launchctl asuser "$UID_NUM" sudo -u "$CONSOLE_USER" \
      "$BIN" --setup language=auto autostart=yes integrations=auto || true
  fi
  sudo -u "$CONSOLE_USER" open -a "/Applications/AgentDock.app" || true
fi
exit 0
POST
chmod +x "$PKGROOT/scripts/postinstall"

cat > "$PKGROOT/resources/welcome.html" <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body { font-family: -apple-system; font-size: 13px; color: #333; }
h2 { font-size: 15px; } code { font-family: ui-monospace, monospace; }
</style></head><body>
<h2>欢迎安装 AgentDock</h2>
<p>AgentDock 是一款 macOS 刘海扩展应用,实时显示本机 AI Agent
(Claude Code / Codex / Cursor)的会话状态、用量与待处理事项,并支持面板内审批。</p>
<p>安装器会把 AgentDock 安装到「应用程序」文件夹,并<b>自动完成初始配置</b>:
按系统语言设置界面语言、开启开机自启、检测并注册本机已安装的 Agent 集成,随后自动启动。</p>
<p>启动后只剩一步可选的系统权限授权;所有配置之后都能在面板的「设置」页中随时修改。</p>
</body></html>
HTML

cat > "$PKGROOT/resources/conclusion.html" <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body { font-family: -apple-system; font-size: 13px; color: #333; }
h2 { font-size: 15px; }
</style></head><body>
<h2>安装完成</h2>
<p>AgentDock 已按推荐默认值配置好并启动。首次运行会弹出一个<b>简短的就绪确认</b>,
展示已完成的配置,并引导授予一项可选的系统权限(辅助功能)。</p>
<p>菜单栏会出现机器人图标,鼠标悬停屏幕顶部刘海区域即可展开面板。
需要调整语言、开机自启、Agent 集成等,都可在面板的「设置」页中修改。</p>
<p>官网:<a href="https://www.agentdockstatus.app">www.agentdockstatus.app</a></p>
</body></html>
HTML

# 必须关闭 bundle relocation:默认 true 时,若目标机上存在同 bundle ID 的旧拷贝
# (开发机的 dist/、用户从 DMG 拖过的副本…),安装器会把安装目标改到那份拷贝,
# /Applications 里就"找不到 App",postinstall 的自动启动也会失败
PKGFILES="dist/pkgroot"
mkdir -p "$PKGFILES/Applications"
cp -R "$APP" "$PKGFILES/Applications/"
pkgbuild --analyze --root "$PKGFILES" "$PKGROOT/component.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$PKGROOT/component.plist"
pkgbuild --root "$PKGFILES" \
         --component-plist "$PKGROOT/component.plist" \
         --install-location / \
         --scripts "$PKGROOT/scripts" \
         --identifier dev.agentdock.AgentDock \
         --version "$VERSION" \
         "dist/AgentDock-component.pkg" >/dev/null
rm -rf "$PKGFILES"

cat > "$PKGROOT/distribution.xml" <<DIST
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>AgentDock $VERSION</title>
    <welcome file="welcome.html"/>
    <conclusion file="conclusion.html"/>
    <options customize="never" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <pkg-ref id="dev.agentdock.AgentDock" version="$VERSION">AgentDock-component.pkg</pkg-ref>
    <choices-outline><line choice="default"/></choices-outline>
    <choice id="default" title="AgentDock"><pkg-ref id="dev.agentdock.AgentDock"/></choice>
</installer-gui-script>
DIST

PKG="dist/AgentDock-$VERSION.pkg"
productbuild --distribution "$PKGROOT/distribution.xml" \
             --resources "$PKGROOT/resources" \
             --package-path dist \
             "$PKG" >/dev/null
rm -rf "$PKGROOT" dist/AgentDock-component.pkg

echo "[6/6] 生成 DMG(备用的拖拽安装)…"
STAGING="dist/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "AgentDock" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "[7/7] 发布到 site/(pkg + version.json 更新源 + 下载链接)…"
rm -f site/AgentDock-*.pkg
cp "$PKG" site/
# 下载走 api 计数跳转;pkg 实体仍托管在官网上
DOWNLOAD_URL="https://api.agentdockstatus.app/v1/download/AgentDock-$VERSION.pkg"
# 只改下载按钮的 href,避免误伤页面其它文案
python3 - "$DOWNLOAD_URL" "$VERSION" <<'PY'
from pathlib import Path
import re, sys
download_url, version = sys.argv[1], sys.argv[2]
path = Path("site/index.html")
text = path.read_text()
text, n = re.subn(
    r'(<a class="download" href=")[^"]+(">)',
    rf'\1{download_url}\2',
    text,
    count=1,
)
text = re.sub(r'>v\d+\.\d+\.\d+<', f'>v{version}<', text)
path.write_text(text)
print(f"  index.html download href updated ({n} match)")
PY
cat > site/version.json <<JSON
{
  "version": "$VERSION",
  "download": "$DOWNLOAD_URL"
}
JSON

echo
echo "✓ 完成:"
ls -lh "$PKG" "$DMG" | awk '{print "  " $9 " (" $5 ")"}'
echo "  推荐分发 pkg:双击 → 分步安装向导 → 自动启动"
echo "  site/ 已更新(pkg + version.json),推送后官网即生效"
