# f303_ice5_fm
An experiment with FPGA for FM audio synthesis.

## Background
This arose out of an interest in electronic music synthesis algorithms and in
particular the innovative way that Yamaha was able to achieve FM using
logarithmic math. I was guided by the approach used in the PPPlay
module player https://github.com/stohrendorf/ppplay but this design deviates
significantly in that it doesn't attempt to do any of the percussion and it
includes a more flexible routing approach that should allow extremely complex
FM algorithms.

## Implementation
This was built and tested out on a custom board comprised of an STM32F303
MCU and a Lattice ice5lp4k FPGA driving an I2S DAC. More detail about the
board is available here: http://ebrombaugh.studionebula.com/embedded/f303_ice5/index.html

## Status
This is working but incomplete - polyphonic audio can be played but setting up
the FM algorithms still has to be done by hand and there's no realtime control
on the patching.
