{   Module of GUI library routines that manipulate the RENDlib event state.
}
module gui_events;
define gui_events_init_key;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Subroutine GUI_EVENTS_INIT_KEY
*
*   Initialize the RENDlib key events state to that assumed by other GUI library
*   routines.  All the keys used anywhere in the GUI library are enabled here.
*   It is up to each event handler to ignore events for irrelevant keys.
}
procedure gui_events_init_key;         {set up RENDlib key events for curr device}

var
  keys_p: rend_key_ar_p_t;             {pointer to array of all key descriptors}
  nk: sys_int_machine_t;               {number of keys at KEYS_P}
  i: sys_int_machine_t;                {scratch integer and loop counter}

begin
  rend_set.enter_rend^;                {push one level deeper into graphics mode}
  rend_get.keys^ (keys_p, nk);         {get RENDlib key descriptors info}
{
*   Find all the keys that map to individual characters and enable
*   these as CHAR keys.  Some of these may get remapped as special keys
*   further below.
}
  for i := 1 to nk do begin            {once for each key descriptor in the list}
    if keys_p^[i].val_p = nil then next; {this key has no character value ?}
    if keys_p^[i].val_p^.len <> 1 then next; {key value is not a single character ?}
    rend_set.event_req_key_on^ (       {enable events for this key}
      i,                               {RENDlib index for this key}
      ord(gui_key_char_k));            {our internal ID for this key}
    end;

  rend_set.event_req_key_on^ (         {enable up arrow key}
    rend_get.key_sp^ (rend_key_sp_arrow_up_k, 0),
    ord(gui_key_arrow_up_k));

  rend_set.event_req_key_on^ (         {enable down arrow key}
    rend_get.key_sp^ (rend_key_sp_arrow_down_k, 0),
    ord(gui_key_arrow_down_k));

  rend_set.event_req_key_on^ (         {enable left arrow key}
    rend_get.key_sp^ (rend_key_sp_arrow_left_k, 0),
    ord(gui_key_arrow_left_k));

  rend_set.event_req_key_on^ (         {enable right arrow key}
    rend_get.key_sp^ (rend_key_sp_arrow_right_k, 0),
    ord(gui_key_arrow_right_k));

  rend_set.event_req_key_on^ (         {enable HOME key}
    gui_key_names_id ('HOME'),
    ord(gui_key_home_k));

  rend_set.event_req_key_on^ (         {enable END key}
    gui_key_names_id ('END'),
    ord(gui_key_end_k));

  rend_set.event_req_key_on^ (         {enable DELETE key}
    gui_key_names_id ('DELETE'),
    ord(gui_key_del_k));
  rend_set.event_req_key_on^ (
    gui_key_names_id ('DEL'),
    ord(gui_key_del_k));

  rend_set.event_req_key_on^ (         {enable mouse left button events}
    rend_get.key_sp^ (rend_key_sp_pointer_k, 1), {RENDlib key ID}
    ord(gui_key_mouse_left_k));
  if rend_get.key_sp^ (rend_key_sp_pointer_k, 3) = rend_key_none_k
    then begin                         {pointer only has 2 or fewer keys}
      rend_set.event_req_key_on^ (     {enable mouse right button events}
        rend_get.key_sp^ (rend_key_sp_pointer_k, 2), {RENDlib key ID}
        ord(gui_key_mouse_right_k));
      end
    else begin                         {pointer has 3 or more keys}
      rend_set.event_req_key_on^ (     {enable mouse middle button events}
        rend_get.key_sp^ (rend_key_sp_pointer_k, 2), {RENDlib key ID}
        ord(gui_key_mouse_mid_k));
      rend_set.event_req_key_on^ (     {enable mouse right button events}
        rend_get.key_sp^ (rend_key_sp_pointer_k, 3), {RENDlib key ID}
        ord(gui_key_mouse_right_k));
      end
    ;

  rend_set.event_req_key_on^ (         {enable TAB key}
    gui_key_alpha_id (chr(9)),
    ord(gui_key_esc_k));

  rend_set.event_req_key_on^ (         {enable ESCAPE key}
    gui_key_alpha_id (chr(27)),
    ord(gui_key_esc_k));

  rend_set.event_req_key_on^ (         {enable ENTER key}
    gui_key_alpha_id (chr(13)),
    ord(gui_key_enter_k));

  rend_set.exit_rend^;                 {pop one level back out of graphics mode}
  end;
