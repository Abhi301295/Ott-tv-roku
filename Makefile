# OTT Accelerator - Roku channel build/deploy
# Sideloads to a Roku device in developer mode.
#
# Usage:
#   make build                       # zip the channel into out/
#   make install ROKU_DEV_TARGET=<ip>  # build + sideload to device
#   make clean

APP_NAME          ?= ott-tv-roku
OUT_DIR           ?= out
ROKU_DEV_TARGET   ?= 192.168.1.100
ROKU_DEV_PASSWORD ?= rokudev

PKG_CONTENTS = manifest source components images fonts locale

.PHONY: build install clean

build:
	@mkdir -p $(OUT_DIR)
	@rm -f $(OUT_DIR)/$(APP_NAME).zip
	@zip -r -q $(OUT_DIR)/$(APP_NAME).zip $(PKG_CONTENTS) -x "*.DS_Store"
	@echo "Built $(OUT_DIR)/$(APP_NAME).zip"

install: build
	@curl -s -S -F "mysubmit=Install" -F "archive=@$(OUT_DIR)/$(APP_NAME).zip" \
		--user rokudev:$(ROKU_DEV_PASSWORD) --digest \
		http://$(ROKU_DEV_TARGET)/plugin_install > /dev/null
	@echo "Installed to $(ROKU_DEV_TARGET)"

clean:
	@rm -rf $(OUT_DIR)
	@echo "Cleaned $(OUT_DIR)"
