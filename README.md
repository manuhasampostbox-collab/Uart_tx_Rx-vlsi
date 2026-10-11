# UART Transmitter / Receiver (Verilog)

An 8-N-1 UART (Universal Asynchronous Receiver/Transmitter) transmitter and
receiver pair, written and verified in Verilog.

## Files
- `uart_tx.v` — synthesizable RTL: UART transmitter (FSM: IDLE -> START -> DATA -> STOP).
- `uart_rx.v` — synthesizable RTL: UART receiver with a 2-flip-flop input
  synchronizer and mid-bit sampling for noise immunity.
- `tb_uart.v` — self-checking testbench: loops the transmitter's serial
  output directly into the receiver and checks every byte received matches
  what was sent.

## Design notes
- Both modules are parameterized by `CLKS_PER_BIT` (clock cycles per UART
  bit period), so the same RTL works at any baud rate for a given clock
  frequency — e.g. `CLKS_PER_BIT = 434` for 115200 baud at 50 MHz.
- The receiver uses a 2-FF synchronizer on the asynchronous serial input and
  samples each bit at the middle of its period, rejecting false starts
  caused by glitches.
- `tx_done` / `rx_done` pulse for one clock cycle so they can drive other
  logic (e.g. a FIFO) without extra handshaking.

## Running the simulation
Requires Icarus Verilog (`iverilog`/`vvp`).

```bash
iverilog -g2012 -o sim uart_tx.v uart_rx.v tb_uart.v
vvp sim
```

### Example output
```
[PASS] test 0: sent 0x00, received 0x00
[PASS] test 1: sent 0xff, received 0xff
[PASS] test 2: sent 0xa5, received 0xa5
[PASS] test 3: sent 0x5a, received 0x5a
[PASS] test 4: sent 0x55, received 0x55
[PASS] test 5: sent 0x3c, received 0x3c
[PASS] test 6: sent 0x81, received 0x81
[PASS] test 7: sent 0x7e, received 0x7e
--------------------------------------------------
UART loopback test summary: 8 passed, 0 failed (of 8)
--------------------------------------------------
RESULT: ALL TESTS PASSED
```
