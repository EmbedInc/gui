{   Module of event handler routines.
}
module gui_evhan;
define gui_win_evhan;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Function GUI_WIN_EVHAN (WIN, LOOP)
*
*   Handle events for the window.  One of the following values is returned:
*
*     GUI_EVHAN_NONE_K  -  No events where processed.  This could be because
*       the window had no event handler, or the event handler chose not to
*       process events at this time.
*
*     GUI_EVHAN_DID_K  -  At least one event was received, and all were handled.
*
*     GUI_EVHAN_NOTME_K  -  One or more events were received, the last of which
*       could not be handled by this window.  The unhandled event was pushed
*       back onto the event queue, and will therefore be the next event
*       received by the next event handler.
}
function gui_win_evhan (               {handle events for a window}
  in out  win: gui_win_t;              {window to handle events for}
  in      loop: boolean)               {keep handling events as long as possible}
  :gui_evhan_k_t;                      {event handler completion code}
  val_param;

var
  pos: gui_win_childpos_t;             {handle to position in child windows list}
  hdone: gui_evhan_k_t;                {child window handler completion code}
  chdone: gui_evhan_k_t;               {overall result of from all child windows}
  cloop: boolean;                      {LOOP flag for child window}

label
  loop_front;

begin
loop_front:                            {back here to restart at front child window}
  gui_win_childpos_last (win, pos);    {go to last window in child list}
  chdone := gui_evhan_none_k;          {init to no events processed by child windows}
  cloop := loop;                       {init loop flag for first child window}

  while pos.child_p <> nil do begin    {thru child list from front to back}
    hdone := gui_win_evhan (pos.child_p^, cloop); {run child window event handler}
    case hdone of
gui_evhan_none_k: ;                    {no events were processed}
gui_evhan_did_k: begin                 {child window succesfully handled events}
        if loop then begin
          goto loop_front;             {restart at front child window}
          end;
        gui_win_evhan := hdone;        {return with result from this child window}
        return;
        end;
gui_evhan_notme_k: begin               {encountered event that couldn't be handled}
        chdone := hdone;               {update overall child window result so far}
        end;
      end;                             {end of child event handler completion cases}
    gui_win_childpos_prev (pos);       {go to next child window back}
    cloop := false;                    {only allow front child window to loop}
    end;                               {back to do next child window}
{
*   All the child windows are done with their turn for handling events.
*   Now run the event handler for this window, if there is one.
}
  if win.evhan = nil then begin        {this window has no event handler ?}
    gui_win_evhan := chdone;           {pass back result from child windows}
    return;
    end;

  hdone := win.evhan^ (addr(win), win.app_p); {run our event handler}

  case hdone of                        {what did our event handler do ?}
gui_evhan_none_k: begin                {no events were processed}
      gui_win_evhan := chdone;         {pass back result from child windows}
      end;
gui_evhan_did_k: begin                 {an event was handled}
      if loop then begin
        goto loop_front;               {restart at front child window}
        end;
      gui_win_evhan := hdone;          {pass back our handler result}
      end;
otherwise
    gui_win_evhan := hdone;            {pass back our handler result}
    end;                               {end of result cases, function value all set}
  end;
