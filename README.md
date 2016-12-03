## FFI Serial
FFI Serial is a simple OS independent gem to allow access to a serial port

## Why?
Other gems exist, why this gem?

1. Uses FFI to negate the need for native compilation
2. Simply acts as a configurator for Ruby IO objects

## Why FFI?
FFI is very widely supported at this point.
By making use of FFI a lot of native compilation concerns go away.

## Why IO?
Serial ports are simply files, in both Posix and Windows, that have special API calls to configure the serial port settings.

Ruby IO provides a rich API and it is part of standard library.
Using IO, this gem benefits from everything Ruby IO provides.
No modification is made to IO nor does this simply emulate IO.

99% of the code in this gem is to call the native operating system functions to configure the IO object serial port settings

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
    port.read #=> ...
    port.readpartial(512) #=> ...
    port.write "\n" #=> 1
    # etc.

    port.close #=> nil

    # Explicit configuration (and works on Windows)
    port = Serial.new port: 'COM1', data_bits: 8, stop_bits: 1, parity: :none #=> <Serial:COM1>

See Ruby standard library IO for complete method list
http://ruby-doc.org/core-1.9.3/IO.html