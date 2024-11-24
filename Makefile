#PREFIX := i686-w64-mingw32-
#OBJCOPY := $(PREFIX)objcopy
#CC := $(PREFIX)gcc
#AS := $(PREFIX)as

ifeq ($(strip $(DEVKITPPC)),)
$(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>devkitPPC")
endif

include $(DEVKITPPC)/wii_rules

#SDL_DIR := /home/pokeemerald/SDL2-2.0.14/i686-w64-mingw32
SDL_DIR := /d/devkitPro/portlibs/wii/include
ASM_PSEUDO_OP_CONV := sed -e 's/\.4byte/\.int/g;s/\.2byte/\.short/g'

export INCLUDE	:=  $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD) \
					-I$(LIBOGC_INC)
                    
LIBS	:= -lSDL2main -lSDL2 -lSDL2_test -lfat -laesnd -lwiiuse -lbte -logc -lm

export CPP := $(PREFIX)cpp
export LD := $(PREFIX)ld

ifeq ($(OS),Windows_NT)
EXE := .exe
else
EXE :=
endif

TITLE       := POKEMON EMER
GAME_CODE   := BPEE
MAKER_CODE  := 01
REVISION    := 0
MODERN      := 1

SHELL := /bin/bash -o pipefail

ELF = $(ROM:.exe=.elf)
MAP = $(ROM:.exe=.map)

C_SUBDIR = src
GFLIB_SUBDIR = gflib
ASM_SUBDIR = asm
DATA_SRC_SUBDIR = src/data
DATA_ASM_SUBDIR = data
SONG_SUBDIR = sound/songs
MID_SUBDIR = sound/songs/midi
SAMPLE_SUBDIR = sound/direct_sound_samples
CRY_SUBDIR = sound/direct_sound_samples/cries

C_BUILDDIR = $(OBJ_DIR)/$(C_SUBDIR)
GFLIB_BUILDDIR = $(OBJ_DIR)/$(GFLIB_SUBDIR)
ASM_BUILDDIR = $(OBJ_DIR)/$(ASM_SUBDIR)
DATA_ASM_BUILDDIR = $(OBJ_DIR)/$(DATA_ASM_SUBDIR)
SONG_BUILDDIR = $(OBJ_DIR)/$(SONG_SUBDIR)
MID_BUILDDIR = $(OBJ_DIR)/$(MID_SUBDIR)

ASFLAGS := 

GCC_VER := $(shell $(CC) -dumpversion)

CC1 	:= $(shell $(PREFIX)gcc --print-prog-name=cc1) -quiet
override CFLAGS += -MMD -MP -Wno-trigraphs -Wimplicit -Wparentheses -Wunused -std=gnu99 -fno-dce -fno-builtin -fsigned-char -Wno-unused-function -DPORTABLE -DNONMATCHING -D UBFIX -DMODERN=$(MODERN) $(MACHDEP)
ROM		:= pokeemerald.exe
OBJ_DIR	:= a/pc

CPPFLAGS := -iquote include -iquote $(GFLIB_SUBDIR) -Wno-trigraphs -D NONMATCHING -D PORTABLE -D MODERN=$(MODERN) -D UBFIX -I"/d/devkitPro/portlibs/wii/include" -I"/d/devkitpro/libogc/include"

LDFLAGS = -Map ../../$(MAP)

LIB := $(LIBPATH) -lgcc -lc

SHA1 := $(shell { command -v sha1sum || command -v shasum; } 2>/dev/null) -c
GFX := tools/gbagfx/gbagfx$(EXE)
AIF := tools/aif2pcm/aif2pcm$(EXE)
MID := tools/mid2agb/mid2agb$(EXE)
SCANINC := tools/scaninc/scaninc$(EXE)
PREPROC := tools/preproc/preproc$(EXE)
RAMSCRGEN := tools/ramscrgen/ramscrgen$(EXE)
FIX := tools/gbafix/gbafix$(EXE)
MAPJSON := tools/mapjson/mapjson$(EXE)
JSONPROC := tools/jsonproc/jsonproc$(EXE)

# Inclusive list. If you don't want a tool to be built, don't add it here.
TOOLDIRS := tools/aif2pcm tools/bin2c tools/gbafix tools/gbagfx tools/jsonproc tools/mapjson tools/mid2agb tools/preproc tools/ramscrgen tools/rsfont tools/scaninc
TOOLBASE = $(TOOLDIRS:tools/%=%)
TOOLS = $(foreach tool,$(TOOLBASE),tools/$(tool)/$(tool)$(EXE))

MAKEFLAGS += --no-print-directory

# Clear the default suffixes
.SUFFIXES:
# Don't delete intermediate files
.SECONDARY:
# Delete files that weren't built properly
.DELETE_ON_ERROR:

# Secondary expansion is required for dependency variables in object rules.
.SECONDEXPANSION:

.PHONY: all rom clean compare tidy tools mostlyclean clean-tools $(TOOLDIRS) libagbsyscall modern tidymodern tidynonmodern

infoshell = $(foreach line, $(shell $1 | sed "s/ /__SPACE__/g"), $(info $(subst __SPACE__, ,$(line))))

# Build tools when building the rom
# Disable dependency scanning for clean/tidy/tools
ifeq (,$(filter-out all rom compare modern,$(MAKECMDGOALS)))
$(call infoshell, $(MAKE) tools)
else
NODEP := 1
endif

C_SRCS_IN := $(wildcard $(C_SUBDIR)/*.c $(C_SUBDIR)/*/*.c $(C_SUBDIR)/*/*/*.c)
C_SRCS := $(foreach src,$(C_SRCS_IN),$(if $(findstring .inc.c,$(src)),,$(src)))
C_OBJS := $(patsubst $(C_SUBDIR)/%.c,$(C_BUILDDIR)/%.o,$(C_SRCS))

GFLIB_SRCS := $(wildcard $(GFLIB_SUBDIR)/*.c)
GFLIB_OBJS := $(patsubst $(GFLIB_SUBDIR)/%.c,$(GFLIB_BUILDDIR)/%.o,$(GFLIB_SRCS))

C_ASM_SRCS += $(wildcard $(C_SUBDIR)/*.s $(C_SUBDIR)/*/*.s $(C_SUBDIR)/*/*/*.s)
C_ASM_OBJS := $(patsubst $(C_SUBDIR)/%.s,$(C_BUILDDIR)/%.o,$(C_ASM_SRCS))

ASM_SRCS := $(wildcard $(ASM_SUBDIR)/*.s)
ASM_OBJS := $(patsubst $(ASM_SUBDIR)/%.s,$(ASM_BUILDDIR)/%.o,$(ASM_SRCS))

# get all the data/*.s files EXCEPT the ones with specific rules
REGULAR_DATA_ASM_SRCS := $(filter-out $(DATA_ASM_SUBDIR)/maps.s $(DATA_ASM_SUBDIR)/map_events.s, $(wildcard $(DATA_ASM_SUBDIR)/*.s))

DATA_ASM_SRCS := $(wildcard $(DATA_ASM_SUBDIR)/*.s)
DATA_ASM_OBJS := $(patsubst $(DATA_ASM_SUBDIR)/%.s,$(DATA_ASM_BUILDDIR)/%.o,$(DATA_ASM_SRCS))

SONG_SRCS := $(wildcard $(SONG_SUBDIR)/*.s)
SONG_OBJS := $(patsubst $(SONG_SUBDIR)/%.s,$(SONG_BUILDDIR)/%.o,$(SONG_SRCS))

MID_SRCS := $(wildcard $(MID_SUBDIR)/*.mid)
MID_OBJS := $(patsubst $(MID_SUBDIR)/%.mid,$(MID_BUILDDIR)/%.o,$(MID_SRCS))

OBJS     := $(C_OBJS) $(GFLIB_OBJS) $(ASM_OBJS) $(DATA_ASM_OBJS) $(SONG_OBJS) $(MID_OBJS)
OBJS_REL := $(patsubst $(OBJ_DIR)/%,%,$(OBJS))

SUBDIRS  := $(sort $(dir $(OBJS)))

AUTO_GEN_TARGETS :=

$(shell mkdir -p $(SUBDIRS))

all: rom

tools: $(TOOLDIRS)

$(TOOLDIRS):
	@$(MAKE) -C $@ CC=$(HOSTCC) CXX=$(HOSTCXX)

rom: $(ROM)
ifeq ($(COMPARE),1)
	@$(SHA1) rom.sha1
endif

# For contributors to make sure a change didn't affect the contents of the ROM.
compare: ; @$(MAKE) COMPARE=1

clean: mostlyclean clean-tools

clean-tools:
	@$(foreach tooldir,$(TOOLDIRS),$(MAKE) clean -C $(tooldir);)

mostlyclean: tidy
	rm -f $(SAMPLE_SUBDIR)/*.bin
	rm -f $(CRY_SUBDIR)/*.bin
	rm -f $(MID_SUBDIR)/*.s
	find . \( -iname '*.1bpp' -o -iname '*.4bpp' -o -iname '*.8bpp' -o -iname '*.gbapal' -o -iname '*.lz' -o -iname '*.rl' -o -iname '*.latfont' -o -iname '*.hwjpnfont' -o -iname '*.fwjpnfont' \) -exec rm {} +
	rm -f $(DATA_ASM_SUBDIR)/layouts/layouts.inc $(DATA_ASM_SUBDIR)/layouts/layouts_table.inc
	rm -f $(DATA_ASM_SUBDIR)/maps/connections.inc $(DATA_ASM_SUBDIR)/maps/events.inc $(DATA_ASM_SUBDIR)/maps/groups.inc $(DATA_ASM_SUBDIR)/maps/headers.inc
	find $(DATA_ASM_SUBDIR)/maps \( -iname 'connections.inc' -o -iname 'events.inc' -o -iname 'header.inc' \) -exec rm {} +
	rm -f $(AUTO_GEN_TARGETS)

tidy:
	rm -f $(ROM)$(EXE) $(ELF) $(MAP)
	rm -r $(OBJ_DIR)
ifeq ($(MODERN),0)
	@$(MAKE) tidy MODERN=1
endif

include graphics_file_rules.mk
include map_data_rules.mk
include spritesheet_rules.mk
include json_data_rules.mk
include songs.mk

%.s: ;
%.png: ;
%.pal: ;
%.aif: ;

%.1bpp: %.png  ; $(GFX) $< $@
%.4bpp: %.png  ; $(GFX) $< $@
%.8bpp: %.png  ; $(GFX) $< $@
%.gbapal: %.pal ; $(GFX) $< $@
%.gbapal: %.png ; $(GFX) $< $@
%.lz: % ; $(GFX) $< $@
%.rl: % ; $(GFX) $< $@
$(CRY_SUBDIR)/%.bin: $(CRY_SUBDIR)/%.aif ; $(AIF) $< $@ --compress
sound/%.bin: sound/%.aif ; $(AIF) $< $@

#%src/platform/sdl2.o: CFLAGS += -fleading-underscore

ifeq ($(NODEP),1)
$(C_BUILDDIR)/%.o: c_dep :=
else
$(C_BUILDDIR)/%.o: c_dep = $(shell [[ -f $(C_SUBDIR)/$*.c ]] && $(SCANINC) -I include -I tools/agbcc/include -I gflib $(C_SUBDIR)/$*.c)
endif

ifeq ($(DINFO),1)
override CFLAGS += -g -O0
else
override CFLAGS += -g -O3
endif

$(C_BUILDDIR)/%.o : $(C_SUBDIR)/%.c $$(c_dep)
	@$(CPP) $(CPPFLAGS) $< -o $(C_BUILDDIR)/$*.i
	@$(PREPROC) $(C_BUILDDIR)/$*.i charmap.txt | $(CC1) $(CFLAGS) -o $(C_BUILDDIR)/$*.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $(C_BUILDDIR)/$*.s
	$(AS) $(ASFLAGS) -o $@ $(C_BUILDDIR)/$*.s

ifeq ($(NODEP),1)
$(GFLIB_BUILDDIR)/%.o: c_dep :=
else
$(GFLIB_BUILDDIR)/%.o: c_dep = $(shell [[ -f $(GFLIB_SUBDIR)/$*.c ]] && $(SCANINC) -I include -I tools/agbcc/include -I gflib $(GFLIB_SUBDIR)/$*.c)
endif

$(GFLIB_BUILDDIR)/%.o : $(GFLIB_SUBDIR)/%.c $$(c_dep)
	@$(CPP) $(CPPFLAGS) $< -o $(GFLIB_BUILDDIR)/$*.i
	@$(PREPROC) $(GFLIB_BUILDDIR)/$*.i charmap.txt | $(CC1) $(CFLAGS) -o $(GFLIB_BUILDDIR)/$*.s
	@echo -e ".text\n\t.align\t2, 0\n" >> $(GFLIB_BUILDDIR)/$*.s
	$(AS) $(ASFLAGS) -o $@ $(GFLIB_BUILDDIR)/$*.s

# The dep rules have to be explicit or else missing files won't be reported.
# As a side effect, they're evaluated immediately instead of when the rule is invoked.
# It doesn't look like $(shell) can be deferred so there might not be a better way.


ifeq ($(NODEP),1)
$(ASM_BUILDDIR)/%.o: $(ASM_SUBDIR)/%.s
	$(AS) $(ASFLAGS) -o $@ $<
else
define ASM_DEP
$1: $2 $$(shell $(SCANINC) -I include -I "" $2)
	$$(AS) $$(ASFLAGS) -o $$@ $$<
endef
$(foreach src, $(ASM_SRCS), $(eval $(call ASM_DEP,$(patsubst $(ASM_SUBDIR)/%.s,$(ASM_BUILDDIR)/%.o, $(src)),$(src))))
endif

ifeq ($(NODEP),1)
$(DATA_ASM_BUILDDIR)/%.o: $(DATA_ASM_SUBDIR)/%.s
	$(PREPROC) $< charmap.txt | $(CPP) -I include | $(ASM_PSEUDO_OP_CONV) | $(AS) $(ASFLAGS) -o $@
else
define DATA_ASM_DEP
$1: $2 $$(shell $(SCANINC) -I include -I "" $2)
	$$(PREPROC) $$< charmap.txt | $$(CPP) -I include | $$(ASM_PSEUDO_OP_CONV) | $$(AS) $$(ASFLAGS) -o $$@
endef
$(foreach src, $(REGULAR_DATA_ASM_SRCS), $(eval $(call DATA_ASM_DEP,$(patsubst $(DATA_ASM_SUBDIR)/%.s,$(DATA_ASM_BUILDDIR)/%.o, $(src)),$(src))))
$(foreach src, $(C_ASM_SRCS), $(eval $(call DATA_ASM_DEP,$(patsubst $(C_SUBDIR)/%.s,$(C_BUILDDIR)/%.o, $(src)),$(src))))
endif

$(SONG_BUILDDIR)/%.o: $(SONG_SUBDIR)/%.s
	$(ASM_PSEUDO_OP_CONV) $< | $(AS) $(ASFLAGS) -I sound -o $@

$(OBJ_DIR)/sym_bss.ld: sym_bss.txt
	$(RAMSCRGEN) .bss $< ENGLISH > $@

$(OBJ_DIR)/sym_common.ld: sym_common.txt $(C_OBJS) $(wildcard common_syms/*.txt)
	$(RAMSCRGEN) COMMON $< ENGLISH -c $(C_BUILDDIR),common_syms > $@

$(OBJ_DIR)/sym_ewram.ld: sym_ewram.txt
	$(RAMSCRGEN) ewram_data $< ENGLISH > $@

LD_SCRIPT := ld_script_pc.ld
LD_SCRIPT_DEPS := 

$(OBJ_DIR)/ld_script.ld: $(LD_SCRIPT) $(LD_SCRIPT_DEPS)
	cd $(OBJ_DIR) && sed "s#tools/#../../tools/#g" ../../$(LD_SCRIPT) > ld_script.ld

$(ELF): $(OBJ_DIR)/ld_script.ld $(OBJS)
	cd $(OBJ_DIR) && $(LD) $(LDFLAGS) -T ld_script.ld -o ../../$@ $(OBJS_REL) $(LIB)
	$(FIX) $@ -t"$(TITLE)" -c$(GAME_CODE) -m$(MAKER_CODE) -r$(REVISION) --silent

$(ROM): $(OBJS)
#	$(LD) -g -DGEKKO -mrvl -mcpu=750 -meabi -Wl,--demangle $^ -L/opt/devkitpro/libogc/lib/wii -L/opt/devkitpro/portlibs/wii/lib -L/opt/devkitpro/portlibs/ppc/lib -lSDL2main -lSDL2 -lSDL2_test -lfat -laesnd -lwiiuse -lbte -logc -lm -o $@
	$(CC) $(CFLAGS) -Wl,--demangle $^ -L/opt/devkitpro/libogc/lib/wii -L/opt/devkitpro/portlibs/wii/lib -L/opt/devkitpro/portlibs/ppc/lib  -lSDL2main -lSDL2 -lfat -laesnd -lwiiuse -lbte -logc -lm -o pokeemerald.elf
