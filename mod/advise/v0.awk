
# Section: utilities

BEGIN{
    false = 0;      true = 1

    RS = "\034"
    # KEYPATH_SEP = "\034"  # Not works with regex pattern [^\034]
    # KEYPATH_SEP = "\003"
    KEYPATH_SEP = ","
    # KEYPATH_SEP = "-"
    VAL_SEP = "\n"
    KV_SEP = RS
    FUNC_SEP = "\004"
    FUNC_SEP_LEN = FUNC_SEP "len"
}

function str_wrap(s){
    return "\"" s "\""
}

function str_unwrap(s){
    # return "\"" s "\""
    s = substr(s, 2, length(s)-2)
    gsub(/\\"/, "\"", s)
    return s
}

function str_startswith(src, prefix,    len){
    len = length(prefix)
    if (len == 0)   return true
    if (substr(src, 1, len) == prefix) {
        return true
    }
    return false
}

function pattern_wrap(s){
    return "\"[^\003]*:" s ":[^\003]*\""
    # return "\"[^-\034\035]*:" s ":[^-\034\035]*\""
    # return "\"[^-]*:" s ":[^-]*\""
}

function debug(msg){
    # if (dbg == false) return
	print "\033[1;31midx[" s_idx "]\tDEBUG:   " msg "\033[0;0m" > "/dev/stderr"
}

function json_walk_panic(msg,       start){
    start = s_idx - 10
    if (start <= 0) start = 1
    print (msg " [index=" s_idx "]:\n-------------------\n" JSON_TOKENS[s_idx -2] "\n" JSON_TOKENS[s_idx -1] "\n" JSON_TOKENS[s_idx ] "\n" JSON_TOKENS[s_idx + 1] "\n" JSON_TOKENS[s_idx + 2] "\n-------------------") > "/dev/stderr"
    exit 1
}

function json_walk_log(msg,       start){
    start = s_idx - 10
    if (start <= 0) start = 1
    print (msg " [index=" s_idx "]:\n-------------------\n" JSON_TOKENS[s_idx -2] "\n" JSON_TOKENS[s_idx -1] "\n" JSON_TOKENS[s_idx ] "\n" JSON_TOKENS[s_idx + 1] "\n" JSON_TOKENS[s_idx + 2] "\n-------------------") > "/dev/stderr"
}

# EndSection

# Section: RULE

BEGIN {
    # RULE_ID_TO_NAME
    # RULE_ID_ARGNUM

    # RULE_ID_M     false:1   true:0   REQUIRED_PROVIDED:100
    REQUIRED_PROVIDED = 100

    # RULE_ID_R
    # RULE_ID_R_LIST
    # RULE_ID_CANDIDATES
}

function rule_add_key( keypath, key,
    num, tmp ) {

    # key = str_unwrap( key )  # Notice: simple unwrap

    keyarrlen = split(key, keyarr, "|")
    first = keyarr[1]

    KEYPREFIX = keypath KEYPATH_SEP
    keyid = KEYPREFIX key

    # It is an option
    # TODO: add code for it is an option :<Object name>

    if (first ~ /-/) {
        # options
        last = keyarr[keyarrlen]
        if ( match(last, /^[0-9]+$/) ) {
            keyid = substr(keyid, 1, length(keyid)-RLENGTH-1)
            num = last
            tmp = RULE_ID_ARGNUM[ keyid ] || 0
            if (tmp < num) {
                RULE_ID_ARGNUM[ keyid ] = num
            }
            keyarrlen = keyarrlen - 1
        } else {
            RULE_ID_ARGNUM[ keyid ] = 1
            # Notice: What if value is null ?
        }

        last = keyarr[keyarrlen]
        if (last ~ /^[rm|mr|r|m]$/) {
            keyarrlen = keyarrlen - 1
            if (last ~ "m")     RULE_ID_M[ keyid ] = true
            if (last ~ "r")     {
                RULE_ID_R[ keyid ] = true
                RULE_ID_R_LIST = RULE_ID_R_LIST "\n" keyid
            }
        }
    } else {
        RULE_ID_ARGNUM[ keyid ] = -1    # Means it is subcmd
    }

    # tmp = ""
    for (i=1; i<=keyarrlen; ++i) {
        e = keyarr[i]
        RULE_ALIAS_TO_ID[ KEYPREFIX e ] = keyid
        # tmp = tmp " " e
    }
    # RULE_ID_CANDIDATES[ keypath ] = RULE_ID_CANDIDATES[ keypath ] tmp
    RULE_ID_CANDIDATES[ keypath ] = RULE_ID_CANDIDATES[ keypath ] "\n" keyid
    # debug("aaa:\t" RULE_ID_CANDIDATES[ keypath ])
}

function rule_add_list_val( keypath, val,
    num, tmp ) {

    val = str_unwrap( val )     # Notice: simple unwrap

    if (match(keypath, KEYPATH_SEP "[0-9]+$") ) {
        keypath = substr( keypath, 1, RSTART-1 )
    }

    RULE_ID_CANDIDATES[ keypath ] = RULE_ID_CANDIDATES[ keypath ] "\n" val   # unwrap val
}

function rule_add_dict_val( keypath, val,
    num, tmp ) {

    if (val == "null") {
        RULE_ID_ARGNUM[ keypath ] = 0
        # No candidates
    } else {
        RULE_ID_CANDIDATES[ keypath ] = "#> " str_unwrap( val )
    }
}

# EndSection

# Section: JSON: utilities

function json_walk_dict_as_candidates(keypath,
    _tmp, _res){

    nth = -1
    s = JSON_TOKENS[ ++s_idx ]

    _res = ""

    while (1) {
        if (s == "}") {
            s = JSON_TOKENS[++s_idx];
            break
        }

        key = str_unwrap( s )
        s = JSON_TOKENS[ ++s_idx ]
        if (s != ":") json_walk_panic("json_walk_dict_as_candidates() Expect : but get " s)
        s = JSON_TOKENS[ ++s_idx ]

        if (s == "[") {
            _tmp = ""
            # TODO: prevent infinite loop
            while (1) {
                s = JSON_TOKENS[ ++s_idx ]
                if (s == ",") {
                    s = JSON_TOKENS[ ++s_idx ]
                }
                if (s == "]") {
                    s = JSON_TOKENS[ ++s_idx ]
                    break
                }
                _tmp = _tmp "\n" str_unwrap( s )
            }
        } else {
            _tmp = "#> " str_unwrap( s )
        }

        _res = _res KV_SEP key KV_SEP _tmp
        if (s == ",") s = JSON_TOKENS[++s_idx]
    }

    RULE_ID_CANDIDATES[ keypath ] = _res

}

function json_walk_dict(keypath, indent,
    data, nth, cur_keypath, cur_indent, key, value){

    if (s != "{") {
        # debug("json_walk_dict() fails" )
        return false
    }

    nth = -1
    s = JSON_TOKENS[++s_idx]

    data = "{"

    while (1) {
        nth ++
        if (s == "}") {
            s = JSON_TOKENS[++s_idx];  break
        }

        # if (s == ":") { json_walk_panic("json_walk_dict() Expect A value NOT :") }
        key = str_unwrap( s )
        rule_add_key(keypath, key)
        cur_keypath = keypath KEYPATH_SEP key


        data = data VAL_SEP key

        s = JSON_TOKENS[++s_idx]
        if (s != ":") json_walk_panic("json_walk_dict() Expect :")

        s = JSON_TOKENS[++s_idx]            # Value

        if ( (s == "{") && (key ~ /^[-#]/) )
        {
            # It means it is an struct candidate
            json_walk_dict_as_candidates(cur_keypath)
            # json_walk_log("json_walk_dict !!! " s)
            # print "s is " s > "/dev/stderr"
        } else {
            json_walk_value(cur_keypath, cur_indent, "dict")
        }
        # json_walk_value(cur_keypath, cur_indent, "dict")

        if (s == ",") s = JSON_TOKENS[++s_idx]
    }

    return true
}

function json_walk_array(keypath, indent,
    data, nth, cur_keypath, cur_indent, cur_item, comma, count){
    if (s != "[")   return false

    nth = -1
    s = JSON_TOKENS[++s_idx]

    data="["

    while (1) {
        nth++;
        if (s == "]") {
            s = JSON_TOKENS[++s_idx];   break
        }

        cur_keypath = keypath KEYPATH_SEP nth

        # if (s == ",")  json_walk_panic("json_walk_array() Expect a value but get " s)
        json_walk_value(cur_keypath, cur_indent, "list")
        # debug("json_walk_array() value: " result)

        data = data VAL_SEP result

        if (s == ",")   s = JSON_TOKENS[++s_idx]
    }

    return true
}

function json_walk_value(keypath, indent, struct_type){
    if (json_walk_dict(keypath, indent) == true) {
        return true
    }

    if (json_walk_array(keypath, indent) == true) {
        return true
    }

    result = s

    if (struct_type == "dict") {
        rule_add_dict_val(keypath, s)
    } else if (struct_type == "list") {
        rule_add_list_val(keypath, s)
    }

    s = JSON_TOKENS[++s_idx]
    return true
}

function _json_walk(    final, idx, nth){
    if (s == "")  s = JSON_TOKENS[++s_idx]

    # nth = 0
    # while (s_idx <= s_len) {
    #     if (json_walk_value(nth++, "") == false) {
    #        json_walk_panic("json_walk() Expect a value")
    #     }
    # }

    json_walk_dict(".", "")
}

# global variable: text, s, s_idx, s_len
function json_walk(text,   final, b_s, b_s_idx, b_s_len){
    b_s = s;    b_s_idx = s_idx;    b_s_len = s_len;

    result = "";
    gsub(/"[^"\\\001-\037]*((\\[^u\001-\037]|\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])[^"\\\001-\037]*)*"|-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?|null|false|true|[ \t\n\r]+|./, "\n&", text)
    # gsub(/^\357\273\277|^\377\376|^\376\377|"[^"\\\001-\037]*((\\[^u\001-\037]|\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])[^"\\\001-\037]*)*"|-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?|null|false|true|[ \t\n\r]+|./, "\n&", text)
    # gsub(/^\357\273\277|^\377\376|^\376\377|"[^"\\\000-\037]*((\\[^u\000-\037]|\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])[^"\\\000-\037]*)*"|-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?|null|false|true|[ \t\n\r]+|./, "\n&", text)
	gsub("\n" "[ \t\n\r]+", "\n", text)

    s_len = split(text, JSON_TOKENS, /\n/)
    s = JSON_TOKENS[s_idx];     s_idx = 1;

    _json_walk()

    s = b_s;    s_idx = b_s_idx;    s_len = b_s_len;
}

# EndSection

# Section: Main
NR==1{
    # debug("json_walk")
    json_walk($0)
}

# Use object

BEGIN {
    COLON_ARG_EXISTED = false
}

function get_colon_argument_optionid(keypath,      _id){
    return RULE_ALIAS_TO_ID[ keypath KEYPATH_SEP "--@" ]
}

NR==2{
    argstr = $0
    # debug("argstr: " argstr)
    if ( argstr == "" ) argstr = "" # "." "\002"

    gsub("\n", "\001", argstr)
    parsed_arglen = split(argstr, parsed_argarr, "\002")
    # debug("arglen\t" parsed_arglen)

    ruleregex = ""

    arglen=0
    rest_argv_len = 0

    current_keypath = "."

    for (i=1; i<=parsed_arglen; ++i) {
        arg = parsed_argarr[i]
        gsub("\001", "\n", arg)
        parsed_argarr[i] = arg
    }

    for (i=1; i<parsed_arglen; ++i) {
        arg = parsed_argarr[i]
        argval = ""

        if (arg ~ /^-/) {
            if(match(arg,/=/)){
                continue
            }
            if (match(arg, /^--?[A-Za-z0-9_+-]+=/)){
                argval = substr(arg, RLENGTH+1)
                arg = substr(arg, 1, RLENGTH)
            }

            cur_option_alias = arg
            option_id = RULE_ALIAS_TO_ID[ current_keypath KEYPATH_SEP cur_option_alias ]

            if (option_id != "") {
                used_option_add( option_id )
            } else {
                is_compact_argument = 0
                if (arg ~ /^-[^-]/) {
                    # like tar: -xvf => -x -v -f
                    _arg_tmp_arrlen = split(arg, _arg_tmp_arr, "")
                    for (j=2; j<=_arg_tmp_arrlen; ++j) {
                        cur_option_alias = "-" _arg_tmp_arr[j]
                        option_id = RULE_ALIAS_TO_ID[ keypath KEYPATH_SEP cur_option_alias ]
                        if (option_id == "") {
                            is_compact_argument = -1
                            break
                        }
                    }

                    if (is_compact_argument == 0) {
                        for (j=2; j<=_arg_tmp_arrlen; ++j) {
                            argarr[++arglen] = cur_option_alias
                            used_option_add( option_id )
                        }
                        arg = argarr[arglen]
                        is_compact_argument = 1
                    }
                }

                if (is_compact_argument != 1) {
                    # Must be positional argument
                    cur_option_alias = ""
                    for (j=i; j<=parsed_arglen; ++j) {
                        rest_argv[++rest_argv_len] = parsed_argarr[j]
                    }
                }
            }

            # handle optarg value
            if (argval != "") {
                cur_option_alias = ""
            } else {
                cur_option_id = RULE_ALIAS_TO_ID[ current_keypath KEYPATH_SEP cur_option_alias ]
                optarg_num = RULE_ID_ARGNUM[ cur_option_id ]
                for (cur_optarg_index=1; cur_optarg_index<=optarg_num; ++cur_optarg_index) {
                    if (i+1 < parsed_arglen) {
                        argarr[++arglen] = parsed_argarr[++i]
                    } else {
                        break
                    }
                }

                if (cur_optarg_index > optarg_num) {
                    cur_option_alias = ""
                    cur_optarg_index = 0
                }
            }
        } else {

            # skip "@<object>"
            if ( (arg ~ /^@/) ) {
                if ( get_colon_argument_optionid( current_keypath ) != "") {
                    COLON_ARG_EXISTED = true
                    continue
                }
            }

            cur_option_alias = ""
            option_id = RULE_ALIAS_TO_ID[ current_keypath KEYPATH_SEP arg ]

            # debug("2\t" option_id "\t|" current_keypath KEYPATH_SEP arg)

            if (option_id == "") {
                # Must be positional argument
                for (j=i; j<=parsed_arglen; ++j) {
                    rest_argv[++rest_argv_len] = parsed_argarr[j]
                }
                break
            }

            # Must be subcommand argument
            current_keypath = option_id
            used_option_clear( )

            COLON_ARG_EXISTED = false
        }
    }

    cur = parsed_argarr[parsed_arglen]

    if (cur == "\177") {    # ascii code 127 0x7F 0177 ==> DEL
        cur = ""
    }

    if ( (cur ~ /^@/ ) ) {
        option_id = get_colon_argument_optionid( current_keypath )

        if (option_id != "") {
            candidates = RULE_ID_CANDIDATES[ option_id ]
            print_list_candidate( candidates, cur )
            exit 0
        }
    }

    if (rest_argv_len > 0) {
        show_positional_candidates( current_keypath, cur, rest_argv_len)
    } else if (cur_option_alias != "") {
        option_id = RULE_ALIAS_TO_ID[ current_keypath KEYPATH_SEP cur_option_alias ]

        candidates = RULE_ID_CANDIDATES[ option_id "|" cur_optarg_index ]
        if (candidates == "") {
            candidates = RULE_ID_CANDIDATES[ option_id ]
        }
        print_list_candidate(candidates, cur)
    } else if (match(cur,/^-.*=/)){
        current_keypath = current_keypath KEYPATH_SEP substr(cur,1,RLENGTH-1)
        candidates = RULE_ID_CANDIDATES[ current_keypath ]
        print_list_candidate(candidates, substr(cur,1,RLENGTH))
    } else {
        # list subcmd or options or postional arguments
        show_candidates( current_keypath, cur )
    }
}

# EndSection

# Section: used_option
BEGIN{
    used_option_list = ""
}

function used_option_add(option_id){
    # debug("used_option_add:\t" option_id)
    RULE_ID_R[ option_id ] = REQUIRED_PROVIDED
    used_option_list = used_option_list "\n" option_id
}

function used_option_clear(){
    used_option_list = ""
}

# EndSection

# Section: candidates

function is_all_required_provided(      arr, arrlen, i, elem){
    arrlen = split(RULE_ID_R_LIST, arr, "\n")

    for (i=2; i<=arrlen; ++i) {
        elem = arr[i]
        if (RULE_ID_R[elem] != REQUIRED_PROVIDED) {
            # debug("is_all_required_provided failed at:\t" elem)
            return false
        }
    }
    return true
}

function print_list_candidate(candidates, cur,
    can, i, can_arr_len, can_arr, _key ){

    if(match(cur,/^-.*=$/)){
        if (candidates !~ "^" KV_SEP) {
            can_arr_len = split( candidates, can_arr, "\n" )
            for (i=2; i<=can_arr_len; ++i) {
                can = cur can_arr[i]
                print can
            }
            return
        }
    }

    if ( str_startswith( candidates, "#> " ) ) {
        # print command line
        print candidates
    }


    if (candidates !~ "^" KV_SEP) {
        can_arr_len = split( candidates, can_arr, "\n" )
        for (i=2; i<=can_arr_len; ++i) {
            can = can_arr[i]
            if (str_startswith( can, cur )) {
                if (cur !~ /=/ && match(can, /=/)){
                    can=substr(can,1,RSTART)
                }
                if (!a[can]++) print can
            }
        }
        return
    }

    gsub("\n", "\001", candidates)
    can_arr_len = split(candidates, can_arr, KV_SEP)
    for (i=2; i<=can_arr_len; i=i+2) {
        _key = can_arr[i]
        # print "list _key ----- " _key "|"
        if ( (_key == "*") || ( ( _key != "*" ) && (cur != "") && (cur ~ "^" _key) ) ) {
            _val = can_arr[i + 1]
            gsub("\001", "\n", _val)
            print_list_candidate( _val )
            return
        }
    }

}

# That is most complicated.
function show_positional_candidates(final_keypath, cur, rest_argv_len,
    candidates, all_required){

    all_required = is_all_required_provided()
    if ( all_required == false ) return
    # debug("show_positional_candidates()  all_required=true")

    if(match(cur,/.*=$/)){
        RULE_ID = RULE_ALIAS_TO_ID[ final_keypath KEYPATH_SEP cur ]
    }else{
        RULE_ID = RULE_ALIAS_TO_ID[ final_keypath KEYPATH_SEP "#" rest_argv_len ]
    }

    candidates = RULE_ID_CANDIDATES[ RULE_ID ]
    # debug("show_positional_candidates(): CANDIDATES\n" candidates)
    if (candidates != "") {
        print_list_candidate( candidates, cur )
        return
    }

    candidates = RULE_ID_CANDIDATES[ final_keypath KEYPATH_SEP "#n" ]
    if (candidates != "") {
        print_list_candidate( candidates, cur )
        return
    }
}

# That is most complicated.
function show_candidates(final_keypath, cur,
    can_arr, can_arr_len,
    num, used_option_set){

    can_arr_len = split( used_option_list, can_arr, "\n" )
    for (i=2; i<=can_arr_len; ++i) {
        if (RULE_ID_M[ can_arr[i] ] != true) {
            used_option_set[ can_arr[i] ] = true
        }
    }

    candidates = RULE_ID_CANDIDATES[ final_keypath ]

    can_arr_len = split( candidates, can_arr, "\n")
    # debug( "show_candidates\t" candidates)
    print_list_candidate(can_arr[1])
    for (i=2; i<=can_arr_len; ++i) {
        can = can_arr[i]
        # debug( "show_candidates\t" can "\t" i)
        if (used_option_set[ can ] == true) continue
        # if ( (can == "#n") || (can ~ /^#[0-9]+$/) )  continue
        if ( can ~ "#(n|[0-9]+)$" )  continue
        # debug( "show_candidates\t" can "\t" i)
        print_candidate_with_optionid( can, cur )
        used_option_set[ can ] = true
    }

    show_positional_candidates( final_keypath, cur, 1 )

    if ( "" != get_colon_argument_optionid( final_keypath ) ) {
        print "@"
    }
}

# NOTICE: option_id = option / subcmd id
function print_candidate_with_optionid( option_id, cur,
    can_arr, can_arr_len, can, i, is_required){

    # if ( (length(cur) > 0) && (cur !~ /^-/) ) return
    # if ( length(cur) == 0)  cur = "-"
    # if ( cur !~ /^-/ ) return

    # debug( "print_candidate_with_optionid\t" option_id "\t>" RULE_ID_R[option_id])
    is_required = RULE_ID_R[option_id]

    can_arr_len = split( option_id, can_arr, KEYPATH_SEP )
    option_id = can_arr[ can_arr_len ]

    can_arr_len = split( option_id, can_arr, "|" )

    if (option_id ~ /^-/) {
        # It is option
        if (is_required != true) {
            if (cur == "") return
            # if (option_id ~ /^-[^-]/) || (cur !~ /^-/))
            if (! cur ~ /^-/ ) return
        }

        if (cur == "-") {
            for (i=1; i<=can_arr_len; ++i) {
                can = can_arr[i]
                if (can ~ /^-[^-]/) print can
            }
            return
        }

    }

    for (i=1; i<=can_arr_len; ++i) {
        can = can_arr[i]
        if (str_startswith( can, cur ) && can != "--@" && cur !~ /^-.*=$/) {
            print can
        }
    }
}

# EndSection
