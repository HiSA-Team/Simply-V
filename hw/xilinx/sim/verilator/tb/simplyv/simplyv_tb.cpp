// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator testbench of the embedded SoC (simplyv_sim_wrapper).
//              Holds the core in reset, loads the program into BRAM_0 through the AXI
//              master VIP (as load_binary does on the FPGA), releases the core reset and
//              compares the UART output with the golden file: "[EMB] PASS" / exit 0 on
//              match, "[EMB] FAIL" / exit 1 otherwise.
//              Usage: Vsimplyv_sim_wrapper +BIN=<program.bin> [+STIMULUS=<file>] <golden>
//              +STIMULUS is sent on uart_rx_i once the firmware prints its prompt.

#include "Vsimplyv_sim_wrapper.h"
#include "verilated.h"
#include "axi_master.hpp"
#include "uart.hpp"

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

// gpio_in toggle period (ticks): each toggle raises a GPIO_IN interrupt (interrupts test).
// 4000 UART bits, longer than the handlers' printf, so the interrupts do not pile up
static constexpr long kGpioTogglePeriod = 4000L * SIM_UART_CYCLES_PER_BIT;
static constexpr const char* kPrompt = "Please enter a string";

static std::string read_file(const char* path) {
    std::ifstream f(path, std::ios::binary);
    return std::string(std::istreambuf_iterator<char>(f), std::istreambuf_iterator<char>());
}

static std::string escape(const std::string& s) {
    std::string out;
    for (unsigned char c : s) {
        if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c >= 0x20 && c < 0x7f) out += char(c);
        else { char b[8]; std::snprintf(b, sizeof(b), "\\x%02x", c); out += b; }
    }
    return out;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    const char *bin_path = nullptr, *stim_path = nullptr, *golden_path = nullptr;
    for (int i = 1; i < argc; ++i) {
        if (!std::strncmp(argv[i], "+BIN=", 5)) bin_path = argv[i] + 5;
        else if (!std::strncmp(argv[i], "+STIMULUS=", 10)) stim_path = argv[i] + 10;
        else if (argv[i][0] != '+' && argv[i][0] != '-') golden_path = argv[i];
    }
    const std::string bin = bin_path ? read_file(bin_path) : "";
    const std::string golden = golden_path ? read_file(golden_path) : "";
    if (bin.empty() || golden.empty()) {
        std::fprintf(stderr, "[EMB] usage: %s +BIN=<bin> [+STIMULUS=<file>] <golden>\n", argv[0]);
        return 2;
    }
    // scanf("%s") ends the token on whitespace: send exactly one '\n'
    std::string stimulus = stim_path ? read_file(stim_path) : "";
    while (!stimulus.empty() && (stimulus.back() == '\n' || stimulus.back() == '\r')) stimulus.pop_back();
    if (stim_path) stimulus += '\n';

    auto* top = new Vsimplyv_sim_wrapper;
    UartRx uart_rx(SIM_UART_CYCLES_PER_BIT);
    UartTx uart_tx(SIM_UART_CYCLES_PER_BIT);
    long cycles = 0;
    bool timeout = false;

    // One period of every clock: one clock in simulation, all the clock pins toggle together
    auto tick = [&] {
        if (++cycles > SIM_MAX_CYCLES) throw cycles;
        if (cycles % kGpioTogglePeriod == 0) top->gpio_in_i ^= 1;
        top->uart_rx_i = uart_tx.step();
        top->sys_clock_i = top->clk_10MHz_i = top->clk_20MHz_i = top->clk_50MHz_i = top->clk_100MHz_i = 1;
        top->eval();
        uart_rx.sample(top->uart_tx_o);
        top->sys_clock_i = top->clk_10MHz_i = top->clk_20MHz_i = top->clk_50MHz_i = top->clk_100MHz_i = 0;
        top->eval();
    };

    bool passed = false;
    AxiMaster<Vsimplyv_sim_wrapper> axi(*top, tick);
    try {
        // PLL not locked, core in reset
        top->sys_reset_i = 1;
        top->locked_i = 0;
        top->vio_resetn_i = 0;
        top->uart_rx_i = 1;
        top->gpio_in_i = 0;
        // Initial blocks run at the first eval: with the clocks low (unisim SRL init waits on them)
        top->eval();
        for (int i = 0; i < 16; ++i) tick();
        top->sys_reset_i = 0;
        top->locked_i = 1;
        for (int i = 0; i < 16; ++i) tick();

        axi.load(0, std::vector<uint8_t>(bin.begin(), bin.end()));
        std::printf("[EMB] loaded %zu bytes in %ld cycles\n", bin.size(), cycles);
        // From here on, cycles and SIM_MAX_CYCLES count from the core reset release, as on xsim
        cycles = 0;
        top->vio_resetn_i = 1;

        bool sent = false;
        for (size_t n = 0; !Verilated::gotFinish() && !passed; ) {
            tick();
            const std::string& cap = uart_rx.captured();
            if (cap.size() == n) continue;
            n = cap.size();
            if (!sent && !stimulus.empty() && cap.find(kPrompt) != std::string::npos) {
                uart_tx.send(stimulus);
                sent = true;
            }
            passed = cap.find(golden) != std::string::npos;
        }
    } catch (long) {
        timeout = true;
    }
    passed = passed && !axi.error();
    top->final();
    delete top;

    std::printf("[EMB] %ld cycles%s%s\n", cycles, timeout ? ", SIM_MAX_CYCLES reached" : "",
                axi.error() ? ", AXI error response" : "");
    std::printf("[EMB] captured: \"%s\"\n", escape(uart_rx.captured()).c_str());
    if (!passed) std::printf("[EMB] expected: \"%s\"\n", escape(golden).c_str());
    std::printf("[EMB] %s\n", passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}
