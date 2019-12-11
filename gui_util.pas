{   Module of relatively small GUI library utility routines.
}
module gui_util;
define gui_string_wrap;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Subroutine GUI_STRING_WRAP (STR, WIDE, LIST)
*
*   Wrap the string STR into multiple lines as needed to not exceed the
*   width limit WIDE.  The current RENDlib text control parameters are used
*   to determine the text size.
*
*   All resulting wrapped text, if any, is inserted as new lines immediately
*   following the current position in LIST.  The position will be left at
*   the last line added, or at the original position if nothing was added.
*
*   Some STR characters have special meaning:
*
*     LINE FEED (10)  -  Unconditionally start a new line.
*
*   The SIZE field of LIST is trashed.
}
procedure gui_string_wrap (            {wrap string into multiple lines}
  in      str: univ string_var_arg_t;  {input string}
  in      wide: real;                  {width to wrap to, uses curr RENDlib tparms}
  in out  list: string_list_t);        {insert at current string position}
  val_param;

var
  p: string_index_t;                   {STR parse index}
  tk: string_var8192_t;                {token parsed from STR}
  ostr: string_var8192_t;              {one line wrapped string buffer}
  spacew: real;                        {width of one space character}
  ow: real;                            {current width of string in OSTR}
  aw: real;                            {additional width if token added to OSTR}
  bv, up, ll: vect_2d_t;               {text string size and position parameters}
  nspace: sys_int_machine_t;           {number of spaces needed before new token}

label
  loop_token, new_line, add_token, leave;

begin
  tk.max := size_char(tk.str);         {init local var strings}
  ostr.max := size_char(ostr.str);

  rend_set.enter_rend^;                {push one level into graphics mode}
  p := 1;                              {init input string parse index}
  rend_get.txbox_txdraw^ (             {measure the size of the blank character}
    ' ', 1,                            {string and string length}
    bv, up, ll);                       {returned string metrics}
  spacew := bv.x;                      {save width of space character}
  ostr.len := 0;                       {init accumulated output line to empty}
  ow := 0.0;                           {init width of text in OSTR}

loop_token:                            {back here to get each new input string token}
  tk.len := 0;                         {init parsed token to empty}
  while (p <= str.len) and then (str.str[p] = ' ') {skip over leading blanks}
    do p := p + 1;
  if p > str.len then goto leave;      {input string exhausted ?}
  if str.str[p] = chr(10) then begin   {LINE FEED, start a new line ?}
    p := p + 1;                        {use up this special character}
    goto new_line;                     {close the current line}
    end;
  while (p <= str.len) and then (str.str[p] <> ' ') do begin {loop until blank char}
    if str.str[p] = chr(10) then begin {LINE FEED special case ?}
      exit;                            {token ends before this special character}
      end;
    string_append1 (tk, str.str[p]);   {append this char to parsed token}
    p := p + 1;                        {advance to next input string character}
    end;                               {back to process this new input string char}
  if tk.len <= 0 then goto leave;      {got no token, hit end of string ?}
{
*   The next input string token is in TK.  This token is treated as being
*   indivisible.
}
  rend_get.txbox_txdraw^ (             {measure the size of this token}
    tk.str, tk.len,                    {string and string length}
    bv, up, ll);                       {returned string metrics}
  aw := bv.x;                          {init additional width to raw token width}
  nspace := 0;                         {init spaces needed before new token}
  if ostr.len <= 0 then goto add_token; {always add token to empty output string}

  case ostr.str[ostr.len] of           {what is last character of previous token ?}
'.', '?', '!': nspace := 2;            {extra space after these sentence end chars}
otherwise
    nspace := 1;                       {normal single space}
    end;
  aw := aw + nspace * spacew;          {additional width if token added to OSTR}

  if ow + aw <= wide then goto add_token; {this token still fits onto output string}
{
*   The current token can't be added to the output string because that would
*   make it too wide.
}
new_line:
  list.size := ostr.len;               {set length for any new lines}
  string_list_line_add (list);         {create new line and make it current}
  string_copy (ostr, list.str_p^);     {copy this line into strings list}

  ostr.len := 0;                       {reset output line to empty}
  ow := 0.0;
  nspace := 0;                         {add no padding before token on new line}
  if tk.len <= 0 then goto loop_token; {no token to start new line with ?}
  aw := bv.x;                          {update token width without padding}
{
*   The current token is to be added to the end of the accumulated output line.
}
add_token:
  string_appendn (ostr, '    ', nspace); {add spaces before new token}
  string_append (ostr, tk);            {append the new token}
  ow := ow + aw;                       {update current width of output string}
  goto loop_token;

leave:                                 {common exit point}
  if ostr.len > 0 then begin           {unwritten output fragment exists ?}
    list.size := ostr.len;             {set length for any new lines}
    string_list_line_add (list);       {create new line and make it current}
    string_copy (ostr, list.str_p^);   {copy this line into strings list}
    end;
  rend_set.exit_rend^;                 {pop one level out of graphics mode}
  end;
