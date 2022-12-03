{   Subroutine GUI_TICKS_MAKE (VMIN, VMAX, WID, HORIZ, MEM, FIRST_P)
*
*   Create a set of tick marks for labeling the displayed value range from VMIN
*   to VMAX.  WID is the displayed length of the VMIN to VMAX range in the
*   RENDlib TXDRAW coordinate space.  The current RENDlib text parameters must
*   be set as they will be when the tick mark labels are drawn.  FIRST_P will be
*   returned pointing to the start of the newly created chain of tick mark
*   descriptors.  The tick mark descriptors will be allocated statically from
*   the MEM memory context.  HORIZ is TRUE if the labels will be written next to
*   each other horizontally, and FALSE if the labels will be written above/below
*   each other vertically.
*
*   This routine finds the major tick mark sequence that maximizes the number of
*   labels without cramming them too close.  Only major tick marks (level 0) are
*   labeled.  Major tick sequences are always one of the following relative
*   values within each power of 10.
*
*     1, 2, 3, 4, ...
*     2, 4, 8, 10, ...
*     5, 10, 15, 20, ...
*
*   The ticks chain is always in minor to major tick marks order.  This is to
*   facilitate drawing and minimize color switching.
}
module gui_ticks_make;
define gui_ticks_make;
%include 'gui2.ins.pas';

const
  space_k = 1.0;                       {min char cell space between adjacent labels}
  nseq_k = 3;                          {number of sequences within each power of 10}

var
  seq_inc_ar:                          {list of sequence increments within pow of 10}
    array[1..nseq_k] of sys_int_machine_t := [
    1, 2, 5];

procedure gui_ticks_make (             {create tick marks with proper spacing}
  in      vmin, vmax: real;            {range of axis values to make tick marks for}
  in      wid: real;                   {RENDlib TXDRAW space VMIN to VMAX distance}
  in      horiz: boolean;              {TRUE = labels side by side, not stacked}
  in out  mem: util_mem_context_t;     {parent context for any new memory}
  out     first_p: gui_tick_p_t);      {will point to start of new tick marks chain}
  val_param;

var
  tp: rend_text_parms_t;               {RENDlib text control parameters}
  tw: real;                            {standard char cell width}
  th: real;                            {standard char cell height}
  space: real;                         {min space required between labels}
  maxsum: real;                        {max sum of adjacent label widths for fit}
  i: sys_int_machine_t;                {scratch integer}
  r: real;                             {scratch floating point number}
  ran: real;                           {size of values range}
  scale: real;                         {mult factor to convert data values to X}
  dmaj: real;                          {delta for each major tick}
  log10: sys_int_machine_t;            {power of 10 major tick sequence within}
  seqi: sys_int_machine_t;             {sequence index within curr power of 10}
  sinc: sys_int_machine_t;             {sequence increment within power of 10}
  seqm: sys_int_machine_t;             {sequence increment multiplier}
  seqmi: sys_int_machine_t;            {SEQM value for first tick}
  seq: real;                           {sequence increment}
  logm: real;                          {sequence power of 10 multiplier}
  tv: real;                            {tick value}
  prevw: real;                         {width of previous label}
  lwid: real;                          {width of this label}
  ntick: sys_int_machine_t;            {number of ticks}
  bv, up, ll: vect_2d_t;               {string metrics returned by RENDlib}
  tick_p: gui_tick_p_t;                {pointer to tick descriptor}
  s: string_var32_t;                   {scratch string for number conversion}

label
  loop_find_maj;
{
****************************************
*
*   Local subroutine MAKE_STRING (S, R, LOG10)
*
*   Set S to the label string to draw for the value R.  LOG10 indicates the
*   power of 10 within which the label sequence exists.  This is used to decide
*   which digits to the right of the decimal point, if any must be shown.  A
*   LOG10 value of 0 is for 1, 1 for 10, -1 for .1, etc.
}
procedure make_string (                {make label string from value}
  in out  s: univ string_var_arg_t;    {the returned string}
  in      r: real;                     {label numeric value}
  in      log10: sys_int_machine_t);   {power of 10 sequence is within}
  val_param; internal;

var
  stat: sys_err_t;                     {completion status code}

begin
  string_f_fp (                        {make string for label}
    s,                                 {returned string}
    r,                                 {value to make string of}
    0,                                 {no fixed field width}
    0,                                 {no fixed width for exponent}
    1,                                 {min required significant digits}
    6,                                 {max digits allowed left of point}
    max(0, -log10),                    {min required digits right of point}
    3,                                 {max digits allowed right of point}
    [ string_ffp_exp_eng_k,            {use engineering notation for exponents}
      string_ffp_nz_bef_k,             {don't write 0 before point as only char}
      string_ffp_group_k],             {write digits in groups}
    stat);
  if sys_error(stat) then s.len := 0;
  end;
{
****************************************
*
*   Start of main routine.
}
begin
  s.max := size_char(s.str);           {init local var string}

  first_p := nil;                      {init to no ticks list created}
  ran := vmax - vmin;                  {set size of values range}
  if ran < 1.0e-30 then return;        {too small a values range to work with ?}
  scale := wid / ran;                  {mult factor from data values to X scale}

  rend_get.text_parms^ (tp);           {get current text control parameters}
  tw := tp.size * tp.width;            {make standard char cell width}
  th := tp.size * tp.height;           {make standard char cell height}
  if horiz
    then begin                         {labels will abutt horizontally}
      space := tw * space_k;           {make min space required between labels}
      i :=                             {can't possibly exceed this many labels}
        trunc(wid / (tw * 0.5 + space) + 2.0);
      end
    else begin                         {labels will abutt vertically}
      space := tp.size * tp.lspace;    {make min space required between labels}
      i :=                             {can't possibly exceed this many labels}
        trunc(wid / (th + space) + 2.0);
      lwid := th;                      {"width" of label string}
      end
    ;
  i := max(10, i);                     {set min number of labels to start with}
  dmaj := ran / i;                     {init major tick delta to a bit too small}
  r := math_log10(dmaj);               {get Log10 of starting major delta}
  log10 := trunc(r + 100.0) - 100;     {find starting base power of 10}
  seqi := 1;                           {init sequence index within this power of 10}
{
*   Back here to check each new major sequence for fit.  LOG10 is the power of
*   10 we are within, and SEQI is the index of the sequence to try.  The
*   sequence is accepted if all labels can be written next to each other with
*   the minimum space in between.  If a sequence fails, the next larger sequence
*   is tried.  This reduces the number of labels required, until eventually all
*   labels should fit.
}
loop_find_maj:
  logm := 10.0 ** log10;               {make base power of 10 multiplier}
  sinc := seq_inc_ar[seqi];            {get increment value for this sequence}
  seq := logm * sinc;                  {sequence value increment}
  seqm := trunc(vmin / seq);           {make initial sequence multiplier}
  tv := seq * seqm;                    {make initial tick value}
  maxsum := (seq * scale - space) * 2.0; {max sum of adjacent label widths for fit}

  while tv < vmin do begin             {loop until tick value up into range}
    seqm := seqm + 1;                  {go one tick value up}
    tv := seq * seqm;
    end;
  seqmi := seqm;                       {save info for first tick}
  prevw := -10.0;                      {init to previous label won't cause squish}

  while tv <= vmax do begin            {loop for all ticks within range}
    if horiz then begin                {label strings in a line horizontally}
      make_string (s, tv, log10);      {make label string for this tick}
      rend_get.txbox_txdraw^ (         {measure the label string}
        s.str, s.len,                  {string and string length}
        bv, up, ll);                   {returned string metrics}
      lwid := bv.x;                    {get width of this label string}
      end;
    if (prevw + lwid) > maxsum then begin {labels don't fit together ?}
      seqi := seqi + 1;                {advance to next sequence in this power of 10}
      if seqi > nseq_k then begin      {wrap to next power of ten ?}
        seqi := 1;
        log10 := log10 + 1;
        end;
      goto loop_find_maj;              {back to try with this new sequence}
      end;
    prevw := lwid;                     {current width becomes previous width}
    seqm := seqm + 1;                  {advance to next tick value in this sequence}
    tv := seq * seqm;
    end;                               {back to check out this new tick value}

  ntick := seqm - seqmi;               {make number of ticks within range}
{
*   A sequence was found for which all the labels fit next to each other.  NTICK
*   is the number of ticks.  SEQMI is the SEQM value for the first tick.
}
  seqm := seqmi;

  for i := 1 to ntick do begin         {once for each tick descriptor to create}
    tv := seq * seqm;                  {make data value of this tick}

    util_mem_grab (                    {allocate memory for new tick descriptor}
      sizeof(tick_p^), mem, false, tick_p);
    tick_p^.next_p := first_p;         {link new tick to front of chain}
    first_p := tick_p;

    tick_p^.val := tv;                 {set tick data value}
    tick_p^.level := 0;                {this is a major tick}
    tick_p^.lab.max := size_char(tick_p^.lab.str);
    make_string (tick_p^.lab, tv, log10); {set label string for this tick}

    seqm := seqm + 1;                  {advance to next tick in sequence}
    end;                               {back to create next tick descriptor}
  end;
