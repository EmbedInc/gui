{   Module of routines for handling child windows.
}
module gui_child;
define gui_win_childpos_first;
define gui_win_childpos_last;
define gui_win_childpos_next;
define gui_win_childpos_prev;
define gui_win_childpos_wentry;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILDPOS_FIRST (WIN, POS)
*
*   Init the child window list position handle POS to the first child of
*   window WIN.
}
procedure gui_win_childpos_first (     {init child position to first child in list}
  in out  win: gui_win_t;              {window object}
  out     pos: gui_win_childpos_t);    {returned child list position object}
  val_param;

begin
  pos.win_p := addr(win);
  pos.block_p := win.childblock_first_p;
  if win.n_child <= 0
    then begin                         {there are no child windows in list}
      pos.n := 0;
      pos.ind := 0;
      pos.child_p := nil;
      end
    else begin                         {there is at least one child in list}
      pos.n := 1;
      pos.ind := 1;
      pos.child_p := pos.block_p^.child_p_ar[pos.ind];
      end
    ;
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILDPOS_LAST (WIN, POS)
*
*   Init the child window list position handle POS to the last child of
*   window WIN.
}
procedure gui_win_childpos_last (      {init child position to last child in list}
  in out  win: gui_win_t;              {window object}
  out     pos: gui_win_childpos_t);    {returned child list position object}
  val_param;

begin
  pos.win_p := addr(win);
  pos.block_p := win.childblock_last_p;
  if win.n_child <= 0
    then begin                         {there are no child windows in list}
      pos.n := 0;
      pos.ind := 0;
      pos.child_p := nil;
      end
    else begin                         {there is at least one child in list}
      pos.n := win.n_child;
      pos.ind := win.child_ind;
      pos.child_p := pos.block_p^.child_p_ar[pos.ind];
      end
    ;
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILDPOS_NEXT (POS)
*
*   Advance the child list position to the next child in the list.  If
*   the end of the list is reached, then the position is left one entry
*   past the end of the list, but there is no guarantee that a list
*   entry for this next position exists.  The position is never advanced
*   to more than one entry past the list.
}
procedure gui_win_childpos_next (      {move position to next child in list}
  in out  pos: gui_win_childpos_t);    {child list position object}
  val_param;

begin
  if pos.n >= pos.win_p^.n_child then begin {will be past end of list ?}
    pos.n := pos.win_p^.n_child + 1;   {indicate one entry past end of list}
    pos.child_p := nil;                {there is no child here}
    return;
    end;

  if pos.ind >= gui_childblock_size_k
    then begin                         {new position will be in next block}
      pos.block_p := pos.block_p^.next_p;
      pos.ind := 1;
      end
    else begin                         {new position is in same block}
      pos.ind := pos.ind + 1;
      end
    ;                                  {BLOCK_P and IND all set}
  pos.n := pos.n + 1;                  {update current child number}

  pos.child_p := pos.block_p^.child_p_ar[pos.ind]; {fetch this list entry}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILDPOS_PREV (POS)
*
*   Move the current child list position to the previous entry, if there
*   is one.
}
procedure gui_win_childpos_prev (      {move position to previous child in list}
  in out  pos: gui_win_childpos_t);    {child list position object}
  val_param;

begin
  if pos.n <= 1 then begin             {will be before start of list ?}
    pos.child_p := nil;
    pos.ind := 0;
    pos.n := 0;
    return;
    end;

  if pos.ind <= 1
    then begin                         {new position is in previous list block}
      pos.block_p := pos.block_p^.prev_p;
      pos.ind := gui_childblock_size_k;
      end
    else begin                         {new position is in same list block}
      pos.ind := pos.ind - 1;
      end
    ;
  pos.n := pos.n - 1;

  pos.child_p := pos.block_p^.child_p_ar[pos.ind]; {fetch this list entry}
  end;
{
*************************************************************************
*
*   Local subroutine GUI_WIN_CHILDPOS_WENTRY (POS, CHILD_P)
*
*   Write the child window pointer CHILD_P at the current child list position.
*   If the current position is past the end of the list, then the new list
*   entry is created if needed.
}
procedure gui_win_childpos_wentry (    {write value to child list entry}
  in out  pos: gui_win_childpos_t;     {child list position object}
  in      child_p: gui_win_p_t);       {pointer to new child window}
  val_param;

var
  block_p: gui_childblock_p_t;         {pointer to new child list block}

begin
  pos.n := max(1, pos.n);              {go to first entry if before list start}
  if pos.n > pos.win_p^.n_child then begin {need to create list position first ?}
    if pos.win_p^.child_ind >= gui_childblock_size_k
      then begin                       {next position is in new block ?}
        if pos.block_p^.next_p = nil then begin {need to allocate new block ?}
          util_mem_grab (              {allocate memory for new list block}
            sizeof(child_p^),          {amount of memory to allocate}
            pos.win_p^.mem_p^,         {memory context}
            false,                     {use pool if possible}
            block_p);                  {returned pointer to new block}
          block_p^.prev_p := pos.block_p; {link new block to end of chain}
          block_p^.next_p := nil;
          pos.block_p^.next_p := block_p;
          end;                         {a next block now definitely exists}
        pos.block_p := pos.block_p^.next_p; {advance to next block in list}
        pos.win_p^.childblock_last_p := pos.block_p; {update pnt to last used block}
        pos.ind := 1;                  {new entry is first entry in new block}
        end
      else begin                       {next position is still in current block}
        pos.ind := pos.win_p^.child_ind + 1;
        end
      ;
    pos.win_p^.child_ind := pos.ind;   {update info for end of child list}
    pos.win_p^.n_child := pos.n;       {update number of child windows}
    end;

  pos.block_p^.child_p_ar[pos.ind] := child_p; {stuff value into this list entry}
  pos.child_p := child_p;              {indicate list entry contents here}
  end;
