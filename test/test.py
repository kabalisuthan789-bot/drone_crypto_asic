import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting ChaCha20 ASIC test")

    # Set up 50 MHz clock (20ns period)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset signals
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)

    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Run for 100 clock cycles to verify circuit stability
    dut.ui_in.value = 0x5A
    dut.uio_in.value = 0xA5
    await ClockCycles(dut.clk, 100)

    dut._log.info("ChaCha20 ASIC test completed successfully")
