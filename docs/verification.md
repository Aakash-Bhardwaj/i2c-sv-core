# I²C SV Core Verification Plan

## 1. Verification Objectives

The objective of verification is to ensure that the I²C SV Core satisfies all functional requirements defined in the project specification.

Verification confirms correct functionality through simulation, self-checking testbenches, assertions, synthesis, and static timing analysis.

---

## 2. Verification Methodology

Verification follows a layered approach consisting of:

- Directed testing
- Self-checking SystemVerilog testbenches
- Immediate SystemVerilog assertions
- Waveform analysis
- Generic RTL synthesis using Yosys
- Technology-mapped synthesis using Sky130 HDLL
- Static timing analysis using OpenSTA

---

## 3. Verification Environment

| Tool | Use |
|------|-----|
| Icarus Verilog | RTL simulation |
| GTKWave | Waveform viewing |
| Yosys | Generic RTL synthesis |
| Yosys + Sky130 HDLL | Technology mapping |
| OpenSTA | Static timing analysis |

---

## 4. Module Verification

### 4.1 I²C Master

Verified using a self-checking SystemVerilog testbench with a behavioural I²C slave model.

Verified properties:

- Reset behaviour
- START condition generation
- STOP condition generation
- Single-byte write transaction
- Single-byte read transaction
- 7-bit slave addressing
- ACK/NACK handling
- Repeated START operation
- Clock stretching support
- Busy signal behaviour
- Done signal behaviour
- Error signalling
- Randomized stress testing
- Parameterized data width

#### Test Summary

| Test Case | Status |
|-----------|:------:|
| Reset | ✓ |
| Single-Byte Write | ✓ |
| Single-Byte Read | ✓ |
| Address NACK | ✓ |
| Data NACK | ✓ |
| Clock Stretching | ✓ |
| Repeated START | ✓ |
| Random Stress Testing | ✓ |

---

### 4.2 I²C Slave

*To be completed after implementation.*

#### Test Summary

*To be completed after implementation.*

---

### 4.3 I²C Top-Level

*To be completed after implementation.*

#### Test Summary

*To be completed after implementation.*

---

## 5. Functional Test Cases

### 5.1 I²C Master

Verified using a self-checking SystemVerilog testbench with a behavioural I²C slave model.

Verified properties:

- Reset behaviour
- START condition generation
- STOP condition generation
- Single-byte write transaction
- Single-byte read transaction
- 7-bit slave addressing
- ACK/NACK handling
- Repeated START operation
- Clock stretching support
- Busy signal behaviour
- Done signal behaviour
- Error signalling
- Randomized stress testing
- Parameterized data width

#### Test Summary

| Test Case | Status |
|-----------|:------:|
| Reset | ✓ |
| Single-Byte Write | ✓ |
| Single-Byte Read | ✓ |
| Address NACK | ✓ |
| Data NACK | ✓ |
| Clock Stretching | ✓ |
| Repeated START | ✓ |
| Random Stress Testing | ✓ |

---

### 5.2 I²C Slave

*To be completed after implementation.*

#### Test Summary

*To be completed after implementation.*

---

### 5.3 I²C Top-Level

*To be completed after implementation.*

#### Test Summary

*To be completed after implementation.*

---

## 6. Assertions

### 6.1 I²C Master

Immediate SystemVerilog assertions were implemented to verify key I²C Master design invariants during simulation.

Verified properties:

- `busy` and `done` are never asserted simultaneously.
- Output signals (`rx_data`, `busy`, `done`, and `error`) never contain unknown (`X`) values after reset.
- `done` is asserted for exactly one clock cycle.

All assertions passed during simulation.

---

### 6.2 I²C Slave

*To be completed after implementation.*

---

### 6.3 I²C Top-Level

*To be completed after implementation.*

---

## 7. Coverage Goals

The verification process aims to:

- Verify all FSM states
- Verify all FSM transitions
- Verify START and STOP conditions
- Verify ACK/NACK handling
- Verify read and write transactions
- Verify parameter configurations
- Verify reset behaviour
- Verify boundary conditions
- Verify end-to-end master transactions using a behavioural slave model.
- Verify end-to-end slave transactions using a behavioural master model.
- Verify end-to-end master-slave integration

---

## 8. Success Criteria

Verification is considered complete when:

- All planned tests pass.
- All assertions pass.
- No simulation errors remain.
- Generic RTL synthesis completes successfully.
- Technology-mapped synthesis completes successfully.
- Static timing analysis reports no timing violations.

---

## 9. Static Timing Analysis Results

*To be completed after OpenSTA timing analysis.*

---

## 10. Future Verification Enhancements

Future versions of the verification environment may include:

- UVM
- Cocotb
- Constrained-random verification
- Functional coverage
- Formal verification