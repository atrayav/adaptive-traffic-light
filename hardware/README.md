# FPGA crossing controller

The Arduino sends HC-SR04 distance and button readings over SPI. The FPGA
classifies vehicle presence and controls the vehicle and pedestrian phases.

## Detection around 300 mm

A valid nonzero reading at or below **350 mm** enters the detected state.
A reading at or above **400 mm** clears it. Between those thresholds, the
previous state is retained to avoid flicker. The old 250/350 mm thresholds
explained why a 300 mm target could stay clear until it moved closer.

Check the Arduino's printed distance and sensor validity when testing. These
threshold changes address the logic; they cannot correct an invalid physical
measurement. Use a reliable far reflector beyond 400 mm for a valid clear road.

## WALK extension

WALK initially lasts **5 seconds**. Every fresh button press during WALK adds
**3 seconds** when sensor data is valid and no vehicle is detected, in either
adaptive or fixed mode. This includes a press on the final timer cycle.
Release the button before pressing again; holding it does not repeatedly add
time. Presses early in WALK also add time. Separate presses may extend it
repeatedly. A later detected vehicle or invalid reading blocks new extensions
but does not cancel time already granted. WALK presses do not queue another
crossing. Clearance remains 2 seconds.

The timing is configured in `rtl/top.sv` with `WALK_EXTENSION_CYCLES`.
The remaining-time counter saturates rather than overflowing.

## Verification

Install Verilator and a C++ build toolchain, then from the repository root run:

```sh
bash hardware/sim/run_tests.sh
```

The script lints the full FPGA top and runs the original FSM tests plus the
threshold/extension regressions. Build artifacts and logs go to a fresh temporary
directory printed by the script. Verified with Verilator 5.052.

## Apply to hardware

Rebuild synthesis, implementation, and the bitstream using all `rtl/*.sv` files,
with `top` as the top module and `constraints/arty_a7_100t.xdc` for the matching
board. Program the FPGA and reset it. No Arduino firmware or protocol change is
required for these features. Simulation and lint have passed; the updated
bitstream still needs synthesis/timing checks and testing on the actual board.

See [the project specification](../docs/PROJECT_SPEC.md) for wiring, protocol,
state timing, known limitations, and the presentation/demo plan.
