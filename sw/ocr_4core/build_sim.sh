export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
make clean
make PROJ=ocr_0
make PROJ=ocr_1
make PROJ=ocr_2
make PROJ=ocr_3
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> ocr_0.elf
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> ocr_1.elf
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> ocr_2.elf
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> ocr_3.elf