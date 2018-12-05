lwasm -9bl -p cd -o obj\fade.bin src\fade.asm > obj\fade.lst
imgtool put coco_jvc_rsdos BOOMRANG.dsk obj/fade.bin fade.bin
