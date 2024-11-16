# SGDH-RVSoC Project, a portable and Linux capable RISC-V computer system on an FPGA

![2024-10-2003-47-18-ezgif com-video-to-gif-converter](https://github.com/user-attachments/assets/df2f0224-5672-4bd0-8b27-411397fcf85c)

The RVSoC Project was the origin, serving as a research and development project of the RISC-V computer system targeting FPGAs in Verilog HDL at Arch Lab, Tokyo Tech. Building on this foundation, we are now aiming to explore new approaches and innovations.

**RVSoC** (**R**ISC-**V** **S**ystem **o**n **C**hip) is a portable and Linux capable RISC-V computer system on an FPGA.

This system can be implemented on an FPGA with fewer hardware resources,
and can be implemented on low cost FPGAs or customized by introducing an accelerator.

The source code of this system is written in Verilog HDL.

RVSoC includes

- RVCoreM: 12-steps **multi cycle** processor (**Not Pipelined**)
- RVuc: 4-steps **multi cycle** processor for I/O (**Not Pipelined**)
- MMU: Sv32 address translation unit and TLB
- Others

**RVSoC supports the following FPGA boards and can run Linux!**

- [Nexys A7](https://reference.digilentinc.com/reference/programmable-logic/nexys-a7/reference-manual) board with Xilinx Artix-7 FPGA
- [Arty A7-35T](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/reference-manual) board with Xilinx Artix-7 FPGA
- [Arty A7-100T](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/reference-manual) board with Xilinx Artix-7 FPGA

## What's new

- 2024/11/05 : The SGDH-RVSOC project has been forked.
- 2024/10/20 : Support the Arty A7-100T FPGA board
- 2020/08/24 : Released Ver.0.5.3 that can execute Verilog simulation using Verilator
- 2020/08/24 : Released Ver.0.5.2 that can execute Verilog simulation using Synopsys VCS simulator
- 2020/06/24 : Released Ver.0.5.1 and support the Arty A7-35T FPGA board
- 2020/06/11 : Update RISC-V Linux binary files
- 2020/05/20 : Add how to build the RISC-V cross compiler and RISC-V Linux binary files
- 2020/05/18 : Change of web page structure and release of Ver.0.4.6
- 2020/03/06 : Ver.0.4.5 is released in this page
- 2020/02/29 : The comming soon page is released!

## Download source file and binary

The latest version of RVSoC is Ver.0.5.3.

- The archive file containing the bitstream files and the memory initialization file :
  - The bitstream files for Nexys A7 FPGA board, Arty A7-35T board and A7-100T board
  - The memory initialization file including Berkeley Boot Loader, device tree, Linux binary, and disk image
  - The Python program to send the memory initialization file by serial communication

- The source code including the project files of Xilinx Vivado :
  - The bitstream files and the memory initialization file
  - The Verilog source code files of RVSoC that can be simulated using some simulators
  - The project files of Xilinx Vivado and some IP source file for Nexys A7 FPGA board, Arty A7-35T board and Arty A7-100T board
  - The source code files for the program executed by RVuc

These published files are released under the MIT License, see LICENSE.txt.

### Change log

- Ver.0.5.3 : The version that can execute Verilog simulation using Verilator
- Ver.0.5.2 : The version that can execute Verilog simulation using Synopsys VCS simulator
- Ver.0.5.1 : The version that supports Arty A7-35T and fixes some bugs
- Ver.0.4.6 : The version supporting pySerial, Vivado 2019.2
- Ver.0.4.5 : The version used in our submitted manuscript

## Recommended environment

- Ubuntu 22.04 LTS
- [Xilinx Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado.html) 2022.1 for logic synthesis
- [Nexys A7 board](https://reference.digilentinc.com/reference/programmable-logic/nexys-a7/reference-manual) or [Arty A7-35T](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/reference-manual) board with Xilinx Artix-7 FPGA for placement and routing
- Python 3.10.12
- [pySerial](https://pythonhosted.org/pyserial/) for sending the binary file by serial communication with FPGA board
- GTKTerm for sending and receiving console screens by serial communication
- [Verilator](https://www.veripool.org/wiki/verilator) or Synopsys VCS simulator Version M-2017.03-SP2_Full64 for Verilog simulation of RVSoC

### Install command

Install pySerial and picocom by the following command.

```
$ sudo apt install python3-pip
$ pip3 install pyserial

$ sudo apt install picocom
```

Install GTKTerm by the following command.

```
$ sudo apt install gtkterm
```

Install verilator by the following command.

```
$ sudo apt install verilator
```

## Getting started guide

### Execution of Linux on a FPGA board using the downloaded bitstream file and memory initialization file

(1) Clone the repository containing the bitstream file and the memory initialization file
```
$ git clone https://github.com/semisgdh/SGDH-RVSOC.git
$ cd SGDH-RVSOC
```

(2) Open Xilinx Vivado to write the bitstream file

```
$ vivado &
```

- Click "Open Hardware Manager" in "Task" at the top page

(3) Write the bitstream file to a FPGA board

- Click "Open target" and "Auto Connect" to recognize a FPGA board

- Click "Program device" and a specify Bitstream file
  - When using Nexys A7 board : `nexys4.bit`
  - When using Arty A7-35T board : `arty35t.bit`
  - When using Arty A7-100T board : `arty100t.bit`

- Click "Program" to write bitstream to a FPGA board

When the bitstream data is correctly written to the Nexys A7 board,
the DONE LED lights up and "ArchProc" is displayed on the 8-digit 7-segment LEDs.
Also, the lower right LED will blink at regular intervals, 

The right RGB LED shines brightly immediately after writing the bitstream file.
**After this right RGB LED turns off, you can write the memory initialization file.**

(4) Prepare for 8M baud serial communication

For sending the binary file by serial communication, the pySerial program `serial_sendfile.py` is used.

For sending and receiving console screens by serial communication, GTKTerm is used.

First, make settings for GTKTerm.

- Execute the following command to start GTKTerm

```
$ gtkterm &
```

- Click "Configuration"->"Port"
- Change the Port of Serial port to the appropriate USB Serial Port like `/dev/ttyUSB1`
- Change the Baud Rate of Serial port to “8000000” and click “OK”
- Click "Configuration"->"CR LF auto" for New-line code

Second, check the setting of the port used for serial communication in the pySerial program `serial_sendfile.py`.

By default, `/dev/ttyUSB1` is set.

```
sudo apt install python3-serial picocom
```

```
sudo picocom /dev/ttyUSB1 -b 8000000
```

The usage of this program is as follows:

```
$ python3 serial_sendfile.py [serial baud rate (Mbaud)] [binary file name]
```

(5) Send the memory initialization file to the FPGA board by serial communication and execute the Linux 

To send the memory initialization file and execute the Linux, execute one of the following commands.

```
$ python3 serial_sendfile.py 8 "initmem.bin"
```

or

```
$ python3 serial_sendfile.py
```

- Send the memory initialization file to the FPGA board via serial communication for about 40 seconds

The program is automatically terminated when the transmission is completed.

Confirm that "finished!" is displayed on the console of the terminal.

Linux starts up and a Linux startup message is displayed on the GTKTerm console.

When using Nexys A7 board, the 7-segment LED shows the value obtained by dividing the value of the mtime register by 1024.

(6) Enjoy the Linux 

After a while, the following message is displayed.

```
Welcome to Buildroot
localhost login:
```

- Log in with the username `root`

After successful login, you can execute standard Linux commands, some games, and a benchmark
like top, sleep, vi, em (uemacs), micropython, sl, ascii_invaders, nyancat, dhrystone.

Enjoy!!

** (An EXT4-fs error may occur when the first command is executed after login,
but there is no problem because the subsequent commands are executed correctly.) **

### Logic synthesis and placement and routing from source code using Xilinx Vivado project file

(1) Clone the source code including the project files of Xilinx Vivado

```
$ git clone https://github.com/semisgdh/SGDH-RVSOC.git
$ cd SGDH-RVSOC
```

(2) Open a project file using Xilinx Vivado

The following project files are prepared depending on the FPGA board.

- When using Nexys A7 board : `nexys4.xpr`
- When using Arty A7-35T board : `arty35t.xpr`
- When using Arty A7-100T board : `arty100t.xpr`

Execute the following command according to the executed project file

```
$ vivado [FPGA board name].xpr &
```

(3) Perform logic synthesis, placement and routing, and generating bitstream using Xilinx Vivado

By default, the operating frequency of the system on chip is set to 104MHz.

In the project file of Arty A7 board,
the following command is added to the option of the strategy of logic synthesis.

- `-verilog_define ARTYA7=1`

The source code is switched for Arty A7 board by the definition of this macro `ARTYA7`,
so please be careful when changing the logic synthesis strategy yourself.

- Click "Generate Bitstream" in Vivado project manager

When you have finished generating the bitstream, you open the hardware manager.

- Click "Open Hardware Manager" in Vivado project manager

Subsequent operations are the same as those from step (4) of "Getting started guide".

The Linux binary file `initmem.bin` sent to the FPGA and the program `serial_sendfile.py` that sends the binary file
are located in the `binary/` directory.

The generated bitstream file is stored in the `bitstream/` directory.

The system source and constraint files are located in the `src/` and `constrs/` directories, respectively.

The used Xilinx IP source file is stored in `[FPGA board name].srcs/`.

The source code of the program executed by RVuc which is a microcontroller is stored in `ucimage/`.

### How to execute Verilog simulation using Verilator or Synopsys VCS simulator

(1) Clone the source code including the project files of Xilinx Vivado

```
$ git clone https://github.com/semisgdh/SGDH-RVSOC.git
$ cd SGDH-RVSOC
```

(2) Generate the text image file to initialize memory for Verilog simulation

You can generate memory initialization files for Verilog simulation by using initmem_gen2 program that summarizes how to build Linux binaries for RVSoC.

Please execute a shell script `initmem_gen.sh` that generates memory initialization files using this initmem_gen2 program.

The initmem_gen2 program uses three binary files, `bbl.bin`, `root.bin`, `devicetree.dtb` to generate a memory initialization file.

If you want to use three Linux binary files built by yourself, please put them in the same directory as the shell script `initmem_gen.sh`.

```
$ cd binary/
$ ./initmem_gen.sh
$ cd ../
```

If the shell script is executed correctly, two text memory initialization files,
`init_kernel.txt` and `init_disk.txt`, are generated.

`init_kernel.txt` is the hex file with `bbl.bin` and `devicetree.dtb` properly placed.\\
`init_disk.txt` is the hex file with `root.bin` properly placed.

(3) Prepare for Verilog simulation of RVSoC

The source files needed for Verilog simulation of RVSoC are in `src/` directory.

```
$ cd src/
```

Two text memory initialization files generated earlier are specified in `define.vh`.

In `define.vh`, specify `init_kernel.txt` in the macro `HEXFILE` and `init_disk.txt` in the macro `IMAGE_FILE`.\\
If `init_kernel.txt` or `init_disk.txt` is not placed in the `binary/` directory,
change the path specified in `HEXFILE` or `IMAGE_FILE` appropriately.

The macro `TIMEOUT` in `define.vh` specifies the number of executed instructions to end the Verilog simulation.\\
The macro `DEBUG` in `define.vh` specifies whether to output debug information during Verilog simulation.

(4) Execute Verilog simulation using Verilator or VCS simulator

You can execute Verilog simulations using either Verilator or VCS simulator.

To use Verilator for RVSoC simulation, execute the following command.

```
$ make veri
$ make run
```

To use VCS simulator for RVSoC simulation, execute the following command.

```
$ make vcs
$ make run
```

** Because Verilog simulation running the Linux on RVSoC takes much longer than running Linux on an FPGA,
please be careful when executing the simulation. **

Please see `Makefile` for detailed command line options for simulating using Verilator or VCS simulator.

When executing Verilog simulation, it is necessary to specify the macro `SIM_MODE` when executing `make` command.


## How to build the RISC-V cross compiler and RISC-V Linux binary files that works with RVSoC

[Please refer the fllowing page](compile-linux.md)

## Publication

This System on Chip RVSoC is explicated in a preprint paper of arXiv.

Junya Miura, Hiromu Miyazaki, Kenji Kise:
A portable and Linux capable RISC-V computer system in Verilog HDL,
[cs.AR (2020-02-10)](https://arxiv.org/abs/2002.03576|arXiv:2002.03576).

## Contact

[Semiconductor Design Self-study](https://semisgdh.com/)

E-Mail : (E-mail)  info (at) semisgdh.com

Contributor : Austin Kim (Hardware), Yunseong Kim (Software)

This file is licensed to the public under a Creative Commons Attribution 4.0 license.
