#!/usr/bin/env bash
setup_terminal() {
    # Setup the terminal for the TUI.
    # '\e[?1049h': Use alternative screen buffer.
    # '\e[?7l':    Disable line wrapping.
    # '\e[?25l':   Hide the cursor.
    # '\e[2J':     Clear the screen.
    # '\e[1;Nr':   Limit scrolling to scrolling area.
    #              Also sets cursor to (0,0).
    printf '\e[?1049h\e[?7l\e[?25l\e[2J\e[1;%sr' "$max_items"
    scroll=1 # initially we want the first line to correspond to src/1
    CURRENT_FILE=""  
    EDITING=0
    VISIT_FILE_INPUT_ACTIVE=0
    DIRTY_DISPLAY=1
    # Hide echoing of user input
    stty -echo
}

reset_terminal() {
    # Reset the terminal to a useable state (undo all changes).
    # '\e[?7h':   Re-enable line wrapping.
    # '\e[?25h':  Unhide the cursor.
    # '\e[2J':    Clear the terminal.
    # '\e[;r':    Set the scroll region to its default value.
    #             Also sets cursor to (0,0).
    # '\e[?1049l: Restore main screen buffer.
    printf '\e[?7h\e[?25h\e[2J\e[;r\e[?1049l'

    # Show user input.
    stty echo
}

clear_screen() {
    # Only clear the scrolling window (dir item list).
    # '\e[%sH':    Move cursor to bottom of scroll area.
    # '\e[9999C':  Move cursor to right edge of the terminal.
    # '\e[1J':     Clear screen to top left corner (from cursor up).
    # '\e[2J':     Clear screen fully (if using tmux) (fixes clear issues).
    # '\e[1;%sr':  Clearing the screen resets the scroll region(?). Re-set it.
    #              Also sets cursor to (0,0).
    printf '\e[%sH\e[9999C\e[1J%b\e[1;%sr' \
           "$((LINES-2))" "${TMUX:+\e[2J}" "$max_items"
}


get_term_size() {
    # Get terminal size ('stty' is POSIX and always available).
    # This can't be done reliably across all bash versions in pure bash.
    # Reads lines x columns into LINES and COLUMNS respectively
    read -r LINES COLUMNS < <(stty size)

    # Max list items that fit in the scroll area.
    ((max_items=LINES-3))
}


visit_file() {
    # If file exists
    if [ -f "$1" ]; then
	CURRENT_FILE=$1
	# if visited before, delete old src
	if [ -d $1"_src" ]; then rm -r $1"_src"; fi
	mkdir $1"_src"

	# generate new src
	split -l 1 "$1" $1"_src/"
	i=$(wc -l $1)
	list_total=$i
	scroll=1
	DIRTY_DISPLAY=1
    fi
    # If file does not exist, do nothing.
    # this is an EDITOR not a CREATOR
}



status_line() {
    # '\e7':       Save cursor position.
    #              This is more widely supported than '\e[s'.
    # '\e[%sH':    Move cursor to bottom of the terminal.
    # '\e[30;41m': Set foreground and background colors.
    # '%*s':       Insert enough spaces to fill the screen width.
    #              This sets the background color to the whole line
    #              and fixes issues in 'screen' where '\e[K' doesn't work.
    # '\r':        Move cursor back to column 0 (was at EOL due to above).
    # '\e[m':      Reset text formatting.
    # '\e[H\e[K':  Clear line below status_line.
    # '\e8':       Restore cursor position.
    #              This is more widely supported than '\e[u'.

    printf '\e7\e[%sH\e[30;4%sm%*s\r%s %s\e[m\e[%sH\e[K\e8' \
           "$((LINES-1))" \
           "${FFF_COL2:-1}" \
           "$COLUMNS" "" \
           "($((scroll))/$((list_total)))" \
	   "Welcome to the Catitor. Current file: $CURRENT_FILE, current input: $cmd_reply" \
           "$LINES"
}
# save the current file
save_file() {
    mv $CURRENT_FILE"_tmp" $CURRENT_FILE
}

clean_up() {
    rm -rf $CURRENT_FILE"_src/"
    rm $CURRENT_FILE"_tmp"
    }

redraw() {
    # Redraw the current window.
    if (( DIRTY_DISPLAY == 1 )); then
	DIRTY_DISPLAY=0
	clear_screen
	if [ -d $CURRENT_FILE"_src" ]; then	
	    list_total=$(ls $CURRENT_FILE"_src"/ | wc -l)
	    local curline=""
	    if (( list_total > 0 )); then
		# cat the src together into a tmp file
		cat  $CURRENT_FILE"_src"/*  > $CURRENT_FILE"_tmp"
		# Display the current file in the terminal window
		cat -n $CURRENT_FILE"_tmp"
		if (( list_total >= scroll )); then
		    # Calculate the current line from stupid a-z index
		    local filename=$(ls $CURRENT_FILE"_src"/ | sed -n $scroll"p")
	            curline=$(<$CURRENT_FILE"_src"/$filename)
		    # elif (( scroll > list_total )) 
		    # 	scroll=$list_total
		    # 	curline=""
		else
		    curline=""
		    scroll=1
		    DIRTY_DISPLAY=1
		fi
		# Highlight current line	    
		printf '\e7\e[%sH\e[30;42m%*s\r%6s  %s \e[m\e8' \
		       "$scroll" \
		       "$COLUMNS" "" \
		       "$scroll" \
		       "$curline"
	    fi	
	else
	    list_total=0
	fi
	status_line
    fi
}

cmd_line() {
    # Write to the command_line (under status_line).
    cmd_reply=

    # '\e7':     Save cursor position.
    # '\e[?25h': Unhide the cursor.
    # '\e[%sH':  Move cursor to bottom (cmd_line).
    printf '\e7\e[%sH\e[?25h' "$LINES"

    # '\r\e[K': Redraw the read prompt on every keypress.
    #           This is mimicking what happens normally.
    set -f
    while IFS=$'\n' read -rsn 1 -p $'\r\e[K'"${1}${cmd_reply}" read_reply; do
        case $read_reply in
            # Backspace.
            $'\177'|$'\b')
                cmd_reply=${cmd_reply%?}
            ;;

            # Escape / Custom 'no' value (used as a replacement for '-n 1').
            $'\e'|${3:-null})
                read "${read_flags[@]}" -rsn 2
                cmd_reply=
                break
            ;;

            # Enter/Return.
            "")
		if (( $EDITING == 1 )); then
		    local line_filename=$(ls $CURRENT_FILE"_src"/ | sed -n $scroll"p")
		    echo "$cmd_reply" > $CURRENT_FILE"_src"/$line_filename
		    EDITING=0
		    DIRTY_DISPLAY=1
		elif (( $VISIT_FILE_INPUT_ACTIVE == 1 )); then
		    VISIT_FILE_INPUT_ACTIVE=0
		    visit_file $cmd_reply
		fi
                break
            ;;

            # Custom 'yes' value (used as a replacement for '-n 1').
            ${2:-null})
                cmd_reply=$read_reply
                break
            ;;

            # Replace '~' with '$HOME'.
            "~")
                cmd_reply+=$HOME/
            ;;

            # Anything else, add it to cmd_reply.
            *)
                cmd_reply+=$read_reply
            ;;
        esac
    done
    unset IFS
    set +f

    # '\e[2K':   Clear the entire cmd_line on finish.
    # '\e[?25l': Hide the cursor.
    # '\e8':     Restore cursor position.
    printf '\e[2K\e[?25l\e8'
}

key() {
    # Handle special key presses.
    [[ $1 == $'\e' ]] && {
        read "${read_flags[@]}" -rsn 2

        # Handle a normal escape key press.
        [[ ${1}${REPLY} == $'\e\e['* ]] &&
            read "${read_flags[@]}" -rsn 1 _

        local special_key=${1}${REPLY}
    }

    case ${special_key:-$1} in
        # Scroll down.
        # 'B' is what bash sees when the down arrow is pressed
        # ('\e[B' or '\eOB').
        ${FFF_KEY_SCROLL_DOWN2:=$'\e[B'}|\
        ${FFF_KEY_SCROLL_DOWN3:=$'\eOB'})
            ((scroll < list_total)) && {
                ((scroll++))
		DIRTY_DISPLAY=1
		redraw
            }
        ;;

        # Scroll up.
        # 'A' is what bash sees when the up arrow is pressed
        # ('\e[A' or '\eOA').
        ${FFF_KEY_SCROLL_UP2:=$'\e[A'}|\
        ${FFF_KEY_SCROLL_UP3:=$'\eOA'})
            # '\e[1L': Insert a line above the cursor.
            # '\e[A':  Move cursor up a line.
            ((scroll > 1)) && {
                ((scroll--))
		DIRTY_DISPLAY=1
		redraw
            }
        ;;

        # # edit current line.
        ${FFF_KEY_MKFILE:=e})
	    EDITING=1
	    VISIT_FILE_INPUT_ACTIVE=0	    
            cmd_line "Editing line $scroll "
	    DIRTY_DISPLAY=1
	    redraw
        ;;
        # visit file.
        ${FFF_KEY_VISITFILE:=v})
	    EDITING=0
	    VISIT_FILE_INPUT_ACTIVE=1
            cmd_line "visit file: "
            [[ $cmd_reply ]] #&&
        ;;
        # save file
        ${FFF_KEY_SAVEFILE:=s})
	    EDITING=0
	    VISIT_FILE_INPUT_ACTIVE=0
	    save_file
            cmd_line "Saved file."
            [[ $cmd_reply ]] #&&
        ;;


        # Quit 
        # Don't allow user to redefine 'q' so a bad keybinding doesn't
        # remove the option to quit.
        q)
	    clean_up
            exit
        ;;
    esac
}

main() {

    # Trap the exit signal (we need to reset the terminal to a useable state.)
    trap 'reset_terminal' EXIT

    # Trap the window resize signal (handle window resize events).
    trap 'get_term_size; redraw' WINCH

    get_term_size
    setup_terminal
    
    visit_file $CURRENT_FILE
    redraw

    # Vintage infinite loop.
    for ((;;)); {
        read "${read_flags[@]}" -srn 1 && key "$REPLY"
	redraw
        # Exit if there is no longer a terminal attached.
        [[ -t 1 ]] || exit 1
    }
}

main "$@"
