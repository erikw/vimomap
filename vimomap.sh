#!/bin/bash
# This script will set sane input methods, kblayout and bindings suiting Erik Westrup. 
# Usage: according to src below.

kblayout_def=us
kblayout_alt=se
xmodmap_path=./.Xmodmap
my_vim_tar=./vim.tar.gz
state_file=states.txt
declare -A states

state_read() {
	if [ ! -e $state_file ]; then return 1; fi

	while read line;
	do
		IFS='=' read -a pair <<< "$line"
		states+=([${pair[0]}]=${pair[1]})
	done < $state_file
}


state_save() {
	rm -f $state_file
	touch $state_file
	for key in "${!states[@]}";
	do
		echo "$key=${states[$key]}" >> $state_file
	done;
}

state_get() {
	if [ ${states[$1]} ];
	then
		echo ${states[$1]}
	else
		return 1
	fi
}

state_set() {
	if [ $# -gt 0 ]; then
		unset states[$1]
		states+=([$1]=$2)
	fi
}


state_print() {
	if [ -f $state_file ]; then
		echo "Current state:"
		cat $state_file
	else
		echo "${state_file} not found."
	fi
}

set_kblayout() {
	if [ -z $1 ];
	then
		cur_layout=`setxkbmap -query | sed -e '/^layout/!d' -e 's/layout:\s*\(.*\)$/\1/'`
		prev_layout=$(state_get kblayout_prev)
		if [ "$?" -eq "0" ]; then
			if [ "$cur_layout" == "$kblayout_def" ]; then
				new_layout=$prev_layout
			else
				new_layout=$kblayout_def
			fi
		else
			case $cur_layout in
				"$kblayout_def")
					new_layout=$kblayout_alt
					;;
				"$kblayout_alt")
					new_layout=$kblayout_def
					;;
				*)
					echo "I don't know what layout you want to switch to."
					return 1
			esac
		fi
	else 
		new_layout=$1
	fi
	setxkbmap -model pc105 -layout $new_layout
	state_set "kblayout_prev" $cur_layout
	state_set "kblayout_now" $new_layout
}

set_vim() {
	eval vimhome="~/"
	cur_vim=$(state_get cur_vim)
	if [ "$?" -ne "0" ]; then
		cur_vim="theirs"
	fi

	if ([ $cur_vim == "theirs" ] && [ -f $my_vim_tar ]); then
		if [ -e "$vimhome/.vim" ]; then
			mv "$vimhome/.vim" "$vimhome/.vim.theirs"
		fi
		if [ -e "$vimhome/.vimrc" ]; then
			mv "$vimhome/.vimrc" "$vimhome/.vimrc.theirs"
		fi
		if [ -e "$vimhome/.vimrc.local" ]; then
			mv "$vimhome/.vimrc.local" "$vimhome/.vimrc.local.theirs"
		fi
		tar xvzf $my_vim_tar -C $vimhome
		new_vim="mine"
	elif [ $cur_vim == "mine" ]; then
		if [ -e "$vimhome/.vim.theirs" ]; then
			mv "$vimhome/.vim.theirs" "$vimhome/.vim"
		fi
		if [ -e "$vimhome/.vimrc.theirs" ]; then
			mv "$vimhome/.vimrc.theirs" "$vimhome/.vimrc"
		fi
		if [ -e "$vimhome/.vimrc.local.theirs" ]; then
			mv "$vimhome/.vimrc.local.theirs" "$vimhome/.vimrc.local"
		fi
		new_vim="theirs"

	fi
	state_set "cur_vim" $new_vim
}

set_xmodmap() {
	cur_map=$(state_get xmodmap)
	if [ "$?" -ne "0" ]; then
		cur_map="theirs"
	fi

	if [ $cur_map == "mine" ];
	then
		if [ -e $xmodmap_path.theirs ];
		then
			xmodmap $xmodmap_path.theirs
		else
			setxkbmap
		fi
		new_map="theirs"
	else
		xmodmap -pke >> $xmodmap_path.theirs
		if [ -e $xmodmap_path ];
		then
			xmodmap $xmodmap_path
		else
			xmodmap -e "remove Lock = Caps_Lock"
			xmodmap -e "keysym Caps_Lock = Escape"
		fi
		new_map="mine"
	fi
	state_set "xmodmap" "$new_map"
}

help() {
	echo "On-the-fly manual:"
	grep '#\sarg:' $0 | sed -e 's/\s*|\s/, /g' -e 's/^\s*\(.*\))\s*#\s*arg:\(.*\)$/\1\t\t\2/' | sort -d
}

if [ $# == 0 ];
then
	echo "No arguments given."
	help
	exit
fi

state_read
for arg; do
	case $arg in
		--all | -a) # arg: Make a full switch.
			set_kblayout
			set_vim
			set_xmodmap
			;;
		--layout | -l) # arg: Switch the keyboard layout.
			set_kblayout
			#set_kblayout "us"
			;;
		--vi | --vim | -v) # arg: Switch vimrc and friends.
			set_vim
			;;
		--xmodmap | -x) # arg: Switch key mappings. Do this _after_ -l. TODO appears to be the other way around.
			set_xmodmap
			;;
		--state | -st) #arg: Print the current status.
			:
			;;
		--noop) #arg: Don't do a damn thing.
			:
			;;
		--help | -h | *) # arg: Generate a short list of arguments.
			help
			exit
	esac
done;
state_save
state_print
