#!/bin/bash
# 打包 AgentDock.app + DMG:
#   构建 release → 组装 .app(Info.plist/图标/资源 bundle)→ ad-hoc 签名 → DMG
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
BIN=".build/arm64-apple-macosx/release"
APP="dist/AgentDock.app"
DMG="dist/AgentDock-$VERSION.dmg"

echo "[1/5] 构建 release…"
swift build -c release >/dev/null

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

# 安装完成后以当前登录用户身份启动 App
cat > "$PKGROOT/scripts/postinstall" <<'POST'
#!/bin/bash
CONSOLE_USER=$(stat -f%Su /dev/console 2>/dev/null || true)
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
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
<p>安装器将把 AgentDock 安装到「应用程序」文件夹,完成后自动启动。</p>
<p>首次运行后,可在面板的「设置」页中完成:Agent 集成安装、开机自启、系统权限授权。</p>
</body></html>
HTML

cat > "$PKGROOT/resources/conclusion.html" <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body { font-family: -apple-system; font-size: 13px; color: #333; }
h2 { font-size: 15px; }
</style></head><body>
<h2>安装完成</h2>
<p>AgentDock 已启动,首次运行会弹出<b>安装设置向导</b>:
语言 → 开机自启 → Agent 集成 → 系统权限,按步骤完成即可。</p>
<p>完成后菜单栏出现机器人图标,鼠标悬停屏幕顶部刘海区域即可展开面板。</p>
<p>官网:<a href="https://www.agentdockstatus.app">www.agentdockstatus.app</a></p>
</body></html>
HTML

pkgbuild --component "$APP" \
         --install-location /Applications \
         --scripts "$PKGROOT/scripts" \
         --identifier dev.agentdock.AgentDock \
         --version "$VERSION" \
         "dist/AgentDock-component.pkg" >/dev/null

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

echo "[7/7] 发布到 site/(pkg + version.json 更新源)…"
cp "$PKG" site/
cat > site/version.json <<JSON
{
  "version": "$VERSION",
  "download": "https://www.agentdockstatus.app/AgentDock-$VERSION.pkg"
}
JSON

echo
echo "✓ 完成:"
ls -lh "$PKG" "$DMG" | awk '{print "  " $9 " (" $5 ")"}'
echo "  推荐分发 pkg:双击 → 分步安装向导 → 自动启动"
echo "  site/ 已更新(pkg + version.json),推送后官网即生效"
