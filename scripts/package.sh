#!/bin/bash
# 打包 AgentDock.app + 拖拽安装 DMG:
#   构建 release → 组装 .app → ad-hoc 签名 → Finder 拖拽式 DMG → 发布到 site/
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.2.4"
# 通用二进制:Intel 机器上纯 arm64 的 App 能安装但无法启动(无提示),必须双架构
BIN=".build/apple/Products/Release"
APP="dist/AgentDock.app"
DMG="dist/AgentDock-$VERSION.dmg"
VOLNAME="AgentDock"

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

echo "[4/5] 签名(ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "[5/5] 生成拖拽安装 DMG(左 App · 右 Applications)…"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 可写中间盘 → 用 Finder 摆好图标位置 → 再压成 UDZO
TEMP_DMG=$(mktemp -u /tmp/agentdock-rw.XXXXXX).dmg
rm -f "$TEMP_DMG" "$DMG"
hdiutil create -volname "$VOLNAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ -format UDRW -ov \
    "$TEMP_DMG" >/dev/null
rm -rf "$STAGING"

# 避免同名卷已挂载导致落在 "/Volumes/AgentDock 1"
if [ -d "/Volumes/$VOLNAME" ]; then
  hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null 2>&1 || true
fi
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen >/dev/null
sleep 2

osascript <<APPLESCRIPT >/dev/null
with timeout of 120 seconds
    tell application "Finder"
        tell disk "$VOLNAME"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {320, 200, 920, 500}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 128
            set text size of theViewOptions to 13
            set position of item "AgentDock.app" of container window to {160, 150}
            set position of item "Applications" of container window to {440, 150}
            close
            open
            update without registering applications
            delay 1
        end tell
    end tell
end timeout
APPLESCRIPT

sync
hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null 2>&1 || true
# 偶发 detach 慢一拍
sleep 1
if [ -d "/Volumes/$VOLNAME" ]; then
  hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null 2>&1 || true
fi

hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$TEMP_DMG"

echo "[publish] 发布到 site/(dmg + version.json + 下载链接)…"
rm -f site/AgentDock-*.pkg site/AgentDock-*.dmg
cp "$DMG" site/
DMG_URL="https://api.agentdockstatus.app/v1/download/AgentDock-$VERSION.dmg"
# 官网与应用内更新都走 dmg;download 字段保持兼容旧客户端字段名
python3 - "$DMG_URL" "$VERSION" <<'PY'
from pathlib import Path
import re, sys
dmg_url, version = sys.argv[1], sys.argv[2]
path = Path("site/index.html")
text = path.read_text()
# 兼容旧 pkg 链接与已是 dmg 的链接
text, n = re.subn(
    r'https://api\.agentdockstatus\.app/v1/download/AgentDock-[0-9.]+\.(?:pkg|dmg)',
    dmg_url,
    text,
)
text = re.sub(r'>v\d+\.\d+\.\d+<', f'>v{version}<', text)
text = re.sub(r'(<b>)v\d+\.\d+\.\d+(</b>)', rf'\1v{version}\2', text)
path.write_text(text)
print(f"  index.html download href updated ({n} match)")
PY
cat > site/version.json <<JSON
{
  "version": "$VERSION",
  "download": "$DMG_URL",
  "dmg": "$DMG_URL"
}
JSON

echo
echo "✓ 完成:"
ls -lh "$DMG" | awk '{print "  " $9 " (" $5 ")"}'
echo "  打开 DMG → 把 AgentDock 拖进 Applications → 启动"
echo "  site/ 已更新(dmg + version.json),推送后官网即生效"
