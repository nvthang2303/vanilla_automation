#!/bin/bash

dir=$(pwd)
repM="python3 $dir/bin/strRep.py"

get_file_dir() {
	if [[ $1 ]]; then
		sudo find $dir/ -name $1 
	else 
		return 0
	fi
}

jar_util() 
{

	if [[ ! -d $dir/jar_temp ]]; then
		mkdir $dir/jar_temp
	fi

	#binary
	bak="java -jar $dir/bin/baksmali.jar d"
	sma="java -jar $dir/bin/smali.jar a"

	if [[ $1 == "d" ]]; then
		echo -ne "====> Patching $2 : "

		if [[ $(get_file_dir $2 ) ]]; then
			sudo mv $(get_file_dir $2 ) $dir/jar_temp
			sudo chown $(whoami) $dir/jar_temp/$2
			unzip $dir/jar_temp/$2 -d $dir/jar_temp/$2.out  >/dev/null 2>&1
			if [[ -d $dir/jar_temp/"$2.out" ]]; then
				rm -rf $dir/jar_temp/$2
				for dex in $(sudo find $dir/jar_temp/"$2.out" -maxdepth 1 -name "*dex" ); do
						if [[ $4 ]]; then
							if [[ "$dex" != *"$4"* && "$dex" != *"$5"* ]]; then
								$bak $dex -o "$dex.out"
								[[ -d "$dex.out" ]] && rm -rf $dex
							fi
						else
							$bak $dex -o "$dex.out"
							[[ -d "$dex.out" ]] && rm -rf $dex		
						fi

				done
			fi
		fi
	else 
		if [[ $1 == "a" ]]; then 
			if [[ -d $dir/jar_temp/$2.out ]]; then
				cd $dir/jar_temp/$2.out
				for fld in $(sudo find -maxdepth 1 -name "*.out" ); do
					if [[ $4 ]]; then
						if [[ "$fld" != *"$4"* && "$fld" != *"$5"* ]]; then
							echo $fld
							$sma $fld -o $(echo ${fld//.out})
							[[ -f $(echo ${fld//.out}) ]] && rm -rf $fld
						fi
					else 
						$sma $fld -o $(echo ${fld//.out})
						[[ -f $(echo ${fld//.out}) ]] && rm -rf $fld	
					fi
				done
				7za a -tzip -mx=0 $dir/jar_temp/$2_notal $dir/jar_temp/$2.out/. >/dev/null 2>&1
				#zip -r -j -0 $dir/jar_temp/$2_notal $dir/jar_temp/$2.out/.
				zipalign -p -v 4 $dir/jar_temp/$2_notal $dir/jar_temp/$2 >/dev/null 2>&1
				if [[ -f $dir/jar_temp/$2 ]]; then
					rm -rf $dir/jar_temp/$2.out $dir/jar_temp/$2_notal 
					#sudo cp -rf $dir/jar_temp/$2 $(get_file_dir $2) 
					echo "Success"
				else
					echo "Fail"
				fi
			fi
		fi
	fi
}

repM () {
	if [[ $4 == "r" ]]; then
		if [[ -f $3 ]]; then
			$repM $1 $2 $3
		fi
	elif [[ $4 == "f" ]]; then
		for i in $3; do
			$repM $1 $2 $i
		done
	else
		file=$(sudo find -name $3)
		if [[ $file ]]; then
			$repM $1 $2 $file
		fi
	fi
}

framework() {
    CLASSES4_DEX="$dir/cts14/classes4.dex"
    FRAMEWORK_JAR="framework.jar"
    TMP_DIR="$dir/jar_temp"
    CLASSES4_DIR="$TMP_DIR/classes4.out"
    FRAMEWORK_DIR="$TMP_DIR/framework.out"

    mkdir -p "$TMP_DIR"

    rm -rf "$FRAMEWORK_DIR" "$CLASSES4_DIR"

    echo "Disassembling framework.jar"
    jar_util d "$FRAMEWORK_JAR" fw classes classes*

    echo "Disassembling classes4.dex"
    jar_util d  "$CLASSES4_DEX" fw -o "$CLASSES4_DIR"
    if [[ ! -d "$CLASSES4_DIR" ]]; then
        echo "Error: Failed to disassemble classes4.dex"
        exit 1
    fi

    for src_dir in $(find "$CLASSES4_DIR" -type d); do
        dest_dir="$FRAMEWORK_DIR/${src_dir#$CLASSES4_DIR}"
        mkdir -p "$dest_dir"
    done

    for smali_file in $(find "$CLASSES4_DIR" -name "*.smali"); do
        dest_file="$FRAMEWORK_DIR/${smali_file#$CLASSES4_DIR}"
        echo "Copying $smali_file to $dest_file"
        cp "$smali_file" "$dest_file"
    done

    jar_util a "$FRAMEWORK_JAR" fw
}

if [[ ! -d $dir/jar_temp ]]; then
    mkdir $dir/jar_temp
fi

framework

if [[ -f $dir/jar_temp/framework.jar ]]; then
    sudo cp -rf $dir/jar_temp/*.jar $dir/module/system/framework
else
    echo "Fail to copy framework"
fi
