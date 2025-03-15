export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
make clean
make PROJ=ocr_0
make PROJ=ocr_1
make PROJ=ocr_2
make PROJ=ocr_3