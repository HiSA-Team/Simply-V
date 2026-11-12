// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: UART 8N1 VIP for the Verilator testbench, one step per testbench tick.
//              UartRx decodes uart_tx_o, sampling each bit at the middle of its period;
//              UartTx serialises a string onto uart_rx_i. The bit period, in ticks,
//              comes from the uartlite configuration (sim.mk).

#ifndef SIMPLYV_UART_HPP
#define SIMPLYV_UART_HPP

#include <cstdint>
#include <string>

class UartRx {
public:
    explicit UartRx(int cycles_per_bit) : cpb_(cycles_per_bit) {}

    // Feed the current level of the line
    void sample(uint8_t line) {
        line &= 1;
        switch (state_) {
        case IDLE:
            if (prev_ && !line) { state_ = START; ctr_ = 0; }
            break;
        case START:
            // Confirm the start bit at mid-bit
            if (++ctr_ >= cpb_ / 2) { state_ = line ? IDLE : DATA; ctr_ = 0; bit_ = 0; byte_ = 0; }
            break;
        case DATA:
            if (++ctr_ >= cpb_) {
                ctr_ = 0;
                byte_ |= uint8_t(line << bit_);
                if (++bit_ == 8) state_ = STOP;
            }
            break;
        case STOP:
            if (++ctr_ >= cpb_) { captured_.push_back(char(byte_)); state_ = IDLE; }
            break;
        }
        prev_ = line;
    }

    const std::string& captured() const { return captured_; }

private:
    enum State { IDLE, START, DATA, STOP };
    const int   cpb_;
    State       state_ = IDLE;
    int         ctr_ = 0, bit_ = 0;
    uint8_t     byte_ = 0, prev_ = 1;
    std::string captured_;
};

class UartTx {
public:
    explicit UartTx(int cycles_per_bit) : cpb_(cycles_per_bit) {}

    void send(const std::string& s) { data_ += s; }

    // Level to drive for this tick: start bit, 8 data bits LSB first, stop bit
    uint8_t step() {
        if (idx_ >= data_.size()) return 1;
        const int bit = ctr_ / cpb_;
        const uint8_t level = bit == 0 ? 0 : bit <= 8 ? (uint8_t(data_[idx_]) >> (bit - 1)) & 1 : 1;
        if (++ctr_ == 10 * cpb_) { ctr_ = 0; ++idx_; }
        return level;
    }

private:
    const int   cpb_;
    std::string data_;
    size_t      idx_ = 0;
    int         ctr_ = 0;
};

#endif // SIMPLYV_UART_HPP
