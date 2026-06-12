.PHONY: help install pods start build dev release clean typecheck test lint fix-dependencies bump permissions-reset

# ─── Usage: make <target> ────────────────────────────────────────────────────
# Run `make` or `make help` to list all targets with descriptions.

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

# ─── Setup ───────────────────────────────────────────────────────────────────

install: ## FIRST TIME / new machine: installs mise toolchain, bun packages, Ruby gems, and CocoaPods
	# Sets up the full dev environment from scratch.
	# Run once after cloning, or after pulling major dependency changes (package.json, Gemfile, Podfile).
	# Requires: mise (https://mise.jdx.dev) installed globally first.
	# NOTE: Ruby commands are prefixed with `mise exec --` to ensure mise's Ruby 3.2.8
	# is used instead of the macOS system Ruby (which is read-only and will error on gem install).
	mise install
	bun install
	mise exec -- gem install bundler
	mise exec -- bundle install

pods: ## NATIVE DEPS CHANGED: clean-reinstall CocoaPods and re-resolve Swift packages
	# Run when Podfile or Podfile.lock is out of date, or after a `pod install` error.
	# Also run after pulling upstream changes that touch the macos/ directory.
	# Slower than `install` — only needed when iOS/macOS native dependencies change.
	# `pod repo update` refreshes the local CocoaPods spec cache — required when a pod
	# version is not found locally (e.g. "CocoaPods could not find compatible versions for pod X").
	cd macos && rm -rf Podfile.lock && mise exec -- bundle exec pod repo update && mise exec -- bundle exec pod install && xcodebuild -resolvePackageDependencies -workspace sol.xcworkspace -scheme debug

# ─── Development ─────────────────────────────────────────────────────────────

start: ## JS DEV: start the Metro bundler (JS hot-reload server)
	# Run this first in one terminal before launching the app.
	# Metro watches src/ and serves the JS bundle to the running native app.
	# Keep it running; restart if you see stale bundle errors.
	bun start

build: ## DEBUG RUN: compile and launch the app in debug mode (connects to Metro)
	# Builds the native macOS shell and loads the JS bundle from Metro.
	# Requires Metro (`make start`) to be running in another terminal.
	# Use this for day-to-day feature work — fast native rebuild, hot JS reload.
	bun macos

dev: ## LOCAL RELEASE: build a release binary and install it to /Applications/Sol.app
	# Runs the Fastlane `dev` lane: release scheme build (no notarization, no publishing), installs to /Applications.
	# Use when you want to test a release build locally without going through the full publish pipeline.
	# Slower than `make build` — skips Metro, no hot reload, but produces a standalone .app.
	mise exec -- bundle exec fastlane dev && rimraf releases/Sol.app && open /Applications/Sol.app

# ─── Quality ─────────────────────────────────────────────────────────────────

typecheck: ## TYPE CHECK: run tsc --noEmit across all TypeScript source files
	# Checks types without emitting output. Fast, no build required.
	# Run before committing to catch type errors early.
	bun typecheck

test: typecheck ## ALL CHECKS: run every quality gate (currently typecheck; add more here)
	# Umbrella target — run before opening a PR.
	# Extend this target as unit/integration tests are added.

lint: ## LINT + FORMAT: run Biome check with auto-fix across the codebase
	# Biome handles both linting and formatting (replaces ESLint + Prettier).
	# Rewrites files in-place. Safe to run any time; review the diff afterward.
	bunx biome check --write .

# ─── Maintenance ─────────────────────────────────────────────────────────────

clean: ## CLEAN BUILD: delete Xcode build artifacts and DerivedData
	# Run when you get mysterious native build failures or cache-related errors.
	# Deletes macos/build and the Xcode DerivedData folder for this project.
	# Next `make build` will be a full recompile — slower but starts fresh.
	rm -rf macos/build
	rm -rf ~/Library/Developer/Xcode/DerivedData/sol-*
	rm -f fastlane/report.xml

fix-dependencies: ## DEPENDENCY DRIFT: align React Native package versions using rnx-align-deps
	# Run when you see peer dependency warnings or version mismatch errors after
	# adding/updating packages. Rewrites package.json version ranges to be consistent.
	# Follow up with `bun install` to apply the changes.
	bun fix-dependencies

bump: ## VERSION BUMP: increment the app version number in all required files
	# Increments the version in Info.plist and package.json together.
	# Run before `make release`, or to mark a checkpoint during development.
	bun bump

permissions-reset: ## PERMISSIONS: reset macOS Calendar and Accessibility grants for Sol
	# Run when permission dialogs stop appearing or the app loses system access.
	# macOS caches permission grants — this wipes them so the app re-requests on next launch.
	# Uses `tccutil reset` targeting com.ospfranco.sol.
	bun permissions:reset

# ─── Release ─────────────────────────────────────────────────────────────────

release: ## PUBLISH: full release pipeline — bump, build, notarize, zip, publish to GitHub
	# Runs the Fastlane `release` lane end-to-end:
	#   1. Bumps version
	#   2. Builds a signed release binary (gym)
	#   3. Notarizes with Apple
	#   4. Zips and uploads to GitHub Releases
	#   5. Regenerates the Sparkle appcast for auto-update
	#   6. Commits and pushes the release commit
	# Requires: GITHUB_API_TOKEN env var, Apple Developer credentials in keychain.
	bun release
