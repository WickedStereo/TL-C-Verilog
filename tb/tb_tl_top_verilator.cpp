#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_tl_top_verilator.h"

// Global time for Verilator
vluint64_t main_time = 0;

// This function is required by Verilator when using VCD tracing
double sc_time_stamp() {
    return main_time;
}

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);
    
    // Create an instance of our module under test
    Vtb_tl_top_verilator* top = new Vtb_tl_top_verilator;
    
    // Initialize VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("tb_tl_top_verilator.vcd");
    
    // Initialize simulation inputs
    top->clk = 0;
    top->rst_n = 0;
    top->eval();
    
    // Run simulation
    while (!Verilated::gotFinish() && main_time < 50000) {
        // Toggle clock every time step
        top->clk = !top->clk;
        
        // Release reset after 100 time steps
        if (main_time > 100) {
            top->rst_n = 1;
        }
        
        // Evaluate model
        top->eval();
        
        // Dump trace data for this cycle
        tfp->dump(main_time);
        
        // Increment simulation time
        main_time++;
    }
    
    // Final model evaluation
    top->final();
    
    // Close trace file
    tfp->close();
    
    // Clean up
    delete top;
    delete tfp;
    
    return 0;
} 