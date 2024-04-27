



process_list() {
  local input_file="$1"
  local output_file="$2"
  local platform="$3"

   
  awk -F'|' -v platform="$platform" 'BEGIN {OFS="|"}{
    new_field = $0; 

    original_field = $1;  # Store the original first field
    
    # Replace .png with .zip
    gsub(".png",".zip",$0);

    # Strip round brackets and their contents
    gsub(/\([^)]*\)/,"", $0);   

    # Strip ", The"
    gsub(/, The/, "", $0);

   # Strip ", A"
    gsub(/, A/, "", $0);

    # Strip specified characters
    gsub(/[-_''!]/, "", $0);

    # Remove duplicate spaces
    gsub(/ +/, "", $0);


    # Replace " .zip" at the end with ".zip"
    #gsub(/ .zip/,".zip", $0);

    $0 = $0"_"platform;

    split($0, path_parts, "/");
    search_key = path_parts[length(path_parts)];

    # Determine region code
    if ($1 ~ /\(Japan\)/) {
        region = "jap";
    } else if ($1 ~ /\(USA\)/) {
        region = "usa";
    } else {
        region = "eur";
    }
   
    print original_field"|"$0"|"search_key"|"region 
} ' $input_file > $output_file
}


copy_files()
{
  local input_file="$1"
  local art_type="$2"
  local output_folder="$3"

# Cycle through each line in the CSV file
while IFS='|' read -r field1 field2 field3 rest; do
    # Check if the line has enough fields (at least 3)
    if [ -n "$field3" ]; then
        # Extract the file path from field 1 and check if the file exists
        file_path="$field1"
        if [ -f "$file_path" ]; then
            # Construct the new filename in /temp/xxx
            new_filename="./$output_folder/${field3}_"$art_type"_$field2.png"
            
            # Copy the file to /temp/xxx and rename it
            cp "$file_path" "$new_filename"
            echo "Copied and renamed '$file_path' to '$new_filename'"
        else
echo "File not found: $file_path"
        fi
    else
        echo "Not enough fields in line: $line"
    fi
done < "$input_file"
}

ls ./Named_Boxarts/*.png > Named_Boxarts.txt
ls ./Named_Snaps/*.png > Named_Snaps.txt
ls ./Named_Titles/*.png > Named_Titles.txt

platform=$1 
output_folder=$2
match_file=$3

process_list "Named_Boxarts.txt" "Prep_Named_Boxarts.txt" $platform
process_list "Named_Snaps.txt" "Prep_Named_Snaps.txt" $platform
process_list "Named_Titles.txt" "Prep_Named_Titles.txt" $platform  


join -t '|' -1 3 -2 1  Prep_Named_Boxarts.txt $match_file |  awk  -F "|" {'print $2"|"$4"|"$6'} > Out_Named_Boxarts.txt
join -t '|' -1 3 -2 1  Prep_Named_Snaps.txt $match_file  |  awk  -F "|"  {'print $2"|"$4"|"$6'} > Out_Named_Snaps.txt
join -t '|' -1 3 -2 1  Prep_Named_Titles.txt $match_file  | awk  -F "|"  {'print $2"|"$4"|"$6'} > Out_Named_Titles.txt


#clean old results
rm -rf $output_folder 
mkdir $output_folder

copy_files Out_Named_Boxarts.txt box $output_folder
copy_files Out_Named_Snaps.txt ingame $output_folder
copy_files Out_Named_Titles.txt title $output_folder

rm *.txt










