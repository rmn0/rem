

        ;; snes.i

        ;; snes register definitions
        

        .ifndef __SNES_INC__
        __SNES_INC__ = 1

        reg_inidisp	= $2100	; Screen Display Register		1B/W
        reg_objsel	= $2101	; OAM Size Control			1B/W
        reg_oamadd	= $2102	; OAM Access Address			2B/W
        reg_oamdata	= $2104	; OAM Data Write			1B/W
        reg_bgmode	= $2105	; Screen Mode Register			1B/W
        reg_mosaic	= $2106	; Screen Pixelation Register		1B/W
        reg_bgxsc	= $2107	; BG1-4 VRAM Location Register		1B/W
        reg_bg12nba	= $210b	; BG1/2 Character Bases			1B/W
        reg_bg34nba	= $210c	; BG3/4 Character Bases			1B/W
        reg_bgxhofs	= $210d	; BG1-4 Horizontal Scroll	        1B/W D
        reg_bgxvofs	= $210e	; BG1-4 Vertical Scroll	                1B/W D
        reg_vmainc	= $2115	; Video Port Control			1B/W
        reg_vmadd	= $2116	; Video Port Address			2B/W
        reg_vmdata	= $2118	; Video Port Data			2B/W
        reg_m7sel	= $211a	; MODE7 settings register		1B/W
        reg_m7a		= $211b	; MODE7 COSINE A			1B/W
        reg_m7b		= $211c	; MODE7 SINE	A			1B/W
        reg_m7c		= $211d	; MODE7 SINE	B			1B/W
        reg_m7d		= $211e	; MODE7 COSINE B			1B/W
        reg_m7x		= $211f	; MODE7 Center Pos X			1B/W D
        reg_m7y		= $2120	; MODE7 Center Pos Y			1B/W D
        reg_cgadd	= $2121	; CGRAM Address				1B/W
        reg_cgdata	= $2122	; CGRAM Data Write			1B/W D
        reg_w12sel	= $2123	; Window Mask Settings Reg1		1B/W
        reg_w34sel	= $2124	; Window Mask Settings Reg2		1B/W
        reg_wobjsel	= $2125	; Window Mask Settings Reg3		1B/W
        reg_whx		= $2126	; Window 1 / 2 Left / Right Posision 	1B/W
        reg_wbglog	= $212a	; Mask Logic for Window 1 & 2		1B/W
        reg_wobjlog	= $212b	; Mask Logic for Color&OBJ Windows	1B/W
        reg_tm		= $212c	; Main Screen Designation		1B/W
        reg_ts		= $212d	; Sub-Screen Designation		1B/W
        reg_tmw		= $212e	; WinMask Main Designation Reg		1B/W
        reg_tsw		= $212f	; WinMask Sub Designation Reg		1B/W
        reg_cgswsel	= $2130	; Fixed Color/Screen Addition Reg	1B/W
        reg_cgadsub	= $2131	; +/- For Screens/BGs/OBJs		1B/W
        reg_coldata	= $2132	; Fixed Color Data for +/-		1B/W
        reg_setini	= $2133	; Screen Mode Select Reg		1B/W
        reg_mpy 	= $2134	; Multiplication Result         	3B/R
        reg_slhv	= $2137	; Sofware Latch For H/V Counter		1B/R
        reg_oamdataread	= $2138	; OAM Data Read				1B/R
        reg_vmdataread	= $2139	; VRAM Data Read 			2B/R
        reg_cgdataread	= $213B	; CGRAM Data Read			1B/R
        reg_ophct	= $213C	; X Scanline Location			1B/R D
        reg_opvct	= $213D	; Y Scanline Location			1B/R D
        reg_stat77	= $213E	; PPU Status Flag & Version		1B/R
        reg_stat78	= $213F	; PPU Status Flag & Version		1B/R
        reg_apuiox	= $2140	; Sound Register 1 - 4			1B/RW
        reg_wmdata	= $2180	; WRAM Data Read/Write			1B/RW
        reg_wmadd	= $2181	; WRAM Address (Low)			3B/RW

        reg_nmitimen	= $4200	; Counter Enable			1B/W
        reg_wrio	= $4201	; Programmable I/O Port			1B/W
        reg_wrmpya	= $4202	; Multiplicand				1B/W
        reg_wrmpyb	= $4203	; Multiplier				1B/W
        reg_wrdiv	= $4204	; Dividend				2B/W
        reg_wrdivb	= $4206	; Divisor				1B/W
        reg_htime	= $4207	; Video X IRQ Beam Pointer		2B/W
        reg_vtime	= $4209	; Video Y IRQ Beam Pointer		2B/W
        reg_mdmaen	= $420B	; DMA Enable Register			1B/W
        reg_hdmaen	= $420C	; HDMA Enable Register			1B/W
        reg_memsel	= $420D	; Cycle Speed Register			1B/W
        reg_rdnmi	= $4210	; NMI Register				1B/R
        reg_timeup	= $4211	; Video IRQ Register			1B/RW
        reg_hvbjoy	= $4212	; Status Register			1B/RW
        reg_rdio	= $4213	; Programmable I/O Port			1B/RW
        reg_rddiv	= $4214	; Quotient Of Divide Result		2B/R
        reg_rdmpy	= $4216	; Multiplication Or Divide Result	2B/R
        reg_joyx	= $4218	; Joypad 1 - 4 Status			2B/R

        reg_dmapx	= $4300	; DMA Control Register			1B/W
        reg_bbadx	= $4301	; DMA Destination Register		1B/W
        reg_a1tx	= $4302	; DMA Source Address			2B/W
        reg_a1bx	= $4304	; Source Bank Address			1B/W
        reg_dasx	= $4305	; DMA Transfer size/HDMA Address	2B/W
        reg_a2ax	= $4308	
        reg_nltrx	= $430a	; Number Of Lines For HDMA		1B/W

        REG_FBNANACNT	= $FEED	; Felon's Banana Register		1B/RW

        .endif
