#include <verilated.h> // Defines common routines
#include "Vm_topsim.h" // From Verilating "top.v"

Vm_topsim *top;           // Instantiation of module
vluint64_t main_time = 0; // Current simulation time
                          // This is a 64-bit integer to reduce wrap over issues and
                          // allow modulus. You can also use a double, if you wish.

double sc_time_stamp () { // Called by $time in Verilog
    return main_time;     // converts to double, to match
                          // what SystemC does
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv); // Remember args
    top = new Vm_topsim;                // Create instance

    // register
    uint32_t CLK   = 0; // reg CLK = 0;
    uint32_t RST_X = 0; // reg RST_X;

    while (!Verilated::gotFinish()) {
        if (main_time == 6) {
            RST_X = 1;
        }
        if ((main_time % 2) == 0) {
            CLK = 0;
        }
        if ((main_time % 2) == 1) { 
            CLK = 1;
        }

        // Set some inputs
        top->CLK   = CLK;
        top->RST_X = RST_X;

        top->eval(); // Evaluate model
        main_time++; // Time passes...
    }
    top->final(); // Done simulating
    delete top;
}
