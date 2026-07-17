APP        := MarkdownQuickLook
APP_BUNDLE := $(HOME)/Applications/$(APP).app
APPEX      := $(APP_BUNDLE)/Contents/PlugIns/PreviewExtension.appex
BUILT_APP  := build/Build/Products/Release/$(APP).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build install uninstall test-jira clean

build:
	xcodegen generate
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) \
		-configuration Release -derivedDataPath build build

# Replacing a registered app bundle in place leaves PlugInKit/LaunchServices
# state stale; install always does the full re-registration dance.
install: build
	-osascript -e 'quit app "$(APP)"' 2>/dev/null
	-pluginkit -r $(APPEX) 2>/dev/null
	rm -rf $(APP_BUNDLE)
	mkdir -p $(HOME)/Applications
	ditto $(BUILT_APP) $(APP_BUNDLE)
	$(LSREGISTER) -f $(APP_BUNDLE)
	open $(APP_BUNDLE)
	sleep 2
	-pluginkit -a $(APPEX) 2>/dev/null
	-pluginkit -e use -i com.deepc0py.$(APP).PreviewExtension
	@echo "Installed. Press Space on a .md file in Finder."

uninstall:
	-osascript -e 'quit app "$(APP)"' 2>/dev/null
	-pluginkit -r $(APPEX) 2>/dev/null
	rm -rf $(APP_BUNDLE)
	-$(LSREGISTER) -u $(APP_BUNDLE) 2>/dev/null

# Converter regression check; runs the real jira.js against the sample.
test-jira:
	node -e 'global.window={};const fs=require("fs");eval(fs.readFileSync("Extension/Resources/jira.js","utf8"));const J=global.window.JiraMarkup;const s=fs.readFileSync("Samples/sample-jira.jira","utf8");if(!J.shouldConvert(s,"jira"))throw new Error("jira not detected");const md=J.toMarkdown(s);for(const want of["# Spike","## Problem","| --- |","```scala","> Persist first","~~lost~~"]){if(!md.includes(want))throw new Error("missing: "+want)}console.log("jira converter OK")'

clean:
	rm -rf build $(APP).xcodeproj
