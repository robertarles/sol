.PHONY: help install pods start build dev release clean typecheck test lint fix-dependencies bump permissions-reset

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

install: ## Install all dependencies (bun + gems + pods)
	mise install
	bun install
	gem install bundler
	bundle install

pods: ## Reinstall CocoaPods and resolve Xcode package dependencies
	cd macos && rm -rf Podfile.lock && bundle exec pod install && xcodebuild -resolvePackageDependencies -workspace sol.xcworkspace -scheme debug

start: ## Start the Metro bundler
	bun start

build: ## Build and run the debug app in the macOS simulator
	bun macos

dev: ## Build release via Fastlane and open /Applications/Sol.app
	bun dev

release: ## Full release: bump version, build, notarize, publish GitHub release
	bun release

bump: ## Bump the app version
	bun bump

typecheck: ## Run TypeScript type checking
	bun typecheck

test: typecheck ## Run all checks (typecheck; extend as tests are added)

lint: ## Lint and format with Biome
	bunx biome check --write .

clean: ## Remove build artifacts and derived data
	rm -rf macos/build
	rm -rf ~/Library/Developer/Xcode/DerivedData/sol-*
	rm -f fastlane/report.xml

fix-dependencies: ## Align React Native dependency versions
	bun fix-dependencies

permissions-reset: ## Reset macOS Calendar and Accessibility permissions for the app
	bun permissions:reset
