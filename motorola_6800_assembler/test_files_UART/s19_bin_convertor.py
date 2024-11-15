import os
import subprocess
import argparse

# Define a maximum address space size, e.g., 64KB for 16-bit addresses
MAX_ADDRESS_SPACE = 0x1FFF

def s19_to_bin(s19_file):
    # Automatically create output file name with .bin suffix
    bin_file = os.path.splitext(s19_file)[0] + ".bin"

    # Initialize the full address space with 0xFF (or other default value)
    address_space = bytearray([0xFF] * MAX_ADDRESS_SPACE)

    with open(s19_file, 'r') as s19:
        for line in s19:
            if line[0] != 'S':
                print("Skipping non-S-record line")
                continue

            record_type = line[1]
            byte_count = int(line[2:4], 16)
            
            # Determine address length and data start based on record type
            if record_type == '1':  # S1 record (16-bit address)
                addr = int(line[4:8], 16)
                data_start = 8
            elif record_type == '9':  # End-of-file record
                continue
            else:
                print("ERROR: Unsupported S-record type!")
                continue
            
            # Calculate data bytes by subtracting address and checksum bytes from byte count
            address_bytes = (data_start - 4) // 2
            data_bytes = byte_count - address_bytes - 1
            
            # Extract data bytes and write them to the address space at the specified address
            data = bytes.fromhex(line[data_start:data_start + data_bytes * 2])
            address_space[addr:addr + len(data)] = data

    # Write the entire initialized address space to the binary output file
    with open(bin_file, 'wb') as bin_out:
        bin_out.write(address_space)

    print(f"Conversion complete! Output file: {bin_file}")

# Set up argparse to handle command-line arguments
if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description="Convert S19 file to binary file.")
    parser.add_argument("s19_file", help="The input S19 file.")
    args = parser.parse_args()

    # Running the assembler program first to get the .s19 file for the script
    subprocess.run(["../bin/as0", f"{args.s19_file[:-4]}.asm"]) # [:-4] to remove the .s19 from the file name

    # Run the conversion function with the provided input file
    s19_to_bin(args.s19_file)
