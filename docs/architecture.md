# I²C SV Core Architecture

## 1. Design Overview

The I²C SV Core follows a modular architecture consisting of independent I²C Master and I²C Slave modules integrated through a top-level module for verification and system integration.

The design supports parameterized transfer widths, configurable I²C clock generation, 7-bit slave addressing, and single-byte read and write transactions while maintaining a reusable and synthesizable RTL implementation suitable for both FPGA and ASIC targets.

Version 1 provides independent I²C Master and I²C Slave modules together with a top-level integration module for communication, verification, synthesis, and timing analysis.

---

## 2. Design Philosophy

The I²C SV Core is designed according to the following principles:

- Modular design
- Parameterization
- Reusability
- Synthesizable RTL
- Vendor-independent implementation
- Clear separation between datapath and control
- Documentation-driven development

The implementation avoids vendor-specific primitives wherever possible, allowing the same RTL to target FPGA and ASIC technologies through standard synthesis flows.

---

## 3. Module Hierarchy

```text
               i2c_top
              /       \
             /         \
      i2c_master    i2c_slave
```

| Module | Description |
|---------|-------------|
| `i2c_master` | Generates the I²C clock and controls I²C transactions. |
| `i2c_slave` | Responds to I²C transactions initiated by the master. |
| `i2c_top` | Integrates the master and slave modules for verification and system-level testing. |

---

## 4. Data Flow

### Master Write Path

```text
tx_data
   │
   ▼
I²C Master
   │
   ▼
SDA
```

Parallel transmit data is serialized by the I²C Master and transmitted over the SDA line.

### Slave Receive Path

```text
SDA
 │
 ▼
I²C Slave
 │
 ▼
rx_data
```

Incoming serial data is received by the I²C Slave and reconstructed into parallel data.

### Slave Read Path

```text
tx_data
 │
 ▼
I²C Slave
 │
 ▼
SDA
```

Parallel transmit data is serialized by the I²C Slave during read transactions.

### Master Receive Path

```text
SDA
 │
 ▼
I²C Master
 │
 ▼
rx_data
```

Incoming serial data is received by the I²C Master and reconstructed into parallel data.

---

## 5. I²C Master

*To be completed after implementation.*

---

## 6. I²C Slave

*To be completed after implementation.*

---

## 7. Top-Level Integration

*To be completed after implementation.*

---

## 8. Future Architecture Extensions

Future versions of the I²C SV Core may include:

- 10-bit addressing
- Fast Mode (400 kHz)
- Fast Mode Plus
- High-Speed Mode
- Multi-master arbitration
- Clock stretching
- Multi-byte transfers
- General Call addressing
- SMBus compatibility
- DMA support
- Interrupt generation
- APB wrapper
- AXI4-Lite wrapper
- Asynchronous clock-domain support
- Formal verification