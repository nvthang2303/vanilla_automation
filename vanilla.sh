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
					echo "Succes"
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
	FRAMEWORK_JAR="framework.jar"  # Adjusted for the jar_util function
	TMP_DIR="$dir/jar_temp"
	CLASSES4_DIR="$TMP_DIR/classes4"
	FRAMEWORK_DIR="$TMP_DIR/framework"

	# Create a temporary directory
	mkdir -p "$TMP_DIR"

	# Ensure previous extractions are cleaned up
	rm -rf "$FRAMEWORK_DIR" "$CLASSES4_DIR"

	# Disassemble framework.jar using jar_util
	jar_util d "$FRAMEWORK_JAR" fw classes*

	# Disassemble classes4.dex
	jar_util d -o "$CLASSES4_DIR" fw "$CLASSES4_DEX"

	declare -a SMALI_FILES=(
		"android/app/ApplicationPackageManager.smali"
    	"android/app/Instrumentation.smali"
    	"android/security/keystore2/AndroidKeyStoreSpi.smali"
    	"com/android/internal/util/summert/AttestationHooks.smali"
    	"com/android/internal/util/summert/GamesPropsUtils.smali"
    	"com/android/internal/util/summert/PixelPropsUtils.smali"
    	"com/android/internal/util/summert/PixelPropsUtils\$1.smali"
    	"com/android/internal/util/summert/PixelPropsUtils\$\$ExternalSyntheticLambda0.smali"
    	"com/android/internal/util/summert/PixelPropsUtils\$\$ExternalSyntheticLambda1.smali"
    	"com/android/internal/util/summert/AttestationHooks\$\$ExternalSyntheticLambda0.smali"
	)
	for smali_file in "${SMALI_FILES[@]}"; do
    	rm -f "$FRAMEWORK_DIR/smali/$smali_file"
	done

# Copy the specified files from classes4.dex to the framework directory
	for smali_file in "${SMALI_FILES[@]}"; do
    	src_file="$CLASSES4_DIR/$smali_file"
    	dest_file="$FRAMEWORK_DIR/smali/$smali_file"
    	mkdir -p "$(dirname "$dest_file")"
    	cp -f "$src_file" "$dest_file"
	done
	
	jar_util a "$FRAMEWORK_JAR" fw classes*
}

if [[ ! -d $dir/jar_temp ]]; then

	mkdir $dir/jar_temp
	
fi

framework


if  [ -f $dir/jar_temp/framework.jar ]; then
		sudo cp -rf $dir/jar_temp/*.jar $dir/module/system/framework
	else
		echo "Fail to copy framework"
fi