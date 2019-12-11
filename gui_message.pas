{   Module of routines that deal with showing a message to the user and
*   getting his response.
}
module gui_message;
define gui_message;
define gui_message_str;
define gui_message_msg;
define gui_message_msg_stat;
%include 'gui2.ins.pas';

type
  butt_t = record                      {data about one user-selectable button}
    lx, rx, by, ty: real;              {button area, including border}
    str: string_var80_t;               {button text}
    on: boolean;                       {button is enabled}
    end;

  message_t = record                   {private data for displaying message to user}
    tparm: rend_text_parms_t;          {text control parameters, TORG = UM}
    msg: string_list_t;                {list of message text lines}
    tx, ty: real;                      {top message text line anchor point}
    tby: real;                         {bottom Y of text region}
    col_back: rend_rgb_t;              {background color}
    col_fore: rend_rgb_t;              {foreground color}
    butt_yes: butt_t;                  {info about YES button}
    butt_no: butt_t;                   {info about NO button}
    butt_abort: butt_t;                {info about ABORT button}
    end;
{
*************************************************************************
*
*   GUI_MESSAGE_DRAW (WIN, M)
*
*   This is the official draw routine for the message window.  M is the
*   private data for this message.
}
procedure gui_message_draw (           {official draw routine for message window}
  in out  win: gui_win_t;              {window to draw}
  in out  m: message_t);               {private data for this message}
  val_param; internal;

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
{
*****************************
*
*   Local subroutine BUTTON (B)
*   This routine is local to GUI_MESSAGE_DRAW.
*
*   Draw the button B, if enabled.  The text parameters must already be set,
*   including TORG = MID.
}
procedure button (                     {draw button, if enabled}
  in      b: butt_t);                  {button descriptor}
  val_param;

begin
  if not b.on then return;             {button is disabled ?}

  if gui_win_clip (win, b.lx, b.rx, b.by, b.ty) then begin {not all clipped off ?}
    rend_set.rgb^ (0.80, 0.80, 0.80);  {button background color}
    rend_prim.clear_cwind^;            {clear button to background color}

    rend_set.rgb^ (0.0, 0.0, 0.0);     {set border color}
    rend_set.cpnt_2d^ (b.lx + 1.4, b.by + 1.4); {draw button inner border}
    rend_prim.vect_2d^ (b.lx + 1.4, b.ty - 1.4);
    rend_prim.vect_2d^ (b.rx - 1.4, b.ty - 1.4);
    rend_prim.vect_2d^ (b.rx - 1.4, b.by + 1.4);
    rend_prim.vect_2d^ (b.lx + 1.4, b.by + 1.4);

    rend_set.cpnt_2d^ (                {go to button center}
      (b.lx + b.rx) * 0.5, (b.by + b.ty) * 0.5);
    rend_prim.text^ (b.str.str, b.str.len); {draw the button text}
    end;
  end;
{
*****************************
*
*   Start of GUI_MESSAGE_DRAW.
}
begin
  rend_set.rgb^ (m.col_back.red, m.col_back.grn, m.col_back.blu); {clear background}
  rend_prim.clear_cwind^;
  tp := m.tparm;                       {make local copy of text parameters}

  rend_set.rgb^ (0.0, 0.0, 0.0);       {set border color}
  rend_set.cpnt_2d^ (0.4, 0.4);        {draw outer window border}
  rend_prim.vect_2d^ (0.4, win.rect.dy - 0.4);
  rend_prim.vect_2d^ (win.rect.dx - 0.4, win.rect.dy - 0.4);
  rend_prim.vect_2d^ (win.rect.dx - 0.4, 0.4);
  rend_prim.vect_2d^ (0.4, 0.4);
{
*   Draw the message text lines.
}
  if gui_win_clip (win, 1.0, win.rect.dx - 1.0, m.tby, win.rect.dy - 1.0) then begin
    rend_set.text_parms^ (tp);
    rend_set.cpnt_2d^ (m.tx, m.ty);    {go to first line anchor point}
    rend_set.rgb^ (m.col_fore.red, m.col_fore.red, m.col_fore.red); {text color}
    string_list_pos_abs (m.msg, 1);    {init to first text line}
    while m.msg.str_p <> nil do begin  {once for each message text line}
      rend_prim.text^ (m.msg.str_p^.str, m.msg.str_p^.len); {draw this text line}
      string_list_pos_rel (m.msg, 1);  {advance to next text line}
      end;                             {back to do this next text line}
    end;
{
*   Draw the buttons.
}
  tp.start_org := rend_torg_mid_k;     {anchor to middle of text string}
  rend_set.text_parms^ (tp);           {set text parameters for buttons}

  button (m.butt_yes);                 {draw the buttons, if enabled}
  button (m.butt_no);
  button (m.butt_abort);
  end;
{
*************************************************************************
*
*   Subroutine GUI_MESSAGE (PARENT, MSTR, COL_BACK, COL_FORE,
*     BUTT_TRUE, BUTT_FALSE, BUTT_ABORT, RESP)
*
*   This is the low level "worker" routine for displaying a message to the
*   user and getting some sort of yes/no, true/false response.  The call
*   arguments are:
*
*     PARENT - Parent window to display message box within.
*
*     MSTR - The messag to display.  This will automatically be wrapped onto
*       multiple lines to fit within the window width.
*
*     COL_BACK, COL_FORE - Background and foreground colors.  The foreground
*       color will be used to draw the message text on top of an area previously
*       cleared to the background color.
*
*     BUTT_TRUE, BUTT_FALSE, BUTT_ABORT - Text for the three types of action
*       buttons supported.  An empty string causes that button to not be
*       drawn.  These three buttons correspond to the yes/no/abort
*       GUI_MSGRESP_K_T returned response.
*
*     RESP - Returned response.  Note that the ABORT response is always possible
*       even if an abort button is not supplied.  The ABORT response is returned
*       whenever an event is encountered that is not explicitly handled by
*       this routine.  The event is pushed back onto the event queue and
*       RESP is set to GUI_MSGRESP_ABORT_K.  Often the ABORT response will be
*       interpreted the same as the NO or FALSE response.
*
*   The displayed message box is always erased before this routine returns.
}
procedure gui_message (                {low level routine to display message to user}
  in out  parent: gui_win_t;           {window to display message box within}
  in      mstr: univ string_var_arg_t; {string to display, will be wrapped at blanks}
  in      col_back: rend_rgb_t;        {background color}
  in      col_fore: rend_rgb_t;        {foreground (text) color}
  in      butt_true: univ string_var_arg_t; {text for TRUE button, may be empty}
  in      butt_false: univ string_var_arg_t; {text for FALSE button, may be empty}
  in      butt_abort: univ string_var_arg_t; {text for ABORT button, may be empty}
  out     resp: gui_msgresp_k_t);      {TRUE/FALSE/ABORT response from user}
  val_param;

var
  lspace: real;                        {size of vertical gap between text lines}
  thigh: real;                         {height of raw text lines}
  space: real;                         {width of space character}
  m: message_t;                        {private data for this message}
  win: gui_win_t;                      {private window for this message}
  bv, up, ll: vect_2d_t;               {text string size and position parameters}
  nbutt: sys_int_machine_t;            {number of enabled buttons}
  htext, hbutt: real;                  {heights of text and button areas}
  hjbutt: real;                        {height of just a button}
  height: real;                        {height needed for whole window}
  f: real;                             {scratch floating point number}
  x: real;                             {scratc X coordinate}
  rend_level: sys_int_machine_t;       {initial RENDlib graphics mode level}
  ev: rend_event_t;                    {event descriptor}
  p: vect_2d_t;                        {scratch 2D coordinate}
  pnt: vect_2d_t;                      {pointer coordinate in our window space}
  xb, yb, ofs: vect_2d_t;              {save copy of old RENDlib 2D transform}
  n: sys_int_machine_t;                {scratch counter}
  modk: rend_key_mod_t;                {modifier keys}
  kid: gui_key_k_t;                    {key ID}
  c: char;                             {scratch character}

label
  event_next, leave_hit, leave_abort, leave;
{
*****************************
*
*   Local subroutine INIT_BUTTON (B, NAME)
*   This routine is local to GUI_MESSAGE.
*
*   Init the button descriptor B.  The displayed button text is NAME.
*   B.RX will be set to the required width to display the button.
}
procedure init_button (                {initialize button descriptor}
  in out  b: butt_t;                   {button descriptor to initialize}
  in      name: univ string_var_arg_t); {button text, may be empty}
  val_param;

var
  bv, up, ll: vect_2d_t;               {text string size and position parameters}

begin
  b.str.max := size_char(b.str.str);   {init var strings}
  string_copy (name, b.str);           {save button text}

  if b.str.len <= 0
    then begin                         {no name string, disable this button}
      b.on := false;                   {this button is disabled}
      b.rx := 0.0;                     {button requires no width to draw}
      end
    else begin                         {the button will be enabled}
      b.on := true;                    {enable the button}
      rend_get.txbox_txdraw^ (         {measure button text string}
        b.str.str, b.str.len,          {string and string length}
        bv, up, ll);                   {returned string metrics}
      b.rx := bv.x + space + 2.0;      {width is text, space, and border widths}
      b.rx := trunc(b.rx + 0.9);       {round to whole pixel width}
      end
    ;
  b.lx := 0.0;
  b.by := 0.0;
  b.ty := 0.0;
  end;
{
*****************************
*
*   Start of routine GUI_MESSAGE.
}
begin
  rend_dev_set (parent.all_p^.rend_dev); {make sure right RENDlib device is current}
  rend_get.enter_level^ (rend_level);  {save initial graphics mode level}
  rend_set.enter_rend^;                {make sure we are in graphics mode}

  rend_get.text_parms^ (m.tparm);      {save current text parameters}
  m.tparm.rot := 0.0;                  {set some required parameters}
  m.tparm.end_org := rend_torg_down_k;
  rend_set.text_parms^ (m.tparm);      {update the current text state}
  lspace := m.tparm.size * m.tparm.lspace; {vertical gap between lines}
  thigh := m.tparm.size * m.tparm.height; {character cell height}
  rend_get.txbox_txdraw^ (             {measure space char}
    ' ', 1,                            {string and string length to measure}
    bv, up, ll);                       {returned string metrics}
  space := bv.x;                       {save width of space character}

  nbutt := 0;                          {init number of enabled buttons}
  init_button (m.butt_yes, butt_true);
  if m.butt_yes.on then nbutt := nbutt + 1;
  init_button (m.butt_no, butt_false);
  if m.butt_no.on then nbutt := nbutt + 1;
  init_button (m.butt_abort, butt_abort);
  if m.butt_abort.on then nbutt := nbutt + 1;
{
*   Create our private window.  This will be originally made the same size
*   as the parent window.  It will later be adjusted.  This allows using
*   the window's dynamic memory context for allocating associated memory.
}
  gui_win_child (                      {create private window for the message}
    win,                               {window to create}
    parent,                            {parent window}
    2.0, 0.0,                          {lower left corner}
    parent.rect.dx - 4.0, parent.rect.dy); {displacement to opposite corner}

  string_list_init (m.msg, win.mem_p^); {create message lines list}
  gui_string_wrap (                    {wrap message text into separate lines}
    mstr,                              {text string to wrap}
    win.rect.dx - 2.0 - space,         {width to wrap lines to}
    m.msg);                            {returned list of separate lines}
{
*   Find desired height of message window and adjust its size and position.
}
  htext :=                             {height of text area}
    thigh * m.msg.n +                  {height of all the text lines}
    lspace * (m.msg.n + 1);            {gaps around text lines}
  htext := trunc(htext + 0.9);         {round text area height to whole pixels}

  hjbutt :=                            {height of just a button}
    4.0 +                              {borders}
    thigh +                            {one line of text}
    2.0 * lspace * 0.6;                {space above and below label text}
  hjbutt := trunc(hjbutt + 0.9);       {round button height to whole pixels}

  if nbutt = 0
    then begin                         {no buttons}
      hbutt := 0.0;
      end
    else begin                         {buttons are present}
      hbutt := hjbutt + lspace * 0.5;  {raw button plus space below it}
      end
    ;
  hbutt := trunc(hbutt + 0.9);         {round button area height to whole pixels}
  height := htext + hbutt + 2.0;       {whole window height, including border}

  gui_win_resize (                     {adjust message window size and position}
    win,                               {window to adjust}
    2.0,                               {left edge X}
    trunc((parent.rect.dy - height) * 0.5), {bottom Y}
    parent.rect.dx - 4.0,              {width}
    height);                           {height}
{
*   Fill in the rest of the message object.
}
  if m.msg.n <= 1
    then begin                         {only one message line, center it}
      m.tx := win.rect.dx * 0.5;
      m.tparm.start_org := rend_torg_um_k;
      end
    else begin                         {multiple message lines, left justify}
      m.tx := 1.0 + space * 0.5;
      m.tparm.start_org := rend_torg_ul_k;
      end
    ;
  m.ty := win.rect.dy - lspace;        {Y of top of top text line}
  m.tby := win.rect.dy - htext;        {bottom Y of text area}

  m.col_back := col_back;              {save background color}
  m.col_fore := col_fore;              {save foreground color}

  m.butt_yes.ty := m.tby;              {set button top}
  m.butt_yes.by := m.butt_yes.ty - hjbutt; {set button bottom}
  m.butt_no.ty := m.butt_yes.ty;       {copy Y coordinates to the other buttons}
  m.butt_no.by := m.butt_yes.by;
  m.butt_abort.ty := m.butt_yes.ty;
  m.butt_abort.by := m.butt_yes.by;

  f := m.butt_yes.rx + m.butt_no.rx + m.butt_abort.rx; {width of all the buttons}
  f := (win.rect.dx - f) / (nbutt + 1); {width of gaps around buttons}
  f := max(0.0, f);                    {never less than no space at all}
  x := 0.0;                            {init starting coordinate}

  if m.butt_yes.on then begin          {YES button enabled, set coordinates ?}
    m.butt_yes.lx := x + f;            {init left edge}
    m.butt_yes.lx := trunc(m.butt_yes.lx + 0.5); {snap to pixel boundary}
    m.butt_yes.rx := m.butt_yes.lx + m.butt_yes.rx; {find button right edge}
    x := m.butt_yes.rx;                {update current X accross}
    end;

  if m.butt_no.on then begin           {NO button enabled, set coordinates ?}
    m.butt_no.lx := x + f;             {init left edge}
    m.butt_no.lx := trunc(m.butt_no.lx + 0.5); {snap to pixel boundary}
    m.butt_no.rx := m.butt_no.lx + m.butt_no.rx; {find button right edge}
    x := m.butt_no.rx;                 {update current X accross}
    end;

  if m.butt_abort.on then begin        {ABORT button enabled, set coordinates ?}
    m.butt_abort.lx := x + f;          {init left edge}
    m.butt_abort.lx := trunc(m.butt_abort.lx + 0.5); {snap to pixel boundary}
    m.butt_abort.rx := m.butt_abort.lx + m.butt_abort.rx; {find button right edge}
    end;
{
*   All the configuration state has been set.  Now draw the window.
}
  gui_win_set_app_pnt (win, addr(m));  {set private data to pass to draw routine}
  gui_win_set_draw (win, univ_ptr(addr(gui_message_draw))); {set draw routine}
  gui_win_draw_all (win);              {draw the window}
  gui_win_xf2d_set (win);              {set RENDlib 2D space to our private window}
{
*   Event loop.  Back here for each new event until abort or button select.
}
event_next:                            {back here to get each new event}
  rend_set.enter_level^ (0);           {make sure not in graphics mode}
  rend_event_get (ev);                 {get the next event}
  case ev.ev_type of                   {what kind of event is this ?}
{
************************************************
*
*   Event POINTER MOTION
}
rend_ev_pnt_move_k: ;                  {pointer movement is ignored}
{
************************************************
*
*   Event KEY
}
rend_ev_key_k: begin                   {a key just transitioned}
  if not ev.key.down then goto event_next; {ignore key releases}
  modk := ev.key.modk;                 {get modifier keys}
  if rend_key_mod_alt_k in modk        {ALT active, this key not for us ?}
    then goto leave_abort;
  kid := gui_key_k_t(ev.key.key_p^.id_user); {make GUI library ID for this key}
  modk := modk - [rend_key_mod_shiftlock_k]; {ignore shift lock}
  p.x := ev.key.x;
  p.y := ev.key.y;
  rend_set.enter_rend^;                {make sure in graphics mode}
  rend_get.bxfpnt_2d^ (p, pnt);        {PNT is pointer coordinate in our space}

  case kid of                          {which one of our keys is it ?}

gui_key_mouse_left_k: begin            {LEFT MOUSE BUTTON}
  if                                   {pointer outside our area ?}
      (pnt.x < 0.0) or (pnt.x > win.rect.dx) or
      (pnt.y < 0.0) or (pnt.y > win.rect.dy)
      then begin
    goto leave_abort;                  {this event is for someone else}
    end;
  if modk <> [] then goto event_next;

  if nbutt = 0 then begin              {no buttons active ?}
    resp := gui_msgresp_abort_k;       {left click dismisses the message}
    goto leave_hit;
    end;

  if                                   {hit YES button ?}
      m.butt_yes.on and                {button is enabled ?}
      (pnt.x >= m.butt_yes.lx) and (pnt.x <= m.butt_yes.rx) and {inside butt area ?}
      (pnt.y >= m.butt_yes.by) and (pnt.y <= m.butt_yes.ty)
      then begin
    resp := gui_msgresp_yes_k;
    goto leave_hit;
    end;

  if                                   {hit NO button ?}
      m.butt_no.on and                 {button is enabled ?}
      (pnt.x >= m.butt_no.lx) and (pnt.x <= m.butt_no.rx) and {inside butt area ?}
      (pnt.y >= m.butt_no.by) and (pnt.y <= m.butt_no.ty)
      then begin
    resp := gui_msgresp_no_k;
    goto leave_hit;
    end;

  if                                   {hit ABORT button ?}
      m.butt_abort.on and              {button is enabled ?}
      (pnt.x >= m.butt_abort.lx) and (pnt.x <= m.butt_abort.rx) and {inside butt area ?}
      (pnt.y >= m.butt_abort.by) and (pnt.y <= m.butt_abort.ty)
      then begin
    resp := gui_msgresp_abort_k;
    goto leave_hit;
    end;

  goto event_next;                     {not hit button, ignore mouse click}
  end;

gui_key_mouse_right_k: begin           {RIGHT MOUSE BUTTON}
  if                                   {pointer outside our area ?}
      (pnt.x < 0.0) or (pnt.x > win.rect.dx) or
      (pnt.y < 0.0) or (pnt.y > win.rect.dy)
      then begin
    goto leave_abort;                  {this event is for someone else}
    end;
  end;

gui_key_esc_k: begin                   {ESCAPE key}
  if modk <> [] then goto event_next;
  resp := gui_msgresp_abort_k;
  goto leave_hit;
  end;

gui_key_enter_k: begin                 {ENTER key}
  if modk <> [] then goto event_next;
  if m.butt_yes.on then begin
    resp := gui_msgresp_yes_k;
    goto leave_hit;
    end;
  if m.butt_no.on then begin
    resp := gui_msgresp_no_k;
    goto leave_hit;
    end;
  resp := gui_msgresp_abort_k;
  goto leave_hit;
  end;

gui_key_char_k: begin                  {character key}
  c := gui_event_char (ev);            {get character represented by key event}
  c := string_upcase_char (c);         {make upper case for matching}
  n := 0;                              {init number of buttons matched to this char}
  if                                   {matches first char of YES button ?}
      m.butt_yes.on and                {the button is enabled ?}
      (string_upcase_char (m.butt_yes.str.str[1]) = c) {matches first character ?}
      then begin
    resp := gui_msgresp_yes_k;
    n := n + 1;
    end;
  if                                   {matches first char of NO button ?}
      m.butt_no.on and                 {the button is enabled ?}
      (string_upcase_char (m.butt_no.str.str[1]) = c) {matches first character ?}
      then begin
    resp := gui_msgresp_no_k;
    n := n + 1;
    end;
  if                                   {matches first char of ABORT button ?}
      m.butt_abort.on and              {the button is enabled ?}
      (string_upcase_char (m.butt_abort.str.str[1]) = c) {matches first character ?}
      then begin
    resp := gui_msgresp_abort_k;
    n := n + 1;
    end;
  if n = 1 then goto leave_hit;        {char uniquely matches a single button ?}
  end;

    end;                               {end of key ID cases}
  end;                                 {end of event KEY case}
{
************************************************
*
*   Event WIPED_RECT
}
rend_ev_wiped_rect_k: begin            {rectangular region needs redraw}
  gui_win_draw (                       {redraw a region}
    win.all_p^.root_p^,                {redraw from the root window down}
    ev.wiped_rect.x,                   {left X}
    ev.wiped_rect.x + ev.wiped_rect.dx, {right X}
    win.all_p^.root_p^.rect.dy - ev.wiped_rect.y - ev.wiped_rect.dy, {bottom Y}
    win.all_p^.root_p^.rect.dy - ev.wiped_rect.y); {top Y}
  end;
{
************************************************
}
otherwise                              {any event type we don't explicitly handle}
    goto leave_abort;
    end;                               {end of event type cases}
  goto event_next;                     {back to process next event}
{
*   The last event can not be handled by this routine.  It will be pushed
*   back onto the event queue for some other routine to handle.  We will
*   return with the ABORT response.
}
leave_abort:
  resp := gui_msgresp_abort_k;         {as if ABORT button hit}
  if ev.ev_type <> rend_ev_none_k then begin {there is an event ?}
    rend_event_push (ev);              {push event back onto queue}
    end;
  goto leave;
{
*   A button was hit.  RESP is already set.
}
leave_hit:
  goto leave;
{
*   Common exit point.
}
leave:
  gui_win_delete (win);                {delete private window for this message}
  rend_set.xform_2d^ (xb, yb, ofs);    {restore original 2D transform}
  rend_set.enter_level^ (rend_level);  {restore original graphics level}
  end;
{
*************************************************************************
*
*   Function GUI_MESSAGE_STR (PARENT, MSGTYPE, MSTR)
*
*   Display a message and wait for user response.  PARENT is the parent window
*   to display the message box within.  MSGTYPE selects one of several
*   pre-defined message types.  The message type selects the colors, which
*   of the YES/NO/ABORT buttons are enabled, and the text to appear for
*   each enabled button.  MSTR is the message to display to the user.  It
*   will be wrapped onto multiple lines as needed.
*
*   The function returns one of these values:
*
*     GUI_MSGRESP_YES_K  -  The user picked the yes or otherwise affirmative choice.
*
*     GUI_MSGRESP_NO_K  -  The user picked the no or otherwise negative choice.
*
*     GUI_MSGRESP_ABORT_K  -  The user explicitly aborted the operation or an
*       event occurred that caused an implicit abort.
}
function gui_message_str (             {display message and get user response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      mstr: univ string_var_arg_t) {string to display, will be wrapped at blanks}
  :gui_msgresp_k_t;                    {TRUE/FALSE/ABORT response from user}
  val_param;

var
  cback, cfore: rend_rgb_t;            {background and foreground colors}
  by, bn, ba: string_var80_t;          {YES, NO, and ABORT button labels}
  resp: gui_msgresp_k_t;               {response from user}

begin
  by.max := size_char(by.str);         {init local var strings}
  bn.max := size_char(bn.str);
  ba.max := size_char(ba.str);

  by.len := 0;                         {init all buttons to disabled}
  bn.len := 0;
  ba.len := 0;

  case msgtype of                      {what type of message is this ?}
gui_msgtype_info_k: begin              {informational, user must acknoledge}
      cback.red := 0.15;
      cback.grn := 0.6;
      cback.blu := 0.15;
      cfore.red := 1.0;
      cfore.grn := 1.0;
      cfore.blu := 1.0;
      string_f_message (by, 'gui', 'button_ok', nil, 0);
      end;
gui_msgtype_infonb_k: begin            {info text only, no buttons, user must cancel}
      cback.red := 0.15;
      cback.grn := 0.6;
      cback.blu := 0.15;
      cfore.red := 1.0;
      cfore.grn := 1.0;
      cfore.blu := 1.0;
      end;
gui_msgtype_yesno_k: begin             {user must make yes/no choice}
      cback.red := 0.40;
      cback.grn := 0.75;
      cback.blu := 0.40;
      cfore.red := 0.0;
      cfore.grn := 0.0;
      cfore.blu := 0.0;
      string_f_message (by, 'gui', 'button_yes', nil, 0);
      string_f_message (bn, 'gui', 'button_no', nil, 0);
      end;
gui_msgtype_todo_k: begin              {user must perform some action}
      cback.red := 0.15;
      cback.grn := 0.15;
      cback.blu := 0.75;
      cfore.red := 1.0;
      cfore.grn := 1.0;
      cfore.blu := 1.0;
      string_f_message (by, 'gui', 'button_done', nil, 0);
      string_f_message (ba, 'gui', 'button_abort', nil, 0);
      end;
gui_msgtype_prob_k: begin              {problem occurred, can continue}
      cback.red := 0.75;
      cback.grn := 0.40;
      cback.blu := 0.15;
      cfore.red := 1.0;
      cfore.grn := 1.0;
      cfore.blu := 1.0;
      string_f_message (by, 'gui', 'button_continue', nil, 0);
      string_f_message (ba, 'gui', 'button_abort', nil, 0);
      end;
gui_msgtype_err_k: begin               {error occurred, must abort operation}
      cback.red := 0.75;
      cback.grn := 0.15;
      cback.blu := 0.15;
      cfore.red := 1.0;
      cfore.grn := 1.0;
      cfore.blu := 1.0;
      string_f_message (ba, 'gui', 'button_abort', nil, 0);
      end;
otherwise                              {unexpected message type}
    gui_message_str := gui_msgresp_abort_k;
    return;
    end;                               {end of message type cases}

  gui_message (                        {call low level routine to do the work}
    parent,                            {parent window to draw message within}
    mstr,                              {message string}
    cback,                             {background color}
    cfore,                             {foreground color}
    by, bn, ba,                        {YES, NO, and ABORT button labels, if any}
    resp);                             {returned response from user}
  gui_message_str := resp;             {pass back response from user}
  end;
{
*************************************************************************
*
*   Function GUI_MESSAGE_MSG (PARENT, MSGTYPE, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Just like funtion GUI_MESSAGE_STR, except that the message text is
*   specified as an MSG file message instead of a string.  SUBSYS, MSG, PARMS,
*   and N_PARMS are the usual parameters for specifying an MSG file message.
}
function gui_message_msg (             {display message and get user response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t)  {number of parameters in PARMS}
  :gui_msgresp_k_t;                    {TRUE/FALSE/ABORT response from user}
  val_param;

var
  str: string_var8192_t;               {message string}

begin
  str.max := size_char(str.str);       {init local var string}

  string_f_message (str, subsys, msg, parms, n_parms); {expand message to string}
  gui_message_msg := gui_message_str ( {call lower routine to do the work}
    parent,                            {parent window to display message in}
    msgtype,                           {message type}
    str);                              {message string}
  end;
{
*************************************************************************
*
*   Function GUI_MESSAGE_MSG_STAT (PARENT, MSGTYPE,
*     STAT, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Just like funtion GUI_MESSAGE_MSG, except that the message associated
*   with STAT is also displayed.  SUBSYS, MSG, PARMS, and N_PARMS are the
*   usual parameters for specifying an MSG file message.
}
function gui_message_msg_stat (        {display err and user message, get response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      stat: sys_err_t;             {error status code}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t)  {number of parameters in PARMS}
  :gui_msgresp_k_t;                    {YES/NO/ABORT response from user}
  val_param;

var
  str: string_var8192_t;               {message string}
  s: string_var8192_t;                 {scratch string for building message string}

begin
  str.max := size_char(str.str);       {init local var strings}
  s.max := size_char(s.str);

  sys_error_string (stat, str);        {init overall message with STAT message}

  string_f_message (s, subsys, msg, parms, n_parms); {get caller message string}
  if (str.len > 0) and (s.len > 0) then begin {have both STAT and caller message ?}
    string_appendn (str, ''(10)(10), 2); {leave blank line between the two messages}
    end;
  string_append (str, s);              {add on caller message expansion string}

  gui_message_msg_stat := gui_message_str ( {call lower routine to do the work}
    parent,                            {parent window to display message in}
    msgtype,                           {message type}
    str);                              {message string}
  end;
