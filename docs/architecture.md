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

The I²C Master follows a synchronous single-clock architecture.

Key design decisions:

- Single clock domain
- Parameterized clock divider
- Four-phase SCL generation
- Open-drain SDA/SCL bus interface
- Separate control and datapath
- Independent transmit and receive shift registers
- Registered outputs
- Parameterized transfer width
- Seven-state transaction FSM
- Repeated START support
- Clock stretching support

### Datapath Overview

The I²C Master datapath consists of:

- Clock divider
- Four-phase timing generator
- Transaction FSM
- Transmit shift register
- Receive shift register
- Bit counter
- Open-drain SDA/SCL bus interface
- Registered outputs

![DATAPATH](./images/I2C_MASTER_DATAPATH.png)

### Internal Registers

| Register | Purpose |
|----------|---------|
| `slave_addr_reg` | Latched slave address |
| `rw_reg` | Latched read/write control |
| `tx_data_reg` | Latched transmit data |
| `tx_shift_reg` | Transmit shift register |
| `rx_shift_reg` | Receive shift register |
| `rx_data_reg` | Received data register |
| `divider_reg` | Clock divider counter |
| `phase` | Quarter-cycle timing phase |
| `bit_count` | Bit counter |
| `state` | Transaction FSM state |
| `sda_drive_low` | Open-drain SDA control |
| `scl_drive_low` | Open-drain SCL control |
| `clock_enable` | Enables SCL generation |
| `repeated_start_reg` | Queued repeated START request |
| `busy_reg` | Busy status |
| `done_reg` | Transaction complete pulse |
| `error_reg` | Transaction error status |

---

## 6. I²C Slave

The I²C Slave follows a synchronous single-clock architecture and responds to transactions initiated by an external I²C Master.

Key design decisions:

- Single clock domain
- Two-stage SDA/SCL synchronization
- START and STOP detection from synchronized bus inputs
- Open-drain SDA and SCL bus interface
- Separate control and datapath
- Dedicated 8-bit address shift register
- Independent transmit and receive shift registers
- Registered outputs
- Parameterized transfer width
- Six-state transaction FSM
- Configurable slave address
- Clock stretching support

### Datapath Overview

The I²C Slave datapath consists of:

- SDA/SCL synchronizers
- START/STOP and SCL edge detection
- Transaction FSM
- Address shift register
- Transmit shift register
- Receive shift register
- Bit counter
- Clock-stretch controller
- Open-drain SDA/SCL bus interface
- Registered outputs

![DATAPATH](./images/I2C_SLAVE_DATAPATH.png)

### Internal Registers

| Register | Purpose |
|----------|---------|
| `rw_reg` | Latched read/write direction |
| `tx_data_reg` | Latched transmit data |
| `tx_shift_reg` | Transmit shift register |
| `rx_shift_reg` | Receive shift register |
| `rx_data_reg` | Received data register |
| `address_shift_reg` | Received 8-bit address and R/W field |
| `bit_count` | Bit counter |
| `stretch_count` | Clock-stretch counter |
| `sda_sync1` | First-stage SDA synchronizer |
| `sda_in` | Synchronized SDA input |
| `scl_sync1` | First-stage SCL synchronizer |
| `scl_in` | Synchronized SCL input |
| `stretch_request` | Clock-stretch request |
| `sda_drive_low` | Open-drain SDA control |
| `scl_drive_low` | Open-drain SCL control |
| `busy_reg` | Busy status |
| `done_reg` | Transaction complete pulse |
| `error_reg` | Transaction error status |


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
- Multi-byte transfers
- General Call addressing
- SMBus compatibility
- DMA support
- Interrupt generation
- APB wrapper
- AXI4-Lite wrapper
- Asynchronous clock-domain support
- Formal verification