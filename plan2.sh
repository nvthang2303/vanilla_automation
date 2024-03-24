#!/bin/bash
dir=$(pwd)
repS="python3 $dir/bin/strRep.py"

jar_util() 
{
	cd $dir
	#binary
	if [[ $3 == "fw" ]]; then 
		bak="java -jar $dir/bin/baksmali.jar d"
		sma="java -jar $dir/bin/smali.jar a"
	else
		bak="java -jar $dir/bin/baksmali-2.5.2.jar d"
		sma="java -jar $dir/bin/smali-2.5.2.jar a"
	fi

	if [[ $1 == "d" ]]; then
		echo -ne "====> Patching $2 : "
		if [[ -f $dir/framework.jar ]]; then
			sudo cp $dir/framework.jar $dir/jar_temp
			sudo chown $(whoami) $dir/jar_temp/$2
			unzip $dir/jar_temp/$2 -d $dir/jar_temp/$2.out  >/dev/null 2>&1
			if [[ -d $dir/jar_temp/"$2.out" ]]; then
				rm -rf $dir/jar_temp/$2
				for dex in $(find $dir/jar_temp/"$2.out" -maxdepth 1 -name "*dex" ); do
						if [[ $4 ]]; then
							if [[ ! "$dex" == *"$4"* ]]; then
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
				for fld in $(find -maxdepth 1 -name "*.out" ); do
					if [[ $4 ]]; then
						if [[ ! "$fld" == *"$4"* ]]; then
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
				zipalign 4 $dir/jar_temp/$2_notal $dir/jar_temp/$2
				if [[ -f $dir/jar_temp/$2 ]]; then
					sudo cp -rf $dir/jar_temp/$2 $dir/module/system/framework/framework.jar
					final_dir="$dir/module/*"
					#7za a -tzip "$dir/framework_patched_$(date "+%d%m%y").zip" $final_dir
					echo "Success"
					rm -rf $dir/jar_temp/$2.out $dir/jar_temp/$2_notal 
				else
					echo "Fail"
				fi
			fi
		fi
	fi
}


framework() {
    lang_dir="$dir/module/lang"
    temp_dir=$(mktemp -d)

    # Extract framework.jar
    unzip -q "framework.jar" -d "$temp_dir"

    # Find ApplicationPackageManager.smali
    smali_file=$(find "$temp_dir" -name "ApplicationPackageManager")

    if [[ -f "$smali_file" ]]; then
        # Create a new file with the desired content
        temp_file=$(mktemp)
        {
            cat "$smali_file"
            echo ""
            echo "# static fields"
            echo ".field private static final blacklist featuresNexus:[Ljava/lang/String;"
            echo ".field private static final blacklist featuresPixel:[Ljava/lang/String;"
            echo ".field private static final blacklist featuresPixelOthers:[Ljava/lang/String;"
            echo ".field private static final blacklist featuresTensor:[Ljava/lang/String;"
            echo ".field private static final blacklist pTensorCodenames:[Ljava/lang/String;"
        } > "$temp_file"

        # Replace the original file with the new one
        mv "$temp_file" "$smali_file"
    else
        echo "ApplicationPackageManager.smali not found"
        exit 1
    fi

    # Rebuild framework.jar
    cd "$temp_dir"
    zip -r -q "../framework.jar" .
    cd - > /dev/null

    # Clean up temporary directory
    rm -rf "$temp_dir"
}

if [[ ! -d $dir/jar_temp ]]; then

	mkdir $dir/jar_temp
	
fi

framework

