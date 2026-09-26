APP := build/QuickJot.app

# With only the Command Line Tools installed, Swift Testing lives outside the default search paths.
CLT := /Library/Developer/CommandLineTools
ifeq ($(shell xcode-select -p 2>/dev/null),$(CLT))
TEST_FLAGS := --disable-xctest \
	-Xswiftc -F -Xswiftc $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT)/Library/Developer/usr/lib
endif

.PHONY: app run install dmg test icon clean

app:
	@scripts/build-app.sh release

run: app
	@pkill -x QuickJot || true
	@open $(APP)

install: app
	@pkill -x QuickJot || true
	@rm -rf /Applications/QuickJot.app
	@cp -R $(APP) /Applications/QuickJot.app
	@open /Applications/QuickJot.app
	@echo "Installed to /Applications/QuickJot.app"

dmg: app
	@scripts/make-dmg.sh

test:
	@swift test --enable-swift-testing $(TEST_FLAGS)

icon:
	@swift scripts/make-icon.swift Resources/AppIcon.icns

clean:
	@rm -rf .build build
