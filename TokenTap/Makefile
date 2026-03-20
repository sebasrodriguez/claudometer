.PHONY: build run install clean

APP_NAME = TokenTap
APP_BUNDLE = $(APP_NAME).app

build:
	swift build -c release

run: build
	.build/release/$(APP_NAME) &

install: build icon
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp .build/release/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@cp "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/" 2>/dev/null || true

icon:
	@mkdir -p /tmp/TokenTap.iconset
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_16x16.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_32x32.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_128x128.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_256x256.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_512x512.png /tmp/TokenTap.iconset/
	@cp TokenTap/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png /tmp/TokenTap.iconset/
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@iconutil -c icns /tmp/TokenTap.iconset -o "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@rm -rf /tmp/TokenTap.iconset
	@echo "Built $(APP_BUNDLE)"
	@echo ""
	@echo "To run:  open $(APP_BUNDLE)"
	@echo "To install:  cp -r $(APP_BUNDLE) /Applications/"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
