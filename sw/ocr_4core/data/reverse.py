with open('test-images.dat', 'rb') as file:
    byte = file.read(1)
    int_list = []
    while byte:
        # 將每個字節轉換為對應的整數
        int_value = ord(byte)
        int_list.append(int_value)
        byte = file.read(1)

print(int_list[0:27456])
print(len(int_list[0:27456]))