
memory {

       hrom:	start = $0000, size = $8000, fill = yes;
       crom:	start = $8000, size = $7FB0, fill = yes;
       chead:	start = $FFB0, size = $50, fill = yes;

       rom1:	start = $C10000, size = $10000, fill = yes;
       rom2:	start = $C20000, size = $10000, fill = yes;
       rom3:	start = $C30000, size = $10000, fill = yes;
       rom4:	start = $C40000, size = $10000, fill = yes;
       rom5:	start = $C50000, size = $10000, fill = yes;
       rom6:	start = $C60000, size = $10000, fill = yes;
       rom7:	start = $C70000, size = $10000, fill = yes;
       rom8:	start = $C80000, size = $10000, fill = yes;
       rom9:	start = $C90000, size = $10000, fill = yes;
       roma:	start = $CA0000, size = $10000, fill = yes;
       romb:	start = $CB0000, size = $10000, fill = yes;
       romc:	start = $CC0000, size = $10000, fill = yes;
       romd:	start = $CD0000, size = $10000, fill = yes;
       rome:	start = $CE0000, size = $10000, fill = yes;
#       romf:	start = $CF0000, size = $10000, fill = yes;
#       rom10:	start = $D00000, size = $10000, fill = yes;

       zpage:	start = $0000, size = $100;	# 8k loram
       loram:	start = $0100, size = $1f00;	#
       hiram1:	start = $7E2000, size = $e000;	# 56k hiram1
       hiram2:	start = $7F0000, size = $10000;	# 64k hiram2

}

segments {

       code:		load = crom, type = ro;		# 32k code
       xcode:		load = hrom, type = ro, optional = yes;		# 32k xcode
       header:		load = chead, type = ro;	# cartridge header
       zeropage:	load = zpage, type = zp, optional = yes;	# zero page
       bss:		load = loram, type = bss, optional = yes;	# 8k (minus zpage) bss
       rodata:		load = rom1, type = ro, optional = yes;		# some rodata...

       hram:		load = hiram1, type = bss, optional = yes, align = $100;	# 56K+64K HRAM
       hram2:		load = hiram2, type = bss, optional = yes, align = $100;	#

       hdata:		load = rom1, run = hiram1, type = rw, define = yes, align = $100;

       code2:           load = rom2, type = ro, optional = yes;
       code3:           load = rom3, type = ro, optional = yes;
       code4:           load = rom4, type = ro, optional = yes;

       res0:	        load = rom5, type = ro, optional = yes;
       res1:	        load = rom6, type = ro, optional = yes;
       res2:	        load = rom7, type = ro, optional = yes;
       res3:	        load = rom8, type = ro, optional = yes;
       res4:	        load = rom9, type = ro, optional = yes;
       res5:	        load = roma, type = ro, optional = yes;
       res6:	        load = romb, type = ro, optional = yes;
       res7:	        load = romc, type = ro, optional = yes;
       res8:	        load = romd, type = ro, optional = yes;
       res9:	        load = rome, type = ro, optional = yes;
#       res10:	        load = romf, type = ro, optional = yes;
#       res11:	        load = rom10, type = ro, optional = yes;

}
