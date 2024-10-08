import os

# 定義兩個檔案路徑
elf_paths = ["CoreMark/coremark.elf", "CoreMark2/coremark.elf"]

elf_list = []
for filepath in elf_paths:
    if os.path.exists(filepath):
        with open(filepath, 'rb') as f:
            elf_data = f.read()

        # 加上 b'\xFF'
        elf_data += b'\xFF'

        # 將修改後的 ELF 資料寫回原檔案
        with open(filepath, 'wb') as f:
            f.write(elf_data)

        elf_list.append(filepath)
    else:
        print(f"File {filepath} does not exist")

print(elf_list)
