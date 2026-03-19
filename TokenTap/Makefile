.PHONY: build run install clean

APP_NAME = TokenTap
APP_BUNDLE = $(APP_NAME).app

build:
	swift build -c release

run: build
	.build/release/$(APP_NAME) &

install: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp .build/release/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@echo "Built $(APP_BUNDLE)"
	@echo ""
	@echo "To run:  open $(APP_BUNDLE)"
	@echo "To install:  cp -r $(APP_BUNDLE) /Applications/"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
