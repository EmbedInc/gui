{   Module of routines for dealing with RENDlib keys.
}
module gui_key;
define gui_key_alpha_id;
define gui_key_name_id;
define gui_key_names_id;
define gui_event_char;
%include 'gui2.ins.pas';
{
*************************************************************************
*
*   Function GUI_KEY_ALPHA_ID (C)
*
*   Returns the RENDlib key ID for the alphnumeric key representing the
*   character C.  The character case of C is irrelevant.  A returned value
*   of REND_KEY_NONE_K indicates the key was not found.
}
function gui_key_alpha_id (            {find RENDlib alphanumeric key ID}
  in      c: char)                     {character to find key for, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param;

var
  lc: char;                            {lower case character looking for}
  keys_p: rend_key_ar_p_t;             {pointer to array of key descriptors}
  nk: sys_int_machine_t;               {number of keys in array}
  k: sys_int_machine_t;                {key number}

begin
  lc := string_downcase_char (c);      {make lower case version of key char}

  rend_get.keys^ (keys_p, nk);         {get key descriptors array info}

  for k := 1 to nk do begin            {once for each key in the array}
    if                                 {found the right key ?}
        (keys_p^[k].val_p <> nil) and then {key has a string value ?}
        (keys_p^[k].val_p^.len = 1) and {key value is exactly one character ?}
        (keys_p^[k].val_p^.str[1] = lc) {key character matches our character ?}
        then begin
      gui_key_alpha_id := k;           {return RENDlib ID of the matching key}
      return;
      end;
    end;                               {back to check out next key in list}

  gui_key_alpha_id := rend_key_none_k; {indicate the key was not found}
  end;
{
*************************************************************************
*
*   Function GUI_KEY_NAME_ID (NAME)
*
*   Return the RENDlib key ID of the key with NAME on the key cap.
*   NAME is case-insensitive.  REND_KEY_NONE_K is returned if not
*   matching key could be found.
}
function gui_key_name_id (             {find RENDlib key ID from key cap name}
  in      name: univ string_var_arg_t) {key name to find, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param;

var
  keys_p: rend_key_ar_p_t;             {pointer to array of key descriptors}
  nk: sys_int_machine_t;               {number of keys in array}
  k: sys_int_machine_t;                {key number}
  uname: string_var80_t;               {upper case search name}
  kn: string_var80_t;                  {key cap name}

begin
  uname.max := size_char(uname.str);   {init local var strings}
  kn.max := size_char(kn.str);

  string_copy (name, uname);           {make local copy of key name to look for}
  string_upcase (uname);               {make upper case for matching}
  rend_get.keys^ (keys_p, nk);         {get key descriptors array info}

  for k := 1 to nk do begin            {once for each key in the array}
    if keys_p^[k].name_p = nil then next; {no key cap name available for this key ?}
    string_copy (keys_p^[k].name_p^, kn); {make local copy of key name}
    string_upcase (kn);                {make upper case for matching}
    if string_equal (name, kn) then begin {found the key ?}
      gui_key_name_id := k;            {return RENDlib ID for the matching key}
      return;
      end;
    end;                               {back to examine next key descriptor}

  gui_key_name_id := rend_key_none_k;  {indicate the key was not found}
  end;
{
*************************************************************************
*
*   Function GUI_KEY_NAMES_ID (NAME)
*
*   Just like GUI_KEY_NAME_ID except that NAME is a plain string instead of
*   a var string.
}
function gui_key_names_id (            {like GUI_KEY_NAME_ID except plain string nam}
  in      name: string)                {key name to find, case-insensitive}
  :rend_key_id_t;                      {RENDlib key ID, REND_KEY_NONE_K on not found}
  val_param;

var
  vname: string_var80_t;               {var string version of NAME}

begin
  vname.max := size_char(vname.str);   {init local var string}

  string_vstring (vname, name, size_char(name)); {make var string copy of NAME}
  gui_key_names_id := gui_key_name_id(vname); {call vstring routine to do the work}
  end;
{
*************************************************************************
*
*   Function GUI_EVENT_CHAR (EVENT)
*
*   Return the single character represented by the RENDlib key event.  The
*   NULL character is returned if the key doesn't represent a character.
}
function gui_event_char (              {get char from character key event}
  in      event: rend_event_t)         {RENDlib event descriptor for key event}
  :char;                               {character, NULL for non-character event}
  val_param;

type
  modk_k_t = (                         {key modifiers we recognize}
    modk_none_k,
    modk_shift_k,
    modk_ctrl_k);

var
  modk: modk_k_t;                      {our internal modifier choices}
  emod: rend_key_mod_t;                {set of modifier keys from event}
  shiftlock: boolean;                  {TRUE if shift lock modifier active}
  c: char;                             {sratch character}

label
  got_modk;

begin
  gui_event_char := chr(0);            {init to event was not a valid char key}
  if event.ev_type <> rend_ev_key_k then return; {not a key event ?}
  emod := event.key.modk;              {make local copy of modifier keys}
  shiftlock := false;                  {init to shift lock not active}

  if rend_key_mod_shiftlock_k in emod then begin {SHIFT LOCK down ?}
    emod := emod - [rend_key_mod_shiftlock_k];
    shiftlock := true;                 {remember shift lock was active}
    end;

  if rend_key_mod_shift_k in emod then begin {SHIFT key down ?}
    emod := emod - [rend_key_mod_shift_k, rend_key_mod_shiftlock_k];
    if emod <> [] then return;         {some other modifiers also down ?}
    modk := modk_shift_k;
    goto got_modk;
    end;

  if rend_key_mod_ctrl_k in emod then begin {CTRL down ?}
    emod := emod - [rend_key_mod_ctrl_k];
    if emod <> [] then return;         {some other modifiers also down ?}
    modk := modk_ctrl_k;
    goto got_modk;
    end;

  if emod <> [] then return;           {other modifiers are active ?}
  modk := modk_none_k;

got_modk:                              {MODK describes the modifier}
  case modk of                         {which modifier, if any, was active}
modk_none_k: begin
      if event.key.key_p^.val_p^.len <> 1 then return; {not single character ?}
      c := event.key.key_p^.val_p^.str[1];
      if shiftlock then begin
        c := string_upcase_char (c);
        end;
      end;
modk_shift_k: begin
      if event.key.key_p^.val_mod[rend_key_mod_shift_k]^.len <> 1 {not 1 char ?}
        then return;
      c := event.key.key_p^.val_mod[rend_key_mod_shift_k]^.str[1];
      if shiftlock then begin
        c := string_downcase_char (c);
        end;
      end;
modk_ctrl_k: begin
      if event.key.key_p^.val_mod[rend_key_mod_ctrl_k]^.len <> 1 {not 1 char ?}
        then return;
      c := event.key.key_p^.val_mod[rend_key_mod_ctrl_k]^.str[1];
      end;
otherwise
    return;                            {internal error, should never happen}
    end;

  gui_event_char := c;                 {pass back final character from key event}
  end;
