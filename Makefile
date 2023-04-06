PROJECTS = rtl8762ckf-dev-board

# Turn on increased build verbosity by defining BUILD_VERBOSE in your main
# Makefile or in your environment. You can also use V=1 on the make command
# line.
ifeq ("$(origin V)", "command line")
BUILD_VERBOSE=$(V)
endif
ifndef BUILD_VERBOSE
$(info Use make V=1 or set BUILD_VERBOSE in your environment to increase build verbosity.)
BUILD_VERBOSE = 0
endif
ifeq ($(BUILD_VERBOSE),0)
Q = @
else
Q =
endif

KICAD_CLI ?= kicad-cli
PDFUNITE ?= pdfunite
PCB_HELPER ?= ./scripts/pcb_helper.py
BOM_HELPER ?= ./scripts/bom_helper.py
NET_HELPER ?= ./scripts/net_helper.py
SED ?= sed
MKDIR ?= mkdir

PLOTS=$(addprefix exports/plots/, $(PROJECTS))
PLOTS_SCH=$(addsuffix -sch.pdf, $(PLOTS))
PLOTS_PCB=$(addsuffix -pcb.pdf, $(PLOTS))
PLOTS_ALL=$(PLOTS_SCH) $(PLOTS_PCB)

GERBER_DIRS=$(addprefix production/gbr/, $(PROJECTS))
GERBER_ZIPS=$(addsuffix .zip, $(GERBER_DIRS))

# POS = $(addprefix production/pos/, $(PROJECTS))
# POS_FRONT=$(addsuffix -front.csv, $(POS))
# POS_BACK=$(addsuffix -back.csv, $(POS))
# POS_ALL=$(POS_FRONT) $(POS_BACK)
POS_ALL = $(addprefix production/pos/, $(addsuffix .csv, $(PROJECTS)))

BOMS = $(addprefix production/bom/, $(addsuffix .csv, $(PROJECTS)))

HEADERS = $(addprefix exports/headers/, $(addsuffix /board_config.h, $(PROJECTS)))

all: $(PLOTS_ALL) $(GERBER_ZIPS) $(POS_ALL) $(BOMS)
.PHONY: all

plots: $(PLOTS_ALL)
.PHONY: plots

gerbers: $(GERBER_ZIPS)
.PHONY: gerbers

pos: $(POS_ALL)
.PHONY: pos

bom: $(BOMS)
.PHONY: bom

header: $(HEADERS)
.PHONY: header

exports/plots/%-sch.pdf: source/*/%.kicad_sch
	$(Q)$(KICAD_CLI) sch export pdf \
		"$<" \
		--output "$@"

exports/plots/%-pcb.pdf: source/*/%.kicad_pcb
	$(eval tempdir := $(shell mktemp -d))

	$(eval copper := $(shell $(PCB_HELPER) \
		--pcb "$<" \
		copper \
	))

	$(Q)n=0; \
	for layer in $(copper); \
	do \
		$(KICAD_CLI) pcb export pdf \
			--include-border-title \
			--layers "$$layer,Edge.Cuts" \
			"$<" \
			--output "$(tempdir)/$$(printf "%02d" $${n})-$*-$$layer.pdf"; \
		let "n+=1" ; \
	done

	$(Q)$(PDFUNITE) $(tempdir)/*-$*-*.pdf "$@" 2>/dev/null

	$(Q)rm -r $(tempdir)

production/gbr/%.zip: source/*/%.kicad_pcb
	$(eval stackup := Edge.Cuts $(shell $(PCB_HELPER) \
		--pcb "$<" \
		stackup \
	))

	$(Q)rm -rf production/gbr/$*
	$(Q)mkdir -p production/gbr/$*

	$(Q)for layer in $(stackup); \
	do \
		$(KICAD_CLI) pcb export gerber \
			--subtract-soldermask \
			--layers $$layer \
			"$<" \
			--output "production/gbr/$*/$*-$$layer.gbr"; \
	done
	$(Q)$(KICAD_CLI) pcb export drill \
		--excellon-separate-th \
		--units mm \
		"$<" \
		--output "production/gbr/$*/"

	$(Q)zip $@ production/gbr/$*/*

production/pos/%.csv: source/*/%.kicad_pcb
	$(Q)$(KICAD_CLI) pcb export pos \
		--format csv \
		--units mm \
		"$<" \
		--output "$@"
	$(Q)$(SED) \
		-e 's/Ref/Designator/' \
		-e 's/PosX/Mid X/' \
		-e 's/PosY/Mid Y/' \
		-e 's/Side/Layer/' \
		-e 's/Rot/Rotation/' \
		-i "$@"

production/bom/%.csv: source/*/%.kicad_sch
	$(Q)$(KICAD_CLI) sch export python-bom \
		"$<" \
		--output "production/bom/$*.xml"
	$(Q)$(BOM_HELPER) \
		--bom "production/bom/$*.xml" \
		--csv "$@"

source/*/%.net: source/*/%.kicad_sch
	$(Q)$(KICAD_CLI) sch export netlist \
		"$<" \
		--output "source/$*/$*.net"

exports/headers/%/board_config.h : source/*/%.net
	$(Q)$(MKDIR) -p exports/headers/$*/
	$(Q)$(NET_HELPER) \
		--net "$<" \
		--part RTL8762CKF \
		--output "$@"

clean:
	$(Q)rm -rf $(PLOTS_ALL)
	$(Q)rm -rf $(GERBER_DIRS)
	$(Q)rm -rf $(GERBER_ZIPS)
	$(Q)rm -rf $(POS_ALL)
	$(Q)rm -rf $(BOMS)
	$(Q)rm -rf $(PATTERN)
.PHONY: clean
