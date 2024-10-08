export PATH=$PATH:/opt/riscv/bin
export RISCV=/opt/riscv

cd CoreMark
make ddr

cd ../CoreMark2

make ddr

cd ..

python3 padding.py