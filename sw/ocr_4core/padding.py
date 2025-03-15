import os

file_list = os.listdir()

elf_files = [filename for filename in file_list if filename.endswith('.elf')]

elf_list = []
for filename in elf_files:
    with open(filename, 'rb') as f:
        elf_data = f.read()
    
        # 加上 b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
        elf_data += b'\xFF'
    
    with open(filename, 'wb') as f:
        f.write(elf_data)
    
    elf_list.append(filename)

print(elf_list)
