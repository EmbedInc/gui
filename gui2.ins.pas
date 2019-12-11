{   Private include file for the GUI library.
}
%include 'base.ins.pas';
%include 'img.ins.pas';
%include 'math.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';
%include 'gui.ins.pas';

type
  gui_win_childpos_t = record          {position into child window list}
    child_p: gui_win_p_t;              {pointer to current child window, may be NIL}
    win_p: gui_win_p_t;                {pointer to window object}
    block_p: gui_childblock_p_t;       {pointer to current child list block}
    ind: sys_int_machine_t;            {curr child list block index, 0 before first}
    n: sys_int_machine_t;              {1-N child number, 0 before first}
    end;
{
*   Routine declarations.
}
procedure gui_win_childpos_first (     {init child position to first child in list}
  in out  win: gui_win_t;              {window object}
  out     pos: gui_win_childpos_t);    {returned child list position object}
  val_param; extern;

procedure gui_win_childpos_last (      {init child position to last child in list}
  in out  win: gui_win_t;              {window object}
  out     pos: gui_win_childpos_t);    {returned child list position object}
  val_param; extern;

procedure gui_win_childpos_next (      {move position to next child in list}
  in out  pos: gui_win_childpos_t);    {child list position object}
  val_param; extern;

procedure gui_win_childpos_prev (      {move position to previous child in list}
  in out  pos: gui_win_childpos_t);    {child list position object}
  val_param; extern;

procedure gui_win_childpos_wentry (    {write value to child list entry}
  in out  pos: gui_win_childpos_t;     {child list position object}
  in      child_p: gui_win_p_t);       {pointer to new child window}
  val_param; extern;
