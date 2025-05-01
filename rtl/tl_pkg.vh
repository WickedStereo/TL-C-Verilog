`ifndef TL_PKG_VH
`define TL_PKG_VH

// Widths
`define TL_DATA_BYTES   8   // 64‑bit data bus
`define TL_ADDR_BITS   32
`define TL_SIZE_BITS    4
`define TL_SOURCE_BITS  3
`define TL_SINK_BITS    1

// Channel‑A opcodes (UL subset)
`define TL_A_PUTFULL      0
`define TL_A_PUTPARTIAL   1
`define TL_A_GET          4

// Channel‑D opcodes (UL subset)
`define TL_D_ACCESSACK     0
`define TL_D_ACCESSACKDATA 1

`endif