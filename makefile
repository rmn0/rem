
SHELL = /bin/bash

# directories

TOOLSDIR = tools
SRCDIR = src
RESDIR = res
OBJDIR = obj
DATADIR = data


# linker and assembler

LD = ../sneskit/cc65/bin/ld65
AS = ../sneskit/cc65/bin/ca65

LDFLAGS =
ASFLAGS = -g -U


# third party tools

smconv = wine ../libSFX/smconv.exe
superfamicheck = ../libSFX/tools/superfamicheck/bin/superfamicheck

# tool binaries

TFLAGS = -v

gifr = $(TOOLSDIR)/gifr
bitsc = $(TOOLSDIR)/bitsc
bytesc = $(TOOLSDIR)/bytesc
room = $(TOOLSDIR)/room
mapc = php $(TOOLSDIR)/mapc.php
spriteas = $(TOOLSDIR)/spriteas
palc = $(TOOLSDIR)/palc
resp = $(TOOLSDIR)/resp
blit = $(TOOLSDIR)/blit
vis = $(TOOLSDIR)/vis

TOOLSRCS = $(shell find $(TOOLSDIR) -name '*.c')
TOOLS = $(patsubst $(TOOLSDIR)/%.c,$(TOOLSDIR)/%,$(TOOLSRCS))


# emulator

bsnes = ../bsnes-plus/bsnes/out/bsnes


# assembly sources, objects and dependencies

SRCS = $(shell find $(SRCDIR) -name '*.s')
OBJS = $(patsubst $(SRCDIR)/%.s,$(OBJDIR)/%.o,$(SRCS))
DEP = $(OBJS:%.o=%.d)


# resources

RES =\
title.screen.r castle.screen.r help.screen.r end.screen.r title.pal.i\
driver.spc\
sound_test.b ambient.b clock.b\
debug.dtil\
glyphdata.bin\
tileset.til\
light.ltil\
border.stil snow.stil keys.stil\
test.room\
idle.ani walking.ani running.ani sliding.ani jumping.ani falling.ani walljump.ani dangling.ani crouching.ani\
sprite.pal.i keys.pal.i light.pal.i\
blit.i vis.i

RESS = $(patsubst %,$(RESDIR)/%,$(RES))

RESI = $(RESDIR)/res.i
INCI = $(SRCDIR)/../$(RESDIR)/inc.i



# recipes



.precious : $(RESS)


# main target

rem.sfc : $(OBJS)
	$(LD) $(LDFLAGS) -C config.ld -o $@ -m rem.map $^
	$(superfamicheck) -f $@


# spc driver

$(RESDIR)/driver.spc : $(OBJDIR)/driver.o700
	$(LD) $(LDFLAGS) -C spc700.ld -o $@ $^


# object files and dependencies

-include $(DEP)

$(OBJDIR)/%.o : $(SRCDIR)/%.s $(DEP)

$(OBJDIR)/res.o : $(SRCDIR)/res.s $(INCI) $(DEP)

$(OBJDIR)/%.o : $(SRCDIR)/%.s $(DEP)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/%.o700 : $(SRCDIR)/%.s700
	$(AS) $(ASFLAGS) -D TARGET_SMP -o $@ $<

$(OBJDIR)/%.d : $(SRCDIR)/%.s
	@((grep -hPo '\.include "\K.*?(?=")' $< | grep "^[^.]" \
	| tee >(sed 's"^"$(SRCDIR)/"' | xargs -d'\n'	       \
	grep -hPo '\.include "\K.*?(?=")' | grep "^[^.]" >&3)) \
	3>&1) | sed 's"^"$(OBJDIR)/$*.o : $(SRCDIR)/"' > $@


# resource includes

$(INCI) : $(RESI) $(resp)
	$(resp) -d $(RESDIR)/ -i -o $@

$(RESI) : $(RESS) $(resp)
	$(resp) -d $(RESDIR)/ -o $@


# tilesets

$(RESDIR)/%.til : $(DATADIR)/%.gif $(gifr) $(bytesc) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bytesc) $(TFLAGS) -w 128 -h 128 | $(bitsc) $(TFLAGS) -p -e -s -o $(RESDIR)/$*.r
	touch $@


# light tileset

$(RESDIR)/%.ltil : $(DATADIR)/%.gif $(gifr) $(bytesc) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bytesc) $(TFLAGS) -w 32 -h 8 | $(bitsc) $(TFLAGS) -p -b 2 -o $(RESDIR)/$*.r
	touch $@


# debug tileset

$(RESDIR)/%.dtil : $(DATADIR)/%.gif $(gifr) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bitsc) $(TFLAGS) -p -b 2 -o $(RESDIR)/$*.r
	touch $@


# sprite tiles

$(RESDIR)/%.stil : $(DATADIR)/%.gif $(gifr) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bitsc) $(TFLAGS) -o $(RESDIR)/$*.r
	touch $@


# room data

$(RESDIR)/%.room : $(DATADIR)/%.json $(room)
	$(mapc) $< | $(room) $(TFLAGS) -o $(RESDIR)/$*.room.r -i $(RESDIR)/$*_info.i > $(RESDIR)/$*.i
	touch $@


# sound bank

$(RESDIR)/%.b : $(DATADIR)/%.it
	$(smconv) $(TFLAGS) -o $(RESDIR)/$* --hirom --soundbank $<
	mv $(RESDIR)/$*.bank $@


# sprite animations

$(RESDIR)/%.ani : $(DATADIR)/%.gif $(gifr) $(spriteas) $(bitsc)
	$(gifr) $(TFLAGS) -f $< | $(spriteas) $(TFLAGS) -a $(RESDIR)/$*.i | $(bitsc) $(TFLAGS) -s -o $(RESDIR)/$*.frame.r
	touch $@


# sprite and light palettes

$(RESDIR)/%.pal.i : $(DATADIR)/%.pal $(palc)
	echo .segment \"rodata\" > $@
	echo .export $*_palette >> $@
	echo $*_palette: >> $@
	cat $< | $(palc) >> $@

# font data

$(RESDIR)/glyphdata.bin : $(DATADIR)/font.gif $(gifr) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 1 | $(bitsc) $(TFLAGS) -b 1 -h 16 -o $@


# screens

$(RESDIR)/%.screen.r : $(DATADIR)/%.gif $(gifr) $(bytesc) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bytesc) $(TFLAGS) -w 8 -h 8 -t $@ | $(bitsc) $(TFLAGS) -o $(RESDIR)/$*.tiles.r

$(RESDIR)/title.screen.r : $(DATADIR)/title.gif $(gifr) $(bytesc) $(bitsc)
	$(gifr) $(TFLAGS) -f $< -n 0 | $(bytesc) $(TFLAGS) -w 8 -h 8 -t $@ -b 8448 | $(bitsc) $(TFLAGS) -o $(RESDIR)/title.tiles.r



# generated assembly

$(RESDIR)/blit.i : $(blit)
	$(blit) > $@

$(RESDIR)/vis.i : $(vis)
	$(vis) > $@


# tools

$(TOOLS) : % : %.c
	cd tools && make


# tasks

clean :
	rm -f rem.sfc $(RESDIR)/* $(OBJDIR)/*

cs :
	@grep -n -E "*" $(SRCS) | sed -e 'N;s/;.*$$//p'  | grep --color=always -E '(\#|[[:space:]])[0-9]{1,4}' || true
	@grep --color=always -E -n "^[[:space:]]*[r,s]ep" $(SRCS)
	@grep --color=always -E -i -n  "todo" $(SRCS)

tools : $(TOOLS)

run : rem.sfc
	$(bsnes) rem.sfc
