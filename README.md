## FFI Serial
FFI Serial is a simple OS independent gem to allow access to a serial port

## Why?
Other gems exist, why this gem?

1. Opens Serial port as Ruby IO object
2. Uses FFI to configure serial port using native operating system functions

### Why IO?
- Serial ports are exposed as files in both Posix(Linux/Mac/BSD/etc) and Windows
- Ruby IO provides a rich API and it is part of standard library
- Ruby IO contains a large amount of very efficient and well tested code
- Reduces gem complexity to only configuring serial port

### Why FFI?
- Removes native compilation concerns
- FFI is very widely supported (portable)

## Installation
    gem install ffi-serial

## Usage
    require 'ffi-serial'

    # Defaults for baud, data_bits, stop_bits and parity
    port = Serial.new port: '/dev/ttyUSB0' #=> <Serial:/dev/ttyUSB0>

    # Get configured settings from OS
    port.baud #=> 9600
    port.data_bits #=> 8
    port.stop_bits #=> 1
    port.parity #=> :none

    # Really is a Ruby IO
    port.is_a?(IO) #=> true
    port.is_a?(File) #=> true

    port.read_nonblock(512) #=> ... <supported in Windows>
    port.readpartial(512) #=> ...
    port.write "\n" #=> 1
    # etc.

    port.read_timeout = 1.5 #=> 1.5 # 1500ms
    port.gets("\n") #=> ... Timeouts after 1.5 seconds

    port.close #=> nil

    # Explicit configuration (and works on Windows)
    port = Serial.new port: 'COM1', data_bits: 8, stop_bits: 1, parity: :none #=> <Serial:COM1>
    # OR
    port = Serial.new port: 1, data_bits: 8, stop_bits: 1, parity: :none #=> <Serial:COM1>

See Ruby standard library IO for complete method list
http://ruby-doc.org/core-1.9.3/IO.html

## Notes
IO.read will not behave exactly as described in IO.read but probably not as most developers expect.
IO.read will read either until read_timeout is reached or EOF is reached.

Serial ports are not truly files and will never reach EOF, therefore if read_timeout is 0, IO.read should be expected to block forever.