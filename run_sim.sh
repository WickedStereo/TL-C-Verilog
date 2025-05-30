#!/bin/bash

# TileLink Simulation Runner Script
# Usage: ./run_sim.sh [iverilog|verilator|both]

SIMULATOR=${1:-both}

echo "TileLink Simulation Runner"
echo "=========================="

# Function to run Icarus Verilog simulation
run_iverilog() {
    echo "Running Icarus Verilog simulation..."
    echo "Compiling with iverilog..."
    iverilog -o tb_tl_top_sim -I rtl/ tb/tb_tl_top.v tb/tb_tl_stimulus.v tb/tb_tl_monitor.v rtl/*.v
    
    if [ $? -eq 0 ]; then
        echo "Compilation successful. Running simulation..."
        vvp tb_tl_top_sim
        echo "Icarus Verilog simulation completed. VCD file: tb_tl_top.vcd"
    else
        echo "Icarus Verilog compilation failed!"
        return 1
    fi
}

# Function to run Verilator simulation
run_verilator() {
    echo "Running Verilator simulation..."
    echo "Compiling with Verilator..."
    verilator --cc --exe --build --trace tb/tb_tl_top_verilator.v tb/tb_tl_top_verilator.cpp rtl/*.v +incdir+rtl/ --top-module tb_tl_top_verilator -Wno-timescalemod -Wno-width -Wno-stmtdly
    
    if [ $? -eq 0 ]; then
        echo "Compilation successful. Running simulation..."
        ./obj_dir/Vtb_tl_top_verilator
        echo "Verilator simulation completed. VCD file: tb_tl_top_verilator.vcd"
    else
        echo "Verilator compilation failed!"
        return 1
    fi
}

# Function to open waveforms in GTKWave
open_waveforms() {
    echo "Opening waveforms in GTKWave..."
    if [ -f "tb_tl_top.vcd" ]; then
        echo "Opening Icarus Verilog waveform..."
        gtkwave tb_tl_top.vcd &
    fi
    
    if [ -f "tb_tl_top_verilator.vcd" ]; then
        echo "Opening Verilator waveform..."
        gtkwave tb_tl_top_verilator.vcd &
    fi
}

# Main execution logic
case $SIMULATOR in
    "iverilog")
        run_iverilog
        ;;
    "verilator")
        run_verilator
        ;;
    "both")
        echo "Running both simulators..."
        run_iverilog
        echo ""
        run_verilator
        echo ""
        echo "Do you want to open waveforms in GTKWave? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            open_waveforms
        fi
        ;;
    *)
        echo "Usage: $0 [iverilog|verilator|both]"
        echo "  iverilog  - Run only Icarus Verilog simulation"
        echo "  verilator - Run only Verilator simulation" 
        echo "  both      - Run both simulations (default)"
        exit 1
        ;;
esac

echo "Simulation(s) completed successfully!" 