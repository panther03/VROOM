import sys

def verilog_hex_to_coe(input_file, output_file):
    try:
        # Open the input Verilog hex file
        with open(input_file, 'r') as infile:
            # Read all lines from the input file
            lines = infile.readlines()

        # Open the output COE file
        with open(output_file, 'w') as outfile:
            # Write the COE header
            outfile.write("memory_initialization_radix = 16;\n")
            outfile.write("memory_initialization_vector =\n")

            # Process each line in the input file
            for i, line in enumerate(lines):
                # Strip any leading/trailing whitespace and newlines
                line = line.strip()
                if line:  # Ensure the line is not empty
                    # Write the hex value to the COE file
                    outfile.write(line)
                    if i < len(lines) - 1:  # Add a comma unless it's the last line
                        outfile.write(",\n")
                    else:
                        outfile.write(";\n")  # End with a semicolon

        print(f"Conversion complete! COE file saved as {output_file}")

    except Exception as e:
        print(f"An error occurred: {e}")

assert len(sys.argv) == 3
# Example usage
input_file = sys.argv[1]  # Replace with your input file name
output_file = sys.argv[2]  # Replace with your desired output file name
verilog_hex_to_coe(input_file, output_file)