# SSD1306 OLED Frequency Counter

## 1. Top Level Design

### 1.1. Block diagram

Frequency counter is built from few components:
- one 6-digits BCD counter with asynchronous reset, which counts pulses from clk_x, unknown frequency signal
- one 6-digits BCD counter with synchronous reset, which counts pulses from clk_ref, known frequency signal, that is used as a reference and defines measurement period
- SSD1306 Driver, responsible for communication with and initialization of SSD1306-based OLED over SPI interface
- Data Streamer, responsible for conversion of measurement result from BCD to enlarged 7-segment format (with size of a digit defined as 21x32 pixels)
- Controller, simple State Machine responsible for synchronization between all other blocks

<img src="docs/diagrams/Block Diagram.drawio.svg">

### 1.2. Controller State Machine's State Diagram

There are only 3 states, that Frequency Counter can be in:
- IDLE - not doing anything meaningful, waiting only for Data Streamer to become ready (that also means that SSD1306 OLED was initialized first time after reset and can be now updated with data to be displayed)
- Measure - both counters are enabled, one is counting pulses of unknown frequency signal and second one is counting pulses of known reference frequency, counting up to overflow of reference counter then stopping them both and transitioning to Display state
- Display - converting and transmitting measured frequency in form of bitmaps to the OLED

<img src="docs/diagrams/Controller State Machine.drawio.svg">

## 2. Components

### 2.1. Counter

#### 2.1.1. 6-digits BCD Counter (with synchronous reset) Block Diagram

Counter is instantiated as N-digits counter (with parameter N set to 6), which results in the following structure of 6 identical 1-digit BCD counters connected together. Each counter block counts in range 0 to 9 (decimal counter) and presents the result in BCD format.

<img src="docs/diagrams/Ndigit Cnt Block Diagram.drawio.svg">

#### 2.1.2. 1-digit BCD Counter (with synchronous reset) Logic Diagram

1-digit BCD Counter's internal logic is built from 4 DFFs (flip-flops), 3 multiplexers, 1 adder, 1 comparator and few logic gates.
- DFFs are responsible for storing actual count (memory).
- Multiplexers allow feeding different values to DFFs inputs to change the state of the counter depending on external reset signal and current state of DFFs.
- Adder is providing current+1 value to update counter in next clock cycle.
- Comparator is checking if counter / DFFs current value is 9, to allow for going back to 0 and activate carry output.

<img src="docs/diagrams/1digit Cnt Diagram.drawio.svg">

### 2.2. Data Streamer

#### 2.2.1. Block Diagram

#### 2.2.2. Data Streamer State Machine's State Diagram

<img src="docs/diagrams/Data Streamer State Machine.drawio.svg">

#### 2.2.3. BCD to 7-segment Decoder

It's simple, combinatorial only, converter from 4 bits to 7 bits that are representing segments of 7-segment display {g, f, e, d, c, b, a}.

<img src="docs/screenshots/7segment decoder.png">

#### 2.2.4. 7-segment to 21x32 pixels Decoder

This decoder is transforming 7 bits that are representing segments of 7-segment display into several (21 x 32 / 8 = 84) bytes forming enlarged 7-segment digit over 21 x 32 pixels area.

<img src="docs/screenshots/21x32pix Digit Big.png">

### 2.3. SSD1306 Driver

#### 2.3.1. Block Diagram

#### 2.3.2. SPI Controller

##### 2.3.2.1. Block Diagram

SPI Controller is built upon simple Shift Register with help of State Machine.
- Shift Register controls 2 out of 3 SPI output signals: MOSI and SCK while transmitting data out and reads back SPI input: MISO.
- State Machine synchronizes Shift Register with input control signals and is responsible for driving CS (Chip Select) signal, allowing for multibyte transfers according to deactivate_cs_in signal. After transmission of each byte, State Machine notifies external components (via tx_done_out) that transfer was finished and data_out is valid data read during that transfer.

<img src="docs/diagrams/SPI.drawio.svg">

##### 2.3.2.2. SPI State Machine's State Diagram

SPI can be only in 1 of 3 states:
- IDLE - not doing anything, waiting for new transfer request (activation of tx_start_in). On transition to Trigger state, activates CS (select_out).
- Trigger - waiting for Shift Register to store input data / acknowledge.
- Transmission - transmitting whole byte (data_in), bit by bit over MOSI output and reading back new byte, bit by bit on MISO input. On transition to IDLE state, deactivates CS (select_out) if it was requested earlier.

<img src="docs/diagrams/SPI State Machine.drawio.svg">

##### 2.3.2.3. Shift Register's Logic Diagram

Shift Register internal logic is build from several DFFs, multiplexers, one adder, one comparator and few logic gates as depicted below. Those components can be divided into 3 groups:
- Bit Counter - responsible for counting bits that are output on serial_out during clock pulses, that helps mark the end of the transmission (ready_out)
- Shadow register with load and shift operations - responsible for storing data (both input and output) and shifting one bit of data out and another bit in in the same time (on the same clock edge)

<img src="docs/diagrams/Shift Register.drawio.svg">
