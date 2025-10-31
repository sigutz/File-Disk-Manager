analyze_files() {
    file1="$1"
    file2="$2"

    echo -e "\e[1;32mAdded files/directories:\e[0m"
    added=$(comm -13 <(sort "$file1") <(sort "$file2"))
    if [[ -z "$added" ]]; then
        echo "  None"
    else
        echo "$added" | sed 's/^/  + /'
    fi

    echo -e "\e[1;31mRemoved files/directories:\e[0m"
    removed=$(comm -23 <(sort "$file1") <(sort "$file2"))
    if [[ -z "$removed" ]]; then
        echo "  None"
    else
        echo "$removed" | sed 's/^/  - /'
    fi
}

convert_for_df() {
    input_file="$1"
    output_file=$(mktemp)

    grep -E '^(none|/dev/sdc|drivers|tmpfs|C:\\|snapfuse|rootfs)' "$input_file" > "$output_file"
    echo "$output_file"
}

disk_usage() {
    df_file1="$1"
    df_file2="$2"

    echo -e "\e[1;34mDisk usage changes:\e[0m"

    added=$(comm -13 <(sort "$df_file1") <(sort "$df_file2"))
    if [[ -n "$added" ]]; then
        echo -e "\e[1;32mAdded entries:\e[0m"
        echo "$added" | sed 's/^/  + /'
    fi

    removed=$(comm -23 <(sort "$df_file1") <(sort "$df_file2"))
    if [[ -n "$removed" ]]; then
        echo -e "\e[1;31mRemoved entries:\e[0m"
        echo "$removed" | sed 's/^/  - /'
    fi

    if [[ -z "$added" && -z "$removed" ]]; then
        echo "  None"
    fi
}

if [[ $# -lt 1 ]]; then
    echo -e "\e[1;31mUsage:\e[0m $0 [--current] <typescript1> [typescript2 ... typescriptN]"
    exit 1
fi

compare_with_current=false
if [[ "$1" == "--current" ]]; then
    compare_with_current=true
    shift
fi

convert_to_txt() {
    input_file="$1"
    output_file=$(mktemp)

    sed -n '/^total\|^[-d]rw\|^[-d]rwx/p' "$input_file" | awk '{print $NF}' > "$output_file"
    echo "$output_file"
}

temp_files=()
for i in $(seq 1 $#); do
    txt_file1=$(convert_to_txt "${!i}")
    df_file1=$(convert_for_df "${!i}")
    temp_files+=("$txt_file1" "$df_file1")

    for j in $(seq $((i + 1)) $#); do
        echo -e "\n\e[1;34mAnalyzing changes between ${!i} and ${!j}\e[0m"
        txt_file2=$(convert_to_txt "${!j}")
        df_file2=$(convert_for_df "${!j}")
        temp_files+=("$txt_file2" "$df_file2")

        if [[ -s "$txt_file1" && -s "$txt_file2" ]]; then
            analyze_files "$txt_file1" "$txt_file2"
        else
            echo "  One or both txt files are empty; skipping file analysis."
        fi

        if [[ -s "$df_file1" && -s "$df_file2" ]]; then
            disk_usage "$df_file1" "$df_file2"
        else
            echo "  One or both df files are empty; skipping disk usage analysis."
        fi
    done

    if [[ $compare_with_current == true ]]; then
        current_ls=$(mktemp)
        current_df=$(mktemp)

        ls -l > "$current_ls"
        df > "$current_df"

        current_ls_converted=$(convert_to_txt "$current_ls")
        current_df_converted=$(convert_for_df "$current_df")

        echo -e "\n\e[1;34mAnalyzing changes between ${!i} and the current state\e[0m"

        if [[ -s "$txt_file1" && -s "$current_ls_converted" ]]; then
            analyze_files "$txt_file1" "$current_ls_converted"
        else
            echo "  One or both txt files are empty; skipping file analysis."
        fi

        if [[ -s "$df_file1" && -s "$current_df_converted" ]]; then
            disk_usage "$df_file1" "$current_df_converted"
        else
            echo "  One or both df files are empty; skipping disk usage analysis."
        fi

        temp_files+=("$current_ls" "$current_df" "$current_ls_converted" "$current_df_converted")
    fi

done

for temp_file in "${temp_files[@]}"; do
    rm -f "$temp_file"
done

echo -e "\e[1;32mAnalysis complete!\e[0m"

