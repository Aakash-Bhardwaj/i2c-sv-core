# I²C SV Core

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-In%20Progress-yellow)

A reusable, parameterized **SystemVerilog Inter-Integrated Circuit (I²C) IP Core** consisting of independent I²C Master and I²C Slave modules together with a top-level integration wrapper for FPGA and ASIC implementations.

This project follows a structured documentation-driven RTL engineering workflow, progressing from specification and architecture through implementation, verification, synthesis, and static timing analysis. The goal is to develop a reusable I²C IP core while emphasizing good engineering practices, documentation, and reproducibility.

Each design decision is documented, verified, synthesized, and analyzed before integration.

---

# Objectives

- Design reusable I²C Master and I²C Slave IP cores.
- Follow modern SystemVerilog coding practices.
- Support Standard Mode (100 kHz) I²C communication.
- Support parameterized transfer width.
- Support parameterized I²C clock generation.
- Support 7-bit slave addressing.
- Support single-byte read and write transactions.
- Develop comprehensive self-checking SystemVerilog testbenches.
- Verify functionality using self-checking testbenches and immediate assertions.
- Perform generic synthesis using Yosys.
- Perform technology-mapped synthesis using the Sky130 HDLL standard-cell library.
- Perform static timing analysis using OpenSTA.
- Maintain clear documentation throughout development.

---

# Planned Features

## Version 1.0.0

- [x] Independent I²C Master module
- [x] Independent I²C Slave module
- [x] Top-level Master–Slave integration
- [x] Standard Mode (100 kHz)
- [x] 7-bit slave addressing
- [x] Parameterized transfer width
- [x] Parameterized I²C clock generation
- [x] Single-byte write transactions
- [x] Single-byte read transactions
- [x] START condition generation and detection
- [x] Repeated START generation and detection
- [x] STOP condition generation and detection
- [x] ACK/NACK generation and detection
- [x] Open-drain SDA and SCL interfaces

## Future Roadmap

- [ ] 10-bit addressing
- [ ] Fast Mode (400 kHz)
- [ ] Fast Mode Plus
- [ ] High-Speed Mode
- [ ] Multi-master arbitration
- [ ] Clock stretching
- [ ] Multi-byte transfers
- [ ] General Call addressing
- [ ] SMBus compatibility
- [ ] DMA support
- [ ] Interrupt generation
- [ ] APB wrapper
- [ ] AXI4-Lite wrapper
- [ ] Formal verification

---

# Repository Structure

```text
rtl/             Synthesizable SystemVerilog RTL
tb/              Self-checking testbenches
assertions/      Immediate SystemVerilog assertions
constraints/     OpenSTA timing constraints
scripts/         Synthesis and timing scripts
reports/         Synthesis and timing reports
docs/            Project documentation
docs/images/     Architecture, FSM, datapath, waveform and timing figures
```

---

# Documentation

The project documentation is organized into the following documents.

| Document | Description |
|----------|-------------|
| [Specification](docs/specification.md) | Functional requirements, interfaces, timing requirements, reset behaviour, assumptions, and future enhancements. |
| [Architecture](docs/architecture.md) | Design philosophy, module hierarchy, architectural organization, datapath, and control flow. |
| [Implementation](docs/implementation.md) | RTL implementation details, algorithms, design decisions, synthesis, and timing analysis. |
| [Verification](docs/verification.md) | Verification methodology, test cases, assertions, coverage goals, and timing validation. |

---

# Toolchain

| Tool | Purpose |
|------|---------|
| SystemVerilog | RTL Design |
| Icarus Verilog | RTL Simulation |
| GTKWave | Waveform Viewing |
| Yosys | Generic RTL Synthesis |
| Sky130 HDLL | Technology Mapping |
| OpenSTA | Static Timing Analysis |
| Git | Version Control |

---

# Development Workflow

```text
Specification
      ↓
Architecture
      ↓
RTL Implementation
      ↓
Architecture Update
      ↓
Implementation Documentation
      ↓
Verification
      ↓
Verification Documentation
      ↓
Generic Synthesis
      ↓
Technology Mapping
      ↓
Static Timing Analysis
      ↓
Final Documentation Review
```

---

# Project Status

- [x] Repository initialized
- [x] Project specification
- [x] Architecture
- [x] Initial Documentation
- [x] I²C Master RTL
- [x] I²C Master Verification
- [x] I²C Master Synthesis
- [x] I²C Slave RTL
- [x] I²C Slave Verification
- [x] I²C Slave Synthesis
- [x] Top-level integration
- [x] Verification
- [x] Generic synthesis
- [ ] Technology-mapped synthesis
- [ ] Static timing analysis
- [ ] Finalize Documentation

---

# Results

*To be completed after full implementation.*

---

# License

This project is licensed under the MIT License.