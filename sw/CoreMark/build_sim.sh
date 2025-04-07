export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
make clean
cd CoreMark
make ddr
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> coremark.elf
cd ../Dummy
make PROJ=test_1
make PROJ=test_2
make PROJ=test_3

printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> test_1.elf
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> test_2.elf
printf '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF' >> test_3.elf