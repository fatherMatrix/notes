#!/bin/sh

if [ $# != 1 ]; then
	echo "Usage: sh release.sh <root dir>"
	exit
fi

mark_tar=mark.tar
html_tar=html.tar
base_dir=$1
cd $base_dir

echo "------ pandoc -------"
rm -rf ./$mark_tar
for file in `find . -name "*.md" -print`
do
	tar -rf $mark_tar $file
	file_without_type=${file%.md}

	# Basic Regular Expression(BRE), "( ) ? + { } |"在不加"\"前缀时是普通字符，表示自己，没有特殊含义
	# 如果想要这几个字符表示特殊含义的话，需要使用-E选项，此时加"\"前缀后才是普通字符
	#
	# 这个正则有贪婪匹配的问题，导致同一行中存在多个ref时只能修改最后一个
	# sed > $file_without_type 's/\[\(.*\)\](\(.*\)\.md\(#.*\)*)/[\1](\2.html\3)/g' $file
	#
	# 这个避免了上边的问题
	sed > $file_without_type -E 's/\[([^]]+)\]\(([^)]+)\.md(#[^)]+)*\)/[\1](\2.html\3)/g' $file

	if [ $? -ne 0 ]; then
		echo "$file sed failed"
		exit
	fi

	pandoc $file_without_type -o ${file_without_type}.html -f markdown -t html
	if [ $? -ne 0 ]; then
		echo "$file pandoc failed"
		exit
	fi 

	echo "$file"
	rm -rf $file_without_type
done

echo "------ tar ----------"
rm -rf ./$html_tar
for file in `find . -name "*.html" -print`
do
	tar -rf $html_tar $file
	if [ $? -ne 0 ]; then
		echo "$file tar failed"
		exit
	else
		echo "$file"
		rm -rf $file
	fi
done

echo "------ release ------"
ssh root@101.43.13.132 "rm -rf /data/www/* && mkdir -p /data/www && mkdir -p /data/backup"
if [ $? -ne 0 ]; then
	echo "remote setup failed"
	exit
else
	echo "remote setup succeed"
fi

scp > /dev/null ./$html_tar ./$mark_tar root@101.43.13.132:/data/backup/
if [ $? -ne 0 ]; then
	echo "remote transfer failed"
	exit
else
	echo "remote transfer succeed"
fi

ssh root@101.43.13.132 "cd /data/www && tar -xf /data/backup/$html_tar"
if [ $? -ne 0 ]; then
	echo "remote release failed"
	exit
else
	echo "remote release succeed"
fi

rm -rf $html_tar $mark_tar
