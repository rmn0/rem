

        ;; header.i

        ;; constants for the rom header


        xram_none		= $00
        xram_16kbit		= $01
        xram_64kbit		= $02
        xram_256kbit		= $03
        xram_512kbit		= $04
        xram_1mbit		= $05

        mode_20			= $20	; mode 20, 2.68 mhz (LoROM)
        mode_21			= $21	; mode 21, 2.68 mhz (HiROM)
        mode_23			= $23	; mode 23, 2.68 mhz (?)
        mode_25			= $25	; mode 25, 2.68 mhz (?)
        mode_20_fast		= $30	; mode 20, 3.58 mhz (LoROM, FastROM)
        mode_21_fast		= $31	; mode 21, 3.58 mhz (HiROM, FastROM)
        mode_25_fast		= $35	; mode 25, 3.58 mhz (?)

        cart_rom		= $00	; ROM Only
        cart_rom_ram		= $01	; ROM+RAM
        cart_rom_ram_batt	= $02	; ROM+RAM+BATTERY

        dest_japan		= $00
        dest_usa_canada		= $01
        dest_europe		= $02
        dest_scandanavia	= $03
        dest_french_europe	= $06
        dest_dutch		= $07
        dest_spanish		= $08
        dest_german		= $09
        dest_italian		= $0A
        dest_chinese		= $0B
        dest_korean		= $0D
        dest_common		= $0E
        dest_canada		= $0F
        dest_brazil		= $10
        dest_australia		= $11
        dest_otherx		= $12
        dest_othery		= $13
        dest_otherz		= $14
