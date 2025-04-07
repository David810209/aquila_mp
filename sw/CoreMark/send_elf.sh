FILE_0="./CoreMark/coremark.elf"
FILE_1="./Dummy/test_1.elf"
FILE_2="./Dummy/test_2.elf"
FILE_3="./Dummy/test_3.elf"

echo "sending $FILE_0"
cat $FILE_0 > /dev/ttyUSB1
sleep 3
printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
sleep 1
echo "$FILE_0 sent done"

echo "sending $FILE_1"
cat $FILE_1 > /dev/ttyUSB1
sleep 3
printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
sleep 1
echo "$FILE_1 sent done"

echo "sending $FILE_2"
cat $FILE_2 > /dev/ttyUSB1
sleep 3
printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
sleep 1
echo "$FILE_2 sent done"

echo "sending $FILE_3"
cat $FILE_3 > /dev/ttyUSB1
sleep 3
printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
sleep 1
echo "$FILE_3 sent"