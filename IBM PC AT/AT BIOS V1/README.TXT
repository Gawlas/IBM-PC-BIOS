IBM PC AT BIOS dated 01/10/84 based on the BIOS listings in the IBM PC AT Technical Reference dated March 1984.
The BIOS was originally built using IBM MASM 1.0.

Notes:
- FILL.ASM was added to properly link the BIOS, this defines the area between the end of the main BIOS code and the ORGS data at E000.
- IAPX286.MAC was derived based upon the generated code in the listings.
- The code at FF5A in ORGS.ASM is hidden from the BIOS listings with .XLIST.
- Using MASM 2.0, the code generated for line 1852 of TEST1.ASM will not match the original BIOS:
        CMP     WORD PTR ES:[DI],0FFFFH
  MASM 1 generates: 26 81 3D FF FF
  MASM 2 generates: 26 83 3D FF

Additional files:
FILL.ASM - see above
ATLINK - linker response file
EXE2BIN - DEBUG script to convert the EXE file to a BIN file

Steps to build the PC AT BIOS:
for %a in (*.asm) do masm %a;
link @atlink
debug < exe2bin
