#/bin/bash

articles="$(find articles -type f -iname "*.md")"

articles_with_date=$(mktemp)

for file in $articles; do
    creation_date=$(grep -m1 "^date:" "$file" | awk '{print $2}' | awk -F'.' '{printf "%s-%s-%s\n", $3, $2, $1}')
    echo "$creation_date"
    if [ -n "$creation_date" ]; then
        echo "$creation_date $file" >> "$articles_with_date"
    fi
done

ordered_articles=$(sort -r -k1,1 "$articles_with_date")

echo "ordering complete: $ordered_articles"

output_dir="out"
mkdir -p $output_dir

IFS=$'\n' read -r -d '' -a articles_array <<< "$ordered_articles"

list_file=$(mktemp)

for file in "${articles_array[@]}"; do
    path=$(echo "$file" | cut -d ' ' -f 2-)
    filedir=$(dirname "$path")
    article=$(basename "$filedir")

    title=$(grep -m1 "^title:" "$path" | sed "s/title: //")
    author=$(grep -m1 "^author:" "$path" | sed "s/author: //")
    creation_date=$(grep -m1 "^date:" "$path" | sed "s/date: //")

    echo "===================================="
    echo "processing file: $path"
    echo "article name: $article"
    echo "title: $title"
    echo "author: $author"
    echo "creation date: $creation_date"
    echo "filedir: $filedir"

    mkdir -p "$output_dir/$article"
    # TODO: in the future, remove article md from output directory
    cp -r "$filedir" "$output_dir/" 
    pandoc "$path" \
	    -o "$output_dir/$article/index.html" \
	    --template=post-template.html \
	    --highlight-style nord.theme

    echo "<div class=\"item\"><a href=\"$article\">$title</a><span class=\"date\">$creation_date</span> • $author</div>" >> $list_file
done

pandoc "$list_file" -f html -o "out/index.html" --template=list-template.html
