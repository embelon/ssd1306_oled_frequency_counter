# SSD1306 OLED Frequency Counter

This is simple hardware implementation of Frequency Counter that displays result on 128 x 32 pixel OLED display with the SSD1306 driver:
[PMOD OLED](https://digilent.com/reference/pmod/pmodoled/start).

It was tested on Upduino 2 and Pico-ICE boards, both based on ICE40UP5K FPGA, supported by Open Source tools: Yosys and nextpnr.

Measured frequency is presented as 6 decimal digits, each being 21 pixels (128 pixels / 6 digits) wide.

This is the view of the display with all "segments" on for all digits:
<img src="docs/screenshots/128x32pix Display.png">
Note, the display is not able to display colors, orange and green background on above picture is added to mark squares of 8 x 8 pixels.

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

Data Streamer is responsible for converting 6-digits BCD input value (digits_in) to a stream of bytes representing 6-digit decimal value, where each decimal digit is displayed on 21 x 32 pixels area.
It's built from:
- Digits Counter, iterating over all digits (from 5th down to 0th)
- Y Counter, iterating over Y axis (4 rows, each 8 bits tall, as streamer is outputting 8 bits at once) 
- X Counter, iterating over X axis (21 columns)
- Binary to 7 Segments Decoder
- 7 Segments to 21x32 pixels Decoder
- State Machine, that synchronizes all blocks with external components (i.e. SSD1306 Driver)

Driving input refresh_stb_in high triggers stream of 504 bytes (6 digits * 21 pixels * 4 bytes per columns) of data on oled_data_out output followed by driving output oled_sync_stb_out to trigger OLED driver to drive internal LCD counter back to first column and first row.


<img src="docs/diagrams/Data Streamer Block Diagram.drawio.svg">

#### 2.2.2. Data Streamer State Machine's State Diagram

Data Streamer can be in 1 of 5 states:
- IDLE - not doing anything, waiting for new transfer request (activation of refresh_stb_in).
- SEND_DATA - outputting one byte of data, representing a part of a column (1/4th) with 8 pixels.
- WAIT_FOR_READY - waiting for OLED Driver to finish transmission of data. When OLED Driver becomes ready, then transition to SEND_SYNC if all bytes for all digits were sent or to SEND_DATA otherwise to output next byte to be displayed.
- SEND_SYNC - driving oled_sync_stb output to trigger OLED Driver to send sync command to go back to first column and first row. Transitions to WAIT_FOR_SYNC after acknowledgment from OLED Driver.
- WAIT_FOR_SYNC - waiting for OLED Driver to finish sync command. Transitions to IDLE, when OLED Driver becomes ready to accept new data.

<img src="docs/diagrams/Data Streamer State Machine.drawio.svg">

#### 2.2.3. BCD to 7-segment Decoder

It's simple, combinatorial only, converter from 4 bits to 7 bits that are representing segments of 7-segment display {g, f, e, d, c, b, a}.

<img src="docs/screenshots/7segment decoder.png">

#### 2.2.4. 7-segment to 21x32 pixels Decoder

This decoder is transforming 7 bits that are representing segments of 7-segment display into several (21 x 32 / 8 = 84) bytes forming enlarged 7-segment digit over 21 x 32 pixels area:
<img src="docs/screenshots/21x32pix Digit Big.png">

Each column is represented by 32 bits, 4 bytes and display is configured to accept data in columns.

Internally the decoder uses two LUTs, one for segments B, C, E, F and one for segments A, D, G.

The LUT for segments B, C, E, F is storing only values for segment F, but decoder uses simple transformations to generate also segments B, C and E (which are symmetrical in X or Y):

| X = | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Y = 0 | 8'h00 | 8'h00 | 8'hf0 | 8'hf8 | 8'hf0 | 8'he0 | 8'h00 | 8'h00 |
| Y = 1 | 8'h00 | 8'h00 | 8'h3f | 8'h7f | 8'h3f | 8'h1f | 8'h00 | 8'h00 |

Each 8 bit value represents one column (8 bit tall) to form segment F:

<img src="docs/screenshots/16x8pix Segment F.png">

As segments B, C, E, F are vertical, they are being displayed on 2 (out of 4 total) bytes of height.

The LUT for segments A, D, G is storing values for segment A and half of segment G, but with simple transformation is used to generate also segment D (which is symmetrical to A):

| X | Value (A + G) |
| --- | --- |
| 0 | 8'h00 |
| 1 | 8'h00 |
| 2 | 8'h00 |
| 3 | 8'h00 |
| 4 | 8'h02 + 8'h00 |
| 5 | 8'h06 + 8'h80 |
| 6 | 8'h0e + 8'hc0 |
| 7 | 8'h1e + 8'hc0 |
| 8 | 8'h1e + 8'hc0 |
| 9 | 8'h1e + 8'hc0 |
| 10 | 8'h1e + 8'hc0 |
| 11 | 8'h1e + 8'hc0 |
| 12 | 8'h1e + 8'hc0 |
| 13 | 8'h0e + 8'hc0 |
| 14 | 8'h06 + 8'h80 |
| 15 | 8'h02 + 8'h00 |
| 16 | 8'h00 |
| 17 | 8'h00 |
| 18 | 8'h00 |
| 19 | 8'h00 |

Each 8 bit value represents one colum (8 bit tall) to form segments A (upper part) and half of G (lower part):

<img src="docs/screenshots/21x8pix Segments A and G.png">


This LUT is result of combining two LUTs together to not waste resources:
- for segment A

<img src="docs/screenshots/21x8pix Segment A.png">

- for half a segment G

<img src="docs/screenshots/21x8pix Segment G.png">

### 2.3. SSD1306 Driver

The SSD1306 Driver module is responsible for initialization of OLED Display (and it's internal controller IC) after each reset and updating displayed image afterwards. Initialization sequence is encoded in form of micro-operations (microcode) and executed by Microcode Execution Unit. In microcode there's also a sequence of operations used to set the initial address for the data to be displayed (point 0,0) - it's executed everytime sync_stb_in is activated.

#### 2.3.1. Block Diagram

<img src="docs/diagrams/SSD1306 Driver Block Diagram.drawio.svg">

#### 2.3.2 SSD1306 Driver State Machine's State Diagram

SSD1306 Driver has 6 states it can be in:
- RESET_WAIT - not doing anything except waiting for both Microcode Execution Unit and SPI Driver to become ready after reset and then transitions to MC_EXEC
- MC_EXEC - activating Microcode Execution Unit and transitions to MC_WAIT after Micorcode Execution Unit acknowledges activation (by becoming not ready)
- MC_WAIT - waiting for Microcode Execution Unit to become ready (which means that init sequence (defined in microcode) was successfully executed and display is ready to accept data) and then transitions to IDLE
- IDLE - not doing anything, waiting for new data transfer request (activation of write_stb_in) or synchronization request (activation of sync_stb_in). In case of data transfer request, transitions to SEND_DATA, in case of synchronization request, sets microcode index to 33 (8'b21) and transitions to MC_EXEC.
- SEND_DATA - activating SPI Driver with data received on input and waiting for SPI Driver acknowledgement, then transitions to DATA_WAIT
- DATA_WAIT - waiting for SPI Driver finishing transmission of data, then transitions to IDLE

<img src="docs/diagrams/SSD1306 Driver State Machine.drawio.svg">

#### 2.3.3. Microcode execution unit

The Microcode execution unit stores procedures in forms of sequences of simple intructions.
Currently it provides only:
- initialization sequence for SSD1306 display driver, used once after reset - starting at offset 0
- synchronization sequence used to drive SSD1306 display driver back to point (0,0) - starting at offset 33 (8'h21)

There are 5 internally interpreted commands implemented in addition to sending data over SPI.
All commands / opcodes are listed below.

| Command | Bit 9 (Interpreted command) | Bit 8 (Deactivate CS after) | Bits 7-0 (Command Opcode and Parameter) |
| --- | --- | --- | --- |
| SPI_SEND Y and leave CS low | 0 | 0 | 8b'YYYY_YYYY |
| SPI_SEND Y and drive CS high after | 0 | 1 | 8b'YYYY_YYYY |
| GOTO Y (absolute 7 bit index) | 1 | x (Don't care) | 8'b1YYY_YYYY |
| DELAY Y | 1 | x (Don't care) | 8'b01YY_YYYY |
| SET_PIN P to state S | 1 | x (Don't care) | 8'b0010_PPxS |
| STOP | 1 | x (Don't care) | 8'b0000_0001 |
| NOP | 1 | x (Don't care) | 8'b0000_0000 |

The SET_PIN command is able to drive one of four pins:

| Pin name | Pin index (P) |
| --- | --- |
| RESET | 2'b00 |
| VBATN | 2'b01 |
| VCDN | 2'b10 |
| DC (Data / command) | 2'b11 |

Pins RESET, VBATN, VCDN are being driven only during SSD1306 initialization sequence.

#### 2.3.4. SPI Controller

##### 2.3.4.1. Block Diagram

SPI Controller is built upon simple Shift Register with help of State Machine.
- Shift Register controls 2 out of 3 SPI output signals: MOSI and SCK while transmitting data out and reads back SPI input: MISO.
- State Machine synchronizes Shift Register with input control signals and is responsible for driving CS (Chip Select) signal, allowing for multibyte transfers according to deactivate_cs_in signal. After transmission of each byte, State Machine notifies external components (via tx_done_out) that transfer was finished and data_out is valid data read during that transfer.

<img src="docs/diagrams/SPI.drawio.svg">

##### 2.3.4.2. SPI State Machine's State Diagram

SPI can be only in 1 of 3 states:
- IDLE - not doing anything, waiting for new transfer request (activation of tx_start_in). On transition to Trigger state, activates CS (select_out).
- Trigger - waiting for Shift Register to store input data / acknowledge.
- Transmission - transmitting whole byte (data_in), bit by bit over MOSI output and reading back new byte, bit by bit on MISO input. On transition to IDLE state, deactivates CS (select_out) if it was requested earlier.

<img src="docs/diagrams/SPI State Machine.drawio.svg">

##### 2.3.4.3. Shift Register's Logic Diagram

Shift Register internal logic is build from several DFFs, multiplexers, one adder, one comparator and few logic gates as depicted below. Those components can be divided into 3 groups:
- Bit Counter - responsible for counting bits that are output on serial_out during clock pulses, that helps mark the end of the transmission (ready_out)
- Shadow register with load and shift operations - responsible for storing data (both input and output) and shifting one bit of data out and another bit in in the same time (on the same clock edge)

<img src="docs/diagrams/Shift Register.drawio.svg">
