IBM PC XT BIOS dated 01/10/86 based on the BIOS listings in the IBM PC XT Technical Reference dated March 1986.
The BIOS was originally built using IBM MASM 2.0.

Notes:
- FILL.ASM was added to properly link the BIOS, this defines the area between the end of the main BIOS code and the ORGS data at E000.

Additional files:
FILL.ASM - see above
XTLINK - linker response file
EXE2BIN - DEBUG script to convert the EXE file to a BIN file

Steps to build the PC XT BIOS:
for %a in (*.asm) do masm %a;
link @xtlink
debug < exe2bin
