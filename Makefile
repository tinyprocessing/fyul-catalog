# One entry point for people, CI and AI agents. `make help` lists targets.
PROJECT      := Catalog.xcodeproj
SCHEME       := Catalog
IPHONE       ?= iPhone 17
IPAD         ?= iPad Pro 11-inch (M5)
DERIVED_DATA := build/DerivedData
XCODEBUILD   := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA)
# A hung UI test fails after a minute instead of blocking the run.
TEST_LIMITS  := -test-timeouts-enabled YES -maximum-test-execution-time-allowance 60
APP          := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/Catalog.app
# UDID of $(IPHONE) on the newest installed iOS. Commands target it explicitly, so a connected
# Android phone or a second booted simulator can't be picked by mistake.
SIM_UDID      = $(shell xcrun simctl list devices available -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; m=sorted((r,x["udid"]) for r,l in d.items() for x in l if x["name"]=="$(IPHONE)"); print(m[-1][1] if m else "")')

.PHONY: help project build boot test ui-test ui-test-ipad logs maestro maestro-live format lint run clean

help: ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

project: ## Regenerate Catalog.xcodeproj from project.yml (needs XcodeGen; the project is committed)
	xcodegen generate

build: ## Build the app for the iPhone simulator
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' build

test: ## Unit tests (Swift Testing), no network
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' test -only-testing:CatalogTests

ui-test: ## XCUITest on iPhone against the stubbed backend, includes the accessibility audit
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' $(TEST_LIMITS) test -only-testing:CatalogUITests

ui-test-ipad: ## The same UI tests on iPad (split view)
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPAD)' $(TEST_LIMITS) test -only-testing:CatalogUITests

boot: ## Boot the $(IPHONE) simulator (newest iOS) if it isn't running, and wait until it is ready
	@if [ -z "$(SIM_UDID)" ]; then echo "No simulator named '$(IPHONE)'. Pass IPHONE=\"<name>\"."; exit 1; fi
	@xcrun simctl boot $(SIM_UDID) 2>/dev/null || true
	@open -a Simulator 2>/dev/null || true
	@xcrun simctl bootstatus $(SIM_UDID) -b >/dev/null && echo "Simulator ready: $(IPHONE) ($(SIM_UDID))"

maestro: build boot ## Maestro flows against the stubbed backend (boots the simulator if needed)
	xcrun simctl install $(SIM_UDID) $(APP)
	maestro --device $(SIM_UDID) test --exclude-tags live maestro/flows

maestro-live: build boot ## Maestro smoke test against the real DummyJSON API
	xcrun simctl install $(SIM_UDID) $(APP)
	maestro --device $(SIM_UDID) test --include-tags live maestro/flows

run: build boot ## Build, install and launch on the simulator (SCENARIO=catalog for stubs)
	xcrun simctl install $(SIM_UDID) $(APP)
	xcrun simctl launch --terminate-running-process $(SIM_UDID) com.tinyprocessing.catalog $(if $(SCENARIO),-uiTestScenario $(SCENARIO))

logs: ## Stream the app's logs from the booted simulator
	xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.tinyprocessing.catalog"'

format: ## Format Swift sources with the swift-format bundled in Xcode
	xcrun swift-format format --in-place --recursive App Packages/CatalogKit/Sources Tests

lint: ## Check formatting without changing files
	xcrun swift-format lint --strict --recursive App Packages/CatalogKit/Sources Tests

clean: ## Remove build output
	rm -rf build
