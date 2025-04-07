FILE_0="ocr_0.elf"
FILE_1="ocr_1.elf"
FILE_2="ocr_2.elf"
FILE_3="ocr_3.elf"
# FILE_4="ocr_4.elf"
# FILE_5="ocr_5.elf"
# FILE_6="ocr_6.elf"
# FILE_7="ocr_7.elf"

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

# echo "sending $FILE_2"
# cat $FILE_2 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_2 sent done"

# echo "sending $FILE_3"
# cat $FILE_3 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_3 sent"

# echo "sending $FILE_4"
# cat $FILE_4 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_4 sent done"

# echo "sending $FILE_5"
# cat $FILE_5 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_5 sent done"

# echo "sending $FILE_6"
# cat $FILE_6 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_6 sent done"

# echo "sending $FILE_7"
# cat $FILE_7 > /dev/ttyUSB1
# sleep 3
# printf "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" > /dev/ttyUSB1
# sleep 1
# echo "$FILE_7 sent done"

