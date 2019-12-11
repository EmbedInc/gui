{   Module of routines that manipulate the GUI_ENTER_T object.  This object
*   is used for getting the user to enter a string.
}
module gui_enter;
define gui_enter_create;
define gui_enter_delete;
define gui_enter_get;
define gui_enter_create_msg;
define gui_enter_get_fp;
define gui_enter_get_int;
%include 'gui2.ins.pas';

const
  back_red = 1.00;                     {ENTER window background color}
  back_grn = 1.00;
  back_blu = 1.00;
{
*************************************************************************
*
*   Local subroutine GUI_ENTER_DRAW (WIN, ENT)
*
*   This is the official drawing routine for the private ENTER window.
*   WIN is the private ENTER window, and ENT is the ENTER object.
}
procedure gui_enter_draw (             {official draw routine for ENTER object}
  in out  win: gui_win_t;              {window of private enter object}
  in out  ent: gui_enter_t);           {the enter object}
  val_param; internal;

var
  lspace: real;                        {size of gap between sequential text lines}
  tp: rend_text_parms_t;               {local copy of our text control parameters}

begin
  lspace := ent.tparm.size * ent.tparm.lspace; {size of gap between text lines}
{
*   Clear to background and draw border.
}
  rend_set.rgb^ (back_red, back_grn, back_blu); {clear all to background color}
  rend_prim.clear_cwind^;

  rend_set.rgb^ (0.0, 0.0, 0.0);       {draw outer window border}
  rend_set.cpnt_2d^ (0.4, 0.4);
  rend_prim.vect_2d^ (0.4, win.rect.dy - 0.4);
  rend_prim.vect_2d^ (win.rect.dx - 0.4, win.rect.dy - 0.4);
  rend_prim.vect_2d^ (win.rect.dx - 0.4, 0.4);
  rend_prim.vect_2d^ (0.4, 0.4);
{
*   Draw the border around the edit string.
}
  if gui_win_clip (win,                {this region drawable ?}
      2.0, win.rect.dx - 2.0, ent.e1 - 1.0, ent.e2 + 1.0)
      then begin
    rend_set.rgb^ (0.0, 0.0, 0.0);     {set border color}
    rend_set.cpnt_2d^ (2.4, ent.e1 - 0.6); {draw border around user entry string}
    rend_prim.vect_2d^ (2.4, ent.e2 + 0.6);
    rend_prim.vect_2d^ (win.rect.dx - 2.4, ent.e2 + 0.6);
    rend_prim.vect_2d^ (win.rect.dx - 2.4, ent.e1 - 0.6);
    rend_prim.vect_2d^ (2.4, ent.e1 - 0.6);
    end;
{
*   Draw top part with prompt lines.
}
  if gui_win_clip (                    {this region drawable ?}
      win, 1.0, win.rect.dx - 1.0, ent.e1 + 0.1, win.rect.dy - 1.0)
      then begin
    rend_set.rgb^ (0.0, 0.0, 0.0);     {set text color}
    if ent.prompt.n <= 1
      then begin                       {only one prompt line, center it}
        rend_set.text_parms^ (ent.tparm); {set our text control parameters}
        rend_set.cpnt_2d^ (            {go to top center of the prompt line}
          win.rect.dx * 0.5,
          win.rect.dy - 1.0 - lspace);
        end
      else begin                       {multiple line, left justify them}
        tp := ent.tparm;               {make local copy of our text parameters}
        tp.start_org := rend_torg_ul_k; {anchor to upper left corner}
        rend_set.text_parms^ (tp);     {set text control parameters}
        rend_set.cpnt_2d^ (            {go to top left corner of top prompt line}
          1.0 + tp.size * tp.width * 0.5,
          win.rect.dy - 1.0 - lspace);
        end
      ;
    string_list_pos_abs (ent.prompt, 1); {get first prompt line}
    while ent.prompt.str_p <> nil do begin {once for each prompt line}
      rend_prim.text^ (ent.prompt.str_p^.str, ent.prompt.str_p^.len);
      string_list_pos_rel (ent.prompt, 1); {advance to next prompt line in list}
      end;                             {back to draw this new prompt line}
    end;
{
*   Draw bottom part with error message, if any.
}
  if gui_win_clip (                    {this region drawable ?}
      win, 1.0, win.rect.dx - 1.0, 1.0, ent.e1 - 1.0)
      then begin
    if ent.err.len > 0 then begin      {there is an error string to draw ?}
      rend_set.rgb^ (0.7, 0.0, 0.0);   {set error text color}
      rend_set.cpnt_2d^ (              {go to top center of error text}
        win.rect.dx * 0.5,
        ent.e1 - 1.0 - lspace);
      rend_set.text_parms^ (ent.tparm); {set our text control parameters}
      rend_prim.text^ (ent.err.str, ent.err.len);
      end;
    end;
  end;
{
*************************************************************************
*
*   Subroutine GUI_ENTER_CREATE (ENTER, PARENT, PROMPT, SEED)
*
*   Create a new ENTER object.  This object is used to let the user enter
*   a string.  PARENT is the window to draw the user entry dialog in.
*   PROMPT is the string that will be displayed to the user that should
*   prompt or explain to the user what to enter.  The string the user
*   enters and edits will be initialized to SEED.
}
procedure gui_enter_create (           {create user string entry object}
  out     enter: gui_enter_t;          {newly created enter object}
  in out  parent: gui_win_t;           {window to draw enter object within}
  in      prompt: univ string_var_arg_t; {message to prompt user for input with}
  in      seed: univ string_var_arg_t); {string to seed user input with}
  val_param;

var
  lspace: real;                        {size of gap between sequential text lines}
  thigh: real;                         {height of each text line}
  high: real;                          {desired height for whole window}

begin
  rend_dev_set (parent.all_p^.rend_dev); {make sure right RENDlib device is current}
  rend_set.enter_rend^;                {push one level into graphics mode}

  gui_win_child (                      {create private window for user entry object}
    enter.win,                         {window to create}
    parent,                            {parent window}
    0.0, 0.0, parent.rect.dx, parent.rect.dy); {init to full size of parent window}
  gui_win_set_app_pnt (                {set pointer passed to our drawing routine}
    enter.win,                         {window setting app pointer for}
    addr(enter));                      {we pass pointer to enter object}

  rend_get.text_parms^ (enter.tparm);  {save current text control properties}
  enter.tparm.start_org := rend_torg_um_k;
  enter.tparm.end_org := rend_torg_down_k;
  enter.tparm.rot := 0.0;
  rend_set.text_parms^ (enter.tparm);  {set our text parameters as current}

  lspace := enter.tparm.size * enter.tparm.lspace; {height of gap between text lines}
  thigh := enter.tparm.size * enter.tparm.height; {raw height of text lines}

  string_list_init (enter.prompt, enter.win.mem_p^); {create prompt lines list}
  enter.prompt.deallocable := false;   {allocate strings from pool if possible}
  gui_string_wrap (                    {make prompt lines list}
    prompt,                            {string to break up into lines}
    enter.win.rect.dx - 2.0 - enter.tparm.size * enter.tparm.width, {max text width}
    enter.prompt);                     {string list to add prompt lines to}

  enter.err.max := size_char(enter.err.str); {init error message to empty}
  enter.err.len := 0;
{
*   Figure out where things are vertically, then adjust the window
*   size and placement accordingly.
}
  enter.e1 :=                          {bottom of edit string area}
    2.0 +                              {outer and edit string borders}
    thigh + lspace * 2.0;              {error message height with vertical space}
  enter.e1 := trunc(enter.e1 + 0.9);   {round up to whole pixels}
  enter.e2 := enter.e1 + thigh + lspace * 2.0; {top of edit string area}
  enter.e2 := trunc(enter.e2 + 0.9);   {round up to whole pixels}
  high := enter.e2 +                   {top of whole window}
    2.0 +                              {enter area and outer window borders}
    enter.prompt.n * thigh +           {height of all the prompt lines}
    (enter.prompt.n + 1) * lspace;     {gaps around all the prompt lines}
  high := trunc(high + 0.99);          {round up to whole pixels}
  high := min(high, enter.win.rect.dy); {clip to max available height}
  gui_win_resize (                     {adjust window size and position}
    enter.win,                         {window to adjust}
    0.0, (parent.rect.dy - high) * 0.5, {bottom left corner}
    parent.rect.dx,                    {width}
    high);                             {height}
{
*   Create and initialize edit string object.
}
  gui_estr_create (                    {create the edit string object}
    enter.estr,                        {object to create}
    enter.win,                         {parent window}
    3.0, enter.win.rect.dx - 3.0,      {left and right edges}
    enter.e1, enter.e2);               {bottom and top edges}

  gui_estr_set_string (                {set initial edit string}
    enter.estr,                        {edit string object}
    seed,                              {initial seed string}
    seed.len + 1,                      {initial cursor position}
    true);                             {treat as original unedited seed string}

  rend_set.exit_rend^;                 {pop one level out of graphics mode}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ENTER_DELETE (ENTER)
*
*   Delete the ENTER object and erase it if appropriate.
}
procedure gui_enter_delete (           {delete user string entry object}
  in out  enter: gui_enter_t);         {object to delete}
  val_param;

begin
  gui_estr_delete (enter.estr);        {delete the nested edit string object}
  gui_win_delete (enter.win);          {delete the window and deallocate memory}
  end;
{
*************************************************************************
*
*   Function GUI_ENTER_GET (ENTER, ERR, RESP)
*
*   Get the string entered by the user.  ENTER is the user string entry
*   object that was previously created with GUI_ENTER_CREATE.  The string
*   in ERR will be displayed as an error message.  It may be empty.
*   RESP is returned as the string entered by the user.  Its length will
*   be set to zero if the entry was cancelled.  The function returns
*   TRUE if a string was entered, FALSE if the entry was cancelled.
*
*   *** NOTE ***
*   The ENTER object is deleted on cancel.  The calling routine must not try
*   to delete the enter object if this function returns FALSE.
*
*   The entry dialog box will be displayed, and will remain displayed
*   when this routine returns unless the entry was cancelled.
}
function gui_enter_get (               {get string entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  in out  resp: univ string_var_arg_t) {response string from user, len = 0 on cancel}
  :boolean;                            {FALSE with ENTER deleted on cancelled}
  val_param;

var
  rend_level: sys_int_machine_t;       {initial RENDlib graphics mode level}
  ev: rend_event_t;                    {event descriptor}
  p: vect_2d_t;                        {scratch 2D coordinate}
  pnt: vect_2d_t;                      {pointer coordinate in our window space}
  xb, yb, ofs: vect_2d_t;              {save copy of old RENDlib 2D transform}
  kid: gui_key_k_t;                    {key ID}
  modk: rend_key_mod_t;                {modifier keys}

label
  event_next, entered, cancelled, leave;

begin
  rend_dev_set (enter.win.all_p^.rend_dev); {make sure right RENDlib device current}
  rend_get.enter_level^ (rend_level);  {save initial graphics mode level}
  rend_set.enter_rend^;                {make sure we are in graphics mode}
  rend_get.xform_2d^ (xb, yb, ofs);    {save 2D transform}
  gui_win_xf2d_set (enter.win);        {set 2D transform for our window}

  string_copy (err, enter.err);        {set the error message string}
  gui_estr_make_seed (enter.estr);     {set up current string as seed string}

  if enter.win.draw = nil then begin   {make sure our window is showing}
    gui_win_set_draw (                 {make our private window drawable}
      enter.win, univ_ptr(addr(gui_enter_draw)));
    end;
  gui_win_draw_all (enter.win);        {draw the entire window}
{
*   Back here to get and process the next event.
}
event_next:
  rend_set.enter_level^ (0);           {make sure not in graphics mode}
  gui_estr_edit (enter.estr);          {do edits until unhandled event}
  rend_event_get (ev);                 {get the event not handled by ESTR object}
  case ev.ev_type of                   {what kind of event is this ?}
{
************************************************
*
*   Event POINTER MOTION
}
rend_ev_pnt_move_k: ;                  {these are ignored}
{
************************************************
*
*   Event KEY
}
rend_ev_key_k: begin                   {a key just transitioned}
  if not ev.key.down then goto event_next; {ignore key releases}
  modk := ev.key.modk;                 {get set of active modifier keys}
  if rend_key_mod_alt_k in modk        {ALT active, this key not for us ?}
    then goto cancelled;
  modk := modk - [rend_key_mod_shiftlock_k]; {ignore shift lock modifier}
  kid := gui_key_k_t(ev.key.key_p^.id_user); {make GUI library ID for this key}
  p.x := ev.key.x;
  p.y := ev.key.y;
  rend_get.bxfpnt_2d^ (p, pnt);        {PNT is pointer coordinate in our space}

  case kid of                          {which one of our keys is it ?}

gui_key_esc_k: begin                   {key ESCAPE, abort from this menu level}
  if modk <> [] then goto event_next;
  ev.ev_type := rend_ev_none_k;        {indicate the event got used up}
  goto cancelled;                      {abort from this menu level}
  end;

gui_key_enter_k: begin                 {key ENTER, user confirmed edited string}
  if modk <> [] then goto event_next;
  goto entered;
  end;

gui_key_mouse_left_k,
gui_key_mouse_right_k: begin           {mouse buttons}
  if                                   {pointer outside our area ?}
      (pnt.x < 0.0) or (pnt.x > enter.win.rect.dx) or
      (pnt.y < 0.0) or (pnt.y > enter.win.rect.dy)
      then begin
    goto cancelled;                    {this event is for someone else}
    end;
  end;

otherwise                              {any key not explicitly handled}
    goto cancelled;                    {assume this event is for someone else}
    end;                               {end of key ID cases}
  end;                                 {end of event KEY case}
{
************************************************
*
*   Event WIPED_RECT
}
rend_ev_wiped_rect_k: begin            {rectangular region needs redraw}
  gui_win_draw (                       {redraw a region}
    enter.win.all_p^.root_p^,          {redraw from the root window down}
    ev.wiped_rect.x,                   {left X}
    ev.wiped_rect.x + ev.wiped_rect.dx, {right X}
    enter.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y - ev.wiped_rect.dy, {bottom Y}
    enter.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y); {top Y}
  end;
{
************************************************
}
otherwise                              {any event type we don't explicitly handle}
    goto cancelled;
    end;                               {end of event type cases}
  goto event_next;                     {back to process next event}
{
*   The entry was completed normally.
}
entered:
  gui_enter_get := true;               {indicate returning with string from user}
  string_copy (enter.estr.str, resp);  {return the entered string}
  goto leave;
{
*   No entry was selected because the selection process was terminated for some
*   reason.  If EV contains an event (EV.EV_TYPE not REND_EV_NONE_K), then it
*   is assumed that this event is for someone else and must be pushed back
*   onto the event queue.
}
cancelled:
  gui_enter_get := false;              {indicate entry was cancelled}
  resp.len := 0;

  if ev.ev_type <> rend_ev_none_k then begin {we took an event for someone else ?}
    rend_event_push (ev);              {put event back at head of queue}
    end;

  gui_enter_delete (enter);            {delete the user entry object}
{
*   Common exit point.  Return values and event state already take care of.
}
leave:
  rend_set.xform_2d^ (xb, yb, ofs);    {restore original 2D transform}
  rend_set.enter_level^ (rend_level);  {restore original graphics mode level}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ENTER_CREATE_MSG (ENTER, PARENT, SEED,
*     SUBSYS, MSG, PARMS, N_PARMS)
*
*   Create an ENTER object.  The prompt text will be the expansion of the
*   message specified by standard message arguments SUBSYS, MSG, PARMS,
*   and N_PARMS.  PARENT is the window in which to display the user entry
*   dialog box.  The initial string for the user to edit will be set to
*   SEED.
}
procedure gui_enter_create_msg (       {create enter string object from message}
  out     enter: gui_enter_t;          {newly created enter object}
  in out  parent: gui_win_t;           {window to draw enter object within}
  in      seed: univ string_var_arg_t; {string to seed user input with}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

var
  prompt: string_var8192_t;            {prompt string expanded from message}

begin
  prompt.max := size_char(prompt.str); {init local var string}

  string_f_message (prompt, subsys, msg, parms, n_parms); {expand message into PARMS}
  gui_enter_create (enter, parent, prompt, seed); {create the string entry object}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ENTER_GET_FP (ENTER, ERR, FLAGS, FP)
*
*   Get a floating point value from the user.  ENTER is the previously created
*   user string entry object.  ERR will be displayed as an error message to
*   the user.  It may be empty.  The floating point value is returned in FP.
*
*   If the entry was cancelled by the user, the function returns FALSE and
*   the enter object is deleted.  Otherwise, the function returns TRUE and
*   the enter object is not deleted.
}
function gui_enter_get_fp (            {get floating point value entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  out     fp: real)                    {returned FP value, unchanged on cancel}
  :boolean;                            {FALSE with ENTER deleted on cancelled}
  val_param;

var
  resp: string_var8192_t;              {response string entered by user}
  e: string_var132_t;                  {local copy of error message string}
  fpmax: sys_fp_max_t;                 {internal floating point value}
  stat: sys_err_t;                     {string to floating point conversion status}

label
  loop;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  e.max := size_char(e.str);

  string_copy (err, e);                {init local copy of error message string}

loop:                                  {back here on string conversion error}
  if not gui_enter_get (enter, e, resp) then begin {get response string from user}
    gui_enter_get_fp := false;
    return;
    end;

  string_t_fpmax (                     {try convert response string to FP value}
    resp,                              {string to convert}
    fpmax,                             {returned FP value}
    [string_tfp_group_k],              {allow digits group characters}
    stat);                             {returned conversion status}
  if sys_error(stat) then begin        {string conversion error ?}
    string_f_message (e, 'gui', 'err_enter_fp', nil, 0); {make error message}
    goto loop;                         {back and ask user again}
    end;

  fp := fpmax;                         {pass back floating point value}
  gui_enter_get_fp := true;            {indicate entry not aborted}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ENTER_GET_INT (ENTER, ERR, I, STAT)
*
*   Get an integer value from the user.  ENTER is the previously created
*   user string entry object.  ERR will be displayed as an error message to
*   the user.  It may be may be empty.  The integer value is returned in I.
*
*   If the entry was cancelled by the user, the function returns FALSE and
*   the enter object is deleted.  Otherwise, the function returns TRUE and
*   the enter object is not deleted.
}
function gui_enter_get_int (           {get integer value entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  out     i: sys_int_machine_t)        {returned integer value, unchanged on cancel}
  :boolean;                            {FALSE with ENTER deleted on cancelled}
  val_param;

var
  resp: string_var8192_t;              {response string entered by user}
  e: string_var132_t;                  {local copy of error message string}
  ii: sys_int_machine_t;               {internal integer value}
  stat: sys_err_t;                     {string to integer conversion status}

label
  loop;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  e.max := size_char(e.str);

  string_copy (err, e);                {init local copy of error message string}

loop:                                  {back here on string conversion error}
  if not gui_enter_get (enter, e, resp) then begin {get response string from user}
    gui_enter_get_int := false;
    return;
    end;

  string_t_int (resp, ii, stat);       {try to convert response to integer value}
  if sys_error(stat) then begin        {string conversion error ?}
    string_f_message (e, 'gui', 'err_enter_int', nil, 0); {make error message}
    goto loop;                         {back and ask user again}
    end;

  i := ii;                             {pass back final integer value}
  gui_enter_get_int := true;           {indicate entry not aborted}
  end;
