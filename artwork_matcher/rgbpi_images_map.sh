##
## given a set of artwork images for a retrogaming system, it maps filenames to match the format required by rgpbi os
## usage:  sh map.sh %systemname% %outputfolder% sortedgames.dat, note that output folder will be erased a rebuilt from scratch
##

#!/bin/bash


##given a rgbpi games.dat formatted file it adds a colum with a key to match images and sorts it
##TODO refactor code  duplicated  with prepareImagesList
prepareMatchesFile() {

    local InputFile="$1"
    local OutputFile="$2"

    #switch to pipe separated, remove double quotes and start the awk fun
    sed  -e 's/","/|/g'  -e 's/"//g'  $InputFile | awk -F'|' 'BEGIN {OFS="|"}{
    SearchKey=$5

    # Extract file name only
    split(SearchKey, PathParts, "/");
    SearchKey = PathParts[length(PathParts)];
    
    #strip version info from amiga games, .i.e v2.0_AGA_1337.lha
    gsub(/_v[0-9](\.[0-9]+)*\.[0-9][^\.]*.(lha|zip)/,"", SearchKey);

    # Strip round and square brackets and their contents
    gsub(/(\[[^\]]*\]|\([^\)]*\))/,"", SearchKey);   

    # Strip extension
    gsub(/\.[a-z|A-Z|0-9]{3}$/, "", SearchKey);

    # Strip ", The" and "The "
    gsub(/, The/, "", SearchKey);
    gsub(/^The /, "", SearchKey);

    # Strip ", A" "A "
    gsub(/, A/, "", SearchKey);
    gsub(/\/A /, "", SearchKey);

    # Strip specified characters, 047 is single '' 
    gsub(/["\047!_?\-&\-\.]/, "", SearchKey);

    # Remove spaces
    gsub(/ /, "",SearchKey);

    #lower case
    SearchKey=tolower(SearchKey)
   
    print SearchKey"|"$0

    } ' | sort -t '|' -k1,1  >$OutputFile
}



##given a list of image files stored in a file, outputs the intermediate csv file required to map them to rgbpi format
## if ImageLookupFile is passed, does a double pass replacing the prepped image filename search keys with what's available in the lookup file
## besides using image filenames.
prepareImagesList() {
    local InputFile="$1"
    local OutputFile="$2"
    local LookupFile="$3"

    awk -F'|' 'BEGIN {OFS="|"}{
    ImageFilename = $1;  # Store the original first field
    
    SearchKey=$0

    # Extract file name only
    split(SearchKey, PathParts, "/");
    SearchKey = PathParts[length(PathParts)];
    
    # Strip round and square brackets and their contents
    gsub(/(\[[^\]]*\]|\([^\)]*\))/,"", SearchKey);   

    #strip AGA|ALG|RTG from name ending, for amiga games
    gsub(/ (AGA|ALG|RTG)\.png/,"", SearchKey);

    # Strip ".png"
    gsub(/\.png$/, "", SearchKey);

    # Strip ", The" and "The "
    gsub(/, The/,"", SearchKey);
    gsub(/^The /,"", SearchKey);

    # Strip ", A" "A "
    gsub(/, A/,"", SearchKey);
    gsub(/\/A /,"", SearchKey);

    # Strip specified characters, 047 is single '' 
    gsub(/["\047!_?\-&\.]/, "", SearchKey);

    # Remove spaces
    gsub(/ /, "", SearchKey);

    #lower case
    SearchKey=tolower(SearchKey)


    # Determine region code
    if (ImageFilename ~ /\((Japan|JAPAN|japan|jap)\)/) {
        Region = "jap";
    } else if (ImageFilename ~ /\((USA|usa|us|US)\)/) {
        Region = "usa";
    } else {
        Region = "eur";
    }
    print SearchKey"|"ImageFilename"|"Region 
} ' $InputFile  | sort -t '|' -k1,1 >$OutputFile


 # if a remap file is passed, use it to replace search keys coming form image names with the corresponding value in the lookup file, this 
 # is useful for datasets where image names are very different from rom names, but a lookup table is available. the lookup table is expected 
 # to have prepped values, see the awk above
 if [[ $ImageLookupFile ]]; then
    # future me, sorry for this headache factory, remember to list fields you want to output explicitly here
    awk -F'|' 'FNR==NR {LookUpArray[$1]=$2;next} { if($1 in LookUpArray){$1=LookUpArray[$1]}else{$1=$1} print $1"|"$2"|"$3  }' $ImageLookupFile $OutputFile  |  sort -t '|' -k1,1 > LookedUpArray.tmp
    cat  $OutputFile >> LookedUpArray.tmp 
    cat LookedUpArray.tmp  | sort -t '|' -k1,1 | uniq > $OutputFile  
 fi

 


}


# joins intermediate images list and outputs it to a file containing the game identifier, the region and the original file name. all lines
# in the same file are for the same media type, it is also assumed that all images are for the same platform
# Expect both InputFile and MatchFile to be sorted
createMatches() {
    local InputFile="$1"
    local OutputFile="$2"
    local MatchFile="$3"
    local UnmacthedFile="$4"
    local Platform="$5"

    #temp file with only games for the current platform, platform is the 5th field in the match file
    awk -F '|' '$4 == "'"$Platform"'" {print}' "$MatchFile"  > ./temp_filtered_gamesdat.tmp
    
    join -t '|' -1 1 -2 1  $InputFile ./temp_filtered_gamesdat.tmp | awk -F "|" {'print $2"|"$3"|"$4'}  | sort -t '|' -k1,1 | uniq  > $OutputFile

    #create list of unmatched files: do an inner and outer join and the keep the differences
    join -a2  -t '|' -1 1 -2 1 $InputFile ./temp_filtered_gamesdat.tmp | sort -t '|' -k1,1  | uniq > ./temp_right_join.tmp
    join -a1  -t '|' -1 1 -2 1 $InputFile ./temp_filtered_gamesdat.tmp | sort -t '|' -k1,1 | uniq  > ./temp_left_join.tmp
    
    comm -23 temp_left_join.tmp temp_right_join.tmp | sort -t '|' -k1,1 | uniq > ./$OutputFolder/$UnmacthedFile
}

# given the intermediate format list generated by prepareImagesList(), copies artwork files to the destination folder using
# %code%_[box|ingame|title]_[eur|jap|usa].png format
copyFiles() {
    local InputFile="$1"
    local ArtType="$2"
    local OutputFolder="$3"

    # Cycle through each line in the CSV file
    while IFS='|' read -r field1 field2 field3 rest; do
        # Check if the line has enough fields (at least 3)
        if [ -n "$field3" ]; then
            # Extract the file path from field 1 and check if the file exists
            FilePath="$field1"
            if [ -f "$FilePath" ]; then
                NewFilename="./$OutputFolder/${field3}_"$ArtType"_$field2.png"

                # Copy the file to output folder and rename it
                cp "$FilePath" "$NewFilename"
                echo "Copied and renamed '$FilePath' to '$NewFilename'"
            else
                echo "File not found: $FilePath"
            fi
        else
            echo "Not enough fields for this image, received:  $field1 $field2 $field3"
        fi
    done <"$InputFile"
}

# Function to display usage instructions
usage() {
    echo "Usage: $0 Platform OutputFolder MatchFile [--debug] [--imagelookupfile=] [--resize] [--sourcefolder=] "
    echo "Platform, Output Folder, games.dat (prepped) file:  Required positional parameters"
    echo "--debug: if set, doesn't delete temp files and copy images"
    echo "--imagelookupfile: if set, uses a lookup file to replace images prep filenames key"
    echo "--resize: if set, uses Imagemagick to resize images to fit a 240p screen, skipped in debug mode"
    echo "--sourcefolder: if set, searched for Box Art, Snaps and Title Screens in its sufbolders"
    exit 1  # Exit with an error code if usage is incorrect
}

# Check for the correct number of positional parameters
if [[ $# -lt 3 ]]; then
    usage
fi

# Assign positional parameters to variables
Platform=$1
OutputFolder=$2
MatchFile=$3

# Initialize variables for optional parameters
Debug=false
Resize=false
SourceFolder=.
ImageLookupFile=

# Parse optional parameters
while [[ $# -gt 3 ]]; do
    key="$4"
    case $key in
        --debug)
            Debug=true
            shift # Shift to the next argument
            ;;
        --imagelookupfile=*)
            ImageLookupFile="${key#*=}" 
            shift # Shift to the next argument
            ;;
        --resize)
            Resize=true
            shift # Shift to the next argument
            ;;
        --sourcefolder=*)
            SourceFolder="${key#*=}" 
            shift # Shift to the next argument
            ;;
        *)
            echo "Error: Unknown option $key"
            usage
            ;;
    esac
done


prepareMatchesFile $MatchFile prep_match_file.tmp


shopt -s nocaseglob
ls $SourceFolder/*boxarts/*.png > boxarts.tmp
ls $SourceFolder/*snaps/*.png > snaps.tmp
ls $SourceFolder/*titles/*.png > titles.tmp
shopt -u nocaseglob


#create intermediate input, processed images list
prepareImagesList "boxarts.tmp" "prep_boxarts.tmp" 
prepareImagesList "snaps.tmp" "prep_snaps.tmp" 
prepareImagesList "titles.tmp" "prep_titles.tmp" 

#map with games.dat from rgbpi and output  fields required for renaming only
#todo automate the creation of preprocessed $MatchFile
createMatches prep_boxarts.tmp out_boxarts.tmp prep_match_file.tmp unmatched_boxarts.out $Platform $ImageLookupFile
createMatches prep_snaps.tmp out_snaps.tmp prep_match_file.tmp unmatched_snaps.out $Platform $ImageLookupFile
createMatches prep_titles.tmp out_titles.tmp prep_match_file.tmp unmatched_titles.out $Platform $ImageLookupFile


#output remapped files
if [ "$Debug" != true ]; then

    #clean old results
    rm -rf $OutputFolder
    mkdir $OutputFolder

    #do the actual copies
    copyFiles out_boxarts.tmp box $OutputFolder
    copyFiles out_snaps.tmp ingame $OutputFolder
    copyFiles out_titles.tmp title $OutputFolder

    #clean the workbench
    rm *.tmp

    if [ "$Resize" = true ]; then
        if which mogrify >/dev/null; then
            echo "Resizing images to 300x225, this may take a while."
            mogrify -resize 300x225 ./$OutputFolder/*.png -quality 100
        else
            echo "Please install Imagemagick to enable images resizing, https://imagemagick.org/index.php"
        fi
    fi
else
    echo "Debug mode, skipped files copy and left temp files on disk"
fi





