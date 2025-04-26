# Zx-Spectrum-Cybernoid-Assembly

### Cybernoid: Z80 Assembly Archaeology
_Reverse engineering the 1988 ZX Spectrum shooter_

[![Platform](https://img.shields.io/badge/ZX_Spectrum-48K-red?logo=retroarch)](https://en.wikipedia.org/wiki/ZX_Spectrum)  

### Project Overview
A deep dive into how Cybernoid works, by studying its original Z80 machine code.

This project is a full disassembly of the ZX Spectrum version of Cybernoid.
I'm working to reverse-engineer the game, adding labels, comments, and notes to make the code easier to understand. It’s a big job, starting from address only assembly instructions.

![Cybernoid](/asm/images/cybernoid-1st-screen.png)  

I'm referencing the original disassembly by Derek Bolli [^1footnote]
, who did a fantastic job extracting the raw code. However, it's a plain instruction dump without labels, so all jumps are hardcoded to memory locations. My aim is to build on this and make it easier to follow.
[^1footnote]: *Original Disassembly by Derek Bolli:*
*Blog post: Cybernoid Disassembly for ZX Spectrum*\
*https://derekbolli.wordpress.com/2014/12/28/cybernoid-disassembly-for-zx-spectrum/*
*ZIP file (2015-01-01): Cybernoid-ZASM.zip*\
*https://www.dropbox.com/s/y4mhwtw5hpitxhr/cybernoid-zasm.zip?dl=1*
