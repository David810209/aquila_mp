export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv
make clean
make PROJ=test_0
make PROJ=test_1
make PROJ=test_2
make PROJ=test_3
# make PROJ=test_4
# make PROJ=test_5
# make PROJ=test_6
# make PROJ=test_7