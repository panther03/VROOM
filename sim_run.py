#!/usr/bin/env python3
import sys
import os
import subprocess

"""
martinch@mit.edu for 6.1920 Spring 2023 final project

Updated by seshan@mit.edu and lasyab@mit.edu to fix some bugs

Converts mem.mem with Word (32 bits) on each line to a memlines.vmh with a Line (512 bits) on each line.

The lines run right to left, but the words run left to right. Something
about endianness.

e.g. 
1234
5678
ABCD
->
0000ABCD 00005678 00001234

Strategy:
    - Iterate through mem.mem <= 16 lines (Words) at a time
    - zero-extend each hex to Word length, then concatenate
    - put new line into output as hex

    - for @line directives, we divide by 0x10
"""
def to_string(list_of_words):
    list_of_words.reverse()
    output = "".join(list_of_words)
    # .lstrip("0")

    if not output:
        output = "0"

    list_of_words.clear()
    #  
    return "a"*(128-len(output)) + output + "\n"

ROM_WIDTH = 1

def convert_rom(inp_rom):
    with open(inp_rom, 'rb') as input, open("build/hw/rom.mem", "w") as output:
        output.write('@')
        ind = 0
        line = ""

        # I think Will's ROM format has two words of metadata to start
        # TODO
        input.read(4)
        input.read(4) 

        while (word := input.read(4)):
            # should always be able to get a word at a time
            assert len(word) == 4
            # big because we don't want to touch the encoding
            # it is actually little endian
            word = int.from_bytes(word, "big") 
            if ind == 0:
                output.write(line + '\n')
                line = ""
            line = "{0:08x}".format(word) + line
            ind = (ind+1) % ROM_WIDTH
        if ind > 0:
            output.write("a"*8*(ROM_WIDTH-ind) + line)
        elif ind == 0:
            output.write(line)

def simulate(prog):
    convert_rom(prog)
    r = subprocess.run(["sh", "Sim"], cwd="build/hw/")
    if r.returncode:
        exit(r.returncode)

if __name__ == "__main__":

    if len(sys.argv) < 2:
        print("Please supply a .rom or directory containing them as an argument.")
    argv = sys.argv[1:]
    progs = []

    for arg in argv:
        arg_p = "build/sw/" + arg
        if os.path.isdir(arg_p):
            for f in os.listdir(arg_p):
                if f.endswith(".rom"):
                    progs.append(arg_p + "/" + f)
        else:
            if not arg_p.endswith(".rom"):
                print("Please supply a .rom or directory containing them as an argument: " + arg_p)
            progs.append(arg_p)
    

    for prog in progs:
        if len(progs) > 1:
            print(f"Testing {prog}...\n")
        simulate(prog)
        if len(progs) > 1:
            print(f"{prog} finish!\n")