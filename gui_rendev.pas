{   Routines to manage the RENDlib device.
}
module gui_rendev;
define gui_rendev_def;
define gui_rendev_setup;
define gui_rendev_resize;
define gui_rendev_xf2d;
%include 'gui2.ins.pas';
{
********************************************************************************
*
*   Subroutine GUI_RENDEV_DEF (DEV)
*
*   Initialize the RENDlib device data for GUI library use, DEV.  This must
*   always be the first use of DEV.  Values are set to defaults, but can be
*   altered before the RENDlib device is used by the GUI library.
}
procedure gui_rendev_def (             {set GUI lib RENDlib dev parameters to default}
  out     dev: gui_rendev_t);          {returned set to default or benign values}
  val_param;

begin
  dev.text_minpix := 13.0;             {min text size in pixels}
  dev.text_minfrx := 1.0 / 90.0;       {min text size, fraction of X dimension}
  dev.text_minfry := 1.0 / 65.0;       {min text size, fraction of y dimension}

  dev.iterps := [                      {interpolants required by GUI library}
    rend_iterp_red_k,
    rend_iterp_grn_k,
    rend_iterp_blu_k];
  end;
{
********************************************************************************
*
*   Subroutine GUI_RENDEV_SETUP (DEV)
*
*   Set up the current RENDlib device and save state about it in DEV.  Some
*   state in DEV indicates how to set up the device.  The RENDlib device will be
*   set up as required by the GUI library.
*
*   DEV must have been initialized with GUI_RENDEV_DEV, then possibly customized
*   with additional calls to GUI_RENDEV_SET_xxx routines.
}
procedure gui_rendev_setup (           {setup RENDlib device, save related state}
  in out  dev: gui_rendev_t);          {GUI lib state about the RENDlib device}
  val_param;

var
  it: rend_iterp_k_t;                  {current interpolant}

begin
  rend_set.enter_rend^;                {make sure in graphics mode}

  rend_get.dev_id^ (dev.id);           {save RENDlib device ID}

  rend_get.text_parms^ (dev.tparm);    {get existing text control parameters}
  dev.tparm.width := 0.72;
  dev.tparm.height := 1.0;
  dev.tparm.slant := 0.0;
  dev.tparm.rot := 0.0;
  dev.tparm.lspace := 0.7;
  dev.tparm.coor_level := rend_space_2d_k;
  dev.tparm.poly := false;

  rend_get.poly_parms^ (dev.pparm);    {get default polygon control parameters}
  dev.pparm.subpixel := true;
  rend_set.poly_parms^ (dev.pparm);    {set our new "base" polygon control parms}

  rend_get.vect_parms^ (dev.vparm);    {get default vector control parameters}
  dev.vparm.width := 2.0;
  dev.vparm.poly_level := rend_space_none_k;
  dev.vparm.subpixel := false;
  rend_set.vect_parms^ (dev.vparm);    {set our new "base" vector control parameters}

  rend_set.alloc_bitmap_handle^ (      {create handle for our software bitmap}
    rend_scope_dev_k,                  {deallocate handle when device closed}
    dev.bitmap_rgba);                  {returned bitmap handle}
  dev.bitmap_alloc := false;           {indicate no pixels allocated for bitmaps}
{
*   Set up the mandatory interpolants.  These are red, green, and blue.
}
  dev.rgbasz := 0;                     {init RGBA pixel size}

  rend_set.iterp_bitmap^ (             {connect interpolant to bitmap}
    rend_iterp_red_k, dev.bitmap_rgba, dev.rgbasz);
  dev.rgbasz := dev.rgbasz + 1;        {update pixel size to include this interpolant}
  dev.iterps := dev.iterps + [rend_iterp_red_k]; {make sure this interpolant in our list}

  rend_set.iterp_bitmap^ (             {connect interpolant to bitmap}
    rend_iterp_grn_k, dev.bitmap_rgba, dev.rgbasz);
  dev.rgbasz := dev.rgbasz + 1;        {update pixel size to include this interpolant}
  dev.iterps := dev.iterps + [rend_iterp_grn_k]; {make sure this interpolant in our list}

  rend_set.iterp_bitmap^ (             {connect interpolant to bitmap}
    rend_iterp_blu_k, dev.bitmap_rgba, dev.rgbasz);
  dev.rgbasz := dev.rgbasz + 1;        {update pixel size to include this interpolant}
  dev.iterps := dev.iterps + [rend_iterp_blu_k]; {make sure this interpolant in our list}
{
*   Set up alpha if enabled.
}
  if rend_iterp_alpha_k in dev.iterps then begin {alpha enabled ?}
    rend_set.iterp_bitmap^ (rend_iterp_alpha_k, dev.bitmap_rgba, dev.rgbasz);
    dev.rgbasz := dev.rgbasz + 1;      {account for alpha in RGBA pixel size}
    end;
{
*   Set up Z if enabled.
}
  dev.zsz := 0;                        {init to Z not in use}
  if rend_iterp_z_k in dev.iterps then begin {Z enabled ?}
    rend_set.alloc_bitmap_handle^ (    {create handle for Z bitmap}
      rend_scope_dev_k, dev.bitmap_z);
    rend_set.iterp_bitmap^ (           {connect Z interpolant to its bitmap}
      rend_iterp_z_k, dev.bitmap_z, 0);
    dev.zsz := dev.zsz + 2;            {set Z bitmap pixel size}
    end;
{
*   Turn on all the interpolants that are in use.
}
  for it := firstof(it) to lastof(it) do begin {loop over all possible interpolants}
    if it in dev.iterps then begin     {this interpolant is in use ?}
      rend_set.iterp_on^ (it, true);   {enable this interpolant}
      end;
    end;
{
*   Other initialization.
}
  rend_set.update_mode^ (rend_updmode_buffall_k); {buffer SW updates for speed sake}

  rend_set.min_bits_vis^ (24.0);       {try for high color resolution}

  rend_set.event_req_close^ (true);    {enable non-key events}
  rend_set.event_req_wiped_resize^ (true);
  rend_set.event_req_wiped_rect^ (true);
  rend_set.event_req_pnt^ (true);

  gui_events_init_key;                 {enable key events required by GUI library}

  rend_set.exit_rend^;                 {pop back to previous graphics mode level}
  gui_rendev_resize (dev);             {adjust to current device dimensions}
  end;
{
********************************************************************************
*
*   Subroutine GUI_RENDEV_RESIZE (DEV)
*
*   Adjust to the current RENDlib device size.  Any existing software bitmaps
*   are deallocated.  New bitmaps are always allocated to match the current
*   device size.
}
procedure gui_rendev_resize (          {adjust to RENDlib device size}
  in out  dev: gui_rendev_t);          {GUI lib state about RENDlib device}
  val_param;

var
  r: real;                             {scratch floating point}
  ii: sys_int_machine_t;               {scratch integer}

begin
  rend_set.enter_rend^;                {make sure we are in graphics mode}
  rend_set.dev_reconfig^;              {look at device parameters and reconfigure}
  rend_get.image_size^ (               {get size and aspect ratio}
    dev.pixx, dev.pixy,                {number of pixels in X and Y dimensions}
    dev.aspect);                       {aspect ratio of whole device}
{
*   Deallocate any existing structures fixed to the old size.
}
  if dev.bitmap_alloc then begin       {bitmaps previously allocated ?}
    rend_set.dealloc_bitmap^ (dev.bitmap_rgba); {dealloc bitmap for RGBA components}
    if dev.zsz > 0 then begin          {Z bitmap in use ?}
      rend_set.dealloc_bitmap^ (dev.bitmap_z); {deallocate it}
      end;
    end;
{
*   Allocate new bitmaps to match the new device dimensions.
}
  rend_set.alloc_bitmap^ (             {allocate mandatory RGBA bitmap}
    dev.bitmap_rgba,                   {bitmap handle}
    dev.pixx, dev.pixy,                {bitmap dimensions in pixels}
    dev.rgbasz,                        {min required bytes/pixel}
    rend_scope_dev_k);                 {deallocate on device close}

  if dev.zsz > 0 then begin            {Z bitmap required ?}
    rend_set.alloc_bitmap^ (           {allocate the optional Z bitmap}
      dev.bitmap_z,                    {bitmap handle}
      dev.pixx, dev.pixy,              {bitmap dimensions in pixels}
      dev.zsz,                         {min required bytes/pixel}
      rend_scope_dev_k);               {deallocate on device close}
    end;

  dev.bitmap_alloc := true;            {indicate bitmaps are allocated}
{
*   Set the text size.  All the other text parameters are already set in
*   DEV.TPARM.
}
  r := max(                            {min text size according to all rules}
    dev.text_minpix,                   {abs min, pixels}
    dev.pixx * dev.text_minfrx,        {min as fraction of X dimension}
    dev.pixy * dev.text_minfry);       {min as fraction of Y dimension}
  ii := trunc(r + 0.999);              {round up to full integer}
  if not odd(ii) then begin            {even number of pixels ?}
    ii := ii + 1;                      {make odd, one row will be in center}
    end;
  dev.tparm.size := ii;                {set overall text size}
  rend_set.text_parms^ (dev.tparm);    {update RENDlib state}

  rend_set.exit_rend^;                 {pop back to previous graphics mode level}
{
*   Set up the 2D transform so that 0,0 is the lower left corner, X is to the
*   right, Y up, and both are in units of pixels.
}
  gui_rendev_xf2d (dev);
  end;
{
********************************************************************************
*
*   Subroutine GUI_RENDEV_XF2D (DEV)
*
*   Set the current RENDlib device 2D transform to the standard assumed by the
*   GUI library.  That is 0,0 in the lower left corner, X to the right, Y up,
*   and both in units of pixels.
*
*   The device size in DEV is assumed to be correct.
}
procedure gui_rendev_xf2d (            {set GUI lib standard 2D transform on RENDlib dev}
  in out  dev: gui_rendev_t);          {GUI lib state about the RENDlib device}
  val_param;

var
  xb, yb, ofs: vect_2d_t;              {2D transform}

begin
  rend_set.enter_rend^;                {make sure we are in graphics mode}

  xb.y := 0.0;                         {fill in fixed part of transform}
  yb.x := 0.0;

  if dev.aspect >= 1.0
    then begin                         {device is wider than tall}
      xb.x := (2.0 * dev.aspect) / dev.pixx;
      yb.y := 2.0 / dev.pixy;
      ofs.x := -dev.aspect;
      ofs.y := -1.0;
      end
    else begin                         {device is taller than wide}
      xb.x := 2.0 / dev.pixx;
      yb.y := (2.0 / dev.aspect) / dev.pixy;
      ofs.x := -1.0;
      ofs.y := -1.0 / dev.aspect;
      end
    ;

  rend_set.xform_2d^ (xb, yb, ofs);    {set new RENDlib transform for this window}
  rend_set.exit_rend^;                 {pop back to previous graphics mode level}
  end;
