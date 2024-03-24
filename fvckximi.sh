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
		bak="java -jar $dir/bin/baksmali-2.3.4.jar d"
		sma="java -jar $dir/bin/smali-2.3.4.jar a"
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
					sudo cp -rf $dir/jar_temp/$2 $dir/module/system/framework
					final_dir="$dir/module/*"
					#7za a -tzip "$dir/services_patched_$(date "+%d%m%y").zip" $final_dir
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

	jar_util d "framework.jar" fw classes classes2 classes3 

	#patch 

	s0=$(find -name ApplicationPackageManager.smali)
	[[ -f $s0 ]] && sed -i 's/# static fields/# static fields\n\n.field private static final blacklist featuresNexus:[Ljava\/lang\/String;\n\n.field private static final blacklist featuresPixel:[Ljava\/lang\/String;\n\n.field private static final blacklist featuresPixelOthers:[Ljava\/lang\/String;\n\n.field private static final blacklist featuresTensor:[Ljava\/lang\/String;\n\n.field private static final blacklist pTensorCodenames:[Ljava\/lang\/String;/g' "$s0"

 
    	
	
	jar_util a "framework.jar" fw classes classes2 classes3 
}

if [[ ! -d $dir/jar_temp ]]; then

	mkdir $dir/jar_temp
	
fi

framework

