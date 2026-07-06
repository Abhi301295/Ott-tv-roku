# OTT Accelerator - Roku channel build/deploy
#
# Usage:
#   make zip                           # validate (bsc) + zip into out/
#   make sim                           # zip + install to BrightScript Simulator
#   make smoke                         # validate + sim + scripts/smoke.sh (telnet assertions)
#   make install ROKU_DEV_TARGET=<ip>  # zip + sideload to a physical Roku
#   make clean
#
# IMPORTANT: Do not ship empty folders under components/, fonts/, or locale/.
# The BrightScript Simulator SceneGraph loader throws ENODATA and fails to
# register ANY components (including MainScene) when it hits an empty directory.

APP_NAME          ?= ott-tv-roku
OUT_DIR           ?= out
ROKU_DEV_TARGET   ?= 192.168.1.100
ROKU_DEV_PASSWORD ?= rokudev
ROKU_SIM_HOST     ?= 127.0.0.1
ROKU_SIM_PORT     ?= 8080

.PHONY: build zip validate install sim smoke clean icons

build: zip

icons:
	@python3 scripts/gen_menu_icons.py
	@echo "Regenerated images/ui/menu_*.png"

profile-square:
	@python3 scripts/gen_profile_square_arc.py
	@echo "Regenerated images/ui/profile_sq_*.png"

profile-circular-masks:
	@python3 scripts/gen_profile_circular_arc_geometry.py
	@echo "Regenerated images/ui/profile_arc_mask_*.png + avatar_ring.png"

# Simulator: pre-colored profile_arc_*.png (regenerate when portal colors change).
# Device: profile_arc_mask_*.png in pkg for runtime bake; colored arcs are fallback until bake completes.
profile-arcs: profile-circular-masks
	@python3 scripts/gen_profile_circular_arc_colored.py \
		--primary "$(or $(PORTAL_PRIMARY),#0b75e0)" \
		--secondary "$(or $(PORTAL_SECONDARY),#d355cb)" \
		--tertiary "$(or $(PORTAL_TERTIARY),#ff6b00)"
	@echo "Regenerated images/ui/profile_arc_*.png (fallback / sim portal colors)"

validate:
	@bsc --project bsconfig.json

# Only ship directories that contain real channel files.
zip: validate
	@mkdir -p $(OUT_DIR)
	@rm -f $(OUT_DIR)/$(APP_NAME).zip
	@zip -r -q $(OUT_DIR)/$(APP_NAME).zip manifest source components images \
		-x "*.DS_Store" -x "*/.gitkeep"
	@if [ -d fonts ] && [ -n "$$(find fonts -type f ! -name '.gitkeep' 2>/dev/null | head -1)" ]; then \
		zip -r -q $(OUT_DIR)/$(APP_NAME).zip fonts -x "*.DS_Store" -x "*/.gitkeep"; \
	fi
	@if [ -d locale ] && [ -n "$$(find locale -type f ! -name '.gitkeep' 2>/dev/null | head -1)" ]; then \
		zip -r -q $(OUT_DIR)/$(APP_NAME).zip locale -x "*.DS_Store" -x "*/.gitkeep"; \
	fi
	@if [ -f config.json ]; then zip -q $(OUT_DIR)/$(APP_NAME).zip config.json; fi
	@echo "Built $(OUT_DIR)/$(APP_NAME).zip"

sim:
	@python3 scripts/gen_livetv_dev_tz.py
	@$(MAKE) zip
	@bash scripts/roku-sim-deploy.sh

# Phase F: validate + sim deploy + telnet log assertions (requires brs-desktop).
smoke:
	@bash scripts/smoke.sh

install: zip
	@curl -s -S -F "mysubmit=Install" -F "archive=@$(OUT_DIR)/$(APP_NAME).zip" \
		--user rokudev:$(ROKU_DEV_PASSWORD) --digest \
		http://$(ROKU_DEV_TARGET)/plugin_install > /dev/null
	@echo "Installed to $(ROKU_DEV_TARGET)"

clean:
	@rm -rf $(OUT_DIR)
	@echo "Cleaned $(OUT_DIR)"
