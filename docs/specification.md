# I²C SV Core Specification

## 1. Introduction

The I²C SV Core is a reusable, parameterized SystemVerilog implementation of the Inter-Integrated Circuit (I²C) protocol. The design targets synthesizable RTL and follows a modular architecture consisting of independent I²C Master and I²C Slave modules with a top-level integration module for verification.

The design targets:

* FPGA implementation
* ASIC implementation
* Generic synthesis
* Sky130 HD technology mapping
* Educational and production-quality reusable IP

This project follows the documentation-driven development methodology established during the UART SV Core, FIFO SV Core, and SPI SV Core projects.

---

## 2. Scope

This specification defines the functional and non-functional requirements for Version 1.0 of the I²C SV Core.

The initial implementation focuses on a standard single-master I²C protocol supporting configurable clock generation, 7-bit slave addressing, and single-byte read and write transactions.

Version 1.0 implements:

* Independent I²C Master and I²C Slave modules
* Top-level integration module for verification
* Single-master operation
* Single-slave integration
* Standard Mode (100 kHz)
* 7-bit slave addressing
* Single-byte read transactions
* Single-byte write transactions
* Repeated START generation and detection
* START condition generation and detection
* STOP condition generation and detection
* Clock stretching
* ACK/NACK generation and detection
* Parameterized transfer width
* Parameterized system clock frequency
* Parameterized I²C clock frequency
* Parameterized slave address
* Open-drain SDA and SCL interfaces

The following features are outside the scope of Version 1.0:

* 10-bit addressing
* Multi-master arbitration
* Multi-byte transfers
* General Call addressing
* SMBus compatibility
* DMA support
* Interrupt generation
* APB wrapper
* AXI4-Lite wrapper

---

## 3. Functional Requirements

### I²C Master

The I²C Master shall:

* Generate the I²C serial clock (`SCL`).
* Generate START conditions.
* Generate STOP conditions.
* Generate Repeated START conditions.
* Transmit the 7-bit slave address and R/W bit.
* Support single-byte write transactions.
* Support single-byte read transactions.
* Generate and detect ACK/NACK conditions.
* Generate the I²C serial clock using the parameterized clock configuration.
* Operate as the only bus master.
* Accept a new transaction request only while idle.
* Generate a status indication while a transaction is in progress.
* Generate a one-clock-cycle transaction-complete indication after the transaction finishes.
* Generate a one-clock-cycle error indication whenever a transaction terminates unsuccessfully.

### I²C Slave

The I²C Slave shall:

* Detect START conditions.
* Detect STOP conditions.
* Detect Repeated START conditions.
* Receive the slave address and R/W bit.
* Compare the received address against the configured slave address.
* Generate ACK/NACK responses.
* Support single-byte write transactions.
* Support single-byte read transactions.
* Ignore transactions addressed to other slave devices.
* Generate a status indication while participating in a transaction.
* Generate a one-clock-cycle transaction-complete indication after the transaction finishes.

### I²C Top

The I²C Top module shall:

* Instantiate one I²C Master and one I²C Slave.
* Connect the master and slave through a shared I²C bus.
* Provide a reusable integration module for simulation and verification.

---

## 4. Parameters

| Parameter | Description |
|-----------|-------------|
| `DATA_WIDTH` | Number of bits transferred during each I²C data phase. |
| `CLOCK_FREQ_HZ` | System clock frequency in Hertz. |
| `SCL_FREQ_HZ` | Target I²C serial clock frequency. |
| `SLAVE_ADDRESS` | 7-bit slave address used for address comparison. |

---

## 5. Interface

### I²C Master

#### Inputs

| Signal | Width | Description |
|--------|------:|-------------|
| `clk` | 1 | System clock |
| `rst_n` | 1 | Active-low synchronous reset |
| `start` | 1 | Transaction request |
| `slave_addr` | 7 | Target slave address |
| `rw` | 1 | Read/Write selection |
| `tx_data` | `DATA_WIDTH` | Parallel transmit data |

#### Outputs

| Signal | Width | Description |
|--------|------:|-------------|
| `rx_data` | `DATA_WIDTH` | Received parallel data |
| `busy` | 1 | Transaction in progress |
| `done` | 1 | Transaction complete |
| `error` | 1 | Transaction error |

#### Bus

| Signal | Width | Description |
|--------|------:|-------------|
| `sda` | 1 | Bidirectional serial data |
| `scl` | 1 | Bidirectional serial clock |

---

### I²C Slave

#### Inputs

| Signal | Width | Description |
|--------|------:|-------------|
| `clk` | 1 | System clock |
| `rst_n` | 1 | Active-low synchronous reset |
| `tx_data` | `DATA_WIDTH` | Parallel transmit data |

#### Outputs

| Signal | Width | Description |
|--------|------:|-------------|
| `rx_data` | `DATA_WIDTH` | Received parallel data |
| `busy` | 1 | Transaction in progress |
| `done` | 1 | Transaction complete |

#### Bus

| Signal | Width | Description |
|--------|------:|-------------|
| `sda` | 1 | Bidirectional serial data |
| `scl` | 1 | Bidirectional serial clock |

---

### I²C Top

#### Inputs

| Signal | Width | Description |
|--------|------:|-------------|
| `clk` | 1 | System clock |
| `rst_n` | 1 | Active-low synchronous reset |

---

## 6. Protocol Overview

Version 1.0 shall implement the following I²C transaction sequence.

### Write Transaction

```text
START

↓

Slave Address + Write

↓

ACK

↓

Data Byte

↓

ACK

↓

STOP
```

### Read Transaction

```text
START

↓

Slave Address + Read

↓

ACK

↓

Data Byte

↓

NACK

↓

STOP
```

A Repeated START condition may be generated in place of a STOP condition without releasing the bus.

---

## 7. Timing Requirements

* All sequential logic shall operate on the rising edge of the system clock.
* The I²C Master shall generate `SCL` using the parameterized clock configuration.
* START and STOP conditions shall comply with the I²C protocol definition.
* SDA shall remain stable while `SCL` is HIGH except during START and STOP conditions.
* One address byte shall be transferred before every data transaction.
* One acknowledge clock cycle shall follow every transferred byte.
* No internally generated clocks other than the I²C serial clock shall be used.

---

## 8. Reset Behaviour

The I²C SV Core shall use an active-low synchronous reset.

Following reset:

### I²C Master

* Internal state machines shall return to their initial states.
* Internal counters shall be cleared.
* SDA and SCL shall return to the released state.
* Status outputs shall return to their default values.

### I²C Slave

* Internal state machines shall return to their initial states.
* Address reception logic shall return to the idle state.
* SDA and SCL shall return to the released state.
* Status outputs shall return to their default values.

---

## 9. Parameter Validation

The implementation shall validate configuration parameters during elaboration whenever possible.

The following constraints apply:

* `DATA_WIDTH > 0`
* `CLOCK_FREQ_HZ > 0`
* `SCL_FREQ_HZ > 0`
* `CLOCK_FREQ_HZ > SCL_FREQ_HZ`

---

## 10. Assumptions

The following assumptions apply to Version 1.0:

* A stable system clock is available.
* The implementation operates in a single-master I²C system.
* External pull-up resistors are present on the SDA and SCL lines.
* All participating devices operate using Standard Mode timing.
* Input control signals are synchronous to the system clock.
* The master shall ignore new transaction requests while `busy` is asserted.
* Parameter values are valid before synthesis.

---

## 11. Future Enhancements

Future versions of the I²C SV Core may include:

* 10-bit addressing
* Fast Mode (400 kHz)
* Fast Mode Plus
* High-Speed Mode
* Multi-master arbitration
* Multi-byte transfers
* General Call addressing
* SMBus compatibility
* DMA support
* Interrupt generation
* APB wrapper
* AXI4-Lite wrapper
* Formal verification