for i in range(1024 * 768//4):
    j = i * 4
    print(f"{((j+3)&0xFF):02x}" + f"{((j+2)&0xFF):02x}" + f"{((j+1)&0xFF):02x}" + f"{((j)&0xFF):02x}")