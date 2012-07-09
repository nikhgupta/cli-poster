#!/bin/bash
#
# ==============================================================
# CLI Poster (c) Nikhil Gupta <me@nikhgupta.com>
# VERSION: 1.0
# LICENSE: GPL (http://www.gnu.org/licenses/gpl.html)
# ==============================================================
#
# EASY POSTING TO WORDPRESS BLOGS FROM WITHIN THE COMMAND LINE
# MULTIPLE FILES, PIPING, REDIRECTED INPUT FROM FILE | ANYTHING
# WORKS WITH SYNTAX HIGHLIGHTER FOR EASY POSTING OF SOURCE FILES
#
# WORK IN PROGRESS && PLEASE RESPECT LICENSE :)
#
# TODO: filter certain words from the post we are doing
# TODO: test compatibility with other environments
# TODO: test wp configuration by creating a post and deleting it later.
# FIXME: erreneous run with arguments containing spaces in file/dir names
# FIXME: success/fail messages appear in new lines for non-colored output
# FIXME: success/fail messages appear in new lines for verbose output while showing posting details
# FIXME: sometimes posting fails with "parse error. not well formed" error!

VERSIONFILE="GEN-VERSION-FILE"
[ -f "$VERSIONFILE" ] && . "$VERSIONFILE"
version() {
    cat <<-EndVersion
		CLI POSTER Command Line WordPress Blog Posting v$VERSION

		First release: Apr 1, 2011
		Author: Nikhil Gupta (http://me.nikhgupta.com)
		Contributors: http://github.com/nikhgupta/cli-poster/network
		License: GPL, http://www.gnu.org/copyleft/gpl.html
		Code repository: http://github.com/nikhgupta/cli-poster/tree/master
	EndVersion
    exit 1
}

# Set script name and full path early.
POSTER_SH=$(basename "$0")
TODO_FULL_SH="$0"
export POSTER_SH TODO_FULL_SH

# define some functions to be used
function shortusage() {
    echo $"Usage:

    $POSTER_SH [-d configfile] (-a address:user:pass(:active|:inactive)) | -r address:user | -t address:user | -l | -x)

    $POSTER_SH [-d configfile] [-f format] [-c category] [-p post-type] [-o (home|post)] [-vsF] file1 file2 file3 ...
    $POSTER_SH [-d configfile] [-f format] [-c category] [-p post-type] [-o (home|post)] [-vsF] -S content [-T title]
    $POSTER_SH [-d configfile] [-f format] [-c category] [-p post-type] [-o (home|post)] [-vsF] [-T title] < file
    pipe | $POSTER_SH [-d configfile] [-f format] [-c category] [-p post-type] [-o (home|post)] [-vsF] [-T title]

    $POSTER_SH [-heV] # for more extended usage help, examples and version info
    "
    exit 900;
}
function usage() {
    echo $"Usage:

    $POSTER_SH file1 file2 ...                                            # post multiple times for all files (you can use partial matching (*) to specify multiple files)
    $POSTER_SH -D dir1 dir2 file1 file2 ...                               # post files in the directories specified (non-recursive)
    $POSTER_SH -R dir1 dir2 file1 file2 ...                               # recursively post directories, implies -D
    $POSTER_SH < file                                                     # read redirected content from this 'file'
    pipe | $POSTER_SH                                                     # read piped content from this 'pipe'
    $POSTER_SH [options] ... [-S content]                                 # read content from argument to -S option
    $POSTER_SH [options] ... [-T title]                                   # can be used with above three type of input to specify title of the post created (doesnt work with first)
    $POSTER_SH [options] ... [-F]                                         # force posting to all blogs (incl. inactive blogs)
    $POSTER_SH [options] ... [-n]                                         # do a dry run - do not actually post anything to blogs - changes to configuration file is still made
    $POSTER_SH [options] ... [-0]                                         # do not colorize output - useful when you want to log output to file

    $POSTER_SH [options] ... [-d configuration_file]                      # use this file to read (or modify) blog settings
    $POSTER_SH [options] ... [-a address:user:pass(:active|:inactive)]    # add a new blog to be used with CLI Poster
    $POSTER_SH [options] ... [-r address:user]                            # remove the specified blog & user from CLI Poster
    $POSTER_SH [options] ... [-t address:user]                            # toggle active state for the specified blog & user
    $POSTER_SH [options] ... [-l]                                         # list all the blogs that are in use
    $POSTER_SH [options] ... [-x]                                         # test logins for the configured blogs

    $POSTER_SH [options] ... [-f format]                                  # make compatible with syntaxhighlighter (is always on by default)
    $POSTER_SH [options] ... [-c category]                                # use this category for posting (defaults to: Uncategorized)
    $POSTER_SH [options] ... [-p post-type]                               # use this post-type for posting (defaults to: post)
    $POSTER_SH [options] ... [-v|s]                                       # verbose/short output (shows url for created posts etc. or only show total errors)
    $POSTER_SH [options] ... [-o (home|post)]                             # open homepage or (all) post pages where we have posted (gnome only)

    $POSTER_SH [-h|e|V]                                                   # show usage instructions, examples, and|or version info

    NOTE: <address> should not contain http:// or https:// e.g. nikhgupta.com is a valid <address>
    NOTE: <format> can be one of these (default is 'auto' which automatically formats the post based on file extension and mimetypes):
        off, auto, actionscript3, shell, coldfusion, c-sharp, cpp, css, pascal, diff, erlang, groovy
        javascript, java, javafx, perl, php, text, powershell, python, ruby, scala, sql, vb, xml, html"
    if [ "$SHOW_EXAMPLES" == "1" ]; then echo; examples; fi
    exit 900
}
function examples() {
    echo $"Examples:

    $POSTER_SH file1                                                      # post file to all active blogs (post title will be the name of the file)
    $POSTER_SH file1 file2 file3                                          # post these files to all active blogs (post titles will be the names of these files)
    $POSTER_SH *                                                          # post all files in current directory to active blogs
    $POSTER_SH ~/.bash*                                                   # post all files that start with '.bash' in 'home' directory

    $POSTER_SH < file1                                                    # get redirected output from 'file1' and post it to all active blogs (title will be 'Posted via: `uname -n`')
    $POSTER_SH < ~/.bashrc                                                # post '~/.bashrc' to all active blogs

    cat ~/.bashrc | $POSTER_SH                                            # get piped output from previous command and post to all active blogs
    free -m | $POSTER_SH                                                  # title will be 'Posted via: $(uname -n)' and can be changed by passing '-T' option
    uptime | $POSTER_SH                                                   # You can also post how long your system has been up to your blog, and guess CRON! ;)

    $POSTER_SH -S \"some random string/paragraph\"                          # create a post from the string passed to '-S' option
    $POSTER_SH -S \"\`df -h\`\" -T \"Disk Usage Data\"                          # you can custom create any post by using -S (for content) and -T (for title) options

    $POSTER_SH -d ~/cli-poster/.config file1                                # read blog settings from the specified file, and post 'file1' to active blogs

    # custom config file, test this configuration, remove the specified blog and then post the redirected input
    $POSTER_SH -xd ~/cli-poster/.config -r blog.wordpress.org:nikhgupta < ~/.bashrc

    # add a new blog, list and then test the new configuration and then post the piped input
    free -m | $POSTER_SH -a wordpress.org:nikhgupta:password:active -lx

    # toggle active status for one blog, create a post with this title and piped content, show verbose output and then open the post page in browser
    cat ~/.bash_history | $POSTER_SH -t wordpress.org:nikhgupta -o post -v -T 'bash history for me'

    # create a custom post for 'stats' post type, in 'disk-usage' category with current time as Title
    df -h | $POSTER_SH -c \"disk-usage\" -p \"stats\" -T \"\`date -R\`\"

    # show very less output, create a post in 'php-source' category, use 'php' syntax highlighting, and then open the homepage
    $POSTER_SH -f 'php' -c 'php-source' -o home -s index.php

    NOTE: for syntax highlighting, syntax highlighter plugin should be installed on these blogs!"
    exit 900
}

function error { show_success 0 "failed" "$1"; }
function warn { show_success 1 "warning" "$1"; }
function success { show_success 2 "success" "$1"; }
function die { show_success 3 "aborted" "$1"; exit 999; }
function cleanup { [ -f "$TMP_FILE" ] && rm "$TMP_FILE"; return 0; }

function show_success() {
	# Parameters: condition_check (0|1|2|3), warn|fail|success|abort, [desc], [override_short]
	# Parameters: condition_check (0|1|2|3), message, [desc]
	if (( ! $SHORTOUTPUT )) || (( $4 )); then
	    message=( $(echo "$2" | tr '|' ' ') ); message="${message[$1]}"; message=${message:-"$2"}
	    color=( "${RED}" "${YLW}" "${GRN}" "${RED}" )
	    desc=( "_Error_" "Warning" "Success" "ABORTED")
	    if (( $COLORCODES )); then desc="${color[$1]}${desc[$1]}!${NML} $3" ; else desc="${desc[$1]}! $3"; fi
	    [ -n "$3" ] && echo -ne "${desc}";
	    if (( $COLORCODES )); then tput hpa $COL; echo -e "${color[$1]}[ ${message} ]${NML}";
	    else printf "\n%${COL}s\n" "...[ ${message} ]"; fi
	fi
}

function check_browser() {
      if type -P gnome-open &>/dev/null; then OPENBROWSER="gnome-open";
    elif type -P firefox &>/dev/null; then OPENBROWSER="firefox";
    elif type -P google-chrome &>/dev/null; then OPENBROWSER="google-chrome";
    elif type -P chromium-browser &>/dev/null; then OPENBROWSER="chromium-browser";
    elif type -P opera &>/dev/null; then OPENBROWSER="opera";
    else OPENBROWSER="";
    fi
}
function check_requirements() {
    check_browser
    type -P curl &>/dev/null || die "I require 'curl' but it's not installed."
    type -P sed  &>/dev/null || die "I require 'sed'  but it's not installed."
    type -P wc   &>/dev/null || die "I require 'wc'   but it's not installed."
    type -P seq  &>/dev/null || die "I require 'seq'  but it's not installed."
    type -P file &>/dev/null || die "I require 'file' but it's not installed."
    type -P grep &>/dev/null || die "I require 'grep' but it's not installed."
    type -P tput &>/dev/null || die "I require 'tput' but it's not installed."
    # PHP only used for htmlentities: replaced with a py3k script in local directory.
    #type -P php  &>/dev/null || die "I require 'php'  but it's not installed."
    [ -n "$OPENBROWSER" ] || warn "Can not find a suitable browser to open URLs. Disabling effect of '-o' option!\n"
}

function get_file_name_and_extension() {
    filebase="${1##*/}"; fileex="${filebase#*.}"; filename="${foo%%.*}"; fileex=${fileex,,};
    if [ "$filename" == "$fileex" ] || [ -z "$filename" ]; then filename="$fileex"; fileex=""; fi
}

# CONFIGURATION FILE RELATED FUNCTIONS
function read_configuration() {
    configuration=$(<"$1")
    TOTALBLOGS=$(wc -l "$1" | cut -f1 -d' ')
    for i in $configuration; do
        THISBLOG=( $(echo "$i" | tr ':' ' ') )
        [ "${#THISBLOG[@]}" == "4" ] || die "Configuration File contains invalid blog settings!"
        BLOGADDRS=( "${BLOGADDRS[@]}" "${THISBLOG[0]}" )
        BLOGUSERS=( "${BLOGUSERS[@]}" "${THISBLOG[1]}" )
        BLOGPASSS=( "${BLOGPASSS[@]}" "${THISBLOG[2]}" )
        BLOGACTVS=( "${BLOGACTVS[@]}" "${THISBLOG[3]}" )
        unset THISBLOG
    done
    for i in ${BLOGACTVS[@]}; do
		[ "$i" == "active" ] && let ACTIVEBLOGS=ACTIVEBLOGS+1
    done
}
function add_new_blog() {
    THISBLOG=( $(echo "$2" | tr ':' ' ') )
    [ "${#THISBLOG[@]}" == "4" ] || die "Blog settings are incorrect! You must specify a new blog in the following format:\n\t< address:user:password(:active|:inactive) > where 'address' should not contain http:// or https://\nYou must, also, set the new blog to 'active' if you want to post to this blog, by default."
    [ "${THISBLOG[3]}" == "active" ] || [ "${THISBLOG[3]}" == "inactive" ] || die "Blog must be either set to 'active' or 'inactive'\n\tCLI Poster only posts to blogs that are marked as 'active' at the time of posting,\n\tunless used with -F option (force posting to 'inactive' blogs)."
    test_wp_configuration "${THISBLOG[0]}" "${THISBLOG[1]}" "${THISBLOG[2]}"
    if (( "$blogcheck" )); then
        if grep -q "$2" "$1"; then
            warn "This blog and login already exists!"
        else
            echo "$2" >> "$1"
            success "Added new blog to configuration file!"
        fi
    else
        error "Could not authenticate! This blog has not been added to CLI Poster!"
    fi
    unset THISBLOG
    sed -i '/^$/d' "$1"
}
function remove__blog() {
    THISBLOG=( $(echo "$2" | tr ':' ' ') )
    if [ "${#THISBLOG[@]}" == "2" ]; then
        if grep -q "$2:" "$1"; then
            sed -i -e "/^$2:.*$/d" "$1"
            success "Removed blog: ${THISBLOG[0]} with user: ${THISBLOG[1]} from CLI Poster!"
        else
            warn "${THISBLOG[0]} with user: ${THISBLOG[1]} was not found in configuration file!"
        fi
    else
        error "You should specify the blog & user to delete in following format:\n\t$POSTER_SH -r address:user"
    fi
    unset THISBLOG
    sed -i '/^$/d' "$1"
}
function toggle__blog() {
    THISBLOG=( $(echo "$2" | tr ':' ' ') )
    if [ "${#THISBLOG[@]}" == "2" ]; then
        if grep -q "$2:" "$1"; then
            if grep -q "^$2:.*:active" "$1"; then
                sed -i -e "s|$2:\(.*\):active|$2:\1:inactive|g" "$1"
                echo "Successfully deactivated blog: ${THISBLOG[0]} with user: ${THISBLOG[1]}"
            elif grep -q "^$2:.*:inactive" $1; then
                sed -i -e "s|$2:\(.*\):inactive|$2:\1:active|g" "$1"
                echo "Successfully activated blog: ${THISBLOG[0]} with user: ${THISBLOG[1]}"
            fi
        else
            warn "${THISBLOG[0]} with user: ${THISBLOG[1]} was not found in configuration file!"
        fi
    else
        error "You should specify the blog & user to toggle in following format:\n\t$POSTER_SH -r address:user"
    fi
    unset THISBLOG
    sed -i '/^$/d' "$1"
}
function list_blogs() {
    echo -e "blog\t\tuser\tactive?"
    echo "==============================================="
    for i in $(<"$1"); do
        echo "$i" | tr ':' ' ' | cut -f1,2,4 -d ' ' | tr ' ' '\t'
    done
    echo "==============================================="
}
function test_blogs() {
    sed -i '/^$/d' "$1"
    for i in $(<"$1"); do
        THISBLOG=( $(echo "$i" | tr ':' ' ') )
        test_wp_configuration "${THISBLOG[0]}" "${THISBLOG[1]}" "${THISBLOG[2]}"
        unset THISBLOG
    done
}

# SyntaxHighlighter RELATED FUNCTIONS
function get_auto_syntax_for_file() {
    postmimetype=$(file -ib "$1")
    get_file_name_and_extension "$1"

    if   [[ $fileex == js ]] || [[ $postmimetype == *javascript* ]]; then syntax="javascript";
    elif [[ $fileex == css ]] || [[ $postmimetype == *css* ]]; then syntax="css";
    elif [[ $fileex == sh ]] || [[ $fileex == bash ]] || [[ $fileex == zsh ]] || [[ $postmimetype == *shell* ]]; then syntax="shell";
    elif [[ $fileex == py ]] || [[ $postmimetype == *python* ]]; then syntax="python";
    elif [[ $fileex == pas ]] || [[ $postmimetype == *pascal* ]]; then syntax="pascal";
    elif [[ $fileex == groovy ]] || [[ $postmimetype == *groovy* ]]; then syntax="groovy";
    elif [[ $fileex == pl ]] || [[ $postmimetype == *perl* ]]; then syntax="perl";
    elif [[ $fileex == rb ]] || [[ $postmimetype == *ruby* ]]; then syntax="ruby";
    elif [[ $fileex == sql ]] || [[ $postmimetype == *sql* ]]; then syntax="sql";
    elif [[ $postmimetype == *php* ]]; then    syntax="php";
    elif [[ $postmimetype == *html* ]]; then syntax="html";
    elif [[ $postmimetype == *xml* ]] || [[ $postmimetype == *xsl* ]]; then syntax="xml";
    elif [[ $postmimetype == *text/x-c* ]] || [[ $postmimetype == *c++* ]]; then syntax="cpp";
    elif [[ $fileex == cs ]] || [[ $postmimetype == *csharp* ]]; then syntax="c-sharp";
    elif [[ $postmimetype == *diff* ]]; then syntax="diff";
    elif [[ $postmimetype == *java* ]]; then syntax="java";
    else syntax=""; fi
}


# WORDPRESS RELATED FUNCTIONS
function test_wp_configuration() {
    # Parameters: blog, user, pass
    XML="<?xml version='1.0' encoding='iso-8859-1'?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value><string>$2</string></value></param><param><value><string>$3</string></value></param></params></methodCall>"
    response=$(curl -ksS -H "Content-Type: application/xml" -X POST --data-binary "${XML}" $1/xmlrpc.php)

    faultString=$(echo $response | grep "faultString");
    if echo $response | grep -q "<name>isAdmin<\/name>"; then
        blogcheck="1"; echo -e "Testing: $1 for user: $2"; success "Login to this site works!" 1
    else
        blogcheck="0";
        if echo $response | grep -q "faultString"; then
            echo -e "Testing: $1 for user: $2"; error "$(echo $response | sed 's|.*faultString.*<string>\(.*\)<\/string>.*$|\1|g')" 1
        else
            echo -e "Testing: $1 for user: $2"; error "Some Unknown error occurred!" 1
        fi
    fi
}
function post_to_wordpress() {
    # Parameters: blog, user, pass, title, category, post-type, content
    XML="<?xml version='1.0' encoding='iso-8859-1'?><methodCall><methodName>metaWeblog.newPost</methodName><params><param><value><int>0</int></value></param><param><value><string>$2</string></value></param><param><value><string>$3</string></value></param><param><value><struct><member><name>title</name><value><string>$4</string></value></member><member><name>description</name><value><string>$7</string></value></member><member><name>mt_allow_comments</name><value><int>1</int></value></member><member><name>mt_allow_pings</name><value><int>1</int></value></member><member><name>post_type</name><value><string>$6</string></value></member><member><name>mt_keywords</name><value><string/></value></member><member><name>categories</name><value><array><data><value><string>$5</string></value></data></array></value></member></struct></value></param><param><value><boolean>1</boolean></value></param></params></methodCall>"

    (( $DRYRUN )) || {
        response=$(curl -ksS -H "Content-Type: application/xml" -X POST --data-binary "${XML}" $1/xmlrpc.php)
        postid=$(echo $response | sed "s|.*string>\(.*\)<\/string.*$|\1|g")
        [ $(echo "$postid" | wc -w) == "1" ] || postid="0"
        faultString=$(echo $response | grep "faultString")
    }

    if [ -z "$faultString" ] && [ "$postid" != "0" ] || (( $DRYRUN )); then
        posterror=0;
        if [ "$VERBOSE" == "1" ]; then echo -e "\n\tPosted successfully to: $1 with user: $2 with URL: http://$1/?p=${postid}"; fi
        if [ "$OPENBLOGS" == "post" ] && [ -n "$OPENBROWSER" ]; then $OPENBROWSER "http://$1/?p=${postid}"; fi
    else
        posterror=1;
        if [ "$VERBOSE" == "1" ]; then
			if test -z "$faultString"; then echo -e "\n\tPosting to: $1 with user: $2"; warn "Unknown error occurred!: $2"
			else echo -e "\n\tPosting to: $1 with user: $2"; warn "$(echo $response | sed 's|.*faultString.*<string>\(.*\)<\/string>.*$|\1|g')"
			fi
		fi
    fi
}

# show success message for posting
function show_posting_success() {
    if (( "$FORCEPOSTING" )); then
        let postedto=TOTALBLOGS-posterrors;
        totaltopost=$TOTALBLOGS;
    else
        let postedto=ACTIVEBLOGS-posterrors;
        totaltopost=$ACTIVEBLOGS;
    fi
    if [ "$postedto" == "$totaltopost" ]; then success="2"; else success="1"; fi
    if [ "$postedto" == "0" ]; then success="0"; fi
    show_success "$success" "$postedto/$totaltopost"
}

# CLI Poster POSTING METHODS
function cliposter_post_file() {
    # Parameters: file(s)

    posterrors="0"

    # set the filename as the title of this post, and file content as the post content and sanitize both
    WPTITLE=$(echo "${filename}" | sed -e "s|'|\&apos;|g" -e "s|[-_]| |g")
    WP_POST=$(echo "$(<"$1")" | sed -e "s|'|\&apos;|g")
    WPTITLE=$(echo $WPTITLE | ./htmlentities.py)
    WP_POST=$(echo $WP_POST | ./htmlentities.py)
    #WPTITLE=$(php -r "echo htmlentities('$WPTITLE',ENT_NOQUOTES,'ISO-8859-1',false);")
    #WP_POST=$(php -r "echo htmlentities('$WP_POST',ENT_NOQUOTES,'ISO-8859-1',false);")

    # if a source format is provided, format the post accordingly
    if [ "$POSTFORMAT" == "auto" ]; then
        get_auto_syntax_for_file "$1"
        if test -z "$syntax"; then WP_POST="[${syntax}]${WP_POST}[/${syntax}]"; fi
    elif [ "$POSTFORMAT" != "off" ]; then
        WP_POST="[${POSTFORMAT}]${WP_POST}[/${POSTFORMAT}]"
        syntax="${POSTFORMAT}"
    fi
    syntax=${syntax:-"text"}

	if [ -z "$ACTIVEBLOGS" ]; then
		die "All blogs are marked inactive.\n\tPlease, enable at least one blog so that I can post to it!"
    elif test -z "$WP_POST"; then
        error "Seems like the source content is empty.\n\t(Or, probably, there was an error while preparing this content for posting.)"
	else
        if [ "${SHORTOUTPUT}" == "0" ]; then echo -en "Posting: ${GRN}${filebase}${NML} (applied formatting: ${GRN}${syntax}${NML})"; fi
        for i in $(let num=TOTALBLOGS-1; seq 0 $num); do
            # only post when the blog is set to active
            if [ "${BLOGACTVS[$i]}" == "active" ] || [ "$FORCEPOSTING" == "1" ]; then
                post_to_wordpress "${BLOGADDRS[$i]}" "${BLOGUSERS[$i]}" "${BLOGPASSS[$i]}" "${WPTITLE}" "${WPCATEGORY}" "${WPPOSTTYPE}" "${WP_POST}"
                let posterrors+=${posterror:0}
            fi
        done
        show_posting_success
    fi
}
function cliposter_post_content() {
    # options: title, content

    posterrors="0"
    # set the filename as the title of this post, and file content as the post content and sanitize both
    WPTITLE=$(echo "$1" | sed -e "s|'|\&apos;|g")
    WP_POST=$(echo "$2" | sed -e "s|'|\&apos;|g")
#    WPTITLE=$(php -r "echo htmlentities('$WPTITLE',ENT_NOQUOTES,'ISO-8859-1',false);")
#    WP_POST=$(php -r "echo htmlentities('$WP_POST',ENT_NOQUOTES,'ISO-8859-1',false);")

    # if a source format is provided, format the post accordingly
    if [ "$POSTFORMAT" != "auto" ] && [ "$POSTFORMAT" != "off" ]; then WP_POST="[${POSTFORMAT}]${WP_POST}[/${POSTFORMAT}]"; else POSTFORMAT="text"; fi

	if [ -z "$ACTIVEBLOGS" ]; then
		die "All blogs are marked inactive.\n\tPlease, enable at least one blog so that I can post to it!"
#    elif test -z "$WP_POST"; then
#        die "Seems like the source content is empty.\n\t(Or, probably, there was an error while preparing this content for posting.)"
    else
        if [ "${SHORTOUTPUT}" == "0" ]; then echo -en "Posting to ${ACTIVEBLOGS} blog(s) (applied formatting: ${POSTFORMAT})"; fi
        for i in $(let num=TOTALBLOGS-1; seq 0 $num); do
            # only post when the blog is set to active
            if [ "${BLOGACTVS[$i]}" == "active" ] || [ "$FORCEPOSTING" == "1" ]; then
                post_to_wordpress "${BLOGADDRS[$i]}" "${BLOGUSERS[$i]}" "${BLOGPASSS[$i]}" "${WPTITLE}" "${WPCATEGORY}" "${WPPOSTTYPE}" "${WP_POST}"
                let posterrors+=${posterror:0}
            fi
        done
        show_posting_success
    fi
}
# prepare a list of files that we need to post
send_files_for_posting() {
    for file in $@; do
        # get file extension, file basename for this file
        get_file_name_and_extension "$file"
        
        if [ -f "$file" ]; then
            cliposter_post_file "$file";
            let totalerrors+=${posterrors:-0};
            let totalposted+=${postedto:-0};
            let totalposts+=${totaltopost:-0}; 
        elif [ -d "$file" ]; then
            if (( $RECURSIVEPOSTING )); then
                postfiles="$(find "$file" -type f -readable -not -iregex ".*\/\..*")"
            elif (( $DIRECTORYPOSTING )); then
                postfiles="$(find "$file" -maxdepth 1 -type f -readable -not -iregex "\..*\/\..*")"
            else
                (( "${SHORTOUTPUT}" )) || warn "Skipping: '${BLD}${filebase}${NML}', as directory posting is disabled, by default!"
            fi
                for postfile in $postfiles; do
                    cliposter_post_file "$postfile"
                    let totalerrors+=${posterrors:-0};
                    let totalposted+=${postedto:-0};
                    let totalposts+=${totaltopost:-0}; 
                done
        else
            (( "${SHORTOUTPUT}" )) || warn "Skipping: '${BLD}${filebase}${NML}', as either it was not found, or is neither a file nor a directory!"
        fi 
    done
}

while getopts ":hlvsxeFVDR0nd:a:t:r:f:c:p:o:S:T:" options
do
  case $options in
    h) SHOW_USAGE=1;;
    e) SHOW_EXAMPLES=1;;
    v) VERBOSE=1;;
    s) SHORTOUTPUT=1;;
    l) LISTBLOGS=1;;
    x) TESTCONFIG=1;;
    F) FORCEPOSTING=1;;
    D) DIRECTORYPOSTING=1;;
    R) RECURSIVEPOSTING=1;;
    0) COLORCODES=0;;
    n) DRYRUN=1;;
    d) CONFIGFILE="$OPTARG";;
    a) ADDNEWBLOG="$OPTARG";;
    r) REMOVEBLOG="$OPTARG";;
    t) TOGGLEBLOG="$OPTARG";;
    f) POSTFORMAT="$OPTARG";;
    c) WPCATEGORY="$OPTARG";;
    p) WPPOSTTYPE="$OPTARG";;
    o) OPENBLOGS="$OPTARG";;
    S) TEXTINPUT="$OPTARG"; READINPUT=1;;
    T) POSTTITLE="$OPTARG";;
    V) version;;
    *) SHORTUSAGE=1;;
  esac
done
shift $(($OPTIND - 1))

# SET SOME DEFAULT DEFINITIONS
CONFIGFILE=${CONFIGFILE:-~/.cli-poster}
ADDNEWBLOG=${ADDNEWBLOG:-""}
REMOVEBLOG=${REMOVEBLOG:-""}
POSTFORMAT=${POSTFORMAT:-"auto"}; POSTFORMAT=${POSTFORMAT,,}; # make lowercase
LISTBLOGS=${LISTBLOGS:-0}
TOGGLEBLOG=${TOGGLEBLOG:-""}
WPCATEGORY=${WPCATEGORY:-"Uncategorized"}
WPPOSTTYPE=${WPPOSTTYPE:-"post"}
VERBOSE=${VERBOSE:-0}
OPENBLOGS=${OPENBLOGS:-""}
READINPUT=${READINPUT:-0}
SHOW_EXAMPLES=${SHOW_EXAMPLES:-0}
SHORTUSAGE=${SHORTUSAGE:-0}
SHOW_USAGE=${SHOW_USAGE:-0}
POSTTITLE=${POSTTITLE:-"Posted via: $(uname -n)"}
TESTCONFIG=${TESTCONFIG:-0}
FORCEPOSTING=${FORCEPOSTING:-0}
COLORCODES=${COLORCODES:-1}
DRYRUN=${DRYRUN:-0}
RECURSIVEPOSTING=${RECURSIVEPOSTING:-0}
if (( $RECURSIVEPOSTING )); then DIRECTORYPOSTING="1"; else DIRECTORYPOSTING=${DIRECTORYPOSTING:-0}; fi
if (( "$VERBOSE" )); then SHORTOUTPUT="0"; else SHORTOUTPUT=${SHORTOUTPUT:-0}; fi

(( $COLORCODES )) && BLD=$(tput bold)
(( $COLORCODES )) && NML=$(tput sgr0)
(( $COLORCODES )) && RED=$BLD$(tput setaf 1)
(( $COLORCODES )) && GRN=$BLD$(tput setaf 2)
(( $COLORCODES )) && YLW=$BLD$(tput setaf 3)
(( $COLORCODES )) && BLU=$BLD$(tput setaf 6)
COL=$(tput cols); let COL=COL-16

# show help
(( "$SHORTUSAGE" )) && shortusage
(( "$SHOW_USAGE" )) && usage
(( "$SHOW_EXAMPLES" )) && examples

# RUN SOME TESTS
check_requirements
[ -e "$HOME/.cli-poster" ] || touch $HOME/.cli-poster
[ -e "$CONFIGFILE" ]  || die "Cannot read configuration file: '$CONFIGFILE'"
[ -n "$(<$CONFIGFILE)" -o -n "$ADDNEWBLOG" ] || die "Empty Configuration File!\nPerhaps, you would like to add some blogs to CLI Poster, first?"

# MODIFY, LIST, READ BLOG SETTINGS
[ "$ADDNEWBLOG" ] && add_new_blog $CONFIGFILE $ADDNEWBLOG
[ "$TOGGLEBLOG" ] && toggle__blog $CONFIGFILE $TOGGLEBLOG
[ "$REMOVEBLOG" ] && remove__blog $CONFIGFILE $REMOVEBLOG
[ "$LISTBLOGS" == "1" ]  && list_blogs $CONFIGFILE
[ "$TESTCONFIG" == "1" ] && test_blogs $CONFIGFILE

# if we do not have any input, check if we have input via pipe or via redirection. if none, show usage instructions if no modifications were made to configuration file.
if [[ $# == 0 && -z "$TEXTINPUT" ]]; then
    if [ -t 0 ]; then
        if [[ $ADDNEWBLOG || $TOGGLEBLOG || $REMOVEBLOG || $LISTBLOGS == 1 || $TESTCONFIG == 1 ]]; then exit 900;
        else shortusage; fi
    elif [ "$READINPUT"=="0" ]; then
        READINPUT=1
        TMPFL=$(tempfile -m 777)
        while read data; do
            echo "${data}" >> $TMPFL
        done
        TEXTINPUT=$(<$TMPFL)
        rm $TMPFL
    else
        echo "This is strange. But, I should never show you this line!"
    fi
fi

read_configuration $CONFIGFILE

totalerrors=0; totalposts=0;totalposted=0;
if [ "$READINPUT" == "0" ]; then
    # POST FILES PROVIDED AS ARGUEMENTS
    echo "${BLD}${BLU}Posting to ${ACTIVEBLOGS} blog(s)${NML}"
    send_files_for_posting "$@"
else
    # READ FROM STDIN
    cliposter_post_content "${POSTTITLE}" "${TEXTINPUT}"
    let totalerrors+=${posterrors:-0};
    let totalposted+=${postedto:-0};
    let totalposts+=${totaltopost:-0};
fi
if (( $totalerrors )); then echo -en "\n${RED}Found ${totalerrors} errors while posting!${NML}"; else echo -en "\n${GRN}Posted ${totalposted} posts!${NML}"; fi
if [ "$totalposted" == "$totalposts" ]; then success="2"; else success="1"; fi
if [ "$totalposted" == "0" ]; then success="0"; fi
show_success "$success" "FAILED|WITH_ERRORS|SUCCESS|ABORTED" "" 1
show_success "$success" "$totalposted/$totalposts" "You can use option: -v (verbose mode) for detailed information while posting!" 1
echo -e "\n\t${BLD}${BLU}Completed.${NML}\n\t"

# OPEN HOMEPAGE IF REQUESTED
if [ "$OPENBLOGS" == "home" ] && [ -n "$OPENBROWSER" ]; then
    echo "Now, opening homepages for 'active' blogs.."
    let num=$TOTALBLOGS-1;
    for i in $(seq 0 $num); do
        # only post when the blog is set to active
        if [ "${BLOGACTVS[$i]}" == "active" ]; then
            $OPENBROWSER "http://${BLOGADDRS[$i]}"
        fi
    done
fi


#### exit status definitions ########################
# 899 required software missing
# 900 usage
# 901 malformed config file
# 902 config file non-existant
# 905 posting error (no active blog or empty content)
#####################################################
