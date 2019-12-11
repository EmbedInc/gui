{   Module of simple window manipulation routines.  These routines all take
*   a window object as their first argument.
}
module gui_win;
define gui_win_resize;
define gui_win_root;
define gui_win_child;
define gui_win_clipto;
define gui_win_clip;
define gui_win_clip_push;
define gui_win_clip_push_2d;
define gui_win_clip_pop;
define gui_win_delete;
define gui_win_xf2d_set;
define gui_win_draw;
define gui_win_draw_all;
define gui_win_draw_behind;
define gui_win_erase;
define gui_win_alloc_static;
define gui_win_set_app_pnt;
define gui_win_get_app_pnt;
define gui_win_set_draw;
define gui_win_set_delete;
define gui_win_set_evhan;
define gui_win_tofront;
%include 'gui2.ins.pas';

const
  mem_pool_size_k = 8192;              {size of window memory context fixed pools}
  mem_chunk_size_k =                   {max size allowed to allocate from fixed pool}
    mem_pool_size_k div 8;
  stack_block_size_k = 512;            {stack mem allocation block size}

{
*************************************************************************
*
*   Subroutine GUI_WIN_CLIPTO (WIN)
*
*   Set the GUI RENDlib clip state for this window set to the window WIN.
*
*   *** WARNING ***
*   This routine must *never* be called from inside a window draw routine.
*   Use CLIP, CLIP_PUSH, and CLIP_POP inside window draw routines.
}
procedure gui_win_clipto (             {clip to win, use outside window draw only}
  in out  win: gui_win_t);             {window to set clip coor to}
  val_param;

begin
  rend_set.clip_2dim^ (                {set clip rectangle to whole window}
    win.all_p^.rend_clip,              {RENDlib clip window handle}
    win.pos.x, win.pos.x + win.rect.dx, {left and right limits}
    win.pos.y, win.pos.y + win.rect.dy, {top and bottom limits}
    true);                             {draw inside, clip outside}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CLIP_COMPUTE (WIN)
*
*   Compute the resulting clip state, taking into account the stacked clip
*   state and the current app clipping region.  This routine updates
*   the following fields:
*
*   CLIP  -  Final resulting drawable region, RENDlib 2DIMI coordinates.
*   NOT_CLIPPED  -  TRUE if at least one pixel center is not clipped.
}
procedure gui_win_clip_compute (       {compute resulting drawable clip region}
  in out  win: gui_win_t);             {window object}
  val_param; internal;

var
  ilx, irx, iby, ity: sys_int_machine_t; {last pixel coor within draw area}

begin
{
*   Make window pixel coordinates of draw region edges.
}
  ilx := trunc(max(win.frame_clip_p^.rect.lx, win.clip_rect.lx) + 0.5);
  irx := trunc(min(win.frame_clip_p^.rect.rx, win.clip_rect.rx) - 0.5);
  iby := trunc(max(win.frame_clip_p^.rect.by, win.clip_rect.by) + 0.5);
  ity := trunc(min(win.frame_clip_p^.rect.ty, win.clip_rect.ty) - 0.5);
{
*   Translate to RENDlib device coordinates.
}
  ilx := win.pos.x + ilx;
  irx := win.pos.x + irx;
  iby := win.pos.y + win.rect.dy - 1 - iby;
  ity := win.pos.y + win.rect.dy - 1 - ity;
{
*   Fill in CLIP field with RENDlib device 2DIM coordinates.
}
  win.clip.x := ilx;
  win.clip.y := ity;
  win.clip.dx := max(0, irx - ilx + 1);
  win.clip.dy := max(0, iby - ity + 1);

  win.not_clipped := (win.clip.dx > 0) and (win.clip.dy > 0);
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_ADJUST (WIN, X, Y, DX, DY)
*
*   This is the low level routine for adjusting a windows size and position.
*   This routine does not handle display updates.  WIN must not be a root
*   window.
}
procedure gui_win_adjust (             {resize and move a window}
  in out  win: gui_win_t;              {window object}
  in      x, y: real;                  {window corner within parent window}
  in      dx, dy: real);               {displacement from the corner at X,Y}
  val_param; internal;

var
  pos: gui_win_childpos_t;             {position into child window list}
  lx, rx, by, ty: real;                {new window edge coordinates within parent}
  ilx, irx, iby, ity: sys_int_machine_t; {integer window edges}

begin
  if dx >= 0.0
    then begin                         {window extends right from corner point}
      lx := x;
      rx := x + dx;
      end
    else begin                         {window extends left from corner point}
      lx := x + dx;
      rx := x;
      end
    ;
  if dy >= 0.0
    then begin                         {window extends up from corner point}
      by := y;
      ty := y + dy;
      end
    else begin                         {window extends down from corner point}
      by := y + dy;
      ty := y;
      end
    ;
  ilx := max(0, min(win.parent_p^.rect.dx, trunc(lx + 0.5)));
  irx := max(0, min(win.parent_p^.rect.dx, trunc(rx + 0.5)));
  iby := max(0, min(win.parent_p^.rect.dy, trunc(by + 0.5)));
  ity := max(0, min(win.parent_p^.rect.dy, trunc(ty + 0.5)));

  win.rect.x := ilx;                   {set new window position within parent}
  win.rect.dx := irx - ilx;
  win.rect.y := iby;
  win.rect.dy := ity - iby;

  win.pos.x :=                         {update RENDlib 2DIM of window upper left}
    win.parent_p^.pos.x + win.rect.x;
  win.pos.y :=
    win.parent_p^.pos.y + win.parent_p^.rect.dy
    - win.rect.y - win.rect.dy;

  win.clip_rect.lx := 0.0;             {set clip region to whole window}
  win.clip_rect.rx := win.rect.dx;
  win.clip_rect.by := 0.0;
  win.clip_rect.ty := win.rect.dy;
  win.frame_clip_p^.rect := win.clip_rect; {init backstop clip to whole window}

  gui_win_clip_compute (win);          {recompute resulting clip state}

  gui_win_childpos_first (win, pos);   {init position to first window in child list}
  while pos.child_p <> nil do begin    {once for each child window}
    gui_win_adjust (                   {adjust this child window}
      pos.child_p^,                    {window to adjust}
      pos.child_p^.rect.x, pos.child_p^.rect.y, {bottom left corner}
      pos.child_p^.rect.dx, pos.child_p^.rect.dy); {displacement to upper right}
    gui_win_childpos_next (pos);       {advance to next child in list}
    end;                               {back to adjust this next child window}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CREATE (WIN)
*
*   This is the raw window object create routine.  All other routines that
*   create a window object call this routine as part of their operation.
*
*   The caller must previously fill in the following fields:
*
*     PARENT_P  -  Pointer to parent window object, or NIL if this is a root
*       window.
*     RECT  -  This must not extend past the parent window, or the RENDlib
*       device area if this is a root window.
*
*   After this routine returns, the caller must:
*
*     If this is a root window, allocate and fill in the common data for
*     this window set pointed to by ALL_P.
*
*     If this is a child window, then add it as a child to the parent window.
}
procedure gui_win_create (             {create bare window object}
  out     win: gui_win_t);             {returned initialized window object}
  val_param; internal;

var
  mem_p: util_mem_context_p_t;         {pointer to parent memory context}

begin
  if win.parent_p = nil
    then begin                         {this is a root window}
      mem_p := addr(util_top_mem_context); {parent mem is root memory context}
      win.all_p := nil;                {indicate window set data not created yet}
      win.pos.x := 0;                  {window is whole RENDlib device}
      win.pos.y := 0;
      end
    else begin                         {this is a child window}
      mem_p := win.parent_p^.mem_p;    {parent mem context is from parent window}
      win.all_p := win.parent_p^.all_p; {copy pointer to window set common data}
      win.pos.x :=                     {make RENDlib 2DIM of window upper left}
        win.parent_p^.pos.x + win.rect.x;
      win.pos.y :=
        win.parent_p^.pos.y + win.parent_p^.rect.dy
        - win.rect.y - win.rect.dy;
      end
    ;
  util_mem_context_get (mem_p^, win.mem_p); {create memory context for this window}
  win.mem_p^.pool_size := mem_pool_size_k; {set our own mem pool parameters}
  win.mem_p^.max_pool_chunk := mem_chunk_size_k;

  win.n_child := 0;                    {init to no child windows}
  util_mem_grab (                      {allocate mem for first child list block}
    sizeof(win.childblock_first_p^),   {amount of mem to allocate}
    win.mem_p^,                        {memory context}
    false,                             {OK to use mem pool}
    win.childblock_first_p);           {returned pointer to new memory}
  win.childblock_first_p^.prev_p := nil;
  win.childblock_first_p^.next_p := nil; {first block is end of blocks chain}
  win.childblock_last_p := win.childblock_first_p; {first block is last block}
  win.child_ind := 0;                  {first child block is completely empty}

  win.clip_rect.lx := 0.0;             {set clip region to whole window}
  win.clip_rect.rx := win.rect.dx;
  win.clip_rect.by := 0.0;
  win.clip_rect.ty := win.rect.dy;

  util_stack_alloc (win.mem_p^, win.stack_clip); {create clip stack for this window}
  win.stack_clip^.stack_len := stack_block_size_k; {keep stack memory small}
  util_stack_push (                    {create permanent backstop stack frame}
    win.stack_clip,                    {stack descriptor}
    sizeof(win.frame_clip_p^),         {size of new stack frame}
    win.frame_clip_p);                 {returned pointer to new stack frame}
  win.frame_clip_p^.rect := win.clip_rect; {init backstop clip to whole window}

  win.draw := nil;                     {no draw routine installed}
  win.delete := nil;                   {no delete cleanup routine installed}
  win.evhan := nil;                    {no event handling routine installed}
  win.app_p := nil;                    {no pointer to private application data}
  win.draw_flag := [];                 {init all drawing flags to off}

  gui_win_clip_compute (win);          {compute final resulting clip state}
  end;
{
*************************************************************************
*
*   Local function GUI_WIN_DRAWABLE (WIN)
*
*   Returns TRUE if any window in the tree is drawable (has a draw routine
*   installed).
}
function gui_win_drawable (            {check for any part of window tree drawable}
  in out  win: gui_win_t)              {window object}
  :boolean;                            {TRUE if any window in tree has draw routine}

var
  pos: gui_win_childpos_t;             {position into child window list}

begin
  gui_win_drawable := true;            {init to some window in tree is drawable}
  if win.draw <> nil then return;      {this window is drawable directly ?}

  gui_win_childpos_first (win, pos);   {init to first child window in list}
  while pos.child_p <> nil do begin    {once for each child window}
    if gui_win_drawable (pos.child_p^) then return; {this child tree drawable ?}
    gui_win_childpos_next (pos);       {advance to next child window}
    end;                               {back to check next child tree}

  gui_win_drawable := false;           {no window in tree has draw routine}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_RESIZE (WIN, X, Y, DX, DY)
*
*   Change the size and position of an existing window.  X,Y is one of the
*   new corners of the window, and DX,DY is the displacement from X,Y to
*   the opposite corner.
}
procedure gui_win_resize (             {resize and move a window}
  in out  win: gui_win_t;              {window object}
  in      x, y: real;                  {window corner within parent window}
  in      dx, dy: real);               {displacement from the corner at X,Y}
  val_param;

var
  drawable: boolean;                   {TRUE on window or children drawable}

begin
  if win.parent_p = nil then return;   {can't adjust root windows}

  drawable := gui_win_drawable (win);  {TRUE if any window in tree has draw routine}

  if drawable then begin
    gui_win_erase (win);               {erase window before moving it}
    end;

  gui_win_adjust (win, x, y, dx, dy);  {adjust all windows in this tree}

  if drawable then begin
    gui_win_draw_all (win);            {redisplay window with new size and position}
    end;
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILD_ADD (WIN, CHILD)
*
*   Add the window CHILD as a child window of WIN.
}
procedure gui_win_child_add (          {add child window to parent window}
  in out  win: gui_win_t;              {object of window to add child to}
  in out  child: gui_win_t);           {object of child window to add}
  val_param; internal;

var
  pos: gui_win_childpos_t;             {child list position object}

begin
  gui_win_childpos_last (win, pos);    {position to last child list entry}
  gui_win_childpos_next (pos);         {make sure are past end of list}
  gui_win_childpos_wentry (pos, addr(child)); {add new child to end of list}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILD_DEL (WIN, CHILD)
*
*   Remove window CHILD as a child window of WIN.  Nothing is done if CHILD
*   is not a child of WIN.
}
procedure gui_win_child_del (          {remove child window}
  in out  win: gui_win_t;              {object of window to remove child from}
  in out  child: gui_win_t);           {object of child window to remove}
  val_param; internal;

var
  to: gui_win_childpos_t;              {destination child list block position}
  from: gui_win_childpos_t;            {source child list block position}

label
  found;

begin
{
*   Scan thru the list of child windows looking for the window to remove.
}
  gui_win_childpos_first (win, to);    {init position to first child list entry}

  while to.child_p <> nil do begin     {once for each child window in the list}
    if to.child_p = addr(child)        {found entry for this child window ?}
      then goto found;
    gui_win_childpos_next (to);        {advance to next child list entry}
    end;                               {back to check this new list entry}

  return;                              {never found child in list}
{
*   TO is positioned to the child list entry containing the window to
*   remove.
}
found:                                 {found window to remove in child list}
  if win.n_child <= 1 then begin       {removing the only child window ?}
    win.n_child := 0;
    win.child_ind := 0;
    return;
    end;
{
*   Copy all the child list entries after this entry backwards one to
*   fill in the gap left by removing this entry.
}
  from := to;
  gui_win_childpos_next (from);        {init copy source to next list entry}

  while from.child_p <> nil do begin   {once for each child list entry to move}
    gui_win_childpos_wentry (to, from.child_p); {copy entry from FROM to TO}
    gui_win_childpos_next (to);        {advance destination position}
    gui_win_childpos_next (from);      {advance source position}
    end;                               {back and copy this next entry}
{
*   The list entries have been moved to fill the hole left by removing
*   the target child window.  Now delete the last list entry.
}
  win.child_ind := win.child_ind - 1;  {update last index to last child list block}
  if win.child_ind <= 0 then begin     {wrap back to start of previous block ?}
    win.child_ind := gui_childblock_size_k;
    win.childblock_last_p := win.childblock_last_p^.prev_p;
    end;

  win.n_child := win.n_child - 1;      {count one less total child window}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_ROOT (WIN)
*
*   Create the root GUI library window for the current RENDlib device.
}
procedure gui_win_root (               {create root window on curr RENDlib device}
  out     win: gui_win_t);             {returned window object}
  val_param;

var
  dev_id: rend_dev_id_t;               {RENDlib ID for current device}
  x_size, y_size: sys_int_machine_t;   {size of RENDlib device in pixels}
  aspect: real;                        {RENDlib device aspect ratio}

begin
  rend_set.enter_rend^;                {push one level into graphics mode}
  rend_get.dev_id^ (dev_id);           {get ID for current RENDlib device}
  rend_get.image_size^ (x_size, y_size, aspect); {get RENDlib device size}
  rend_set.exit_rend^;                 {pop one level back from graphics mode}

  win.parent_p := nil;                 {indicate this is a root window}
  win.rect.x := 0;                     {window covers whole RENDlib device}
  win.rect.y := 0;
  win.rect.dx := x_size;
  win.rect.dy := y_size;

  gui_win_create (win);                {fill in and init rest of window object}

  util_mem_grab (                      {allocate common state for this window set}
    sizeof(win.all_p^),                {amount of memory to allocate}
    win.mem_p^,                        {memory context}
    false,                             {use pool if possible}
    win.all_p);                        {returned pointer to new memory}

  win.all_p^.root_p := addr(win);      {set pointer to root window for this set}
  win.all_p^.rend_dev := dev_id;       {save RENDlib device ID}
  rend_set.enter_rend^;                {push one level into graphics mode}
  rend_get.clip_2dim_handle^ (win.all_p^.rend_clip); {get handle to new clip rect}
  rend_set.clip_2dim^ (                {set clip region to whole RENDlib device}
    win.all_p^.rend_clip,              {clip rectangle handle}
    0.0, x_size,                       {X limits}
    0.0, y_size,                       {Y limits}
    true);                             {draw inside, clip outside}
  rend_set.exit_rend^;                 {pop one level back from graphics mode}
  win.all_p^.draw_high_p := nil;       {init to no drawing in progress}
  win.all_p^.draw_low_p := nil;
  win.all_p^.drawing := false;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_CHILD (WIN, PARENT, X, Y, DX, DY)
*
*   Create a child window to overlay an existing window.  WIN will be returned
*   as the object for the new window.  PARENT is the object for the window
*   to overlay.  X, Y, DX, and DY describe the new window's position and size
*   in the parent window's coordinate space.  The new window's actual size and
*   position is always clipped to the parent window.  In other words, child
*   windows never exceed their parent windows.
}
procedure gui_win_child (              {create child window}
  out     win: gui_win_t;              {returned child window object}
  in out  parent: gui_win_t;           {object for parent window}
  in      x, y: real;                  {a child window corner within parent space}
  in      dx, dy: real);               {child window dispacement from corner}
  val_param;

var
  lx, rx, by, ty: real;                {sorted window limits}
  ilx, irx, iby, ity: sys_int_machine_t; {integer window limits}

begin
  win.parent_p := addr(parent);        {set up as child window, identify parent}

  if dx >= 0.0
    then begin                         {window extends right from corner point}
      lx := x;
      rx := x + dx;
      end
    else begin                         {window extends left from corner point}
      lx := x + dx;
      rx := x;
      end
    ;
  if dy >= 0.0
    then begin                         {window extends up from corner point}
      by := y;
      ty := y + dy;
      end
    else begin                         {window extends down from corner point}
      by := y + dy;
      ty := y;
      end
    ;
  ilx := max(0, min(win.parent_p^.rect.dx, trunc(lx + 0.5)));
  irx := max(0, min(win.parent_p^.rect.dx, trunc(rx + 0.5)));
  iby := max(0, min(win.parent_p^.rect.dy, trunc(by + 0.5)));
  ity := max(0, min(win.parent_p^.rect.dy, trunc(ty + 0.5)));

  win.rect.x := ilx;                   {set new window position within parent}
  win.rect.dx := irx - ilx;
  win.rect.y := iby;
  win.rect.dy := ity - iby;

  gui_win_create (win);                {fill in and init rest of window object}
  gui_win_child_add (parent, win)      {add new window as child to parent window}
  end;
{
*************************************************************************
*
*   Function GUI_WIN_CLIP (WIN, LFT, RIT, BOT, TOP)
*
*   Set a new clipping region for the window.  This clip rectangle is merged with
*   the stacked clip state for the window.  If any drawable pixels remain,
*   the RENDlib clip state is updated and the function returns TRUE.  If
*   no drawable pixels are left, the RENDlib state is not altered and the
*   function returns FALSE.  Note that the caller must inhibit whatever drawing
*   is associated with the clip region when the function returns FALSE, because
*   the RENDlib clip state is left in its previous condition.  This routine
*   has no effect on the stacked clip state.
}
function gui_win_clip (                {set window clip region and update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coordinates}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param;

begin
  win.clip_rect.lx := lft;             {save requested clip region in window obj}
  win.clip_rect.rx := rit;
  win.clip_rect.by := bot;
  win.clip_rect.ty := top;

  gui_win_clip_compute (win);          {compute the final resulting clip region}

  if not win.not_clipped then begin    {everything is clipped off ?}
    gui_win_clip := false;             {indicate to inhibit drawing}
    return;
    end;

  gui_win_clip := true;                {indicate draw region left, RENDlib clip set}
  rend_set.clip_2dim^ (                {set RENDlib clip rectangle}
    win.all_p^.rend_clip,              {handle to clip rectangle}
    win.clip.x,                        {left X limit}
    win.clip.x + win.clip.dx,          {right X limit}
    win.clip.y,                        {top Y limit}
    win.clip.y + win.clip.dy,          {bottom Y limit}
    true);                             {draw inside, clip outside}
  end;
{
*************************************************************************
*
*   Function GUI_WIN_CLIP_PUSH (WIN, LFT, RIT, BOT, TOP)
*
*   Push a new clip region onto the clip stack for this window if any pixels
*   remain drawable after the new clip region is taken into account.
*
*   If drawable pixels remain, this routine:
*
*     1 - Pushes the clip region from the call arguments onto the clip stack
*         for this window.
*
*     2 - Sets the non-stacked clip region to the remaining drawable region.
*         The previous non-stacked clip region is irrelevant.
*
*     3 - Sets the RENDlib clip state to the new drawable region.
*
*     4 - Returns TRUE.
*
*   If no drawable pixels remain, this routine:
*
*     1 - Does not alter the clip stack.
*
*     2 - Trashes the non-stacked clip region.
*
*     3 - Returns FALSE.  This indicates to the caller to NOT perform a
*         corresponding POP of the clip stack, and to inhibit any drawing
*         associated with the clip region.  The caller must do this explicitly
*         since the RENDlib clip state is not updated, and is essentially
*         invalid.
}
function gui_win_clip_push (           {push clip region onto stack, update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coordinates}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param;

var
  drawable: boolean;                   {TRUE if some pixels drawable after new clip}

begin
  drawable := gui_win_clip (win, lft, rit, bot, top); {set as non-stacked clip first}
  gui_win_clip_push := drawable;       {indicate whether drawable region after clip}
  if not drawable then return;         {everything clipped off, nothing more to do ?}
{
*   The new clip rectangle has been temporarily set as the non-stacked clip
*   region.  Drawable pixels definitely remain, and the RENDlib clip state
*   has been updated accordingly.
}
  win.clip_rect.lx :=                  {set non-stacked to combined clip region}
    max(win.clip_rect.lx, win.frame_clip_p^.rect.lx);
  win.clip_rect.rx :=
    min(win.clip_rect.rx, win.frame_clip_p^.rect.rx);
  win.clip_rect.by :=
    max(win.clip_rect.by, win.frame_clip_p^.rect.by);
  win.clip_rect.ty :=
    min(win.clip_rect.ty, win.frame_clip_p^.rect.ty);

  util_stack_push (                    {create new frame on top of clip stack}
    win.stack_clip, sizeof(win.frame_clip_p^), win.frame_clip_p);

  win.frame_clip_p^.rect := win.clip_rect; {fill in new stack frame}
  end;
{
*************************************************************************
*
*   Function GUI_WIN_CLIP_PUSH_2D (WIN, LFT, RIT, BOT, TOP)
*
*   Just like GUI_WIN_CLIP_PUSH, except that clip region is specified in
*   the current RENDlib 2D coordinate space instead of the GUI window
*   coordinate space.
*
*   Clip regions are always rectangles that are axis aligned with the
*   window edges.  The smallest clip region will be chosen that encompasses
*   all four corners of the 2D space rectangle specified by the call arguments.
}
function gui_win_clip_push_2d (        {push clip region onto stack, update RENDlib}
  in out  win: gui_win_t;              {window object}
  in      lft, rit, bot, top: real)    {clip region rectangle coor, RENDlib 2D space}
  :boolean;                            {TRUE if any part enabled for current redraw}
  val_param;

var
  xmin, xmax: real;                    {2DIM X limits of clip region}
  ymin, ymax: real;                    {2DIM Y limits of clip region}
  p1, p2: vect_2d_t;                   {for transforming a point}

begin
  p1.x := lft;                         {lower left corner}
  p1.y := bot;
  rend_get.xfpnt_2d^ (p1, p2);
  xmin := p2.x;
  xmax := p2.x;
  ymin := p2.y;
  ymax := p2.y;

  p1.x := rit;                         {lower right corner}
  rend_get.xfpnt_2d^ (p1, p2);
  xmin := min(xmin, p2.x);
  xmax := max(xmax, p2.x);
  ymin := min(ymin, p2.y);
  ymax := max(ymax, p2.y);

  p1.y := top;                         {upper right corner}
  rend_get.xfpnt_2d^ (p1, p2);
  xmin := min(xmin, p2.x);
  xmax := max(xmax, p2.x);
  ymin := min(ymin, p2.y);
  ymax := max(ymax, p2.y);

  p1.x := lft;                         {upper left corner}
  rend_get.xfpnt_2d^ (p1, p2);
  xmin := min(xmin, p2.x);
  xmax := max(xmax, p2.x);
  ymin := min(ymin, p2.y);
  ymax := max(ymax, p2.y);

  gui_win_clip_push_2d := gui_win_clip_push ( {do clip in GUI window coordinates}
    win,                               {window clipping within}
    xmin - win.pos.x,                  {left}
    xmax - win.pos.x,                  {right}
    win.rect.dy + win.pos.y - ymax,    {bottom}
    win.rect.dy + win.pos.y - ymin);   {top}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_CLIP_POP (WIN)
*
*   Pop the top entry from the window's clip stack, and update the clip state
*   accordingly.  The non-stacked clip region will be set to the maximum
*   drawable region allowed by the stacked clip state.  The previous contents
*   of the non-stacked clip region are lost.
*
*   Attempting to pop a stack frame that was not previously explicitly pushed
*   can result in all manner of destruction.  Don't do this!
}
procedure gui_win_clip_pop (           {pop clip region from stack, update RENDlib}
  in out  win: gui_win_t);             {window object}
  val_param;

begin
  util_stack_pop (                     {remove top stack frame}
    win.stack_clip, sizeof(win.frame_clip_p^));
  util_stack_last_frame (              {get pointer to new top stack frame}
    win.stack_clip, sizeof(win.frame_clip_p^), win.frame_clip_p);

  win.clip_rect := win.frame_clip_p^.rect; {set to max region allowed by stack}
  gui_win_clip_compute (win);          {compute final RENDlib 2DIM clip region}

  rend_set.clip_2dim^ (                {set RENDlib clip rectangle}
    win.all_p^.rend_clip,              {handle to clip rectangle}
    win.clip.x,                        {left X limit}
    win.clip.x + win.clip.dx,          {right X limit}
    win.clip.y,                        {top Y limit}
    win.clip.y + win.clip.dy,          {bottom Y limit}
    true);                             {draw inside, clip outside}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_DELETE (WIN)
*
*   Delete the indicated window and all its children.  The area underneath
*   the window will be repainted with the contents of the windows that were
*   "covered up".  Nothing is redrawn if the root window is being deleted.
}
procedure gui_win_delete (             {delete a window and all its children}
  in out  win: gui_win_t);             {object for window to delete}
  val_param;

var
  pos: gui_win_childpos_t;             {child list position state}
  top: boolean;                        {TRUE if this is top DELETE call}

begin
  top := not win.all_p^.drawing;       {set flag if this is top level DELETE call}
  win.all_p^.drawing := true;          {prevent all other calls from being top level}
{
*   Delete all the child windows recursively.  This makes sure all window
*   delete cleanup routines are run.
}
  gui_win_childpos_last (win, pos);    {start at last child window}
  while pos.child_p <> nil do begin    {once for each child window}
    gui_win_delete (pos.child_p^);     {delete the child window}
    gui_win_childpos_prev (pos);       {advance to previous child window}
    end;                               {back and process this new child window}
{
*   All child windows have been deleted.  Now delete this window.
}
  if top then begin                    {this is the top level DELETE call ?}
    win.all_p^.drawing := false;       {reset top call interlock}
    gui_win_draw_behind (              {erase window by drawing what is underneath}
      win,                             {window to draw what is below of}
      0.0, win.rect.dx,                {X limits of redraw area}
      0.0, win.rect.dy);               {Y limits of redraw area}
    end;

  if win.delete <> nil then begin      {this window has app delete cleanup routine ?}
    win.delete^ (addr(win), win.app_p); {call app delete cleanup routine}
    end;

  if win.parent_p = nil
    then begin                         {deleting the root window ?}
      rend_set.clip_2dim_delete^ (     {delete RENDlib clip window we were using}
        win.all_p^.rend_clip);
      end
    else begin                         {other windows in this set will remain}
      gui_win_child_del (win.parent_p^, win); {remove as child of parent window}
      end
    ;

  util_mem_context_del (win.mem_p);    {deallocate all dynamically allocated memory}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_DRAWFLAGS_CLEAR (WIN)
*
*   Clear the drawing flags for the window tree starting at WIN, except
*   not for the window pointed to by DRAW_LOW_P or lower in the ALL block
*   for this window set.  DRAW_LOW_P may be NIL to indicate unconditionally
*   clear the flag for all windows in the WIN tree.  The LOW_REACHED
*   flag must be set to FALSE on entry and will be trashed.
}
procedure gui_win_drawflags_clear (    {clear draw flags in tree of windows}
  in out  win: gui_win_t);             {root window of tree to clear}
  val_param; internal;

var
  pos: gui_win_childpos_t;             {child list position state}

begin
  if addr(win) = win.all_p^.draw_low_p then begin {hit low limit window ?}
    win.all_p^.low_reached := true;    {indicate low limit has been reached}
    return;
    end;

  win.draw_flag := [];                 {clear draw flags for this window}

  gui_win_childpos_first (win, pos);   {init position to first child window in list}
  while pos.child_p <> nil do begin    {once for each child window}
    gui_win_drawflags_clear (pos.child_p^); {clear flags for this child tree}
    if win.all_p^.low_reached then return; {already hit low window limit ?}
    gui_win_childpos_next (pos);       {advance to next child window in list}
    end;                               {back to process this new child window}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_XF2D_SET (WIN)
*
*   Set the RENDlib 2D transform to set up the GUI library standard coordinate
*   space for the window WIN.  The previous RENDlib 2D transform is lost.
*
*   The GUI library standard coordinates for each window put 0,0 in the lower
*   left corner.  X increases to the right and Y increases up.  X and Y are
*   both in units of pixels.  The RENDlib 2D transformation converts from
*   the application's 2D model coordinate space into a space where the
*   -1 to +1 X,Y square is centered and maximized within the device.
}
procedure gui_win_xf2d_set (           {set standard 2D coordinate space for window}
  in out  win: gui_win_t);             {window object}
  val_param;

var
  x_size, y_size: sys_int_machine_t;   {pixel size of RENDlib device}
  aspect: real;                        {width/height aspect ratio of RENDlib device}
  xb, yb, ofs: vect_2d_t;              {2D transform}

begin
  rend_set.enter_rend^;                {push one level into graphics mode}

  xb.y := 0.0;                         {fill in fixed part of transform}
  yb.x := 0.0;

  rend_get.image_size^ (x_size, y_size, aspect); {get device size and aspect ratio}

  if aspect >= 1.0
    then begin                         {device is wider than tall}
      xb.x := (2.0 * aspect) / x_size;
      yb.y := 2.0 / y_size;
      ofs.x := (-1.0 * aspect) + win.pos.x * xb.x;
      ofs.y := -1.0 + (y_size - win.pos.y - win.rect.dy) * yb.y;
      end
    else begin                         {device is taller than wide}
      xb.x := 2.0 / x_size;
      yb.y := (2.0 / aspect) / y_size;
      ofs.x := -1.0 + win.pos.x * xb.x;
      ofs.y := -1.0/aspect + (y_size - win.pos.y - win.rect.dy) * yb.y;
      end
    ;

  rend_set.xform_2d^ (xb, yb, ofs);    {set new RENDlib transform for this window}
  rend_set.exit_rend^;                 {pop one level from graphics mode}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_DRAW_RAW (WIN, LX, RX, BY, TY)
*
*   Just draw the indicated region of the window WIN.
}
procedure gui_win_draw_raw (           {low level window draw}
  in out  win: gui_win_t;              {object for window to draw contents of}
  in      lx, rx: real;                {left and right redraw region limits}
  in      by, ty: real);               {bottom and top redraw region limits}
  val_param; internal;

var
  xb, yb, ofs: vect_2d_t;              {saved copy of RENDlib 2D transform}

begin
  if gui_wdraw_done_k in win.draw_flag {this window already drawn ?}
    then return;
  win.draw_flag := win.draw_flag + [gui_wdraw_done_k]; {prevent drawing twice}

  if win.draw = nil then return;       {this window has no draw routine}

  if not gui_win_clip_push (win, lx, rx, by, ty) {everything is clipped away ?}
    then return;

  rend_set.enter_rend^;                {push one level into graphics mode}
  rend_get.xform_2d^ (xb, yb, ofs);    {save old RENDlib 2D transform}
  gui_win_xf2d_set (win);              {set RENDlib 2D transform for this window}
  win.draw^ (addr(win), win.app_p);    {draw this window}
  rend_set.xform_2d^ (xb, yb, ofs);    {restore old RENDlib 2D transform}
  rend_set.exit_rend^;                 {pop one level from graphics mode}
  gui_win_clip_pop (win);              {pop our redraw clip region}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_DRAW (WIN, LX, RX, BY, TY)
*
*   Draw the indicated region of the window.  Only this and lower windows
*   (decendents) will be drawn as appropriate.  Only the rectangle indicated
*   by the last four call arguments will be drawn.
}
procedure gui_win_draw (               {draw window contents}
  in out  win: gui_win_t;              {object for window to draw contents of}
  in      lx, rx: real;                {left and right redraw region limits}
  in      by, ty: real);               {bottom and top redraw region limits}
  val_param;

var
  pos: gui_win_childpos_t;             {child list position state}
  top: boolean;                        {TRUE if this is top draw request}

begin
  top := not win.all_p^.drawing;       {TRUE if this is original draw request}

  if top then begin                    {need to set state for original draw ?}
    rend_dev_set (win.all_p^.rend_dev); {make sure right RENDlib device is current}
    win.all_p^.drawing := true;        {indicate drawing is now in progress}
    win.all_p^.draw_high_p := addr(win); {don't draw any window above this one}
    win.all_p^.draw_low_p := nil;      {no restriction on lowest drawable window}
    win.all_p^.low_reached := false;   {indicate low limit window not reached yet}
    gui_win_drawflags_clear (win);     {clear draw flags for all candidate windows}
    win.all_p^.low_reached := false;   {reset flag trashed by DRAWFLAGS_CLEAR}
    end;

  if addr(win) = win.all_p^.draw_low_p then begin {not supposed to draw this win ?}
    win.all_p^.low_reached := true;    {indicate low limit window has been reached}
    return;
    end;
{
*   Draw this window if appropriate.
}
  gui_win_draw_raw (win, lx, rx, by, ty); {draw the window contents}

  gui_win_childpos_first (win, pos);   {init position to first child window in list}
  while pos.child_p <> nil do begin    {once for each child window}
    gui_win_draw (                     {draw this child window}
      pos.child_p^,                    {window to draw}
      lx - pos.child_p^.rect.x,        {draw region in child window coordinates}
      rx - pos.child_p^.rect.x,
      by - pos.child_p^.rect.y,
      ty - pos.child_p^.rect.y);
    if win.all_p^.low_reached then exit; {tree traversal limit reached ?}
    gui_win_childpos_next (pos);       {advance to next child window in list}
    end;                               {back to process this new child window}
{
*   Done drawing all the windows.
}
  if top then begin                    {completed entire original draw request ?}
    win.all_p^.drawing := false;       {reset to no drawing in progress}
    end;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_DRAW_ALL (WIN)
*
*   Draw the whole window.
}
procedure gui_win_draw_all (           {draw entire window contents}
  in out  win: gui_win_t);             {object for window to draw contents of}
  val_param;

begin
  gui_win_draw (
    win,                               {window to draw}
    0.0, win.rect.dx,                  {left and right draw limits}
    0.0, win.rect.dy);                 {bottom and top draw limits}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_DRAW_BEHIND (WIN, LX, RX, BY, TY)
*
*   Draw the indicated region below the window.  This causes the rectangle
*   to be refreshed with whatever the window WIN is drawn on top of.
*   GUI_WIN_DRAW_BEHIND is intended for use by windows that are not fully
*   opaque, and for use when a window is deleted.  This routine essentially
*   erases the window WIN.
}
procedure gui_win_draw_behind (        {draw what is behind a window}
  in out  win: gui_win_t;              {object for window to draw behind of}
  in      lx, rx: real;                {left and right redraw region limits}
  in      by, ty: real);               {bottom and top redraw region limits}
  val_param;

var
  dx, dy: real;                        {coor offset from this window to root window}
  top: boolean;                        {TRUE if this is top draw request}

begin
  if win.parent_p = nil then return;   {there is nothing behind top window}
  top := not win.all_p^.drawing;       {TRUE if this is original draw request}
  with win.all_p^.root_p^: root do begin {ROOT is abbrev for root window}

    if top then begin                  {need to set state for original draw ?}
      rend_dev_set (win.all_p^.rend_dev); {make sure right RENDlib device is current}
      win.all_p^.drawing := true;      {indicate drawing is now in progress}
      win.all_p^.draw_high_p := nil;   {we can draw all the way up to the root win}
      win.all_p^.draw_low_p := addr(win); {stop before drawing this window}
      win.all_p^.low_reached := false; {indicate low limit window not reached yet}
      gui_win_drawflags_clear (root);  {clear all drawing flags}
      win.all_p^.low_reached := false; {reset flag trashed by DRAWFLAGS_CLEAR}
      end;

    dx := win.pos.x - root.pos.x;      {make offsets for translating to root window}
    dy := (root.pos.y + root.rect.dy) - (win.pos.y + win.rect.dy);

    gui_win_draw (                     {redraw requested rectangle starting at root}
      root,                            {window at top of tree to redraw}
      lx + dx, rx + dx,                {left and right redraw limits}
      by + dy, ty + dy);               {bottom and top redraw limits}
{
*   Done drawing all the windows.
}
    if top then begin                  {completed entire original draw request ?}
      win.all_p^.drawing := false;     {reset to no drawing in progress}
      end;
    end;                               {done with ROOT abbreviation}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_ERASE (WIN)
*
*   Erase the window.
}
procedure gui_win_erase (              {draw what is behind entire window}
  in out  win: gui_win_t);             {object for window to draw behind of}
  val_param;

begin
  gui_win_draw_behind (                {draw what is behind the window}
    win,                               {the window}
    0.0, win.rect.dx,                  {left and right redraw limits}
    0.0, win.rect.dy);                 {bottom and top redraw limits}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_ALLOC_STATIC (WIN, SIZE, P)
*
*   Allocate new memory that will be automatically deallocated when the
*   window is deleted.  It will not be possible to individually deallocate
*   this memory.
}
procedure gui_win_alloc_static (       {allocate static mem deleted on win delete}
  in out  win: gui_win_t;              {window object}
  in      size: sys_int_adr_t;         {amount of memory to allocate}
  out     p: univ_ptr);                {returned pointing to new memory}
  val_param;

begin
  util_mem_grab (                      {allocate memory}
    size,                              {amount of memory to allocate}
    win.mem_p^,                        {memory context}
    false,                             {use pool if possible}
    p);                                {returned pointer to the new memory}
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_SET_APP_PNT (WIN, APP_P)
*
*   Set pointer to application-specific data for this window.  Any previous
*   app pointer is lost.  The application-specific data can be used for any
*   purpose by the application, and will be passed to the draw and event
*   handler routines for this window.
}
procedure gui_win_set_app_pnt (        {set pointer to application private data}
  in out  win: gui_win_t;              {window object}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param;

begin
  win.app_p := app_p;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_GET_APP_PNT (WIN, APP_P)
*
*   Returns the pointer to the application-specific data for this window.
}
procedure gui_win_get_app_pnt (        {get pointer to application private data}
  in out  win: gui_win_t;              {window object}
  out     app_p: univ_ptr);            {returned pointer to arbitrary app data}
  val_param;

begin
  app_p := win.app_p;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_SET_DRAW (WIN, ROUT_P)
*
*   Set the routine to be called to redraw this window.
}
procedure gui_win_set_draw (           {set window's draw routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_draw_p_t);  {pointer to window's new draw routine}
  val_param;

begin
  win.draw := rout_p;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_SET_DELETE (WIN, ROUT_P)
*
*   Set the routine to be called to redraw this window.
}
procedure gui_win_set_delete (         {set window's delete cleanup routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_delete_p_t); {pointer to window's new cleanup routine}
  val_param;

begin
  win.delete := rout_p;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_SET_EVHAN (WIN, ROUT_P)
*
*   Set the routine to be called to handle events for this window.
}
procedure gui_win_set_evhan (          {set window's event handler routine}
  in out  win: gui_win_t;              {window object}
  in      rout_p: univ gui_evhan_p_t); {pointer to window's new event handler}
  val_param;

begin
  win.evhan := rout_p;
  end;
{
*************************************************************************
*
*   Subroutine GUI_WIN_TOFRONT (WIN)
*
*   Make this window the last window in the parent's child list.  This has
*   the effect of bringing the window in front of all its other sibling
*   windows.
}
procedure gui_win_tofront (            {make last child in parent's child list}
  in out  win: gui_win_t);             {window object}
  val_param;

var
  pos: gui_win_childpos_t;             {child list position state}
  par_p: gui_win_p_t;                  {pointer to parent window}

begin
  par_p := win.parent_p;               {get pointer to parent window}
  if par_p = nil then return;          {no parent window ?}

  gui_win_childpos_last (win, pos);    {go to last entry in parent's child list}
  if pos.child_p = addr(win)           {already last entry in child list ?}
    then return;
{
*   The window is not currently the last child of the parent.
}
  gui_win_child_del (par_p^, win);     {remove from parent's child list}
  gui_win_child_add (par_p^, win);     {add back at end of list}

  gui_win_draw_all (win);              {update display of window moved to font}
  end;
