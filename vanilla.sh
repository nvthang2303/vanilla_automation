#!/bin/bash

dir=$(pwd)
repM="python3 $dir/bin/strRep.py"

get_file_dir() {
    if [[ $1 ]]; then
        find $dir/ -name $1
    else
        return 0
    fi
}

jar_util() {
    if [[ ! -d $dir/jar_temp ]]; then
        mkdir $dir/jar_temp
    fi

    bak="java -jar $dir/bin/baksmali.jar d --api 33"
    sma="java -jar $dir/bin/smali.jar a --api 33"

    if [[ $1 == "d" ]]; then
        echo "====> Disassembling $2"

        file_path=$(get_file_dir $2)
        if [[ $file_path ]]; then
            cp "$file_path" $dir/jar_temp
            chown $(whoami) $dir/jar_temp/$2
            unzip $dir/jar_temp/$2 -d $dir/jar_temp/$2.out >/dev/null 2>&1
            if [[ -d $dir/jar_temp/"$2.out" ]]; then
                rm -rf $dir/jar_temp/$2
                for dex in $(find $dir/jar_temp/"$2.out" -maxdepth 1 -name "*dex" ); do
                    echo "Disassembling $dex"
                    $bak $dex -o "$dex.out"
                    [[ -d "$dex.out" ]] && rm -rf $dex
                done
            fi
        fi
    elif [[ $1 == "a" ]]; then
        if [[ -d $dir/jar_temp/$2.out ]]; then
            cd $dir/jar_temp/$2.out || exit 1
            for fld in $(find . -maxdepth 1 -name "*.out" ); do
                echo "Assembling $fld"
                $sma $fld -o ${fld//.out}
                [[ -f ${fld//.out} ]] && rm -rf $fld
            done
            7za a -tzip -mx=0 $dir/jar_temp/$2_notal $dir/jar_temp/$2.out/. >/dev/null 2>&1
            zipalign -p -v 4 $dir/jar_temp/$2_notal $dir/jar_temp/$2 >/dev/null 2>&1
            if [[ -f $dir/jar_temp/$2 ]]; then
                rm -rf $dir/jar_temp/$2.out $dir/jar_temp/$2_notal
                echo "Success"
            else
                echo "Failed to create $2"
                return 1
            fi
        fi
    fi
}

CLASSES4_DEX="$dir/cts14/classes4.dex"
FRAMEWORK_JAR="$dir/framework.jar"
TMP_DIR="$dir/jar_temp"
CLASSES4_DIR="$TMP_DIR/classes4.out"
FRAMEWORK_DIR="$TMP_DIR/framework.jar.out/classes4.dex.out"

mkdir -p "$TMP_DIR"


echo "Disassembling framework.jar"
jar_util d "framework.jar" fw

echo "Disassembling classes4.dex"
java -jar $dir/bin/baksmali.jar d "$CLASSES4_DEX" -o "$CLASSES4_DIR"

if [[ ! -d "$CLASSES4_DIR" ]]; then
    echo "Error: Failed to disassemble classes4.dex"
    exit 1
fi

echo "Copying disassembled .smali files from classes4.dex to framework.jar"
cp -rf "$CLASSES4_DIR"/* "$FRAMEWORK_DIR"/

echo "Assembling framework.jar"
jar_util a "framework.jar" fw

# Check if framework.jar exists in the jar_temp directory
if  [ -f $dir/jar_temp/framework.jar ]; then
		sudo cp -rf $dir/jar_temp/*.jar $dir/module/system/framework
	else
		echo "Fail to copy framework"
fi
