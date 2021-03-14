{   Public include file for the GUI library.  This library contains
*   graphical user interface services layered on RENDlib.
}
const
  gui_childblock_size_k = 8;           {number of child windows per list block}

type
  gui_ixy_t = record                   {one integer X,Y coordinate}
    x, y: sys_int_machine_t;
    end;

  gui_irect_t = record                 {integer pixel axis aligned rectangle}
    x, y: sys_int_machine_t;           {low corner pixel just within rectangle}
    dx, dy: sys_int_machine_t;         {rectangle size in pixels}
    end;

  gui_rect_t = record                  {rectangle within a GUI window}
    llx, lly: real;                    {lower left rectangle corner}
    dx, dy: real;                      {rectangle size}
    end;

  gui_cliprect_t = record              {FP clip rectangle}
    lx, rx: real;                      {left and right edges}
    by, ty: real;                      {bottom and top edges}
    end;

  gui_win_p_t = ^gui_win_t;            {pointer to window object}

  gui_selres_k_t = (                   {result of user selection process}
    gui_selres_perf_k,                 {valid selection, action performed}
    gui_selres_prev_k,                 {user wants to go to previous level of choices}
    gui_selres_canc_k);                {explicit user cancel}

  gui_evhan_k_t = (                    {event handler completion codes}
    gui_evhan_none_k,                  {no events processed}
    gui_evhan_did_k,                   {at least one event, all handled}
    gui_evhan_notme_k);                {last event not for this win, pushed back}

  gui_evhan_p_t = ^function (          {event handler for a GUI window}
    in      win_p: gui_win_p_t;        {pointer to window object to handle event for}
    in      app_p: univ_ptr)           {pointer to arbitrary application data}
    :gui_evhan_k_t;                    {event handler completion code}
    val_param;

  gui_draw_p_t = ^procedure (          {routine to redraw window contents}
    in      win_p: gui_win_p_t;        {pointer to window object}
    in      app_p: univ_ptr);          {pointer to arbitrary application data}
    val_param;

  gui_delete_p_t = ^procedure (        {routine called before window deleted}
    in      win_p: gui_win_p_t;        {pointer to window object}
    in      app_p: univ_ptr);          {pointer to arbitrary application data}
    val_param;

  gui_childblock_p_t = ^gui_childblock_t;
  gui_childblock_t = record            {one block of window child list}
    prev_p: gui_childblock_p_t;        {pnt to previous list block, NIL: this is 1st}
    child_p_ar:                        {list of child pointers}
      array[1..gui_childblock_size_k] of gui_win_p_t;
    next_p: gui_childblock_p_t;        {pnt to next block in list, NIL = none}
    end;

  gui_win_clip_frame_t = record        {window object clip stack frame}
    rect: gui_cliprect_t;              {draw in, clip out rectangle}
    end;
  gui_win_clip_frame_p_t = ^gui_win_clip_frame_t;

  gui_wdraw_k_t = (                    {window drawing management flags}
    gui_wdraw_done_k);                 {done drawing this window}
  gui_wdraw_t = set of gui_wdraw_k_t;  {all the flags in one set}

  gui_win_all_t = record               {info common to all windows with same root}
    root_p: gui_win_p_t;               {pointer to root window}
    rend_dev: rend_dev_id_t;           {RENDlib device ID for this set of windows}
    rend_clip: rend_clip_2dim_handle_t; {RENDlib clip handle}
    draw_high_p: gui_win_p_t;          {highest window allowed to draw}
    draw_low_p: gui_win_p_t;           {first window too low to allow draw}
    drawing: boolean;                  {TRUE when drawing in progress}
    low_reached: boolean;              {lowest draw window has been drawn}
    end;
  gui_win_all_p_t = ^gui_win_all_t;

  gui_win_t = record                   {object for one GUI library window}
    parent_p: gui_win_p_t;             {pointer to parent window, NIL = this is root}
    rect: gui_irect_t;                 {rectangle within parent win}
    mem_p: util_mem_context_p_t;       {handle for mem owned by this window}
    all_p: gui_win_all_p_t;            {pnt to info shared by all windows this root}
    pos: gui_ixy_t;                    {window UL on REND device, 2DIMI coordinates}
    n_child: sys_int_machine_t;        {number of child windows}
    childblock_first_p: gui_childblock_p_t; {pnt to first child list block of chain}
    childblock_last_p: gui_childblock_p_t; {pnt to child block for last child entry}
    child_ind: sys_int_machine_t;      {block index of last child, 0 for no children}
    clip_rect: gui_cliprect_t;         {app non-stacked clip rectangle}
    stack_clip: util_stack_handle_t;   {handle to nested clip rectangles stack}
    frame_clip_p: gui_win_clip_frame_p_t; {pointer to top STACK_CLIP frame}
    clip: gui_irect_t;                 {total resulting drawable region, 2DIMI}
    draw: gui_draw_p_t;                {pointer to redraw routine, NIL = none}
    delete: gui_delete_p_t;            {cleanup rout called just before win delete}
    evhan: gui_evhan_p_t;              {pointer to event handler, NIL = none}
    app_p: univ_ptr;                   {pointer arbitrary application data}
    not_clipped: boolean;              {TRUE if at least one pixel drawable}
    draw_flag: gui_wdraw_t;            {set of flags used for redraw management}
    end;

  gui_key_k_t = sys_int_machine_t (    {our IDs for various system keys}
    gui_key_arrow_up_k = 1,            {up arrow}
    gui_key_arrow_down_k,              {down arrow}
    gui_key_arrow_left_k,              {left arrow}
    gui_key_arrow_right_k,             {right arrow}
    gui_key_home_k,                    {key to jump to left edge}
    gui_key_end_k,                     {key to jump to right edge}
    gui_key_del_k,                     {DELETE character to right of cursor key}
    gui_key_mouse_left_k,              {left mouse button}
    gui_key_mouse_mid_k,               {middle mouse button}
    gui_key_mouse_right_k,             {right mouse button}
    gui_key_tab_k,                     {TAB key}
    gui_key_esc_k,                     {ESCAPE key}
    gui_key_enter_k,                   {ENTER key}
    gui_key_char_k);                   {remaining keys that map to single characters}

  gui_entflag_k_t = (                  {flags for menu entries}
    gui_entflag_vis_k,                 {this entry is visible}
    gui_entflag_selectable_k,          {this entry is selectable}
    gui_entflag_selected_k,            {this entry is currently selected}
    gui_entflag_nlevel_k);             {this entry brings up another menu level}
  gui_entflags_t = set of gui_entflag_k_t; {all the flags in one word}

  gui_menent_p_t = ^gui_menent_t;
  gui_menent_t = record                {descriptor for one menu entry}
    prev_p: gui_menent_p_t;            {points to previous menu entry}
    next_p: gui_menent_p_t;            {points to next menu entry}
    name_p: string_var_p_t;            {points to string to display to user}
    id: sys_int_machine_t;             {ID returned when this entry selected}
    shcut: sys_int_machine_t;          {name char num for shortcut key, 0 = none}
    xl, xr: real;                      {left/right X limits for button}
    yb, yt: real;                      {bottom/top Y limits for button}
    xtext: real;                       {left edge X of text string}
    key_p: rend_key_p_t;               {pointer to RENDlib descriptor for shcut key}
    mod_req: rend_key_mod_t;           {required modifiers for shortcut key}
    mod_not: rend_key_mod_t;           {modifiers not allowed for shortcut key}
    flags: gui_entflags_t;             {set of flags for this entry}
    end;

  gui_menform_k_t = (                  {different menu layout formats}
    gui_menform_horiz_k,               {horizontal, like top menu bar}
    gui_menform_vert_k);               {vertical, like drop down menu}

  gui_menflag_k_t = (                  {independant flags governing a menu}
    gui_menflag_canera_k,              {erase menu when menu cancelled}
    gui_menflag_candel_k,              {delete menu when menu cancelled}
    gui_menflag_pickera_k,             {erase menu when entry picked}
    gui_menflag_pickdel_k,             {delete menu when entry picked}
    gui_menflag_alt_k,                 {assume shortcut keys require ALT modifier}
    gui_menflag_border_k,              {draw border around menu when displayed}
    gui_menflag_fill_k,                {fill parent window to LR when menu drawn}
    gui_menflag_sel1_k,                {init to first selectable entry on MENU_SELECT}
    gui_menflag_selsel_k,              {init to first selected entry on MENU_SELECT}
    {
    *   The following flags must not be touched by applications.
    }
    gui_menflag_window_k);             {display config determined, window exists}
  gui_menflags_t = set of gui_menflag_k_t;

  gui_menu_t = record                  {object for one GUI library menu}
    mem_p: util_mem_context_p_t;       {pnt to mem context private to this menu}
    parent_p: gui_win_p_t;             {pointer to parent window}
    win: gui_win_t;                    {private window for this menu}
    col_fore: rend_rgb_t;              {normal foreground color}
    col_back: rend_rgb_t;              {normal background color}
    col_fore_sel: rend_rgb_t;          {foreground color for selected entry}
    col_back_sel: rend_rgb_t;          {background color for selected entry}
    first_p: gui_menent_p_t;           {points to first menu entry in chain}
    last_p: gui_menent_p_t;            {points to last menu entry in chain}
    tparm: rend_text_parms_t;          {text parameters for drawing the menu}
    flags: gui_menflags_t;             {set of individual flags}
    form: gui_menform_k_t;             {menu layout format}
    evhan: gui_evhan_k_t;              {event useage result from last SELECT}
    end;
  gui_menu_p_t = gui_menu_t;

  gui_mmsg_t = record                  {object for reading menu entries message}
    conn: file_conn_t;                 {descriptor to message connection}
    open: boolean;                     {TRUE if CONN is open}
    end;

  gui_estrf_k_t = (                    {individual flags for edit string object}
    gui_estrf_orig_k,                  {enabled original unedited string mode}
    gui_estrf_curs_k);                 {draw cursor}
  gui_estrf_t = set of gui_estrf_k_t;

  gui_estr_t = record                  {low level edit string object}
    win: gui_win_t;                    {private window for all the drawing}
    tparm: rend_text_parms_t;          {saved copy of text control parameters}
    lxh: real;                         {string left edge X home position}
    lx: real;                          {current string left edge X}
    by: real;                          {bottom edge Y of character cells}
    bc: real;                          {bottom Y of cursor}
    curs: real;                        {cursor X}
    curswh: real;                      {half width of widest part of cursor}
    col_bn: rend_rgb_t;                {normal background color}
    col_fn: rend_rgb_t;                {normal foreground color}
    col_cn: rend_rgb_t;                {normal cursor color}
    col_bo: rend_rgb_t;                {background color for original unedited text}
    col_fo: rend_rgb_t;                {foreground color for original unedited text}
    col_co: rend_rgb_t;                {cursor color for original unedited text}
    str: string_var256_t;              {the string being edited}
    ind: string_index_t;               {STR index of where next char goes}
    flags: gui_estrf_t;                {option flags}
    orig: boolean;                     {TRUE on draw string is original unedited}
    cmoved: boolean;                   {TRUE if cursor position changed}
    end;
  gui_estr_p_t = ^gui_estr_t;

  gui_enter_t = record                 {object for getting string response from user}
    win: gui_win_t;                    {private window for all the drawing}
    estr: gui_estr_t;                  {low level edit string object}
    tparm: rend_text_parms_t;          {text parameters for drawing prompts, etc}
    prompt: string_list_t;             {list of lines to prompt user for input}
    err: string_var256_t;              {error message string}
    e1, e2: real;                      {bottom and top Y of edit string area}
    end;
  gui_enter_p_t = gui_enter_t;

  gui_msgtype_k_t = (                  {types of user messages}
    gui_msgtype_info_k,                {informational, user must confirm}
    gui_msgtype_infonb_k,              {info text only, no buttons, user must cancel}
    gui_msgtype_yesno_k,               {user must make yes/no choice}
    gui_msgtype_todo_k,                {user must perform some action}
    gui_msgtype_prob_k,                {problem occurred, can continue}
    gui_msgtype_err_k);                {error occurred, must abort operation}

  gui_msgresp_k_t = (                  {user response to message}
    gui_msgresp_yes_k,                 {affirmative: yes, OK, continue, etc}
    gui_msgresp_no_k,                  {negative: no, stop, etc}
    gui_msgresp_abort_k);              {abort button or other event caused abort}

  gui_tick_p_t = ^gui_tick_t;
  gui_tick_t = record                  {info about one axis tick mark}
    next_p: gui_tick_p_t;              {pointer to next tick in chain, NIL = last}
    val: real;                         {axis value at this tick mark}
    level: sys_int_machine_t;          {0 is major tick, higher values more minor}
    lab: string_var32_t;               {label string, may be empty}
    end;
{
******************************
*
*   Routines
}
procedure gui_enter_create (           {create user string entry object}
  out     enter: gui_enter_t;          {newly created enter object}
  in out  parent: gui_win_t;           {window to draw enter object within}
  in      prompt: univ string_var_arg_t; {message to prompt user for input with}
  in      seed: univ string_var_arg_t); {string to seed user input with}
  val_param; extern;

procedure gui_enter_create_msg (       {create enter string object from message}
  out     enter: gui_enter_t;          {newly created enter object}
  in out  parent: gui_win_t;           {window to draw enter object within}
  in      seed: univ string_var_arg_t; {string to seed user input with}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param; extern;

procedure gui_enter_delete (           {delete user string entry object}
  in out  enter: gui_enter_t);         {object to delete}
  val_param; extern;

function gui_enter_get (               {get string entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  in out  resp: univ string_var_arg_t) {response string from user, len = 0 on cancel}
  :boolean;                            {FALSE with ENTER deleted or cancelled}
  val_param; extern;

function gui_enter_get_fp (            {get floating point value entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  out     fp: real)                    {returned FP value, unchanged on cancel}
  :boolean;                            {FALSE with ENTER deleted on cancelled}
  val_param; extern;

function gui_enter_get_int (           {get integer value entered by user}
  in out  enter: gui_enter_t;          {user string entry object}
  in      err: univ string_var_arg_t;  {error message string}
  out     i: sys_int_machine_t)        {returned integer value, unchanged on cancel}
  :boolean;                            {FALSE with ENTER deleted on cancelled}
  val_param; extern;

procedure gui_estr_create (            {create edit string object}
  out     estr: gui_estr_t;            {newly created object}
  in out  parent: gui_win_t;           {window to draw object within}
  in      lx, rx: real;                {left and right edges within parent window}
  in      by, ty: real);               {top and bottom edges within parent window}
  val_param; extern;

procedure gui_estr_delete (            {delete edit string object}
  in out  estr: gui_estr_t);           {object to delete}
  val_param; extern;

procedure gui_estr_edit (              {edit string until unhandled event}
  in out  estr: gui_estr_t);           {edit string object}
  val_param; extern;

function gui_estr_edit1 (              {perform one edit string operation}
  in out  estr: gui_estr_t)            {edit string object}
  :boolean;                            {FALSE on encountered event not handled}
  val_param; extern;

procedure gui_estr_make_seed (         {make current string the seed string}
  in out  estr: gui_estr_t);           {edit string object}
  val_param; extern;

procedure gui_estr_set_string (        {init string to be edited}
  in out  estr: gui_estr_t;            {edit string object}
  in      str: univ string_var_arg_t;  {seed string}
  in      curs: string_index_t;        {char position where next input char goes}
  in      seed: boolean);              {TRUE if treat as seed string before mods}
  val_param; extern;

procedure gui_events_init_key;         {set up RENDlib key events for curr device}
  extern;

function gui_event_char (              {get char from character key event}
  in      event: rend_event_t)         {RENDlib event descriptor for key event}
  :char;                               {character, NULL for non-character event}
  val_param; extern;

function gui_key_alpha_id (            {find RENDlib alphanumeric key ID}
  in      c: char)                     {character to find key for, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param; extern;

function gui_key_name_id (             {find RENDlib key ID from key cap name}
  in      name: univ string_var_arg_t) {key name to find, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param; extern;

function gui_key_names_id (            {like GUI_KEY_NAME_ID except plain string nam}
  in      name: string)                {key name to find, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param; extern;

procedure gui_menu_create (            {create and initialize menu object}
  out     menu: gui_menu_t;            {returned initialized menu object}
  in out  win: gui_win_t);             {window menu to appear in later}
  val_param; extern;

procedure gui_menu_delete (            {delete menu object, reclaim resources}
  in out  menu: gui_menu_t);           {returned invalid}
  val_param; extern;

procedure gui_menu_draw (              {draw menu}
  in out  menu: gui_menu_t);           {menu object}
  val_param; extern;

procedure gui_menu_drawable (          {make menu drawable, add to redraw list}
  in out  menu: gui_menu_t);           {menu object}
  val_param; extern;

procedure gui_menu_ent_add (           {add new entry to end of menu}
  in out  menu: gui_menu_t;            {menu object}
  in      name: univ string_var_arg_t; {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID returned when this entry picked}
  val_param; extern;

procedure gui_menu_ent_add_str (       {add entry to menu, takes regular string}
  in out  menu: gui_menu_t;            {menu object}
  in      name: string;                {name to display to user for this choice}
  in      shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  in      id: sys_int_machine_t);      {ID returned when this entry picked}
  val_param; extern;

procedure gui_menu_ent_next (          {select next sequential selectable menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param; extern;

procedure gui_menu_ent_pixel (         {find menu entry containing a pixel}
  in out  menu: gui_menu_t;            {menu object}
  in      x, y: sys_int_machine_t;     {pixel coordinate to test for}
  out     ent_p: gui_menent_p_t);      {returned pointer to selected entry or NIL}
  val_param; extern;

procedure gui_menu_ent_prev (          {select previous sequential selectable entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t);      {pointer to selected menu entry}
  val_param; extern;

procedure gui_menu_ent_refresh (       {refresh the graphics of a menu entry}
  in out  menu: gui_menu_t;            {menu containing entry}
  in      ent: gui_menent_t);          {descriptor of entry to draw}
  val_param; extern;

procedure gui_menu_ent_select (        {select new menu entry}
  in out  menu: gui_menu_t;            {menu object}
  in out  sel_p: gui_menent_p_t;       {pointer to old selected entry, updated}
  in      new_p: gui_menent_p_t);      {pointer to new entry to select}
  val_param; extern;

procedure gui_menu_erase (             {erase menu, refresh what was underneath}
  in out  menu: gui_menu_t);           {menu object}
  val_param; extern;

procedure gui_menu_place (             {set final menu placement and make drawable}
  in out  menu: gui_menu_t;            {menu object}
  in      ulx, uly: real);             {preferred upper left corner of whole menu}
  val_param; extern;

function gui_menu_select (             {get user menu selection}
  in out  menu: gui_menu_t;            {menu object}
  out     id: sys_int_machine_t;       {selected entry ID, -1 cancelled, -2 prev}
  out     sel_p: gui_menent_p_t)       {pnt to sel entry, NIL on cancel or delete}
  :boolean;                            {TRUE on selection made, FALSE on cancelled}
  val_param; extern;

procedure gui_menu_setup_top (         {convenience wrapper for top menu bar}
  in out  menu: gui_menu_t);           {menu object}
  val_param; extern;

procedure gui_message (                {low level routine to display message to user}
  in out  parent: gui_win_t;           {window to display message box within}
  in      mstr: univ string_var_arg_t; {string to display, will be wrapped at blanks}
  in      col_back: rend_rgb_t;        {background color}
  in      col_fore: rend_rgb_t;        {foreground (text) color}
  in      butt_true: univ string_var_arg_t; {text for TRUE button, may be empty}
  in      butt_false: univ string_var_arg_t; {text for FALSE button, may be empty}
  in      butt_abort: univ string_var_arg_t; {text for ABORT button, may be empty}
  out     resp: gui_msgresp_k_t);      {YES/NO/ABORT response from user}
  val_param; extern;

function gui_message_msg (             {display message and get user response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t)  {number of parameters in PARMS}
  :gui_msgresp_k_t;                    {YES/NO/ABORT response from user}
  val_param; extern;

function gui_message_msg_stat (        {display err and user message, get response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      stat: sys_err_t;             {error status code}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t)  {number of parameters in PARMS}
  :gui_msgresp_k_t;                    {YES/NO/ABORT response from user}
  val_param; extern;

function gui_message_str (             {display message and get user response}
  in out  parent: gui_win_t;           {window to display message box within}
  in      msgtype: gui_msgtype_k_t;    {overall type or intent of message}
  in      mstr: univ string_var_arg_t) {string to display, will be wrapped at blanks}
  :gui_msgresp_k_t;                    {YES/NO/ABORT response from user}
  val_param; extern;

procedure gui_mmsg_close (             {close connection to menu entries message}
  in out  mmsg: gui_mmsg_t);           {menu entries message object}
  val_param; extern;

procedure gui_mmsg_init (              {init for reading a menu entries message}
  out     mmsg: gui_mmsg_t;            {returned menu entries message object}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param; extern;

function gui_mmsg_next (               {return parameters for next menu entry}
  in out  mmsg: gui_mmsg_t;            {menu entries message object}
  in out  name: univ string_var_arg_t; {name to display to user for this choice}
  out     shcut: string_index_t;       {NAME index for shortcut key, 0 = none}
  out     id: sys_int_machine_t)       {ID returned when this entry picked}
  :boolean;                            {TRUE on got entry info, closed on FALSE}
  val_param; extern;

procedure gui_string_wrap (            {wrap string into multiple lines}
  in      str: univ string_var_arg_t;  {input string}
  in      wide: real;                  {width to wrap to, uses curr RENDlib tparms}
  in out  list: string_list_t);        {insert at current string position}
  val_param; extern;

procedure gui_ticks_make (             {create tick marks with proper spacing}
  in      vmin, vmax: real;            {range of axis values to make tick marks for}
  in      wid: real;                   {RENDlib TXDRAW space VMIN to VMAX distance}
  in      horiz: boolean;              {TRUE = labels side by side, not stacked}
  in out  mem: util_mem_context_t;     {parent context for any new memory}
  out     first_p: gui_tick_p_t);      {will point to start of new tick marks chain}
  val_param; extern;

procedure gui_win_alloc_static (       {allocate static mem deleted on win delete}
  in out  win: gui_win_t;              {window object}
  in      size: sys_int_adr_t;         {amount of memory to allocate}
  out     p: univ_ptr);                {returned pointing to new memory}
  val_param; extern;

procedure gui_win_child (              {create child window}
  out     win: gui_win_t;              {returned child window object}
  in out  parent: gui_win_t;           {object for parent window}
  in      x, y: real;                  {a child window corner within parent space}
  in      dx, dy: real);               {child window dispacement from corner}
  val_param; extern;

function gui_win_clip (                {set window clip region and update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coordinates}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param; extern;

procedure gui_win_clipto (             {clip to win, use outside window draw only}
  in out  win: gui_win_t);             {window to set clip coor to}
  val_param; extern;

procedure gui_win_clip_pop (           {pop clip region from stack, update RENDlib}
  in out  win: gui_win_t);             {window object}
  val_param; extern;

function gui_win_clip_push (           {push clip region onto stack, update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coor, GUI window space}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param; extern;

function gui_win_clip_push_2d (        {push clip region onto stack, update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coor, RENDlib 2D space}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param; extern;

procedure gui_win_delete (             {delete a window and all its children}
  in out  win: gui_win_t);             {object for window to delete}
  val_param; extern;

procedure gui_win_draw (               {draw window contents}
  in out  win: gui_win_t;              {object for window to draw contents of}
  in      lx, rx: real;                {left and right redraw region limits}
  in      by, ty: real);               {bottom and top redraw region limits}
  val_param; extern;

procedure gui_win_draw_all (           {draw entire window contents}
  in out  win: gui_win_t);             {object for window to draw contents of}
  val_param; extern;

procedure gui_win_draw_behind (        {draw what is behind a window}
  in out  win: gui_win_t;              {object for window to draw behind of}
  in      lx, rx: real;                {left and right redraw region limits}
  in      by, ty: real);               {bottom and top redraw region limits}
  val_param; extern;

procedure gui_win_erase (              {draw what is behind entire window}
  in out  win: gui_win_t);             {object for window to draw behind of}
  val_param; extern;

function gui_win_evhan (               {handle events for a window}
  in out  win: gui_win_t;              {window to handle events for}
  in      loop: boolean)               {keep handling events as long as possible}
  :gui_evhan_k_t;                      {event handler completion code}
  val_param; extern;

procedure gui_win_get_app_pnt (        {get pointer to application private data}
  in out  win: gui_win_t;              {window object}
  out     app_p: univ_ptr);            {returned pointer to arbitrary app data}
  val_param; extern;

procedure gui_win_resize (             {resize and move a window}
  in out  win: gui_win_t;              {window object}
  in      x, y: real;                  {window corner within parent window}
  in      dx, dy: real);               {displacement from the corner at X,Y}
  val_param; extern;

procedure gui_win_root (               {create root window on curr RENDlib device}
  out     win: gui_win_t);             {returned window object}
  val_param; extern;

procedure gui_win_set_app_pnt (        {set pointer to application private data}
  in out  win: gui_win_t;              {window object}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; extern;

procedure gui_win_set_delete (         {set window's delete cleanup routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_delete_p_t); {pointer to window's new cleanup routine}
  val_param; extern;

procedure gui_win_set_draw (           {set window's draw routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_draw_p_t);  {pointer to window's new draw routine}
  val_param; extern;

procedure gui_win_set_evhan (          {set window's event handler routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_evhan_p_t); {pointer to window's new event handler}
  val_param; extern;

procedure gui_win_tofront (            {make last child in parent's child list}
  in out  win: gui_win_t);             {window object}
  val_param; extern;

procedure gui_win_xf2d_set (           {set standard 2D coordinate space for window}
  in out  win: gui_win_t);             {window object}
  val_param; extern;
