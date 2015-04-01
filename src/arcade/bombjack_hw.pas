unit bombjack_hw;

interface
uses {$IFDEF WINDOWS}windows,{$ENDIF}
     nz80,main_engine,controls_engine,ay_8910,gfx_engine,rom_engine,
     pal_engine,sound_engine,qsnapshot;

procedure Cargar_BJ;
procedure bombjack_principal;
function bombjack_iniciar:boolean;
procedure bombjack_reset;
procedure bombjack_cerrar;
//Main CPU
function bombjack_getbyte(direccion:word):byte;
procedure bombjack_putbyte(direccion:word;valor:byte);
//Sound CPU
function sbj_getbyte(direccion:word):byte;
procedure sbj_putbyte(direccion:word;valor:byte);
procedure sbj_outbyte(valor:byte;puerto:word);
procedure bj_despues_instruccion;
//Save/load
procedure bombjack_qsave(nombre:string);
procedure bombjack_qload(nombre:string);

const
        bombjack_rom:array[0..5] of tipo_roms=(
        (n:'09_j01b.bin';l:$2000;p:0;crc:$c668dc30),(n:'10_l01b.bin';l:$2000;p:$2000;crc:$52a1e5fb),
        (n:'11_m01b.bin';l:$2000;p:$4000;crc:$b68a062a),(n:'12_n01b.bin';l:$2000;p:$6000;crc:$1d3ecee5),
        (n:'13.1r';l:$2000;p:$c000;crc:$70e0244d),());
        bombjack_char:array[0..3] of tipo_roms=(
        (n:'03_e08t.bin';l:$1000;p:0;crc:$9f0470d5),(n:'04_h08t.bin';l:$1000;p:$1000;crc:$81ec12e6),
        (n:'05_k08t.bin';l:$1000;p:$2000;crc:$e87ec8b1),());
        bombjack_char16:array[0..3] of tipo_roms=(
        (n:'06_l08t.bin';l:$2000;p:0;crc:$51eebd89),(n:'07_n08t.bin';l:$2000;p:$2000;crc:$9dd98e9d),
        (n:'08_r08t.bin';l:$2000;p:$4000;crc:$3155ee7d),());
        bombjack_sprites:array[0..3] of tipo_roms=(
        (n:'16_m07b.bin';l:$2000;p:0;crc:$94694097),(n:'15_l07b.bin';l:$2000;p:$2000;crc:$013f58f2),
        (n:'14_j07b.bin';l:$2000;p:$4000;crc:$101c858d),());
        bombjack_tiles:tipo_roms=(n:'02_p04t.bin';l:$1000;p:0;crc:$398d4a02);
        bombjack_sonido:tipo_roms=(n:'01_h03t.bin';l:$2000;p:0;crc:$8407917d);

var
 memoria_fondo:array[0..$fff] of byte;
 numero_fondo,comando_sonido:byte;
 fondo_activo,nmi_vblank:boolean;

implementation

procedure Cargar_BJ;
begin
llamadas_maquina.iniciar:=bombjack_iniciar;
llamadas_maquina.bucle_general:=bombjack_principal;
llamadas_maquina.cerrar:=bombjack_cerrar;
llamadas_maquina.reset:=bombjack_reset;
llamadas_maquina.save_qsnap:=bombjack_qsave;
llamadas_maquina.load_qsnap:=bombjack_qload;
end;

function bombjack_iniciar:boolean;
const
      pc_x:array[0..7] of dword=(0, 1, 2, 3, 4, 5, 6, 7);
      pc_y:array[0..7] of dword=(0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8);
      ps_x:array[0..15] of dword=(0, 1, 2, 3, 4, 5, 6, 7,
			8*8+0, 8*8+1, 8*8+2, 8*8+3, 8*8+4, 8*8+5, 8*8+6, 8*8+7);
      ps_y:array[0..15] of dword=(0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8,
			16*8, 17*8, 18*8, 19*8, 20*8, 21*8, 22*8, 23*8);
      pt_x:array[0..31] of dword=(0, 1, 2, 3, 4, 5, 6, 7,
			8*8+0, 8*8+1, 8*8+2, 8*8+3, 8*8+4, 8*8+5, 8*8+6, 8*8+7,
			32*8+0, 32*8+1, 32*8+2, 32*8+3, 32*8+4, 32*8+5, 32*8+6, 32*8+7,
			40*8+0, 40*8+1, 40*8+2, 40*8+3, 40*8+4, 40*8+5, 40*8+6, 40*8+7);
      pt_y:array[0..31] of dword=(0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8,
			16*8, 17*8, 18*8, 19*8, 20*8, 21*8, 22*8, 23*8,
			64*8, 65*8, 66*8, 67*8, 68*8, 69*8, 70*8, 71*8,
			80*8, 81*8, 82*8, 83*8, 84*8, 85*8, 86*8, 87*8);
var
  memoria_temp:array[0..$5fff] of byte;
begin
bombjack_iniciar:=false;
iniciar_audio(false);
screen_init(1,256,256); //Fondo
screen_init(2,256,256,true); //Chars
screen_init(3,256,256,false,true); //Final
iniciar_video(224,256);
//Main CPU
main_z80:=cpu_z80.create(4000000,256);
main_z80.change_ram_calls(bombjack_getbyte,bombjack_putbyte);
//Sound CPU
snd_z80:=cpu_z80.create(3072000,256);
snd_z80.change_ram_calls(sbj_getbyte,sbj_putbyte);
snd_z80.change_io_calls(nil,sbj_outbyte);
snd_z80.init_sound(bj_despues_instruccion);
//Sound Chip
ay8910_0:=ay8910_chip.create(1500000,1);
ay8910_1:=ay8910_chip.create(1500000,1);
ay8910_2:=ay8910_chip.create(1500000,1);
//cargar roms
if not(cargar_roms(@memoria[0],@bombjack_rom[0],'bombjack.zip',0)) then exit;
//cargar roms sonido
if not(cargar_roms(@mem_snd[0],@bombjack_sonido,'bombjack.zip')) then exit;
//informacion adicional de las tiles
if not(cargar_roms(@memoria_fondo[0],@bombjack_tiles,'bombjack.zip')) then exit;
//convertir chars
if not(cargar_roms(@memoria_temp[0],@bombjack_char[0],'bombjack.zip',0)) then exit;
init_gfx(0,8,8,512);
gfx[0].trans[0]:=true;
gfx_set_desc_data(3,0,8*8,0*8,512*8*8,512*2*8*8);
convert_gfx(@gfx[0],0,@memoria_temp[0],@pc_x[0],@pc_y[0],true,false);
//convertir chars16
if not(cargar_roms(@memoria_temp[0],@bombjack_char16[0],'bombjack.zip',0)) then exit;
init_gfx(1,16,16,256);
gfx[1].trans[0]:=true;
gfx_set_desc_data(3,0,32*8,0,1024*8*8,1024*2*8*8);
convert_gfx(@gfx[1],0,@memoria_temp[0],@ps_x[0],@ps_y[0],true,false);
//sprites
if not(cargar_roms(@memoria_temp[0],@bombjack_sprites[0],'bombjack.zip',0)) then exit;
init_gfx(2,16,16,128);
gfx[2].trans[0]:=true;
convert_gfx(@gfx[2],0,@memoria_temp[0],@ps_x[0],@ps_y[0],true,false);
//sprites grandes
init_gfx(3,32,32,32);
gfx[3].trans[0]:=true;
gfx_set_desc_data(3,0,128*8,0*8+$1000*8,1024*8*8+$1000*8,2*1024*8*8+$1000*8);
convert_gfx(@gfx[3],0,@memoria_temp[0],@pt_x[0],@pt_y[0],true,false);
//final
bombjack_reset;
bombjack_iniciar:=true;
end;

procedure bombjack_cerrar;
begin
main_z80.free;
snd_z80.free;
ay8910_0.free;
ay8910_1.free;
ay8910_2.free;
close_audio;
close_video;
end;

procedure bombjack_reset;
begin
main_z80.reset;
snd_z80.reset;
ay8910_0.reset;
ay8910_1.reset;
ay8910_2.reset;
reset_audio;
nmi_vblank:=false;
fondo_activo:=false;
comando_sonido:=0;
numero_fondo:=0;
marcade.in0:=0;
marcade.in1:=0;
marcade.in2:=$f0;
end;

procedure update_video_bombjack;inline;   //330 - 444 fps
var
        x,y,atrib:byte;
        f,nchar,color:word;
begin
  {distribucion de los tiles
        256bytes-->numero del tile referidos al banco grafico
        256bytes-->atributos de color
        ---------->total 512bytes*8 tiles = 4096}
if fondo_activo then actualiza_trozo(0,0,256,256,1,0,0,256,256,3)
  else fill_full_screen(3,0);
for f:=0 to $3ff do begin
  atrib:=memoria[$9400+f];
  color:=atrib and $f;
  if (gfx[0].buffer[f] or buffer_color[color]) then begin
    x:=31-(f shr 5);
    y:=f and $1f;
    nchar:=memoria[$9000+f]+(atrib and $10) shl 4;
    put_gfx_trans(x*8,y*8,nchar,color shl 3,2,0);
    gfx[0].buffer[f]:=false;
  end;
end;
actualiza_trozo(0,0,256,256,2,0,0,256,256,3);
for f:=0 to 24 do begin
   x:=memoria[$9822+(f*4)];
   y:=memoria[$9823+(f*4)];
   nchar:=memoria[$9820+(f*4)];
   atrib:=memoria[$9821+(f*4)];
   color:=(atrib and $1f) shl 3;
   if (nchar and $80)=0 then begin
      put_gfx_sprite(nchar and $7f,color,atrib and $80<>0,atrib and $40<>0,2);
      actualiza_gfx_sprite(x,y,3,2);
   end else begin
      put_gfx_sprite(nchar and $1f,color,false,false,3);
      actualiza_gfx_sprite(x-1,y,3,3);
   end;
end;
actualiza_trozo_final(16,0,224,256,3);
fillchar(buffer_color[0],MAX_COLOR_BUFFER,0);
end;

procedure eventos_bombjack;inline;
begin
if event.arcade then begin
  //p1
  if arcade_input.right[0] then marcade.in0:=(marcade.in0 or 1) else marcade.in0:=(marcade.in0 and $fe);
  if arcade_input.left[0] then marcade.in0:=(marcade.in0 or 2) else marcade.in0:=(marcade.in0 and $fd);
  if arcade_input.up[0] then marcade.in0:=(marcade.in0 or 4) else marcade.in0:=(marcade.in0 and $fb);
  if arcade_input.down[0] then marcade.in0:=(marcade.in0 or 8) else marcade.in0:=(marcade.in0 and $f7);
  if arcade_input.but0[0] then marcade.in0:=(marcade.in0 or $10) else marcade.in0:=(marcade.in0 and $ef);
  //p2
  if arcade_input.right[1] then marcade.in1:=(marcade.in1 or 1) else marcade.in1:=(marcade.in1 and $fe);
  if arcade_input.left[1] then marcade.in1:=(marcade.in1 or 2) else marcade.in1:=(marcade.in1 and $fd);
  if arcade_input.up[1] then marcade.in1:=(marcade.in1 or 4) else marcade.in1:=(marcade.in1 and $fb);
  if arcade_input.down[1] then marcade.in1:=(marcade.in1 or 8) else marcade.in1:=(marcade.in1 and $f7);
  if arcade_input.but0[1] then marcade.in1:=(marcade.in1 or $10) else marcade.in1:=(marcade.in1 and $ef);
  //System
  if arcade_input.coin[0] then marcade.in2:=(marcade.in2 or 1) else marcade.in2:=(marcade.in2 and $fe);
  if arcade_input.coin[1] then marcade.in2:=(marcade.in2 or 2) else marcade.in2:=(marcade.in2 and $fd);
  if arcade_input.start[0] then marcade.in2:=(marcade.in2 or 4) else marcade.in2:=(marcade.in2 and $fb);
  if arcade_input.start[1] then marcade.in2:=(marcade.in2 or 8) else marcade.in2:=(marcade.in2 and $f7);
end;
end;

procedure bombjack_principal;
var
  frame_m,frame_s:single;
  f:byte;
begin
init_controls(false,false,false,true);
frame_s:=main_z80.tframes;
frame_m:=snd_z80.tframes;
while EmuStatus=EsRuning do begin
  for f:=0 to $ff do begin
    //Main CPU
    main_z80.run(frame_m);
    frame_m:=frame_m+main_z80.tframes-main_z80.contador;
    //Sound
    snd_z80.run(frame_s);
    frame_s:=frame_s+snd_z80.tframes-snd_z80.contador;
    if f=239 then begin
      if nmi_vblank then main_z80.pedir_nmi:=PULSE_LINE;
      update_video_bombjack;
      snd_z80.pedir_nmi:=PULSE_LINE;
    end;
  end;
  eventos_bombjack;
  video_sync;
end;
end;

function bombjack_getbyte(direccion:word):byte;
begin
case direccion of
  0..$97ff,$9820..$987f,$c000..$dfff:bombjack_getbyte:=memoria[direccion];
  $b000:bombjack_getbyte:=marcade.in0;
  $b001:bombjack_getbyte:=marcade.in1;
  $b002:bombjack_getbyte:=marcade.in2;
  $b004:bombjack_getbyte:=$c0;
  $b005:bombjack_getbyte:=$50;
end;
end;

procedure cambiar_color(dir:word);inline;
var
  tmp_color:byte;
  color:tcolor;
begin
  tmp_color:=buffer_paleta[dir];
  color.r:=pal4bit(tmp_color);
  color.g:=pal4bit(tmp_color shr 4);
  tmp_color:=buffer_paleta[dir+1];
  color.b:=pal4bit(tmp_color);
  dir:=dir shr 1;
  set_pal_color(color,@paleta[dir]);
  buffer_color[(dir shr 3) and $f]:=true;
end;

procedure cambia_fondo(base:word);inline;
var
    x,y,color,nchar,f:byte;
begin
for f:=0 to $ff do begin
    x:=15-(f shr 4);
    y:=f and $f;
    nchar:=memoria_fondo[base+f];
    color:=memoria_fondo[base+$100+f] shl 3;
    put_gfx(16*x,16*y,nchar,color,1,1);
end;
end;

procedure bombjack_putbyte(direccion:word;valor:byte);
begin
if ((direccion<$8000) or ((direccion>$bfff) and (direccion<$e000))) then exit;
memoria[direccion]:=valor;
case direccion of
        $9000..$97ff:gfx[0].buffer[direccion and $3ff]:=true;
        $9c00..$9cff:if buffer_paleta[direccion and $ff]<>valor then begin
                          buffer_paleta[direccion and $ff]:=valor;
                          cambiar_color(direccion and $fe);
                     end;
        $9e00:begin
                {byte 9e00 --> 76543210
                               XXXXbaaa
                   b--> fondo activo o no
                   aaa--> numero de tile del fondo}
                   fondo_activo:=(valor and $10)<>0;
                   if (fondo_activo and (numero_fondo<>(valor and 7))) then begin
                      numero_fondo:=valor and 7;
                      cambia_fondo(numero_fondo*$200);
                   end;
              end;
        $b000:nmi_vblank:=valor<>0;
        $b004:main_screen.flip_main_screen:=(valor and 1)<>0;
        $b800:comando_sonido:=valor;
end;
end;

function sbj_getbyte(direccion:word):byte;
begin
case direccion of
  0..$1fff,$4000..$43ff:sbj_getbyte:=mem_snd[direccion];
  $6000:begin
          sbj_getbyte:=comando_sonido;
          comando_sonido:=0;
        end;
end;
end;

procedure sbj_putbyte(direccion:word;valor:byte);
begin
if direccion<$2000 then exit;
mem_snd[direccion]:=valor;
end;

procedure sbj_outbyte(valor:byte;puerto:word);
begin
case (puerto and $ff) of
  $00:ay8910_0.Control(valor);
  $01:ay8910_0.Write(valor);
  $10:ay8910_1.Control(valor);
  $11:ay8910_1.Write(valor);
  $80:ay8910_2.Control(valor);
  $81:ay8910_2.Write(valor);
end
end;

procedure bj_despues_instruccion;
begin
  ay8910_0.update;
  ay8910_1.update;
  ay8910_2.update;
end;

procedure bombjack_qsave(nombre:string);
var
  data:pbyte;
  size:word;
  buffer:array[0..3] of byte;
begin
open_qsnapshot_save('bombjack'+nombre);
getmem(data,200);
//CPU
size:=main_z80.save_snapshot(data);
savedata_qsnapshot(data,size);
size:=snd_z80.save_snapshot(data);
savedata_qsnapshot(data,size);
//SND
size:=ay8910_0.save_snapshot(data);
savedata_qsnapshot(data,size);
size:=ay8910_1.save_snapshot(data);
savedata_qsnapshot(data,size);
size:=ay8910_2.save_snapshot(data);
savedata_qsnapshot(data,size);
//MEM
savedata_com_qsnapshot(@memoria[$8000],$8000);
savedata_com_qsnapshot(@mem_snd[$2000],$e000);
//MISC
buffer[0]:=numero_fondo;
buffer[1]:=comando_sonido;
buffer[2]:=byte(fondo_activo);
buffer[3]:=byte(nmi_vblank);
savedata_qsnapshot(@buffer[0],4);
savedata_com_qsnapshot(@buffer_paleta[0],$100*2);
freemem(data);
close_qsnapshot;
end;

procedure bombjack_qload(nombre:string);
var
  data:pbyte;
  buffer:array[0..3] of byte;
  f:byte;
begin
if not(open_qsnapshot_load('bombjack'+nombre)) then exit;
getmem(data,200);
//CPU
loaddata_qsnapshot(data);
main_z80.load_snapshot(data);
loaddata_qsnapshot(data);
snd_z80.load_snapshot(data);
//SND
loaddata_qsnapshot(data);
ay8910_0.save_snapshot(data);
loaddata_qsnapshot(data);
ay8910_1.save_snapshot(data);
loaddata_qsnapshot(data);
ay8910_2.save_snapshot(data);
//MEM
loaddata_qsnapshot(@memoria[$8000]);
loaddata_qsnapshot(@mem_snd[$2000]);
//MISC
loaddata_qsnapshot(@buffer[0]);
numero_fondo:=buffer[0];
comando_sonido:=buffer[1];
fondo_activo:=buffer[2]<>0;
nmi_vblank:=buffer[3]<>0;
loaddata_qsnapshot(@buffer_paleta[0]);
freemem(data);
close_qsnapshot;
for f:=0 to $7f do cambiar_color(f*2);
if fondo_activo then cambia_fondo(numero_fondo*$200);
end;

end.