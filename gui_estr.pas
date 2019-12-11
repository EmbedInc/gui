{   Module of routines that manipulate the edit string object.  Each of
*   these routines take an edit string object ESTR passed by reference as
*   their first parameter.
*
*   An ESTR is a low level object intended for imbedding in other objects.
*   It displays a rectangle with a text string and lets the user edit the
*   string.  ESTR only draws the text string and its background.
}
module gui_estr;
define gui_estr_create;
define gui_estr_delete;
define gui_estr_make_seed;
define gui_estr_set_string;
define gui_estr_edit1;
define gui_estr_edit;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Local subroutine GUI_ESTR_DRAW (WIN, ESTR)
*
*   This is the offical draw routine for the ESTR private window.
}
procedure gui_estr_draw (              {draw routine for ESTR private window}
  in out  win: gui_win_t;              {window to draw}
  in out  estr: gui_estr_t);           {edit string object begin drawn}
  val_param; internal;

var
  poly: array[1..3] of vect_2d_t;      {scratch polygon descriptor}

begin
  rend_set.text_parms^ (estr.tparm);   {set our text control parameters}
{
*   Draw the background.
}
  if estr.orig                         {set background color}
    then rend_set.rgb^ (estr.col_bo.red, estr.col_bo.grn, estr.col_bo.blu)
    else rend_set.rgb^ (estr.col_bn.red, estr.col_bn.grn, estr.col_bn.blu);
  rend_prim.clear_cwind^;              {draw background}
{
*   Draw the cursor.
}
  if gui_estrf_curs_k in estr.flags then begin {cursor drawing enabled ?}
    if estr.orig                       {set cursor color}
      then rend_set.rgb^ (estr.col_co.red, estr.col_co.grn, estr.col_co.blu)
      else rend_set.rgb^ (estr.col_cn.red, estr.col_cn.grn, estr.col_cn.blu);
    poly[1].x := estr.curs;            {tip}
    poly[1].y := estr.by;
    poly[2].x := estr.curs - estr.curswh; {bottom left corner}
    poly[2].y := estr.bc;
    poly[3].x := estr.curs + estr.curswh; {lower right corner}
    poly[3].y := estr.bc;
    rend_prim.poly_2d^ (3, poly);      {draw the cursor}
    end;
{
*   Draw the text string.
}
  if estr.orig                         {set text color}
    then rend_set.rgb^ (estr.col_fo.red, estr.col_fo.grn, estr.col_fo.blu)
    else rend_set.rgb^ (estr.col_fn.red, estr.col_fn.grn, estr.col_fn.blu);
  rend_set.cpnt_2d^ (estr.lx, estr.by); {go to char string bottom left corner}
  rend_prim.text^ (estr.str.str, estr.str.len); {draw the text string}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ESTR_CREATE (ESTR, PARENT, LX, RX, BY, TY)
*
*   Create a new edit string object in ESTR.  PARENT is the parent window
*   this object will be drawn within.  LX and RX are the left and right
*   edges for the new object within the parent window.  BY and TY are the
*   bottom and top edges within the parent window.  The current
*   RENDlib text control parameters will be saved and used for displaying
*   the string.  The object is made displayable, although it is not
*   explicitly displayed.
}
procedure gui_estr_create (            {create edit string object}
  out     estr: gui_estr_t;            {newly created object}
  in out  parent: gui_win_t;           {window to draw object within}
  in      lx, rx: real;                {left and right edges within parent window}
  in      by, ty: real);               {top and bottom edges within parent window}
  val_param;

var
  dy: real;                            {requested drawing height}
  thigh: real;                         {text character cell height}
  lspace: real;                        {vertical gap between text lines}

begin
  rend_set.enter_rend^;                {push one level into graphics mode}

  dy := ty - by;                       {total height requested by caller}
  gui_win_child (                      {create private window for this object}
    estr.win,                          {returned new window object}
    parent,                            {parent window}
    lx, by,                            {a corner of the new window}
    rx - lx, dy);                      {displacement from the corner point}
  gui_win_set_app_pnt (estr.win, addr(estr)); {set app data passed to draw routine}
  gui_win_set_draw (estr.win, univ_ptr(addr(gui_estr_draw))); {set draw routine}

  rend_get.text_parms^ (estr.tparm);   {get current text control parameters}
  estr.tparm.rot := 0.0;               {set some required parameters our way}
  estr.tparm.start_org := rend_torg_ll_k;
  thigh := estr.tparm.size * estr.tparm.height; {character cell height}
  lspace := estr.tparm.size * estr.tparm.lspace; {gap between text lines}

  estr.lxh :=                          {set text left edge home position}
    estr.tparm.size * estr.tparm.width * 0.6;
  estr.lx := estr.lxh;                 {init to text is at home position}
  estr.by := max(                      {figure where text string bottom goes}
    dy * 0.5 - thigh * 0.5,            {center vertically}
    dy - lspace - thigh);              {leave one lspace room above}
  estr.bc := max(0.0, estr.by - thigh); {cursor bottom Y}
  estr.curs := estr.lx;                {init cursor to first character position}
  estr.curswh :=                       {half width of widest part of cursor}
    estr.tparm.size * estr.tparm.width * 0.5;
  estr.col_bn.red := 0.7;              {normal background color}
  estr.col_bn.grn := 0.7;
  estr.col_bn.blu := 0.7;
  estr.col_fn.red := 0.0;              {normal foreground color}
  estr.col_fn.grn := 0.0;
  estr.col_fn.blu := 0.0;
  estr.col_cn.red := 1.0;              {normal cursor color}
  estr.col_cn.grn := 1.0;
  estr.col_cn.blu := 0.0;
  estr.col_bo.red := 0.15;             {background color for seed text}
  estr.col_bo.grn := 0.15;
  estr.col_bo.blu := 0.60;
  estr.col_fo.red := 1.0;              {foreground color for seed text}
  estr.col_fo.grn := 1.0;
  estr.col_fo.blu := 1.0;
  estr.col_co.red := 1.0;              {cursor color for seed text}
  estr.col_co.grn := 1.0;
  estr.col_co.blu := 0.0;
  estr.str.max := size_char(estr.str.str);
  estr.str.len := 0;
  estr.ind := 1;
  estr.flags := [
    gui_estrf_orig_k,                  {enable seed string mode}
    gui_estrf_curs_k];                 {enable drawing the cursor}
  estr.orig := false;
  estr.cmoved := false;

  rend_set.exit_rend^;                 {pop one level from graphics mode}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_ESTR_CURSOR_PUT (ESTR)
*
*   Determine the cursor position by setting the CURS field.  No other
*   state is changed.  The text parameters for this window must already
*   be set current.
}
procedure gui_estr_cursor_put (        {determine cursor position}
  in out  estr: gui_estr_t);           {edit string object}
  val_param; internal;

var
  bv, up, ll: vect_2d_t;               {text string size and position parameters}

begin
  if estr.ind <= 1
    then begin                         {cursor is at start of string}
      estr.curs := estr.lx;
      end
    else begin                         {cursor is past start of string}
      rend_set.enter_rend^;            {make sure we are in graphics mode}
      rend_set.text_parms^ (estr.tparm); {set appropriate text parameters}
      rend_get.txbox_txdraw^ (         {measure string to left of cursor}
        estr.str.str, estr.ind - 1,    {string and string length}
        bv, up, ll);                   {returned string metrics}
      estr.curs := estr.lx + bv.x;     {set cursor X coordinate}
      rend_set.exit_rend^;             {pop one level from graphics mode}
      end
    ;
  end;
{
*************************************************************************
*
*   Subroutine GUI_ESTR_MAKE_SEED (ESTR)
*
*   Set the current string to be the seed string if everything is properly
*   enabled.  This window is not explicitly redrawn.
}
procedure gui_estr_make_seed (         {make current string the seed string}
  in out  estr: gui_estr_t);           {edit string object}
  val_param;

begin
  estr.orig :=                         {TRUE if treat this as undedited seed string}
    (estr.str.len > 0) and (gui_estrf_orig_k in estr.flags);
  end;
{
*************************************************************************
*
*   Subroutine GUI_ESTR_SET_STRING (ESTR, STR, CURS, SEED)
*
*   Set the current string being edited to STR.  SEED TRUE indicates that
*   the new string should be considered a "seed" string that is displayed
*   differently until first edited by the user.  A seed string is also
*   automatically deleted if the user just starts typing characters.  For
*   the new string to be considered a seed string all of the following
*   conditions must be met:
*
*     1 - SEED is TRUE.
*
*     2 - STR contains at least one character.
*
*     3 - Seed strings are enabled with the GUI_ESTRF_ORIG_K flag
*         in ESTR.FLAGS.
}
procedure gui_estr_set_string (        {init string to be edited}
  in out  estr: gui_estr_t;            {edit string object}
  in      str: univ string_var_arg_t;  {seed string}
  in      curs: string_index_t;        {char position where next input char goes}
  in      seed: boolean);              {TRUE if treat as seed string before mods}
  val_param;

begin
  string_copy (str, estr.str);         {copy new string into object}
  estr.ind := max(1, min(estr.str.len + 1, curs)); {set cursor string index}
  gui_estr_cursor_put (estr);          {calculate new cursor X coordinate}
  if seed then begin                   {make new string the seed string ?}
    gui_estr_make_seed (estr);
    end;
  gui_win_draw (                       {redraw the whole window}
    estr.win, 0.0, estr.win.rect.dx, 0.0, estr.win.rect.dy);
  end;
{
*************************************************************************
*
*   Subroutine GUI_ESTR_DELETE (ESTR)
*
*   Delete the edit string object.
}
procedure gui_estr_delete (            {delete edit string object}
  in out  estr: gui_estr_t);           {object to delete}
  val_param;

begin
  gui_win_delete (estr.win);           {delete the private window}
  end;
{
*************************************************************************
*
*   Function GUI_ESTR_EDIT1 (ESTR)
*
*   Perform one edit operation on the edit string object ESTR.  This routine
*   gets and processes events until one of these two things happen:
*
*     1 - The event causes the string or the cursor position to change.
*         The string is redrawn and the function returns TRUE.
*
*     2 - The event can not be handled by this routine.  The event is pushed
*         back onto the event queue and the function returns FALSE.
}
function gui_estr_edit1 (              {perform one edit string operation}
  in out  estr: gui_estr_t)            {edit string object}
  :boolean;                            {FALSE on encountered event not handled}
  val_param;

var
  rend_level: sys_int_machine_t;       {initial RENDlib graphics mode level}
  ev: rend_event_t;                    {event descriptor}
  lx, rx: real;                        {scratch left and right limits}
  ty: real;                            {scratch top Y coordinate}
  clx, crx: real;                      {old cursor left and right limits}
  p: vect_2d_t;                        {scratch 2D coordinate}
  pnt: vect_2d_t;                      {pointer coordinate in our window space}
  xb, yb, ofs: vect_2d_t;              {save copy of old RENDlib 2D transform}
  bv, up, ll: vect_2d_t;               {text string size and position parameters}
  i: sys_int_machine_t;                {scratch integer}
  indc: string_index_t;                {string index of left-most changed char}
  ocurs: string_index_t;               {old cursor string index}
  modk: rend_key_mod_t;                {modifier keys}
  kid: gui_key_k_t;                    {key ID}
  c: char;                             {character from key event}

label
  event_next, khome, kend, delete, leave_true, leave_false, leave;
{
************************************************
*
*   Local subroutine ORIG_CLEAR
*   This routine is local to GUI_ESTR_EDIT1.
*
*   An edit is about to be performed that would require first clearing
*   the seed string, if the current string is a seed string.
}
procedure orig_clear;

begin
  if estr.orig then begin              {current string is seed string ?}
    estr.str.len := 0;                 {clear current string}
    estr.ind := 1;
    indc := 0;                         {force redraw of everything}
    estr.orig := false;                {this is no longer a seed string}
    end;
  end;
{
************************************************
*
*   Local subroutine ORIG_KEEP
*   This routine is local to GUI_ESTR_EDIT1.
*
*   An edit is about to be performed such that if the current string is a
*   seed string, it should be converted to a permanent string.
}
procedure orig_keep;

begin
  if estr.orig then begin              {current string is seed string ?}
    estr.orig := false;                {this is no longer a seed string}
    indc := 0;                         {force redraw of everything}
    end;
  end;
{
************************************************
*
*   Start of routine GUI_ESTR_EDIT1.
}
begin
  rend_get.enter_level^ (rend_level);  {save initial graphics mode level}
  rend_set.enter_rend^;                {make sure we are in graphics mode}
  rend_get.xform_2d^ (xb, yb, ofs);    {save 2D transform}
  gui_win_xf2d_set (estr.win);         {set 2D transform for our window}

  indc := estr.str.max + 1;            {init to no part of string changed}
  ocurs := estr.ind;                   {save starting cursor index}
  estr.cmoved := false;
  clx := estr.curs - estr.curswh;      {save cursor left edge}
  crx := estr.curs + estr.curswh;      {save curser right edge}

event_next:                            {back here to get each new event}
  rend_set.enter_level^ (0);           {make sure not in graphics mode}
  rend_event_get (ev);                 {get the next event}
  case ev.ev_type of                   {what kind of event is this ?}
{
************************************************
*
*   Event POINTER MOTION
}
rend_ev_pnt_move_k: ;                  {pointer movement is ingored}
{
************************************************
*
*   Event KEY
}
rend_ev_key_k: begin                   {a key just transitioned}
  if not ev.key.down then goto event_next; {ignore key releases}
  modk := ev.key.modk;                 {get modifier keys}
  if rend_key_mod_alt_k in modk        {ALT active, this key not for us ?}
    then goto leave_false;
  kid := gui_key_k_t(ev.key.key_p^.id_user); {make GUI library ID for this key}
  modk := modk - [rend_key_mod_shiftlock_k]; {ignore shift lock}
  p.x := ev.key.x;
  p.y := ev.key.y;
  rend_set.enter_rend^;                {make sure in graphics mode}
  rend_get.bxfpnt_2d^ (p, pnt);        {PNT is pointer coordinate in our space}

  case kid of                          {which one of our keys is it ?}

gui_key_arrow_up_k,                    {these keys are ignored}
gui_key_arrow_down_k: ;

gui_key_arrow_right_k: begin           {RIGHT ARROW}
  if rend_key_mod_ctrl_k in modk then begin {go to end of line ?}
    modk := modk - [rend_key_mod_ctrl_k];
    goto kend;
    end;
  if modk <> [] then goto event_next;
  orig_keep;                           {convert seed string to permanent, if any}
  estr.ind := min(estr.str.len + 1, estr.ind + 1); {move cursor right one char}
  goto leave_true;
  end;

gui_key_arrow_left_k: begin            {LEFT ARROW}
  if rend_key_mod_ctrl_k in modk then begin {go to beginning of line ?}
    modk := modk - [rend_key_mod_ctrl_k];
    goto khome;
    end;
  if modk <> [] then goto event_next;
  orig_keep;                           {convert seed string to permanent, if any}
  estr.ind := max(1, estr.ind - 1);    {move cursor left one char}
  goto leave_true;
  end;

gui_key_home_k: begin                  {HOME key}
khome:
  if modk <> [] then goto event_next;
  orig_keep;                           {convert seed string to permanent, if any}
  estr.ind := 1;                       {move cursor to left end of string}
  goto leave_true;
  end;

gui_key_end_k: begin                   {END key}
kend:
  if modk <> [] then goto event_next;
  orig_keep;                           {convert seed string to permanent, if any}
  estr.ind := estr.str.len + 1;        {move cursor to right end of string}
  goto leave_true;
  end;

gui_key_del_k: begin                   {DELETE key}
  if modk <> [] then goto event_next;
delete:                                {common code with RUBOUT character key}
  orig_keep;                           {convert seed string to permanent, if any}
  if estr.ind > estr.str.len then goto event_next; {nothing to delete ?}
  for i := estr.ind + 1 to estr.str.len do begin {once for each char to move}
    estr.str.str[i - 1] := estr.str.str[i]; {move this character}
    end;                               {back to move the next character}
  estr.str.len := estr.str.len - 1;    {one less character in edit string}
  indc := min(indc, estr.ind);         {update to left most char that got altered}
  goto leave_true;
  end;

gui_key_mouse_left_k: begin            {LEFT MOUSE BUTTON}
  if                                   {pointer outside our area ?}
      (pnt.x < 0.0) or (pnt.x > estr.win.rect.dx) or
      (pnt.y < 0.0) or (pnt.y > estr.win.rect.dy)
      then begin
    goto leave_false;                  {this event is for someone else}
    end;
  if modk <> [] then goto event_next;
  orig_keep;                           {convert seed string to permanent, if any}

  if pnt.x <= estr.lx then begin       {left of whole string ?}
    estr.ind := 1;                     {move cursor to string start}
    goto leave_true;
    end;

  lx := estr.lx;                       {init current position to string left edge}
  for i := 1 to estr.str.len do begin  {loop thru the string looking for pointer pos}
    rend_get.txbox_txdraw^ (           {measure this string character}
      estr.str.str[i], 1,              {string and string length to measure}
      bv, up, ll);                     {returned string metrics}
    lx := lx + bv.x;                   {update X to right of this character}
    if pnt.x < lx then begin           {click was within this character ?}
      estr.ind := i;
      goto leave_true;
      end
    end;                               {back to check next character in string}

  estr.ind := estr.str.len + 1;        {put cursor at end of last character}
  goto leave_true;
  end;

gui_key_mouse_right_k: begin           {RIGHT MOUSE BUTTON}
  if                                   {pointer outside our area ?}
      (pnt.x < 0.0) or (pnt.x > estr.win.rect.dx) or
      (pnt.y < 0.0) or (pnt.y > estr.win.rect.dy)
      then begin
    goto leave_false;                  {this event is for someone else}
    end;
  end;

gui_key_char_k: begin                  {character key}
  c := gui_event_char (ev);            {get character code from key event}
  case ord(c) of                       {check for special characters}

8: begin                               {backspace}
      orig_keep;                       {convert seed string to permanent, if any}
      if estr.ind <= 1 then goto event_next; {nothing to delete left of cursor ?}
      for i := estr.ind to estr.str.len do begin {once for each char to move left}
        estr.str.str[i - 1] := estr.str.str[i]; {move this character}
        end;                           {back to move the next character}
      estr.str.len := estr.str.len - 1; {one less character in edit string}
      estr.ind := estr.ind - 1;        {update where next character goes}
      indc := min(indc, estr.ind);     {update to left most char that got altered}
      goto leave_true;
      end;

127: begin                             {delete}
      goto delete;                     {to common code with DELETE key}
      end;
    end;                               {end of special character cases}

  if not string_char_printable (c)     {this is not a printable character ?}
    then goto event_next;              {ignore it}
  orig_clear;                          {delete seed string, if any}
  if estr.ind > estr.str.max           {this char would go past end of string ?}
    then goto event_next;              {ignore it}
  if estr.ind <= estr.str.len then begin {inserting into middle of string ?}
    for i := estr.str.len downto estr.ind do begin {once for each char to move}
      if i < estr.str.max then begin   {there is room to put this char ?}
        estr.str.str[i + 1] := estr.str.str[i]; {move this character}
        end;
      end;                             {back to move next char}
    end;
  estr.str.str[estr.ind] := c;         {put new character into string}
  estr.str.len := min(estr.str.max, estr.str.len + 1); {update string length}
  indc := min(indc, estr.ind);         {update to left most char that got altered}
  estr.ind := min(estr.str.len + 1, estr.ind + 1); {update index for next char}
  goto leave_true;
  end;                                 {end of character key case}

otherwise                              {abort on any key not explicitly handled}
    goto leave_false;
    end;                               {end of key ID cases}
  end;                                 {end of event KEY case}
{
************************************************
*
*   Event WIPED_RECT
}
rend_ev_wiped_rect_k: begin            {rectangular region needs redraw}
  gui_win_draw (                       {redraw a region}
    estr.win.all_p^.root_p^,           {redraw from the root window down}
    ev.wiped_rect.x,                   {left X}
    ev.wiped_rect.x + ev.wiped_rect.dx, {right X}
    estr.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y - ev.wiped_rect.dy, {bottom Y}
    estr.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y); {top Y}
  end;
{
************************************************
}
otherwise                              {any event type we don't explicitly handle}
    goto leave_false;
    end;                               {end of event type cases}
  goto event_next;                     {back to process next event}
{
*   One or more events were processed which resulted in the ESTR state to
*   change.  INDC is the left-most string index of any character that got
*   changed.  INDC must be set to the special value of 0 if the whole string
*   got moved, not just changed.
}
leave_true:
  gui_estr_edit1 := true;              {indicate all events processed normally}

  lx := estr.win.rect.dx;              {init changed limits to nothing changed}
  rx := 0.0;
  ty := estr.by;                       {init to not redraw higher than cursor}

  if                                   {cursor got moved on display ?}
      (estr.ind <> ocurs) or           {cursor string index changed ?}
      (estr.ind > indc)                {chars changed left of cursor ?}
      then begin
    estr.cmoved := true;               {indicate cursor got moved}
    gui_estr_cursor_put (estr);        {calculate new cursor position}
    lx := min(lx, clx, estr.curs - estr.curswh); {update min region to redraw}
    rx := max(rx, crx, estr.curs + estr.curswh);
    ocurs := min(ocurs, estr.ind);     {update left index already flagged for redraw}
    end;                               {done dealing with cursor position changes}

  if indc <= estr.str.max then begin   {part of string got changed ?}
    ty := estr.win.rect.dy;            {redraw all the way to window top edge}
    rx := estr.win.rect.dx;            {redraw all the way to window right edge}
    if indc <= 1
      then begin                       {whole string changed}
        lx := 0.0;                     {redraw whole window}
        end
      else begin                       {left part of string didn't change}
        if indc >= ocurs
          then begin                   {all change was right of cursor}
            lx := min(lx, estr.curs);  {redraw all to right of cursor position}
            end
          else begin                   {string changed left of cursor}
            lx := 0.0;                 {just redraw the whole string}
            end
          ;
        end
      ;
    end;

  if lx < rx then begin                {need to redraw something ?}
    gui_win_draw (                     {redraw the modified region}
      estr.win,                        {window to redraw}
      lx, rx,                          {left and right limits to redraw}
      0.0, ty);                        {bottom and top limits to redraw}
    end;
  goto leave;
{
*   The last event can not be handled by this routine.  It will be pushed
*   back onto the event queue for some other routine to handle.
}
leave_false:
  gui_estr_edit1 := false;             {indicate returned due to unhandled event}
  if ev.ev_type <> rend_ev_none_k then begin {there is an event ?}
    rend_event_push (ev);              {push event back onto head or queue}
    end;
{
*   Common exit point.
}
leave:
  rend_set.xform_2d^ (xb, yb, ofs);    {restore original 2D transform}
  rend_set.enter_level^ (rend_level);  {restore original graphics level}
  end;
{
*************************************************************************
*
*   Subroutine GUI_ESTR_EDIT (ESTR)
*
*   This routine allows the user to perform continuous edit operations on the
*   string until an event is encountered that is not handled by the low
*   level edit routine.  The unhandled event is pushed back onto the event
*   queue.  It is up to the calling routine to decide whether this event
*   indicates the user is done editing the string, cancelled the edit, or
*   whatever.
}
procedure gui_estr_edit (              {edit string until unhandled event}
  in out  estr: gui_estr_t);           {edit string object}
  val_param;

begin
  while gui_estr_edit1(estr) do ;      {keep looping until unhandled event}
  end;
