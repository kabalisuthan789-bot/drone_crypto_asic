# ChaCha20 Stream Cipher ASIC Core

## How it works

This project implements an area-optimized ChaCha20 stream cipher compliant with RFC 8439. 
It features a folded quarter-round execution engine designed to balance high cryptographic throughput with minimal silicon footprint on the SkyWater 130nm process node. 

The core interfaces through 8-bit bidirectional parallel I/O ports (`ui_in`, `uo_out`, `uio_in`, `uio_out`, `uio_oe`) controlled by standard clock and active-low reset inputs.

## How to test

Apply clock pulses while holding `rst_n` low to initialize internal state registers. Release `rst_n` high and drive initialization vectors (key, nonce, counter) via the input bus. Monitor the output bus `uo_out` for the resulting ChaCha20 keystream bytes.
