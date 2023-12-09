{   Routines that manipulate individual menu entries.
}
module gui_menu;
define gui_menu_ent_add;
define gui_menu_ent_add_mmsg;
define gui_menu_ent_add_str;
define gui_menu_ent_draw;
define gui_menu_ent_refresh;
define gui_menu_ent_pixel;
define gui_menu_ent_select;
define gui_menu_ent_next;
define gui_menu_ent_prev;
%include 'gui2.ins.pas';
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_ADD (MENU, NAME, SHCUT, ID)
*
*   Add a new entry to the end of the menu.  NAME is the name to display to the
*   user for this entry.  SHCUT is the 1-N character position in NAME of the
*   shortcut key for this entry.  This character will be displayed underlined.
*   SHCUT of 0 indicates no shortcut key exists for this entry.
*
*   ID will be returned to the application when this entry is selected.  IDs
*   must be 0 or more.  Negative IDs are used to indicate special conditions
*   internally in the menu system.
}
procedure gui_menu_ent_add (           {add new entry to end of menu}
  in out  menu: gui_menu_t;            {menu object}
  in      name: univ string_var_arg_t; {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID to return when entry picked, >= 0}
  val_param;

var
  ent_p: gui_menent_p_t;               {pointer to new menu entry}
  kid: rend_key_id_t;                  {RENDlib ID for shortcut key}
  keys_p: rend_key_ar_p_t;             {pointer to list of RENDlib keys}
  nk: sys_int_machine_t;               {number of RENDlib keys}

label
  done_shcut;

begin
  util_mem_grab (                      {allocate memory for the new menu entry}
    sizeof(ent_p^), menu.mem_p^, false, ent_p);
{
*   Link the new menu entry to the end of the menu entries chain.
}
  if menu.first_p = nil
    then begin                         {this is first entry in menu}
      menu.first_p := ent_p;
      ent_p^.prev_p := nil;
      end
    else begin                         {there is an existing entries chain}
      menu.last_p^.next_p := ent_p;
      ent_p^.prev_p := menu.last_p;
      end
    ;
  ent_p^.next_p := nil;                {this entry is at end of chain}
  menu.last_p := ent_p;
{
*   Fill in this menu entry descriptor.
}
  string_alloc (                       {allocate memory for entry name string}
    name.len, menu.mem_p^, false, ent_p^.name_p);
  string_copy (name, ent_p^.name_p^);  {save entry name string}
  ent_p^.id := id;                     {application ID for this entry}
  ent_p^.shcut := 0;                   {init to no shortcut key for this entry}
  ent_p^.xl := 0.0;                    {display coordinates not set yet}
  ent_p^.xr := 0.0;
  ent_p^.yb := 0.0;
  ent_p^.yt := 0.0;
  ent_p^.xtext := 0.0;
  ent_p^.key_p := nil;                 {init to no modifier key}
  ent_p^.mod_req := [];                {init to no modifier keys required}
  ent_p^.mod_not := [];                {init to no modifier keys disallowed}
  ent_p^.flags := [                    {init flags for this entry}
    gui_entflag_vis_k,                 {entry will be visible}
    gui_entflag_selectable_k];         {entry is candidate for user selection}
  if                                   {name ends in "..."}
      (name.len >= 3) and
      (name.str[name.len] = '.') and
      (name.str[name.len - 1] = '.') and
      (name.str[name.len - 2] = '.')
      then begin
    ent_p^.flags :=                    {flag entry as bringing up anothe menu level}
      ent_p^.flags + [gui_entflag_nlevel_k];
    end;
{
*   Deal with special shortcut key issues.  The entry has been initialized
*   as if there is no shortcut key.
}
  if (shcut <= 0) or (shcut > ent_p^.name_p^.len) {SHCUT argument out of range ?}
    then goto done_shcut;
  ent_p^.shcut := shcut;               {set shortcut character index}
  kid :=                               {get RENDlib ID for shortcut key, if any}
    gui_key_alpha_id (ent_p^.name_p^.str[ent_p^.shcut]);
  if kid = rend_key_none_k then goto done_shcut; {no such key is available ?}

  rend_get.keys^ (keys_p, nk);         {get list of all available keys}
  ent_p^.key_p := addr(keys_p^[kid]);  {get pointer to descriptor for shortcut key}
  ent_p^.mod_req := [];                {no modifier keys required with shortcut key}
  ent_p^.mod_not := [                  {modifiers not allowed with shortcut key}
    rend_key_mod_ctrl_k,               {control}
    rend_key_mod_alt_k];               {ALT}
  if gui_menflag_alt_k in menu.flags then begin {ALT required with shcut key ?}
    ent_p^.mod_req := ent_p^.mod_req + [rend_key_mod_alt_k]; {ALT is required}
    ent_p^.mod_not := ent_p^.mod_not - [rend_key_mod_alt_k]; {ALT allowed}
    end;
done_shcut:                            {all done dealing with shortcut key setup}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_ADD_MMSG (MENU, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Add entries to a menu from a menu entries message.  The new entries will be
*   added to the end of the menu MENU.  SUBSYS, MSG, PARMS, and N_PARMS are the
*   standard message parameters.  See the header comments in the GUI_MMSG module
*   for details of message entries messages.
*
*   The process of adding menu entries is silently aborted on any error.
}
procedure gui_menu_ent_add_mmsg (      {add entries from menu entries message}
  in out  menu: gui_menu_t;            {menu to add entries to}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

var
  mmsg: gui_mmsg_t;                    {menu entries message object}
  name: string_var132_t;               {menu entry name}
  shcut: string_index_t;               {index of shortcut key within entry name}
  id: sys_int_machine_t;               {menu entry ID}

begin
  name.max := size_char(name.str);     {init local var string}

  gui_mmsg_init (                      {init for reading menu entries from message}
    mmsg, subsys, msg, parms, n_parms);

  while gui_mmsg_next (mmsg, name, shcut, id) do begin {once for each entry}
    gui_menu_ent_add (menu, name, shcut, id); {add this entry to end of menu}
    end;                               {back for entry from message}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_ADD_STR (MENU, NAME, SHCUT, ID)
*
*   Just like GUI_MENU_ENT_ADD, above, except that NAME is a regular string
*   instead of a var string.  ID must be 0 or greater.  Negative IDs are
*   reserved for internal use in the menu system.
}
procedure gui_menu_ent_add_str (       {add entry to menu, takes regular string}
  in out  menu: gui_menu_t;            {menu object}
  in      name: string;                {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID to return when entry picked, >= 0}
  val_param;

var
  vname: string_var80_t;               {var string version of NAME}

begin
  vname.max := size_char(vname.str);   {init local var string}

  string_vstring (vname, name, size_char(name));

  gui_menu_ent_add (                   {call routine to do the real work}
    menu, vname, shcut, id);
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_DRAW (MENU, ENT)
*
*   Low level routine to perform the actual drawing of a menu entry.
*   Applications should call GUI_MENU_ENT_REFRESH, which causes the specfic part
*   of the menu window to be refreshed.  This routine does the actual drawing,
*   and is for use within the menu window drawing routine.
}
procedure gui_menu_ent_draw (          {draw one entry of a menu}
  in out  menu: gui_menu_t;            {menu containing entry}
  in      ent: gui_menent_t);          {descriptor of entry to draw}
  val_param;

const
  usfore_k = 0.4;                      {unselectable entry foreground color fraction}
  usback_k = 1.0 - usfore_k;           {unselectable entry background color fraction}

var
  col_fore, col_back: rend_rgb_t;      {foreground and background colors}
  bv, up, ll: vect_2d_t;               {character string size/position values}
  x, y: real;                          {scratch coordinate}

label
  done_shcut;

begin
  if not gui_win_clip (menu.win, ent.xl, ent.xr, ent.yb, ent.yt)
    then return;                       {whole entry clipped off ?}

  rend_set.enter_rend^;                {push one level into graphics mode}

  if gui_entflag_selected_k in ent.flags
    then begin                         {this entry is selected}
      col_fore := menu.col_fore_sel;
      col_back := menu.col_back_sel;
      end
    else begin                         {this entry is not selected}
      col_fore := menu.col_fore;
      col_back := menu.col_back;
      end
    ;
  if not (gui_entflag_selectable_k in ent.flags) then begin {user can't select ent ?}
    col_fore.red := col_fore.red * usfore_k + col_back.red * usback_k; {"grayed" col}
    col_fore.grn := col_fore.grn * usfore_k + col_back.grn * usback_k;
    col_fore.blu := col_fore.blu * usfore_k + col_back.blu * usback_k;
    end;

  rend_set.rgb^ (col_back.red, col_back.grn, col_back.blu); {clear to background}
  rend_prim.clear_cwind^;

  rend_set.rgb^ (col_fore.red, col_fore.grn, col_fore.blu); {set to foreground color}
  rend_set.cpnt_2d^ (                  {go to left center of text string}
    ent.xtext, (ent.yb + ent.yt) * 0.5);
  rend_prim.text^ (ent.name_p^.str, ent.name_p^.len); {draw the entry name}
{
*   Underline the shortcut letter, if any.
}
  if ent.shcut = 0 then goto done_shcut; {no shortcut letter ?}

  if ent.shcut > 1
    then begin                         {shortcut letter is not first letter}
      rend_get.txbox_txdraw^ (         {get size of string up to shortcut letter}
        ent.name_p^.str, ent.shcut - 1, {string to measure}
        bv, up, ll);                   {returned string metrics}
      x := ent.xtext + bv.x;           {make left X of shortcut letter}
      end
    else begin                         {shortcut letter is first letter}
      x := ent.xtext;                  {set left X of shortcut letter}
      end
    ;
  rend_get.txbox_txdraw^ (             {get size of shortcut letter}
    ent.name_p^.str[ent.shcut], 1,     {string to measure}
    bv, up, ll);                       {returned string metrics}
  y :=                                 {make Y coordinate of underline}
    (ent.yb + ent.yt) * 0.5 -          {start in middle of character cell}
    menu.tparm.size * (menu.tparm.height * 0.5 + {down to bottom of character cell}
    menu.tparm.lspace * 0.40);         {to near bottom of vertical padding}

  rend_set.cpnt_2d^ (x, y);            {go to left end of underline}
  rend_prim.vect_2d^ (x + bv.x, y);    {draw to right end of underline}
done_shcut:                            {all done underlining the shortcut letter}

  rend_set.exit_rend^;                 {pop back one level from graphics mode}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_REFRESH (MENU, ENT)
*
*   Unconditionally redraw the entry ENT of the menu MENU.
}
procedure gui_menu_ent_refresh (       {refresh the graphics of a menu entry}
  in out  menu: gui_menu_t;            {menu containing entry}
  in      ent: gui_menent_t);          {descriptor of entry to draw}
  val_param;

begin
  gui_win_draw (                       {draw the part of menu window with this entry}
    menu.win,                          {window to redraw}
    ent.xl, ent.xr,                    {left and right draw limits}
    ent.yb, ent.yt);                   {bottom and top draw limits}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_PIXEL (MENU, X, Y, ENT_P)
*
*   Determine which menu entry, if any, the pixel X,Y is in.  ENT_P is returned
*   pointing to the menu entry.  If X,Y is not within a menu entry then ENT_P is
*   returned NIL.  X and Y are in RENDlib 2DIMI coordinates.
}
procedure gui_menu_ent_pixel (         {find menu entry containing a pixel}
  in out  menu: gui_menu_t;            {menu object}
  in      x, y: sys_int_machine_t;     {pixel coordinate to test for}
  out     ent_p: gui_menent_p_t);      {returned pointer to selected entry or NIL}
  val_param;

var
  rp: vect_2d_t;                       {RENDlib 2DIM point coordinates}
  mp: vect_2d_t;                       {menu 2D coordinates}

begin
  rp.x := x + 0.5;                     {make 2DIM coordinate at pixel center}
  rp.y := y + 0.5;
  rend_get.bxfpnt_2d^ (rp, mp);        {make menu 2D coordinate in MP}

  ent_p := menu.first_p;               {init to first entry in menu}
  while ent_p <> nil do begin          {once for each entry in the menu}
    if                                 {this is the selected entry ?}
        (gui_entflag_vis_k in ent_p^.flags) and {entry is drawable ?}
        (mp.x >= ent_p^.xl) and (mp.x <= ent_p^.xr) and {within horizontally ?}
        (mp.y >= ent_p^.yb) and (mp.y <= ent_p^.yt) {within vertically ?}
      then return;
    ent_p := ent_p^.next_p;            {advance to next entry in the menu}
    end;                               {back to process this new entry}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_SELECT (MENU, SEL_P, NEW_P)
*
*   Change the selected menu entry from that pointed to by SEL_P to the one
*   pointed to by NEW_P.  SEL_P is updated to point to the new selected menu
*   entry.  Either pointer may be NIL to indicate no entry is selected.
*
*   The entries are re-drawn as appropriate.
}
procedure gui_menu_ent_select (        {select new menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t;       {pointer to old selected entry, updated}
  in      new_p: gui_menent_p_t);      {pointer to new entry to select}
  val_param;

begin
  if new_p = sel_p then return;        {nothing is being changed ?}

  if sel_p <> nil then begin           {an existing entry is being deselected ?}
    sel_p^.flags := sel_p^.flags - [gui_entflag_selected_k]; {de-select entry}
    gui_menu_ent_refresh (menu, sel_p^); {update display of deselected entry}
    end;

  sel_p := new_p;                      {update pointer to currently selected entry}

  if sel_p <> nil then begin           {new entry is being selected ?}
    sel_p^.flags := sel_p^.flags + [gui_entflag_selected_k]; {select entry}
    gui_menu_ent_refresh (menu, sel_p^); {update display of selected entry}
    end;
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ENT_NEXT (MENU, SEL_P)
*
*   Select the next selectable entry after the one pointed to by SEL_P.  SEL_P
*   will be updated to point to the new selected entry.
}
procedure gui_menu_ent_next (          {select next sequential selectable menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param;

var
  start_p: gui_menent_p_t;             {starting menu entry pointer}
  ent_p: gui_menent_p_t;               {pointer to current menu entry}

begin
  if sel_p = nil
    then begin                         {no entry is currently selected}
      start_p := menu.first_p;         {start at first entry}
      end
    else begin                         {there is a currently selected entry}
      start_p := sel_p^.next_p;        {start at next entry after current}
      if start_p = nil then start_p := menu.first_p; {wrap back to first entry ?}
      end
    ;
  if start_p = nil then return;        {no entries in menu, nothing to do ?}

  ent_p := start_p;                    {init current entry to starting entry}
  while                                {loop until next selectable entry}
      not (gui_entflag_selectable_k in ent_p^.flags)
      do begin
    ent_p := ent_p^.next_p;            {advance to next entry}
    if ent_p = nil then ent_p := menu.first_p; {wrap back to first entry ?}
    if ent_p = start_p then return;    {go back to starting entry ?}
    end;
{
*   ENT_P is pointing to the entry to make the new selected entry.
}
  gui_menu_ent_select (menu, sel_p, ent_p); {updated selected menu entry}
  end;
{
********************************************************************************
*
*   Local subroutine GUI_MENU_ENT_PREV (MENU, SEL_P)
*
*   Select the previous selectable entry after the one pointed to by SEL_P.
*   SEL_P will be updated to point to the new selected entry.
}
procedure gui_menu_ent_prev (          {select previous sequential selectable entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param;

var
  start_p: gui_menent_p_t;             {starting menu entry pointer}
  ent_p: gui_menent_p_t;               {pointer to current menu entry}

begin
  if sel_p = nil
    then begin                         {no entry is currently selected}
      start_p := menu.last_p;          {start at last entry}
      end
    else begin                         {there is a currently selected entry}
      start_p := sel_p^.prev_p;        {start at previous entry before current}
      if start_p = nil then start_p := menu.last_p; {wrap back to last entry ?}
      end
    ;
  if start_p = nil then return;        {no entries in menu, nothing to do ?}

  ent_p := start_p;                    {init current entry to starting entry}
  while                                {loop until next selectable entry}
      not (gui_entflag_selectable_k in ent_p^.flags)
      do begin
    ent_p := ent_p^.prev_p;            {advance to previous entry}
    if ent_p = nil then ent_p := menu.last_p; {wrap back to last entry ?}
    if ent_p = start_p then return;    {go back to starting entry ?}
    end;
{
*   ENT_P is pointing to the entry to make the new selected entry.
}
  gui_menu_ent_select (menu, sel_p, ent_p); {updated selected menu entry}
  end;
