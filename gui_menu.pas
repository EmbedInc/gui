{   Module of routines that manipulate menus.  These routines all take
*   a menu object as their first argument.
}
module gui_menu;
define gui_menu_create;
define gui_menu_setup_top;
define gui_menu_delete;
define gui_menu_place;
define gui_menu_drawable;
define gui_menu_draw;
define gui_menu_clear;
define gui_menu_erase;
define gui_menu_select;
%include 'gui2.ins.pas';
{
********************************************************************************
*
*   Subroutine GUI_MENU_CREATE (MENU, WIN)
*
*   Initialize a menu object.  WIN is the window the menu is eventually to be
*   displayed in.  This routine does no drawing.
*
*   The menu flags will be initialized for a typical drop down menu.  The flags
*   should be changed to the desired configuration immediately after this call.
*   Note that there are wrapper routines, like GUI_MENU_SETUP_TOP, which set the
*   flags for other canned configurations.
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
********************************************************************************
*
*   Subroutine GUI_MENU_SETUP_TOP (MENU)
*
*   Change the flags and other state to make this a "standard" menu for use with
*   the top menu bar.
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
********************************************************************************
*
*   Subroutine GUI_MENU_DELETE (MENU)
*
*   Delete the menu.  The menu object is returned invalid.  If the menu is
*   currently displayed, it will be erased.  Nothing is done if the menu was
*   previously deleted.
}
procedure gui_menu_delete (            {delete menu if not already deleted}
  in out  menu: gui_menu_t);           {returned deleted}
  val_param;

begin
  if menu.mem_p <> nil then begin      {menu exists ?}
    if gui_menflag_window_k in menu.flags then begin {private window exists for menu ?}
      gui_win_delete (menu.win);       {erase and delete the window}
      end;
    util_mem_context_del (menu.mem_p); {delete dynamic memory context for this menu}
    end;
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_PLACE (MENU, ULX, ULY)
*
*   Determine the final placement and any other configuration details required
*   to draw the menu.  This call makes the menu drawable.
*
*   ULX,ULY is the preferred upper left coordinate of the menu.  This is the
*   outer coordinate of the border, if any.  The preferred coordinate will be
*   used if possible, but the menu may be moved to better fit it within the
*   window.
*
*   The current text control parameters will be saved and used to draw the menu
*   later.
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
*   MWIDE and MHIGH are the sizes required to draw the entire menu.  Now
*   determine the placement of the menu within the parent window and create our
*   private window that will be completely filled with the menu.
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
********************************************************************************
*
*   Local subroutine GUI_MENU_DRAW_WIN (WIN, MENU)
*
*   This is the window draw routine for menu windows.  It is called by the GUI
*   library when appropriate in response to redraw requests.
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
    gui_menu_ent_draw (menu, e_p^);    {draw this entry}
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
********************************************************************************
*
*   Subroutine GUI_MENU_DRAWABLE (MENU)
*
*   Make the menu drawable.  The state will be set up such that the menu will
*   automatically be drawn when appropriate.  The menu will not be explicitly
*   drawn by this routine.
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
********************************************************************************
*
*   Subroutine GUI_MENU_DRAW (MENU)
*
*   Draw the menu.  This will also set up the redraw state so that the menu will
*   automatically be redrawn as necessary.  This routine does nothing if the
*   menu is already drawable.
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
********************************************************************************
*
*   Subroutine GUI_MENU_CLEAR (MENU)
*
*   De-select any selected entries of the menu, and redraw the menu as needed.
*   The overall effect is to "clear" all selected entries.
}
procedure gui_menu_clear (             {de-select all selected entries of menu}
  in out  menu: gui_menu_t);           {menu to clear selected entries of}
  val_param;

var
  ent_p: gui_menent_p_t;               {pointer to current menu entry}

begin
  ent_p := menu.first_p;               {init to first entry in the menu}
  while ent_p <> nil do begin          {scan the list of entries}
    if gui_entflag_selected_k in ent_p^.flags then begin {this entry selected ?}
      ent_p^.flags := ent_p^.flags     {de-select this entry}
        - [gui_entflag_selected_k];
      gui_menu_ent_refresh (menu, ent_p^); {redraw this entry}
      end;
    ent_p := ent_p^.next_p;            {to next entry in this menu}
    end;                               {back to check this new entry}
  end;
{
********************************************************************************
*
*   Subroutine GUI_MENU_ERASE (MENU)
*
*   Erase the menu from the display.  This will cause the pixels covered by the
*   menu to be redrawn to what was underneath the menu.
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
*   If no selection is made, the function returns FALSE, SEL_P is returned NIL,
*   and ID is set to one of:
*
*     GUI_MENSEL_CANCEL_K
*
*       Menu selection was cancelled by the user.
*
*     GUI_MENSEL_PREV_K
*
*       Menu selection was cancelled by the user, and the user wants to go back
*       to the previous menu.
*
*     GUI_MENSEL_RESIZE_K
*
*       The window the menu was in was resized and the menu therefore needs to
*       be redrawn.  The user may still be willing to continue with menu
*       selection.
*
*   The EVHAN field in MENU is set according to how the RENDlib events were
*   handled.
}
function gui_menu_select (             {get user menu selection}
  in out  menu: gui_menu_t;            {menu object}
  out     id: sys_int_machine_t;       {1-N selected entry ID or GUI_MENSEL_xxx_K}
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
  gui_menu_select := false;            {init to no selection made}
  cancelid := gui_mensel_cancel_k;     {init to generic cancel reason}
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
*   Determine which entry, if any, is to be initially selected.  SEL_P will be
*   set pointing to the initial selected entry.  ENT_P is pointing to the first
*   selected entry, and E2_P is pointing to the first selectable entry.
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
*   SEL_P is pointing to the entry that is to be initially selected.  SEL_P may
*   be NIL to indicate no entry is initially selected.  Now loop thru all the
*   entries and set their state accordingly.
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
      gui_menu_ent_refresh (menu, ent_p^);
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
*     Jump to CANCELLED  -  The menu selection process was cancelled.  This
*       might be due to an explicit user request to cancell, or to an implicit
*       event that we decide cancells the selection.  The event in EV will be
*       pushed back onto the event queue unless EV.EV_TYPE has been set to
*       REND_EV_NONE_K.
*
*   SEL_P is maintained pointing to the currently selected menu entry.
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

  gui_menu_ent_pixel (                 {find menu entry pointer is now within}
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
      gui_menu_ent_prev (menu, sel_p); {select previous menu entry}
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
      gui_menu_ent_next (menu, sel_p); {select next menu entry}
      end;
    end;
  end;

gui_key_arrow_left_k: begin            {key LEFT ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries are in one horizontal row}
      gui_menu_ent_prev (menu, sel_p); {select previous menu entry}
      end;
gui_menform_vert_k: begin              {entries are in vertical list}
      ev.ev_type := rend_ev_none_k;    {indicate the event got used up}
      cancelid := gui_mensel_prev_k;   {user wants to go back to previous menu}
      goto cancelled;                  {abort from this menu level}
      end;
    end;
  end;

gui_key_arrow_right_k: begin           {key RIGHT ARROW}
  if modk <> [] then goto event_next;
  case menu.form of                    {what is menu layout format ?}
gui_menform_horiz_k: begin             {entries are in one horizontal row}
      gui_menu_ent_next (menu, sel_p); {select next menu entry}
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
  gui_menu_ent_pixel (                 {find if pixel is within a menu entry}
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
rend_ev_wiped_resize_k: begin          {window size changed}
  id := gui_mensel_resize_k;           {cancelled due to parent window resize}
  sel_p := nil;                        {indicate no selection made}
  rend_event_push (ev);                {put WIPED_RESIZE event back on queue}
  menu.evhan := gui_evhan_notme_k;     {indicate unhandled event pushed back}
  goto leave;                          {leave without changing curr menu selection}
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
*   reason.  If EV contains an event (EV.EV_TYPE not REND_EV_NONE_K), then it is
*   assumed that this event is for someone else and must be pushed back onto the
*   event queue.
}
cancelled:
  gui_menu_ent_select (menu, sel_p, nil); {de-select current entry, if any}
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
