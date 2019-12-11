{   Module of routines that manipulate menus.  These routines all take
*   a menu object as their first argument.
}
module gui_menu;
define gui_menu_create;
define gui_menu_setup_top;
define gui_menu_delete;
define gui_menu_ent_add;
define gui_menu_ent_add_str;
define gui_menu_place;
define gui_menu_drawable;
define gui_menu_draw;
define gui_menu_erase;
define gui_menu_select;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Subroutine GUI_MENU_CREATE (MENU, WIN)
*
*   Initialize a menu object.  WIN is the window the menu is eventually
*   to be displayed in.  This routine does no drawing.  The menu flags
*   will be initialized for a typical drop down menu.  The flags should
*   be changed to the desired configuration immediately after this call.
*   Note that there are wrapper routines, like GUI_MENU_SETUP_TOP, which
*   set the flags for other canned configurations.
}
procedure gui_menu_create (            {create and initialize menu object}
  out     menu: gui_menu_t;            {returned initialized menu object}
  in out  win: gui_win_t);             {window menu to appear in later}
  val_param;

begin
  util_mem_context_get (win.mem_p^, menu.mem_p); {create our private mem context}
  menu.parent_p := addr(win);          {set pointer to owning window}
  menu.col_fore.red := 0.0;            {foreground color}
  menu.col_fore.grn := 0.0;
  menu.col_fore.blu := 0.0;
  menu.col_back.red := 1.0;            {background color}
  menu.col_back.grn := 1.0;
  menu.col_back.blu := 1.0;
  menu.col_fore_sel.red := 1.0;        {foreground color for selected entry}
  menu.col_fore_sel.grn := 1.0;
  menu.col_fore_sel.blu := 1.0;
  menu.col_back_sel.red := 0.15;       {background color for selected entry}
  menu.col_back_sel.grn := 0.15;
  menu.col_back_sel.blu := 0.6;
  menu.first_p := nil;                 {init to no entries exist}
  menu.last_p := nil;
  menu.flags := [                      {initial configuration flags}
    gui_menflag_candel_k,              {delete menu when cancelled by user}
    gui_menflag_border_k,              {draw border around menu when displayed}
    gui_menflag_selsel_k,              {init to first selected entry on MENU_SELECT}
    gui_menflag_sel1_k];               {init to first selectable on no selected}
  menu.form := gui_menform_vert_k;     {init for vertical layout format}
  menu.evhan := gui_evhan_none_k;      {init to no events processed}
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_SETUP_TOP (MENU)
*
*   Change the flags and other state to make this a "standard" menu for
*   use with the top menu bar.
}
procedure gui_menu_setup_top (         {convenience wrapper for top menu bar}
  in out  menu: gui_menu_t);           {menu object}
  val_param;

begin
  menu.col_fore.red := 1.0;            {foreground color}
  menu.col_fore.grn := 1.0;
  menu.col_fore.blu := 1.0;
  menu.col_back.red := 0.15;           {background color}
  menu.col_back.grn := 0.15;
  menu.col_back.blu := 0.60;
  menu.col_fore_sel.red := 0.0;        {foreground color for selected entry}
  menu.col_fore_sel.grn := 0.0;
  menu.col_fore_sel.blu := 0.0;
  menu.col_back_sel.red := 1.0;        {background color for selected entry}
  menu.col_back_sel.grn := 1.0;
  menu.col_back_sel.blu := 1.0;
  rend_get.text_parms^ (menu.tparm);   {set default text parameter for this menu}
  menu.flags := menu.flags - [         {remove these flags}
    gui_menflag_canera_k,              {don't erase on cancel}
    gui_menflag_candel_k,              {don't delete on cancel}
    gui_menflag_pickera_k,             {don't erase on pick}
    gui_menflag_pickdel_k,             {don't delete on pick}
    gui_menflag_border_k,              {don't draw border around menu}
    gui_menflag_sel1_k, gui_menflag_selsel_k]; {no initial selected menu entry}
  menu.flags := menu.flags + [         {add these flags}
    gui_menflag_alt_k];                {assume ALT required for shortcut keys}
  menu.form := gui_menform_horiz_k;    {entries listed horizontally}
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_DELETE (MENU)
*
*   Delete the menu.  The menu object is returned invalid.  If the menu
*   is displayed, it will be erased.
}
procedure gui_menu_delete (            {delete menu object, reclaim resources}
  in out  menu: gui_menu_t);           {returned invalid}
  val_param;

begin
  if gui_menflag_window_k in menu.flags then begin {private window exists for menu ?}
    gui_win_delete (menu.win);         {erase and delete the window}
    end;
  util_mem_context_del (menu.mem_p);   {delete dynamic memory context for this menu}
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_ENT_ADD (MENU, NAME, SHCUT, ID)
*
*   Add a new entry to the end of the menu.  NAME is the name to display to
*   the user for this entry.  SHCUT is the 1-N character position in
*   NAME of the shortcut key for this entry.  This character will be displayed
*   underlined.  SHCUT of 0 indicates no shortcut key exists for this
*   entry.  ID is an arbitrary integer value that will be returned to the
*   application when this entry is selected.
}
procedure gui_menu_ent_add (           {add new entry to end of menu}
  in out  menu: gui_menu_t;            {menu object}
  in      name: univ string_var_arg_t; {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID returned when this entry picked}
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
*************************************************************************
*
*   Subroutine GUI_MENU_ENT_ADD_STR (MENU, NAME, SHCUT, ID)
*
*   Just like GUI_MENU_ENT_ADD, above, except that NAME is a regular string
*   instead of a var string.
}
procedure gui_menu_ent_add_str (       {add entry to menu, takes regular string}
  in out  menu: gui_menu_t;            {menu object}
  in      name: string;                {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID returned when this entry picked}
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
*************************************************************************
*
*   Subroutine GUI_MENU_PLACE (MENU, ULX, ULY)
*
*   Determine the final placement and any other configuration details
*   required to draw the menu.  This call makes the menu drawable.
*
*   ULX,ULY is the preferred upper left coordinate of the menu.  This is
*   the outer coordinate of the border, if any.  The preferred coordinate
*   will be used if possible, but the menu may be moved to better fit it
*   within the window.
*
*   The current text control parameters will be saved and used to draw
*   the menu later.
}
procedure gui_menu_place (             {set final menu placement and make drawable}
  in out  menu: gui_menu_t;            {menu object}
  in      ulx, uly: real);             {preferred upper left corner of whole menu}
  val_param;

var
  border: real;                        {width of each border}
  space: real;                         {width of standard char cell (not space char)}
  mwide, mhigh: real;                  {whole menu width and height}
  ehigh: real;                         {height of each menu entry}
  ewide: real;                         {width of all menu entries}
  n_ent: sys_int_machine_t;            {number of entries in menu}
  n_high: sys_int_machine_t;           {menu height in entries}
  e_p: gui_menent_p_t;                 {scratch menu entry pointer}
  bv, up: vect_2d_t;                   {char string baseline and up vectors}
  ll: vect_2d_t;                       {char string lower left coordinate}
  posx, posy: real;                    {final upper left corner within parent window}
  dx: real;                            {scratch X coordinate delta}

begin
  if gui_menflag_window_k in menu.flags then begin {window already exists for menu ?}
    gui_win_delete (menu.win);         {delete the old window}
    end;

  rend_get.text_parms^ (menu.tparm);   {save text parameters size configured with}
  menu.tparm.start_org := rend_torg_ml_k; {set text anchor to middle left}
  menu.tparm.rot := 0.0;
  rend_set.text_parms^ (menu.tparm);   {set text parms to that used by menu}

  space := menu.tparm.size * menu.tparm.width; {width of normal character cell}
  if gui_menflag_border_k in menu.flags
    then begin                         {menu will be displayed with a border}
      border := 2.0;
      end
    else begin                         {no border around menu}
      border := 0.0;
      end
    ;
{
*   Examine all the entries and determine width and number of entries.
}
  mwide := 0.0;                        {init menu width}
  n_ent := 0;                          {init number of entries}

  rend_set.cpnt_2d^ (0.0, 0.0);        {go to harmless coor to prevent overflow}
  e_p := menu.first_p;
  while e_p <> nil do begin            {once for each menu entry}
    n_ent := n_ent + 1;                {count one more entry in this menu}
    rend_get.txbox_txdraw^ (           {get name string size}
      e_p^.name_p^.str, e_p^.name_p^.len, {string to get size of}
      bv, up, ll);                     {returned size info}
    dx := bv.x + space;                {min width with 1/2 char space on sides}
    case menu.form of                  {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries displayed horizontally}
        dx := dx + space;              {full char space on each side}
        dx := trunc(dx + 0.99);        {min full pixels required for this entry}
        e_p^.xr := dx;                 {save width of this entry}
        mwide := mwide + dx;           {update width of whole menu}
        end;
gui_menform_vert_k: begin              {entries displayed vertically}
        dx := trunc(dx + 0.99);        {min full pixels required for this entry}
        mwide := max(mwide, dx);       {update width needed for whole menu}
        end;
      end;                             {end of menu layout format cases}
    e_p := e_p^.next_p;                {advance to next entry in menu}
    end;                               {back to process this new entry}

  mwide := mwide + 2.0 * border;       {make total width including borders}
{
*   Determine menu height.
}
  ehigh :=                             {make height of one entry}
    menu.tparm.size * (menu.tparm.height + menu.tparm.lspace);
  ehigh := trunc(ehigh + 0.99);        {make whole pixels needed for each entry}

  case menu.form of                    {what is menu layout format ?}
gui_menform_vert_k: begin              {entries displayed vertically}
      n_high := n_ent;                 {number of entries stacked vertically}
      end;
otherwise
    n_high := 1;                       {menu is one entry high}
    end;                               {end of menu layout format cases}

  mhigh := ehigh * n_high;             {make height for all entries}
  mhigh := mhigh + 2.0 * border;       {make total height including borders}
{
*   MWIDE and MHIGH are the sizes required to draw the entire menu.
*   Now determine the placement of the menu within the parent window
*   and create our private window that will be completely filled with
*   the menu.
}
  posx := max(0.0,                     {left justify if something gets clipped}
    min(ulx, menu.parent_p^.rect.dx - mwide)); {move left as needed to fit}
  posx := trunc(posx + 0.5);           {snap to whole pixel boundary}

  posy := min(menu.parent_p^.rect.dy,  {top justify if something gets clipped}
    max(uly, mhigh));                  {move up as needed to fit}
  posy := trunc(posy + 0.5);           {snap to whole pixel boundary}

  if gui_menflag_fill_k in menu.flags then begin {fill window to lower right ?}
    mwide := max(mwide, menu.parent_p^.rect.dx - posx);
    mhigh := max(mhigh, posy);
    end;

  gui_win_child (                      {create private window for this menu}
    menu.win,                          {returned window object}
    menu.parent_p^,                    {parent window object}
    posx, posy,                        {corner of new window within parent}
    mwide, -mhigh);                    {displacement from corner}
  menu.flags := menu.flags + [gui_menflag_window_k]; {indicate menu window exists}
  gui_win_set_app_pnt (menu.win, addr(menu)); {"application" data is menu object}
{
*   Set the final coordinates of each menu entry within our private window.
}
  ehigh :=                             {make final height for each entry}
    max(ehigh, (menu.win.rect.dy - 2.0 * border) / n_high);
  ewide :=                             {make final width of entries area}
    max(mwide, menu.win.rect.dx) - 2.0 * border;
  posx := border;                      {init left edge of first entry}
  posy := menu.win.rect.dy - border;   {init top edge of first entry}

  e_p := menu.first_p;
  while e_p <> nil do begin            {once for each menu entry}
    e_p^.xl := posx;                   {set entry left edge}
    e_p^.yt := posy;                   {set entry top edge}
    e_p^.yb := posy - ehigh;           {set entry bottom edge}
    case menu.form of                  {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries displayed horizontally}
        e_p^.xr := e_p^.xl + e_p^.xr;  {set right edge for width for this entry}
        e_p^.xtext := e_p^.xl + space; {set left edge of text string}
        posx := e_p^.xr;               {update left edge for next entry}
        end;
gui_menform_vert_k: begin              {entries displayed vertically}
        e_p^.xr := e_p^.xl + ewide;    {set right edge to entry area edge}
        e_p^.xtext := e_p^.xl + space * 0.5; {set left edge of text string}
        posy := e_p^.yb;               {update top edge for next entry}
        end;
      end;                             {end of menu layout format cases}
    e_p := e_p^.next_p;                {advance to next entry in menu}
    end;                               {back to process this new entry}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_MENU_DRAW_ENTRY (MENU, ENT)
*
*   Draw the indicated menu entry.  This is a low level routine that assumes
*   the graphics state has already been set up.  The menu window clip state
*   will be trashed.
}
procedure gui_menu_draw_entry (        {draw one entry of a menu}
  in out  menu: gui_menu_t;            {menu containing entry}
  in      ent: gui_menent_t);          {descriptor of entry to draw}
  val_param; internal;

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
*************************************************************************
*
*   Local subroutine GUI_MENU_REFRESH_ENTRY (MENU, ENT)
*
*   The interface is just like GUI_MENU_DRAW_ENTRY, except this routine
*   uses the regular window drawing mechanism to cause the appropriate
*   portion of the menu window to be redrawn.
}
procedure gui_menu_refresh_entry (     {refresh one entry of a menu}
  in out  menu: gui_menu_t;            {menu containing entry}
  in      ent: gui_menent_t);          {descriptor of entry to draw}
  val_param; internal;

begin
  gui_win_draw (                       {draw the part of menu window with this entry}
    menu.win,                          {window to redraw}
    ent.xl, ent.xr,                    {left and right draw limits}
    ent.yb, ent.yt);                   {bottom and top draw limits}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_MENU_DRAW_WIN (WIN, MENU)
*
*   This is the window draw routine for menu windows.  It is called by
*   the GUI library when appropriate in response to a redraw request.
}
procedure gui_menu_draw_win (          {menu window draw routine}
  in out  win: gui_win_t;              {window object}
  in out  menu: gui_menu_t);           {menu object}
  val_param; internal;

var
  border: real;                        {width of border around menu}
  e_p: gui_menent_p_t;                 {pointer to current menu entry}

begin
  rend_set.text_parms^ (menu.tparm);   {set text params menu was configured with}

  border := 0.0;                       {init to no border}
  if gui_menflag_border_k in menu.flags then begin {draw border around menu ?}
    border := 2.0;                     {indicate border width}
    rend_set.rgb^ (0.0, 0.0, 0.0);     {draw outer black border}
    rend_set.cpnt_2d^ (0.49, 0.49);
    rend_prim.vect_2d^ (0.49, win.rect.dy - 0.49);
    rend_prim.vect_2d^ (win.rect.dx - 0.49, win.rect.dy - 0.49);
    rend_prim.vect_2d^ (win.rect.dx - 0.49, 0.49);
    rend_prim.vect_2d^ (0.49, 0.49);
    rend_set.rgb^ (1.0, 1.0, 1.0);     {draw inner white border}
    rend_set.cpnt_2d^ (1.49, 1.49);
    rend_prim.vect_2d^ (1.49, win.rect.dy - 1.49);
    rend_prim.vect_2d^ (win.rect.dx - 1.49, win.rect.dy - 1.49);
    rend_prim.vect_2d^ (win.rect.dx - 1.49, 1.49);
    rend_prim.vect_2d^ (1.49, 1.49);
    end;

  e_p := menu.first_p;
  while e_p <> nil do begin            {once for each menu entry}
    gui_menu_draw_entry (menu, e_p^);  {draw this entry}
    e_p := e_p^.next_p;                {advance to next entry in the menu}
    end;                               {back to draw this new entry}
{
*   Done drawing the menu border and all the entries.
*   Horizontal format menus may have unused area to the right of the
*   last entry.  This area will be filled with the background color.
}
  if                                   {need to draw filler ?}
      (menu.form = gui_menform_horiz_k) and then {this is a horizontal menu ?}
      gui_win_clip (win,               {there is drawable space in filler area ?}
        menu.last_p^.xr,               {left edge}
        win.rect.dx - border,          {right edge}
        menu.last_p^.yb,               {bottom edge}
        menu.last_p^.yt)               {top edge}
      then begin
    rend_set.rgb^ (menu.col_back.red, menu.col_back.grn, menu.col_back.blu);
    rend_prim.clear_cwind^;
    end;
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_DRAWABLE (MENU)
*
*   Make the menu drawable.  The state will be set up such that the
*   menu will automatically be drawn when appropriate.  The menu will not
*   be explicitly drawn by this routine.
}
procedure gui_menu_drawable (          {make menu drawable, add to redraw list}
  in out  menu: gui_menu_t);           {menu object}
  val_param;

begin
  if not (gui_menflag_window_k in menu.flags) then begin {no window for menu yet ?}
    gui_menu_place (                   {set menu position and create its window}
      menu,                            {menu to set position of}
      0.0, menu.parent_p^.rect.dy);    {put menu in upper left corner}
    end;

  gui_win_set_draw (                   {set draw routine for menu window}
    menu.win, univ_ptr(addr(gui_menu_draw_win)));
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_DRAW (MENU)
*
*   Draw the menu.  This will also set up the redraw state so that the menu
*   will automatically be redrawn as necessary.  This routine does nothing if
*   the menu is already drawable.
}
procedure gui_menu_draw (              {draw menu}
  in out  menu: gui_menu_t);           {menu object}
  val_param;

begin
  if                                   {assume menu already drawn ?}
      (gui_menflag_window_k in menu.flags) and {window exists to draw menu in ?}
      (menu.win.draw <> nil)           {draw routine exists for menu window ?}
    then return;

  gui_menu_drawable (menu);            {make menu drawable, install in redraw list}

  gui_win_draw (                       {draw the menu window}
    menu.win,                          {window to draw}
    0.0, menu.win.rect.dx,             {left and right draw limits}
    0.0, menu.win.rect.dy);            {bottom and top draw limits}
  end;
{
*************************************************************************
*
*   Subroutine GUI_MENU_ERASE (MENU)
*
*   Erase the menu from the display.  This will cause the pixels covered
*   by the menu to be redrawn to what was underneath the menu.
}
procedure gui_menu_erase (             {erase menu, refresh what was underneath}
  in out  menu: gui_menu_t);           {menu object}
  val_param;

begin
  if not (gui_menflag_window_k in menu.flags) {no window, not displayed ?}
    then return;

  gui_win_set_draw (menu.win, nil);    {prevent menu from being redrawn}
  gui_win_draw_behind (                {refresh the region behind the menu}
    menu.win,                          {window to draw behind of}
    0.0, menu.win.rect.dx,             {left, right redraw region}
    0.0, menu.win.rect.dy);            {bottom, top redraw region}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_MENU_ENTRY_PIXEL (MENU, X, Y, ENT_P)
*
*   Determine which menu entry, if any, the pixel X,Y is in.  ENT_P is
*   returned pointing to the menu entry.  If X,Y is not within a menu
*   entry then ENT_P is returned NIL.  X and Y are in RENDlib 2DIMI
*   coordinates.
}
procedure gui_menu_entry_pixel (       {find menu entry containing a pixel}
  in out  menu: gui_menu_t;            {menu object}
  in      x, y: sys_int_machine_t;     {pixel coordinate to test for}
  out     ent_p: gui_menent_p_t);      {returned pointer to selected entry or NIL}
  val_param; internal;

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
*************************************************************************
*
*   Subroutine GUI_MENU_ENT_SELECT (MENU, SEL_P, NEW_P)
*
*   Change the selected menu entry from that pointed to by SEL_P to the
*   one pointed to by NEW_P.  SEL_P is updated to point to the new
*   selected menu entry.  Either pointer may be NIL to indicate no entry
*   is selected.
*
*   The entries are re-drawn as appropriate.
}
procedure gui_menu_ent_select (        {select new menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t;       {pointer to old selected entry, updated}
  in      new_p: gui_menent_p_t);      {pointer to new entry to select}
  val_param; internal;

begin
  if new_p = sel_p then return;        {nothing is being changed ?}

  if sel_p <> nil then begin           {an existing entry is being deselected ?}
    sel_p^.flags := sel_p^.flags - [gui_entflag_selected_k]; {de-select entry}
    gui_menu_refresh_entry (menu, sel_p^); {update display of deselected entry}
    end;

  sel_p := new_p;                      {update pointer to currently selected entry}

  if sel_p <> nil then begin           {new entry is being selected ?}
    sel_p^.flags := sel_p^.flags + [gui_entflag_selected_k]; {select entry}
    gui_menu_refresh_entry (menu, sel_p^); {update display of selected entry}
    end;
  end;
{
*************************************************************************
*
*   Local subroutine GUI_MENU_SELECT_NEXT (MENU, SEL_P)
*
*   Select the next selectable entry after the one pointed to by SEL_P.
*   SEL_P will be updated to point to the new selected entry.
}
procedure gui_menu_select_next (       {select next sequential selectable menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param; internal;

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
*************************************************************************
*
*   Local subroutine GUI_MENU_SELECT_PREV (MENU, SEL_P)
*
*   Select the previous selectable entry after the one pointed to by SEL_P.
*   SEL_P will be updated to point to the new selected entry.
}
procedure gui_menu_select_prev (       {select previous sequential selectable entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param; internal;

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
{
********************************************************************************
*
*   Function GUI_MENU_SELECT (MENU, ID, SEL_P)
*
*   Get a user menu selection.  MENU identifies the menu the user will select
*   from.  It will be drawn if it isn't already.
*
*   If an entry is selected the function returns TRUE.  ID is returned the ID
*   of the selected menu entry.  SEL_P is returned pointing to the menu entry
*   unless the menu was configured for delete on selection, in which case
*   SEL_P is returned NIL.
*
*   If no selection is made (menu cancelled) the function returns FALSE, ID
*   is returned < 0, and SEL_P is returned NIL.  Some additional information is
*   returned in ID:
*
*     -1  -  Cancelled.  No more inforation avaiable.
*
*     -2  -  Cancelled but with desire to go back to the previous menu.
*
*   The EVHAN field in MENU is set according to how the RENDlib events were
*   handled.
}
function gui_menu_select (             {get user menu selection}
  in out  menu: gui_menu_t;            {menu object}
  out     id: sys_int_machine_t;       {selected entry ID, -1 cancelled, -2 prev}
  out     sel_p: gui_menent_p_t)       {pnt to sel entry, NIL on cancel or delete}
  :boolean;                            {TRUE on selection made, FALSE on cancelled}
  val_param;

var
  ent_p, e2_p: gui_menent_p_t;         {scratch menu entry pointers}
  rend_level: sys_int_machine_t;       {initial RENDlib graphics mode level}
  ev: rend_event_t;                    {event descriptor}
  p1, p2: vect_2d_t;                   {scratch coordinates}
  nev: sys_int_machine_t;              {number of events received from queue}
  kid: gui_key_k_t;                    {key ID}
  modk: rend_key_mod_t;                {modifier keys}
  cancelid: sys_int_machine_t;         {ID to return on cancelled}
  shcut: boolean;                      {TRUE if any shortcut key active}
  alt: boolean;                        {ALT key modifier is active}
  drawn: boolean;                      {TRUE on menu already drawn on entry}
  changed: boolean;                    {TRUE if menu entry getting changed}
  c: char;                             {scratch character}

label
  got_initial_sel, event_next, selected, cancelled, leave;

begin
  cancelid := -1;                      {init to generic cancel reason}
  menu.evhan := gui_evhan_did_k;       {init to events handled and all processed}

  rend_get.enter_level^ (rend_level);  {save initial graphics mode level}
  rend_set.enter_rend^;                {make sure we are in graphics mode}
  drawn :=                             {TRUE if menu already displayed}
    (gui_menflag_window_k in menu.flags) and {menu has a window ?}
    (menu.win.draw <> nil);            {draw routine installed for menu window ?}
  if drawn then gui_win_xf2d_set (menu.win); {set 2D transform for menu window ?}
{
*   Find the first selectable and selected entries.
}
  e2_p := nil;                         {init to no entry is selectable}
  sel_p := nil;                        {init to no entry is selected}
  ent_p := menu.first_p;               {go to first entry in menu}
  while ent_p <> nil do begin          {once for each entry in the list}
    if                                 {first selectable entry ?}
        (e2_p = nil) and               {not already found first selectable ?}
        (gui_entflag_selectable_k in ent_p^.flags) {entry may be selected ?}
        then begin
      e2_p := ent_p;                   {save pointer to first selectable entry}
      end;
    if                                 {first selected entry ?}
        (sel_p = nil) and              {not already found first selected ?}
        (gui_entflag_selected_k in ent_p^.flags) {entry may be selected ?}
        then begin
      sel_p := ent_p;                  {save pointer to first selected entry}
      end;
    ent_p := ent_p^.next_p;            {advance to next entry in the menu}
    end;                               {back to check out next menu entry}

  ent_p := sel_p;                      {set pointer to first selected entry}
{
*   Determine which entry, if any, is to be initially selected.  SEL_P
*   will be set pointing to the initial selected entry.  ENT_P is
*   pointing to the first selected entry, and E2_P is pointing to the
*   first selectable entry.
}
  sel_p := nil;                        {init to no entry initially selected}

  if                                   {pick first selected entry}
      (gui_menflag_selsel_k in menu.flags) and {pick first selected is enabled ?}
      (ent_p <> nil)                   {an entry is selected ?}
      then begin
    sel_p := ent_p;
    goto got_initial_sel;
    end;

  if                                   {pick first selectable entry ?}
      (gui_menflag_sel1_k in menu.flags) and {pick first selectable is enabled ?}
      (e2_p <> nil)                    {there is a selectable entry ?}
      then begin
    sel_p := e2_p;
    goto got_initial_sel;
    end;

got_initial_sel:
{
*   SEL_P is pointing to the entry that is to be initially selected.  SEL_P
*   may be NIL to indicate no entry is initially selected.  Now loop thru
*   all the entries and set their state accordingly.
}
  shcut := false;                      {init to no shortcut keys in use}
  ent_p := menu.first_p;               {init to first entry in menu}
  while ent_p <> nil do begin          {once for each entry in the list}
    if ent_p = sel_p
      then begin                       {this is to be initial selected entry}
        changed := not (gui_entflag_selected_k in ent_p^.flags); {flag on change}
        ent_p^.flags :=                {set this entry as selected}
          ent_p^.flags + [gui_entflag_selected_k];
        end
      else begin                       {this entry will not be initially selected}
        changed := gui_entflag_selected_k in ent_p^.flags; {flag on change}
        ent_p^.flags :=
          ent_p^.flags - [gui_entflag_selected_k];
        end
      ;
    if changed and drawn then begin    {need to update display of this entry ?}
      gui_menu_refresh_entry (menu, ent_p^);
      end;
    shcut := shcut or                  {make true on shortcut key active}
      (ent_p^.shcut <> 0) and          {shortcut key is active for this entry ?}
      ((gui_entflag_selectable_k in ent_p^.flags) or {entry is selectable ?}
      (gui_entflag_vis_k in ent_p^.flags)); {entry is visible ?}
    ent_p := ent_p^.next_p;            {advance to next entry in the menu}
    end;                               {back and process this new entry}
{
*   Other initialization before event loop.
}
  if not drawn then begin              {menu not already drawn ?}
    gui_menu_draw (menu);              {make sure the menu is displayed to user}
    gui_win_xf2d_set (menu.win);       {set 2D transform for menu window ?}
    end;

  nev := 0;                            {init number of events fetched}
{
*   Back here to get and process the next event.
}
event_next:
  rend_set.enter_level^ (0);           {make sure not in graphics mode}
  rend_event_get (ev);                 {get the next event}
  nev := nev + 1;                      {count one more event fetched}
{
*   The code for each event must eventually do one of these things:
*
*     Fall thru or jump to EVENT_NEXT  -  When the event was handled but did not
*       result in a definative selection or cancellation.  We will continue to
*       handle events.
*
*     Jump to SELECTED  -  A definative selection was made with SEL_P pointing
*       to the selected entry.  SEL_P may be NIL to indicate no selection made,
*       but no unused events exist.
*
*     Jump to CANCELLED  -  The menu selection process was cancelled.  This might
*       be due to an explicit user request to cancell, or to an implicit event
*       that we decide cancells the selection.  The event in EV will be pushed
*       back onto the event queue unless EV.EV_TYPE has been set to
*       REND_EV_NONE_K.
}
  case ev.ev_type of                   {what kind of event is this ?}
{
************************************************
*
*   Event POINTER MOTION
}
rend_ev_pnt_move_k: begin
  p1.x := ev.pnt_move.x + 0.5;
  p1.y := ev.pnt_move.y + 0.5;
  rend_get.bxfpnt_2d^ (p1, p2);        {transform pointer coor to window space}
  if                                   {assume event is for someone else ?}
      ( (p2.x < 0.0) or (p2.x > menu.win.rect.dx) or {pointer outside menu window ?}
        (p2.y < 0.0) or (p2.y > menu.win.rect.dy)
        )
      and (not (
        (gui_menflag_canera_k in menu.flags) or {menu stays on abort ?}
        (gui_menflag_candel_k in menu.flags)
        ))
      then begin
    goto cancelled;                    {this event belongs to someone else}
    end;

  gui_menu_entry_pixel (               {find menu entry pointer is now within}
    menu,                              {menu descriptor}
    ev.pnt_move.x, ev.pnt_move.y,      {2DIMI pixel coordinate}
    ent_p);                            {returned pointer to menu entry with pixel}
  if ent_p = nil then goto event_next; {pointer isn't on any menu entry ?}
  if not (gui_entflag_selectable_k in ent_p^.flags) then begin {ent not selectable ?}
    goto event_next;                   {don't change any state}
    end;
  gui_menu_ent_select (menu, sel_p, ent_p); {switch currently selected menu entry}
  end;
{
************************************************
*
*   Event KEY
}
rend_ev_key_k: begin                   {a key just transitioned}
  if not ev.key.down then goto event_next; {ignore key releases}
  kid := gui_key_k_t(ev.key.key_p^.id_user); {make GUI library ID for this key}
  modk := ev.key.modk - [rend_key_mod_shiftlock_k]; {working copy of modifier keys}
  alt := rend_key_mod_alt_k in modk;   {TRUE if ALT modifier active}
  if                                   {this is important event for someone else ?}
      alt and                          {ALT modifier active ?}
      ( (not shcut) or                 {we recognize no shortcut keys ?}
        (not (gui_menflag_alt_k in menu.flags))) {our shortcuts don't use ALT ?}
      then begin
    goto cancelled;                    {this event is for someone else}
    end;

  case kid of                          {which one of our keys is it ?}

gui_key_arrow_up_k: begin              {key UP ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_vert_k: begin              {entries are in vertical list}
      gui_menu_select_prev (menu, sel_p); {select previous menu entry}
      end;
otherwise
    goto cancelled;
    end;
  end;

gui_key_arrow_down_k: begin            {key DOWN ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries are in one horizontal row}
      if                               {pick this entry ?}
          (sel_p <> nil) and then      {an entry is selected ?}
          (gui_entflag_nlevel_k in sel_p^.flags) {brings up another menu level ?}
          then begin
        goto selected;
        end;
      goto cancelled;
      end;
gui_menform_vert_k: begin              {entries are in vertical list}
      gui_menu_select_next (menu, sel_p); {select next menu entry}
      end;
    end;
  end;

gui_key_arrow_left_k: begin            {key LEFT ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries are in one horizontal row}
      gui_menu_select_prev (menu, sel_p); {select previous menu entry}
      end;
gui_menform_vert_k: begin              {entries are in vertical list}
      ev.ev_type := rend_ev_none_k;    {indicate the event got used up}
      cancelid := -2;                  {user wants to go back to previous menu}
      goto cancelled;                  {abort from this menu level}
      end;
    end;
  end;

gui_key_arrow_right_k: begin           {key RIGHT ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries are in one horizontal row}
      gui_menu_select_next (menu, sel_p); {select next menu entry}
      end;
gui_menform_vert_k: begin              {entries are in vericial list}
      if                               {pick this entry ?}
          (sel_p <> nil) and then      {an entry is selected ?}
          (gui_entflag_nlevel_k in sel_p^.flags) {brings up another menu level ?}
          then begin
        goto selected;
        end;
      end;
    end;
  end;

gui_key_esc_k: begin                   {key ESCAPE, abort from this menu level}
  if modk <> [] then goto event_next;
  ev.ev_type := rend_ev_none_k;        {indicate the event got used up}
  goto cancelled;                      {abort from this menu level}
  end;

gui_key_enter_k: begin                 {key ENTER}
  if modk <> [] then goto event_next;
  goto selected;
  end;

gui_key_mouse_left_k: begin            {key LEFT MOUSE BUTTON}
  if modk <> [] then goto event_next;
  gui_menu_entry_pixel (               {find if pixel is within a menu entry}
    menu,                              {menu descriptor}
    ev.key.x, ev.key.y,                {2DIMI pixel coordinate}
    ent_p);                            {returned pointer to menu entry with pixel}
  if ent_p = nil then goto cancelled;  {this mouse click isn't for us}
  if not (gui_entflag_selectable_k in ent_p^.flags) {this entry can't be selected ?}
    then goto event_next;
  gui_menu_ent_select (menu, sel_p, ent_p); {update the curr selected menu entry}
  goto selected;
  end;

gui_key_char_k: begin                  {a regular character key}
  if shcut
    then begin                         {explicit shortcut keys are in use}
      ent_p := menu.first_p;
      while ent_p <> nil do begin      {scan forwards thru menu entries}
        if                             {this is entry selected by shortcut key ?}
            (gui_entflag_selectable_k in ent_p^.flags) and {entry selectable ?}
            (ent_p^.key_p = ev.key.key_p) and {it's the right key ?}
            (ent_p^.mod_req <= modk) and {all required modifiers are present ?}
            (modk * ent_p^.mod_not = []) {no disqualifying modifiers present ?}
            then begin
          gui_menu_ent_select (menu, sel_p, ent_p); {make sure this entry selected}
          goto selected;               {we have final selection}
          end;
        ent_p := ent_p^.next_p;        {advance to next entry in menu}
        end;
      end                              {end of explicit shortcut keys in use case}
    else begin                         {explicit shortcut keys are not in use}
      modk := modk - [rend_key_mod_shift_k]; {ignore SHIFT modifier key}
      if modk <> [] then goto event_next;
      c := gui_event_char (ev);        {get character represented by this key event}
      c := string_upcase_char(c);      {upcase for case-insensitive matching}
      if sel_p = nil                   {set ENT_P at entry to start at}
        then ent_p := menu.first_p
        else ent_p := sel_p;
      e2_p := ent_p;                   {remember what entry we started at}
      while true do begin              {loop around all the menu entries}
        ent_p := ent_p^.next_p;        {advance to next entry in the menu}
        if ent_p = nil then ent_p := menu.first_p;
        if ent_p = e2_p then exit;     {got back to where we started ?}
        if                             {check for key selects this entry}
            (gui_entflag_selectable_k in ent_p^.flags) and {this entry selectable ?}
            (string_upcase_char(ent_p^.name_p^.str[1]) = c) {first char matches key ?}
            then begin
          gui_menu_ent_select (menu, sel_p, ent_p); {select the new entry}
          goto event_next;
          end;
        end;                           {back to try next entry in the menu}
      end                              {end of no explicity shortcut keys case}
    ;
  end;                                 {end of event is character key case}

    end;                               {end of key ID cases}
  end;                                 {end of event KEY case}
{
************************************************
*
*   Event WIPED_RECT
}
rend_ev_wiped_rect_k: begin            {rectangular region needs redraw}
  gui_win_draw (                       {redraw a region}
    menu.win.all_p^.root_p^,           {redraw from the root window down}
    ev.wiped_rect.x,                   {left X}
    ev.wiped_rect.x + ev.wiped_rect.dx, {right X}
    menu.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y - ev.wiped_rect.dy, {bottom Y}
    menu.win.all_p^.root_p^.rect.dy - ev.wiped_rect.y); {top Y}
  end;
{
************************************************
}
otherwise                              {any event type we don't explicitly handle}
    goto cancelled;
    end;                               {end of event type cases}
  goto event_next;                     {back to process next event}
{
*   An entry was selected.  SEL_P is pointing to the selected entry.
}
selected:
  if sel_p = nil then begin            {no selection really made ?}
    ev.ev_type := rend_ev_none_k;      {indicate no unused event for someone else}
    goto cancelled;
    end;
  id := sel_p^.id;                     {pass back ID of selected entry}
  gui_menu_select := true;             {indicate menu entry was selected}


  if gui_menflag_pickdel_k in menu.flags then begin {delete menu on pick ?}
    gui_menu_delete (menu);            {delete the menu}
    sel_p := nil;                      {can't point to entry we just deleted}
    goto leave;
    end;

  if gui_menflag_pickera_k in menu.flags then begin {erase menu on pick ?}
    gui_menu_erase (menu);             {erase the menu}
    goto leave;
    end;

  goto leave;
{
*   No entry was selected because the selection process was terminated for some
*   reason.  If EV contains an event (EV.EV_TYPE not REND_EV_NONE_K), then it
*   is assumed that this event is for someone else and must be pushed back
*   onto the event queue.
}
cancelled:
  gui_menu_select := false;            {indicate no menu entry was selected}
  gui_menu_ent_select (menu, sel_p, nil); {make sure no entry is selected}
  id := cancelid;

  if ev.ev_type <> rend_ev_none_k then begin {we took an event for someone else ?}
    rend_event_push (ev);              {put event back at head of queue}
    if nev <= 1 then begin             {no events were actually processed ?}
      menu.evhan := gui_evhan_notme_k; {indicate unhandled event pushed back}
      end;
    end;

  if gui_menflag_candel_k in menu.flags then begin {delete menu on cancel ?}
    gui_menu_delete (menu);            {delete the menu}
    goto leave;
    end;

  if gui_menflag_canera_k in menu.flags then begin {erase menu on cancel ?}
    gui_menu_erase (menu);             {erase the menu}
    goto leave;
    end;
{
*   Common exit point.  Return values and event state already take care of.
}
leave:
  rend_set.enter_level^ (rend_level);  {restore original graphics mode level}
  end;
