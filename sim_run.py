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

def fix_mem(inp_hex):
    with open(inp_hex) as input, open("build/hw/memlines.mem", "w") as output:
        
        current_word = 0
        current_line = []

        for line in input:
            if '@' in line:
                if current_line:
                    output.write(to_string(current_line))
    
                current_word = 0

                num = line[1:-2]

                output.write("@" + str(num) + "\n")
                continue

            word = line.rjust(9, "0").strip()
            current_line.append(word)

            current_word = (current_word + 1) % 16
            
            if current_word == 0:
                output.write(to_string(current_line))

        if current_word != 0:
            output.write(to_string(current_line))

def simulate(prog):
    fix_mem(prog)
    r = subprocess.run(["sh", "Sim"], cwd="build/hw/")
    if r.returncode:
        exit(r.returncode)

if __name__ == "__main__":

    if len(sys.argv) < 2:
        print("Please supply a .hex or directory containing them as an argument.")
    argv = sys.argv[1:]
    progs = []

    for arg in argv:
        arg_p = "build/sw/" + arg
        if os.path.isdir(arg_p):
            for f in os.listdir(arg_p):
                if f.endswith(".hex"):
                    progs.append(arg_p + "/" + f)
        else:
            if not arg_p.endswith(".hex"):
                print("Please supply a .hex or directory containing them as an argument: " + arg_p)
            progs.append(arg_p)
    

    for prog in progs:
        if len(progs) > 1:
            print(f"Testing {prog}...\n")
        simulate(prog)
        if len(progs) > 1:
            print(f"{prog} finish!\n")