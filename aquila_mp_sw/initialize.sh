export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
cd elibc
make
cd ../ocr_2core
./build.sh
cd ../uartboot
make
cd ..