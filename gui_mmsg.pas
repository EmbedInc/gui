{   Module of routines that deal with messages specifically for supplying
*   information about menu entries.  All the routines here take the menu entries
*   message object as their first argument.
*
*   A menu entries message supplies information about the entries of a menu.
*   Such a message must adhere to a particular format within the message file
*   constructs.  These messages are expected to expand into one line per menu
*   entry.  The .NFILL command must therefore be used at the start of each
*   message to prevent line wrapping.  Each line read from the message must have
*   the format:
*
*     <ID> <name> [<shortcut index>]
*
*   ID is the internal number used to identify this menu entry, and is an
*   integer >= 0.  Menu entries are not identified by their position, but only
*   by this ID.  Therefore, the order of menu entries can be re-arranged, and
*   the program will function normally as long as the IDs are rearranged to
*   follow their entries.
*
*   NAME is the menu entry name to display to the user.  This is parsed as one
*   token, so must be enclosed in quotes ("") or apostrophies ('') if it
*   contains special characters, like spaces.
*
*   SHORTCUT INDEX is the character index into NAME for the shortcut character
*   for this entry.  The shortcut character is typically underlined so that the
*   user knows pressing that key will select that menu entry.  The index of the
*   first character is 1.  The menu entry will have no shortcut key if this
*   parameter is omitted or explicitly set to 0.  Note that SHORTCUT INDEX is
*   the index into NAME as parsed.  This means enclosing quotes aren't counted,
*   since they are not part of the name displayed to the user.
*
*   For example:
*
*     3 "Close File" 2
*
*   The menu entry will be displayed as:
*
*     Close File
*
*   with the "l" in "Close" being the shortcut character for this entry.  The
*   ID 3 will be returned when this menu entry is selected by the user.
}
module gui_mmsg;
define gui_mmsg_init;
define gui_mmsg_close;
define gui_mmsg_next;
%include 'gui2.ins.pas';
{
********************************************************************************
*
*   Subroutine GUI_MMSG_INIT (MMSG, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Set up a new connection to a menu entries message.  MMSG is the returned
*   menu entries message object.  The remaining arguments are the standard
*   arguments for specifying a message and supplying it parameters.
}
procedure gui_mmsg_init (              {init for reading a menu entries message}
  out     mmsg: gui_mmsg_t;            {returned menu entries message object}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

var
  vsubsys: string_var80_t;             {var string subsystem name}
  vmsg: string_var80_t;                {var string message name}
  stat: sys_err_t;

begin
  vsubsys.max := size_char(vsubsys.str); {init local var strings}
  vmsg.max := size_char(vmsg.str);

  string_vstring (vsubsys, subsys, sizeof(subsys)); {make var strings of str parms}
  string_vstring (vmsg, msg, sizeof(msg));

  file_open_read_msg (                 {try to open message for reading}
    vsubsys,                           {generic message file name}
    vmsg,                              {message name within file}
    parms,                             {array of parameter descriptors}
    n_parms,                           {number of parameters in PARMS}
    mmsg.conn,                         {returned connection descriptor}
    stat);

  mmsg.open := not sys_error(stat);    {indicate whether opened successfully}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MMSG_CLOSE (MMSG)
*
*   Close any connection to a menu entries message in MMSG.  Nothing is done if
*   the connection was previously closed.
}
procedure gui_mmsg_close (             {close menu entries msg object, if open}
  in out  mmsg: gui_mmsg_t);           {menu entries message object}
  val_param;

begin
  if mmsg.open then begin              {message is actually open ?}
    file_close (mmsg.conn);            {close connection to the message}
    mmsg.open := false;                {indicate connection to message closed}
    end;
  end;
{
********************************************************************************
*
*   Function GUI_MMSG_NEXT (MMSG, NAME, SHCUT, ID)
*
*   Get the next menu entry specified in the menu entries message.  MMSG is the
*   menu entries message object.  NAME, SHCUT, and ID are returned the menu
*   entry name string, shortcut character index, and ID, respectively.
*
*   The function returns TRUE when returning with the information for a new
*   menu entry.  The function returns FALSE on end of the menu entries message,
*   if MMSG was previously closed, or any error.  MMSG is always returned closed
*   when the function returns FALSE.
}
function gui_mmsg_next (               {return parameters for next menu entry}
  in out  mmsg: gui_mmsg_t;            {menu entries message object}
  in out  name: univ string_var_arg_t; {name to display to user for this choice}
  out     shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  out     id: sys_int_machine_t)       {ID returned when this entry picked}
  :boolean;                            {TRUE on got entry info, closed on FALSE}
  val_param;

var
  buf: string_var132_t;                {one line from message}
  p: string_index_t;                   {BUF parse index}
  tk: string_var16_t;                  {token parsed from BUF}
  i: sys_int_machine_t;                {scratch integer}
  stat: sys_err_t;

label
  yes, err, no;

begin
  buf.max := size_char(buf.str);       {init local var strings}
  tk.max := size_char(tk.str);

  if not mmsg.open then goto no;       {connection to message closed ?}

  file_read_msg (mmsg.conn, buf.max, buf, stat); {read next line from message}
  if sys_error(stat) then goto err;    {didn't get message line ?}
  p := 1;                              {init BUF parse index}

  string_token_int (buf, p, id, stat); {get entry ID value}
  if sys_error(stat) then goto err;

  string_token (buf, p, name, stat);   {get entry name string}
  if sys_error(stat) then goto err;

  string_token_int (buf, p, i, stat);  {get shortcut character index}
  if string_eos(stat)
    then begin                         {this token was not present}
      shcut := 0;                      {indicate no shortcut key}
      goto yes;                        {return with info}
      end
    else begin                         {other than hit end of string}
      if sys_error(stat) then goto err;
      shcut := i;                      {pass back shortcut character index}
      end
    ;

  string_token (buf, p, tk, stat);     {try to parse another token}
  if not string_eos(stat) then goto err; {not hit end of string like supposed to ?}

yes:                                   {jump here to return with entry info}
  gui_mmsg_next := true;               {indicate entry info successfully returned}
  return;                              {normal return}
{
*   Something went wrong.  We don't try to figure out what or why, just
*   terminate processing.  We close the connection to the message and indicate
*   no entry data was returned.
}
err:                                   {something went wrong}
  gui_mmsg_close (mmsg);               {close connection to message}
no:                                    {jump here to return with no entry info}
  gui_mmsg_next := false;              {init to no menu entry info returned}
  end;
