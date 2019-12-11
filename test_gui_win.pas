{   TEST_GUI_WIN
*
*   Test the window management of the GUI library.
}
program "gui" test_gui_win;
%include 'rend_test_all.ins.pas';
%include 'math.ins.pas';
%include 'gui.ins.pas';

const
  inten_k = 0.7;                       {window color intensity}
  dhue_k = 3.0 / 7.5;                  {hue increment per window}
  sat_k = 0.7;                         {window color saturation}

type
  win_data_t = record                  {our private data stored with each window}
    red, grn, blu: real;               {window background color}
    end;
  win_data_p_t = ^win_data_t;

var
  win_root: gui_win_t;                 {root window object}
  hue: real;                           {hue for next window background color}
  vparms: rend_vect_parms_t;           {vector configuration parameters}
  pparms: rend_poly_parms_t;           {polygon configuration parameters}
  event: rend_event_t;                 {RENDlib event descriptor}

label
  redraw, event_wait, leave;
{
*********************************************************************
*
*   Local subroutine DRAW_WINDOW (WIN, DAT)
*
*   Draw the contents of the window WIN.  DAT is our private application
*   data for this window.
}
procedure draw_window (                {draw contents of window}
  in out  win: gui_win_t;              {window object}
  in out  dat: win_data_t);            {our private app data for this window}
  val_param;

var
  poly: array[1..4] of vect_2d_t;

begin
  rend_set.rgb^ (0.0, 0.0, 0.0);
  rend_set.cpnt_2d^ (0.49, 0.49);
  rend_prim.vect_2d^ (0.49, win.rect.dy - 0.49);
  rend_prim.vect_2d^ (win.rect.dx - 0.49, win.rect.dy - 0.49);
  rend_prim.vect_2d^ (win.rect.dx - 0.49, 0.49);
  rend_prim.vect_2d^ (0.49, 0.49);

  rend_set.rgb^ (1.0, 1.0, 1.0);
  rend_set.cpnt_2d^ (1.49, 1.49);
  rend_prim.vect_2d^ (1.49, win.rect.dy - 1.49);
  rend_prim.vect_2d^ (win.rect.dx - 1.49, win.rect.dy - 1.49);
  rend_prim.vect_2d^ (win.rect.dx - 1.49, 1.49);
  rend_prim.vect_2d^ (1.49, 1.49);

  if not gui_win_clip (win, 2.0, win.rect.dx - 2.0, 2.0, win.rect.dy - 2.0)
    then return;

  rend_set.rgb^ (dat.red, dat.grn, dat.blu);
  rend_prim.clear_cwind^;

  rend_set.rgb^ (dat.red * 1.1, dat.grn * 1.1, dat.blu * 1.1);
  poly[1].x := 2.0;
  poly[1].y := win.rect.dy * 0.5;
  poly[2].x := win.rect.dx * 0.5;
  poly[2].y := 2.0;
  poly[3].x := win.rect.dx - 2.0;
  poly[3].y := win.rect.dy * 0.5;
  poly[4].x := win.rect.dx * 0.5;
  poly[4].y := win.rect.dy - 2.0;
  rend_prim.poly_2d^ (4, poly);
  end;
{
*********************************************************************
*
*   Local function NEW_WINDOW (PARENT, X, Y, DX, DY)
*
*   Make a new window and return the pointer to the new window.  PARENT
*   is the parent window.
}
function new_window (                  {make new window}
  in out  parent: gui_win_t;           {parent window}
  in      x, y, dx, dy: real)          {new window coordinates within parent window}
  :gui_win_p_t;                        {pointer to newly created window}
  val_param;

var
  win_p: gui_win_p_t;                  {pointer to new window object}
  dat_p: win_data_p_t;                 {pointer to our private app data}

begin
  gui_win_alloc_static (parent, sizeof(win_p^), win_p); {alloc mem for window obj}
  gui_win_child (win_p^, parent, x, y, dx, dy); {create new child window}

  gui_win_alloc_static (win_p^, sizeof(dat_p^), dat_p); {alloc private window data}
  math_ihs_rgb (                       {make RGB window color from IHS}
    inten_k, hue, sat_k,               {IHS color}
    dat_p^.red, dat_p^.grn, dat_p^.blu); {resulting RGB color}
  hue := hue + dhue_k;                 {update hue for next window}
  gui_win_set_app_pnt (win_p^, dat_p); {set pnt to our private data for this win}
  gui_win_set_draw (                   {set draw routine for this window}
    win_p^, univ_ptr(addr(draw_window)));
  new_window := win_p;                 {return pointer to new window}
  end;
{
*********************************************************************
*
*   Local subroutine MAKE_WINDOWS
*
*   Create the GUI library windows.
}
procedure make_windows;

var
  win_p: gui_win_p_t;                  {scratch window pointer}
  dat_p: win_data_p_t;                 {pointer to our private window data}

begin
  hue := 0.0;                          {init hue for first window}
{
*   Create root window.
}
  gui_win_root (win_root);             {create root window to cover whole device}
  gui_win_alloc_static (               {allocate our private data for this window}
    win_root, sizeof(dat_p^), dat_p);
  math_ihs_rgb (                       {make background color for this window}
    inten_k, hue, sat_k,               {intensity, hue, saturation}
    dat_p^.red, dat_p^.grn, dat_p^.blu); {resulting RGB color value}
  hue := hue + dhue_k;                 {update hue for next window}
  gui_win_set_app_pnt (win_root, dat_p); {set pnt to our private data for this win}
  gui_win_set_draw (                   {set draw routine for this window}
    win_root, univ_ptr(addr(draw_window)));
{
*   Create subordinate windows.
}
  win_p := new_window (                {create new window}
    win_root,                          {parent window to new window}
    win_root.rect.dx * 0.1,            {left X}
    win_root.rect.dy * 0.2,            {bottom Y}
    win_root.rect.dx * 0.7,            {X size}
    win_root.rect.dy * 0.5);           {Y size}
  end;
{
*********************************************************************
*
*   Start of main routine.
}
begin
{
*   Initialize RENDlib.
}
  rend_test_cmline ('TEST_GUI_WIN');   {process command line}
  rend_test_cmline_done;               {abort on unrecognized command line options}
  rend_test_graphics_init;             {init RENDlib, configure, enter graphics}
  rend_test_bitmaps (                  {create bitmaps and init interpolants}
    [ rend_test_comp_red_k,
      rend_test_comp_grn_k,
      rend_test_comp_blu_k
      ]
    );

  if not set_bits_vis then begin       {no -BITS_VIS on command line ?}
    rend_set.min_bits_vis^ (24.0);     {request full color}
    end;

  rend_test_clip_all_off;              {we won't use REND_TEST clip window}
  rend_event_req_stdin_line (false);   {ignore standard input}

  rend_get.vect_parms^ (vparms);
  vparms.poly_level := rend_space_none_k; {disable vector to polygon conversion}
  vparms.subpixel := false;            {disable vector subpixel addressing}
  rend_set.vect_parms^ (vparms);

  rend_get.poly_parms^ (pparms);
  pparms.subpixel := false;            {disable polygon subpixel addressing}
  rend_set.poly_parms^ (pparms);

  make_windows;                        {create the GUI library windows}
{
*   Back here to re-draw everything.
}
redraw:
  gui_win_draw (win_root, 0.0, 1.0E6, 0.0, 1.0E6); {redraw all the windows}
{
*   Done drawing.  Now wait for an event to occurr.
}
  rend_set.enter_level^ (0);           {make sure we are out of graphics mode}

event_wait:                            {back here to wait for another event}
  rend_event_get (event);              {get next RENDlib event}
  case event.ev_type of                {what kind of event is this ?}
{
*   We exit RENDlib on all these events.
}
rend_ev_close_k,                       {draw device was closed}
rend_ev_close_user_k: begin            {user aksed to close device}
  goto leave;
  end;
{
*   The draw area size has changed, and we can now redraw all the pixels.
}
rend_ev_resize_k,
rend_ev_wiped_resize_k: begin
  rend_test_resize;                    {update REND_TEST state to new window size}
  gui_win_delete (win_root);           {delete our whole window set}
  make_windows;                        {re-create the window set with the new size}
  goto redraw;                         {re-draw all the window contents}
  end;
{
*   A rectangular region of pixels was previously corrupted, and we are now
*   able to draw into them again.
}
rend_ev_wiped_rect_k: begin
  rend_set.enter_rend^;                {enter graphics mode}
  gui_win_draw (                       {re-draw the rectangle that got wiped out}
    win_root,                          {top window of tree to redraw}
    event.wiped_rect.x,                {left}
    event.wiped_rect.x + event.wiped_rect.dx, {right}
    win_root.rect.dy - (event.wiped_rect.y + event.wiped_rect.dy), {bottom}
    win_root.rect.dy - event.wiped_rect.y); {top}
  end;
{
*   Not an event we care about.  All these events are just ignored.
}
    end;                               {end of event type cases}
  goto event_wait;                     {back and wait for another event}
{
*   All done with program.  Clean up and then return indicating no refresh
*   is needed.
}
leave:
  gui_win_delete (win_root);           {delete all our GUI library windows}
  rend_end;                            {completely close down RENDlib}
  end;
