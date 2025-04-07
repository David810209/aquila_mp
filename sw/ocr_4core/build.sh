export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
make clean
make PROJ=ocr_0
make PROJ=ocr_1
make PROJ=ocr_2
make PROJ=ocr_3
# make PROJ=ocr_4
# make PROJ=ocr_5
# make PROJ=ocr_6
# make PROJ=ocr_7