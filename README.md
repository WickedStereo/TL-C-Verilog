# TileLink Protocol Implementation

This repository contains a Verilog implementation of the TileLink protocol with support for both **Icarus Verilog** and **Verilator** simulators.

## Project Structure

```
TL-C-Verilog/
├── rtl/                           # RTL source files
│   ├── tl_top.v                   # Top-level module
│   ├── tl_l1_adapter.v            # L1 cache adapter (master)
│   ├── tl_l2_adapter.v            # L2 cache adapter (slave)
│   ├── tl_interconnect.v          # TileLink interconnect
│   ├── tl_memory.v                # Memory model
│   └── tl_pkg.vh                  # Package definitions
├── tb/                            # Testbench files
│   ├── tb_tl_top.v                # Top-level testbench (Icarus)
│   ├── tb_tl_stimulus.v           # Stimulus generator (Icarus)
│   ├── tb_tl_monitor.v            # Transaction monitor (Icarus)
│   ├── tb_tl_top_verilator.v      # Simplified testbench (Verilator)
│   └── tb_tl_top_verilator.cpp    # C++ wrapper (Verilator)
└── run_sim.sh                     # Simulation runner script
```

## Features

- **TileLink UL (Uncached Lightweight) Protocol**: Supports GET, PUTFULL, and PUTPARTIAL operations
- **Dual Simulator Support**: Compatible with both Icarus Verilog and Verilator
- **Comprehensive Testbench**: Includes stimulus generation and transaction monitoring
- **Waveform Generation**: Produces VCD files for analysis in GTKWave

## Requirements

### Software Dependencies
- **Icarus Verilog** (`iverilog` and `vvp`)
- **Verilator** (for faster simulation)
- **GTKWave** (for waveform viewing)
- **GCC/G++** (for Verilator C++ compilation)

### Installation (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install iverilog verilator gtkwave build-essential
```

## Running Simulations

### Quick Start
The easiest way to run simulations is using the provided script:

```bash
# Run both simulators
./run_sim.sh

# Run only Icarus Verilog
./run_sim.sh iverilog

# Run only Verilator
./run_sim.sh verilator
```

### Manual Execution

#### Icarus Verilog
```bash
# Compile
iverilog -o tb_tl_top_sim -I rtl/ tb/tb_tl_top.v tb/tb_tl_stimulus.v tb/tb_tl_monitor.v rtl/*.v

# Run simulation
vvp tb_tl_top_sim

# View waveforms
gtkwave tb_tl_top.vcd
```

#### Verilator
```bash
# Compile and build
verilator --cc --exe --build --trace tb/tb_tl_top_verilator.v tb/tb_tl_top_verilator.cpp rtl/*.v +incdir+rtl/ --top-module tb_tl_top_verilator -Wno-timescalemod -Wno-width -Wno-stmtdly

# Run simulation
./obj_dir/Vtb_tl_top_verilator

# View waveforms
gtkwave tb_tl_top_verilator.vcd
```

## Simulation Differences

### Icarus Verilog
- **Full testbench features**: Complex timing controls, wait statements, and procedural blocks
- **Comprehensive monitoring**: Detailed transaction verification and error checking
- **Longer simulation**: Runs 10 test cases with complete stimulus/response verification
- **Output file**: `tb_tl_top.vcd`

### Verilator
- **Synthesizable testbench**: State machine-based approach compatible with Verilator
- **Faster simulation**: C++ compilation provides better performance
- **Simplified tests**: 4 basic test cases (GET, PUTFULL, PUTPARTIAL, verify)
- **Output file**: `tb_tl_top_verilator.vcd`

## Test Cases

The testbench validates the following TileLink operations:

1. **GET Operation**: Read data from memory
2. **PUTFULL Operation**: Write complete data words
3. **PUTPARTIAL Operation**: Write partial data with byte masks
4. **Read-after-Write**: Verify data integrity
5. **Multiple Source IDs**: Test transaction routing
6. **Address Patterns**: Various memory locations

## Protocol Support

This implementation supports the **TileLink UL (Uncached Lightweight)** subset:

### Channel A (Request) Operations
- `GET`: Read data from address
- `PUTFULL`: Write full data word
- `PUTPARTIAL`: Write partial data with byte mask

### Channel D (Response) Operations
- `AccessAck`: Acknowledgment for write operations
- `AccessAckData`: Data response for read operations

## Waveform Analysis

Key signals to observe in GTKWave:

- **Clock and Reset**: `clk`, `rst_n`
- **L1 Channel A**: `l1_a_valid`, `l1_a_ready`, `l1_a_opcode`, `l1_a_address`, `l1_a_data`
- **L1 Channel D**: `l1_d_valid`, `l1_d_ready`, `l1_d_opcode`, `l1_d_data`
- **Memory Operations**: `mem_write_valid`, `mem_read_valid`, `mem_write_data`, `mem_read_data`
- **Transaction Control**: `start_transaction`, `transaction_done`, `transaction_type`

## Known Limitations

1. **Verilator Constraints**: Some testbench features are simplified due to Verilator's synthesis-oriented approach
2. **Memory Size**: Fixed 1024-word memory model
3. **Single Master/Slave**: Current interconnect supports only one master and one slave
4. **UL Subset Only**: Does not implement coherence protocols (UC/UH/C)

## Contributing

To extend this implementation:

1. **Add More Operations**: Implement additional TileLink operations
2. **Multi-Master Support**: Extend interconnect for multiple masters
3. **Cache Coherence**: Add support for coherent TileLink protocols
4. **Performance Counters**: Add transaction latency and bandwidth monitoring

## License

This project is provided as educational material for understanding TileLink protocol implementation. 