

# Rem

This is my hombrew SNES game project, Rem.

Please note that this is an early state and while you should get it to compile, it has some awkward dependencies that could make it unneccessarily difficult for you to build it. They are there because I had the tools lying around anyways, and was too lazy to remove those. This will change in the future however.

Nevertheless, I have tried to document the source in many places and keep it as tidy as possible so maybe it is still of use to some people in its current state.

I still need to add a proper license to this, however you can feel free to use it in any way you like...




# How to set up and build the project

The project is currently only known to build on linux. You need the standard gnu toolchain.

Make sure you have the required dependencies listed below installed. If necessary, adjust the paths in the makefile for LD, AS, smconv, and superfamicheck, and bsnes.

Type "make" and it should build an sfc rom file.
Type "make run" and it should start up in the bsnes emulator, if configured.



# Required Dependencies

[https://cc65.github.io/]
macro compiler for 6502 family CPUs.

[http://snes.mukunda.com/]
SNES Impulse Tracker Module Player.

[http://giflib.sourceforge.net/]
Gif library.

[https://www.winehq.org/]
Sorry about this one, this dependency will be removed in the future.

[https://www.php.net/]
Sorry about this one, this dependency will be removed in the future.



# Optional Dependencies

[https://github.com/devinacker/bsnes-plus]
fork of BSNES with debugging features.

[http://schismtracker.org/]
reimplementation of Impulse Tracker.

[http://grafx2.chez.com/]
pixel art paint program like Deluxe Paint

[https://www.mapeditor.org/]
Tiled tile map editor



# Toolchain Documentation



## bitsc

Convert an rri file (streamed from stdin) to one or more raw tile resources files

### options

**-h** *tile height*
Set tile height (default = 8)

**-w** *tile width*
Set tile width (default = 8)

**-b** *bit planes*
Set number of bit planes (default = 4). Possible values are 1, 2, 4, or 8.

**-o** *output file*
Name of output file

**-s**
Split file. If set, each layer in the input file will be written into a seperate resource file.
The resulting files will be named "filename.0.extension".

**-p**
Write the palette to the end of the resource file(s)

**-e**
Do not emit empty layers

**-v**
Be more verbose



## blit

Code generator for optimized blitting routines.



## bytesc

Shuffle regions from an rri file into seperate layers.

The input is read from stdin. The output is written to stdout.

There has to be exactly one layer in the input file.

### options

**-h** *layer height*
Set layer height (default = 8)

**-w** *layer width*
Set layer width (default = 8)

**-w** *tilemap file*
Detect unique tiles and only emit each tile once, and generate a tilemap file.

**-v**
Be more verbose


## gifr

Extracts one or multiple frames or palette data from a GIF file.

An rri file is written to stdout

### options

**-f** *file*
GIF file name

**-n** *frame no*
Write a specific frame. If not set, all the frames are written stacked vertically on top of each other.

**-v**
Be more verbose



## mapc.php

Convert a tiled json file to an rrl file.

The json file is passed as the only command line argument and the result is written to stdout.

The script is hard coded to expect three tilesets named "tileset", "light", and "vis".

Sorry that this is a php file. Will be replaced with C later to remove the php dependency.



## mapd.php

This is a stub to generate some random lighting data. Will be replaced with something better using 2d raytracing / global illumination.



## palc

convert a palette file emitted by GrafX2 to an assembly resource file.



## resp

Searches a directory for files and generates an include file for the files.
In the default mode, bank (.b) and resource (.r) files will be included as binary includes.
*resp* will try to fit the resources into 64kbyte banks, without crossing page boundaries.
Bank data will be aligned with the start of a bank.
Additionally, labels for the resources will be created.

### options

**-b** *bank*
Starting bank (default = 0)

**-d** *directory*
The directory to search for files

**-o** *filename*
Output include filename

**-i**
Toggle include mode.
In include mode, *resp* will search for include (.i) files and include those in the output file.

**-v**
Be more verbose



## room

Extract room data from an rrl file.

The rrl file is read from stdin. The result is written to stdout.

The room size is hardcoded to 16x16 tiles. The input data is expected to contain 4 layers. Layer 3 is expected to be the light layer and will use the second tileset. The other three layers should contain background data.

If there are tiles in both layer 1 and 2, these will be used for BG 1 and BG 2 and layer 0 will be ignored. The priority bit will be set for both layers.

If there is a tile in only one of the layers 1 and 2, this tile will be used for BG 1



## spriteas

Process sprite images.

### options

**-a** *filename*
Annotation filename

**-v**
Be more verbose



## vis

Code generator for optimized visibility / lighting routines.




# Other Links

[https://github.com/Optiroc/libSFX]
SNES development framework.

[https://github.com/Optiroc/SuperFamiconv]
tile graphics converter

[http://6502.org/tutorials/65c816opcodes.html]
68516 instruction set
