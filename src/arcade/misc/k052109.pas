unit k052109;

interface
uses {$IFDEF WINDOWS}windows,{$ENDIF}main_engine,gfx_engine;

type
  t_k052109_cb=procedure(layer,bank:word;var code:word;var color:word;var flags:word;var priority:word);
  k052109_chip=class
        constructor create(pant1,pant2,pant3:byte;call_back:t_k052109_cb;rom:pbyte;rom_size:dword);
        destructor free;
    public
        rmrd_line:byte;
        scroll_x:array[1..2,0..$ff] of word;
        scroll_y:array[1..2,0..$1ff] of byte;
        scroll_tipo:array[1..2] of byte;
        function word_r(direccion:word):word;
        procedure word_w(direccion,valor:word;access:boolean);
        function read(direccion:word):byte;
        procedure write(direccion:word;val:byte);
        procedure update_scroll;
        procedure draw_tiles;
        procedure reset;
        function is_irq_enabled:boolean;
    protected
        ram:array[0..$5fff] of byte;
        tileflip_enable,romsubbank,scrollctrl:byte;
        charrombank,charrombank_2:array[0..3] of byte;
        pant:array[0..2] of byte;
        irq_enabled,has_extra_video_ram:boolean;
        char_rom:pbyte;
        char_size:dword;
        k052109_cb:t_k052109_cb;
        procedure update_all_tile(layer:byte);
        procedure calc_scroll_1;
        procedure calc_scroll_2;
  end;

var
  k052109_0:k052109_chip;

implementation

constructor k052109_chip.create(pant1,pant2,pant3:byte;call_back:t_k052109_cb;rom:pbyte;rom_size:dword);
const
  pc_x:array[0..7] of dword=(0, 1, 2, 3, 4, 5, 6, 7);
  pc_y:array[0..7] of dword=(0*32, 1*32, 2*32, 3*32, 4*32, 5*32, 6*32, 7*32);
begin
  self.has_extra_video_ram:=false;
  self.pant[0]:=pant1;
  self.pant[1]:=pant2;
  self.pant[2]:=pant3;
  self.k052109_cb:=call_back;
  if (rom<>nil) then begin
		self.char_rom:=rom;
		self.char_size:=rom_size;
	end;
  init_gfx(0,8,8,char_size div 32);
  gfx_set_desc_data(4,0,8*32,24,16,8,0);
  convert_gfx(0,0,rom,@pc_x[0],@pc_y[0],false,false);
  gfx[0].trans[0]:=true;
end;

destructor k052109_chip.free;
begin
end;

procedure k052109_chip.reset;
var
  f:byte;
begin
	self.rmrd_line:=CLEAR_LINE;
	self.irq_enabled:=false;
	self.romsubbank:=0;
	self.scrollctrl:=0;
	self.has_extra_video_ram:=false;
  self.tileflip_enable:=0;
	for f:=0 to 3 do begin
		self.charrombank[f]:=0;
		self.charrombank_2[f]:=0;
	end;
end;

function k052109_chip.read(direccion:word):byte;
var
  code,color,flags,priority,bank,addr:word;
begin
	if (self.rmrd_line=CLEAR_LINE) then begin
		read:=self.ram[direccion];
	end else begin  // Punk Shot and TMNT read from 0000-1fff, Aliens from 2000-3fff */
	 //	assert (m_char_size != 0);
		code:=(direccion and $1fff) shr 5;
		color:=self.romsubbank;
		flags:=0;
		priority:=0;
		bank:=self.charrombank[(color and $0c) shr 2] shr 2;   // discard low bits (TMNT) */
		bank:=bank or (self.charrombank_2[(color and $0c) shr 2] shr 2); // Surprise Attack uses this 2nd bank in the rom test
	  if self.has_extra_video_ram then code:=code or (color shl 8) // kludge for X-Men */
	    else k052109_cb(0,bank,code,color,flags,priority);
		addr:=(code shl 5)+(direccion and $1f);
		addr:=addr and (char_size-1);
//      logerror("%04x: off = %04x sub = %02x (bnk = %x) adr = %06x\n", space.device().safe_pc(), offset, m_romsubbank, bank, addr);
		read:=self.char_rom[addr];
	end;
end;

procedure k052109_chip.write(direccion:word;val:byte);
var
  dirty:byte;
  i:word;
begin
if ((direccion and $1fff)<$1800) then begin // tilemap RAM */
		if (direccion>=$4000) then self.has_extra_video_ram:=true;  // kludge for X-Men */
		self.ram[direccion]:=val;
		//m_tilemap[(offset & 0x1800) >> 11]->mark_tile_dirty(offset & 0x7ff);
end	else begin   // control registers
		self.ram[direccion]:=val;
    case direccion of
      $1c80:self.scrollctrl:=val;
      $1d00:self.irq_enabled:=(val and $04)<>0; // bit 2 = irq enable * the custom chip can also generate NMI and FIRQ, for use with a 6809 */
      $1d80:begin
              dirty:=0;
			        if (self.charrombank[0]<>(val and $0f)) then dirty:=dirty or 1;
			        if (self.charrombank[1]<>((val shr 4) and $0f)) then dirty:=dirty or 2;
			        if (dirty<>0) then begin
				        self.charrombank[0]:=val and $0f;
				        self.charrombank[1]:=(val shr 4) and $0f;
				        //for i:=0 to $17ff do begin
				        //	int bank = (m_ram[i]&0x0c) >> 2;
				        //	if ((bank == 0 && (dirty & 1)) || (bank == 1 && (dirty & 2)))
                    {
						        m_tilemap[(i & 0x1800) >> 11]->mark_tile_dirty(i & 0x7ff);
					          }
                //end;
			        end;
            end;
      $1e00,$3e00:self.romsubbank:=val; // Surprise Attack uses offset 0x3e00
      $1e80:begin
			          //m_tilemap[0]->set_flip((data & 1) ? (TILEMAP_FLIPY | TILEMAP_FLIPX) : 0);
			          //m_tilemap[1]->set_flip((data & 1) ? (TILEMAP_FLIPY | TILEMAP_FLIPX) : 0);
			          //m_tilemap[2]->set_flip((data & 1) ? (TILEMAP_FLIPY | TILEMAP_FLIPX) : 0);
			          if (self.tileflip_enable<>((val and $06) shr 1)) then begin
				          self.tileflip_enable:= ((val and $06) shr 1);
				          //m_tilemap[0]->mark_all_dirty();
				          //m_tilemap[1]->mark_all_dirty();
				          //m_tilemap[2]->mark_all_dirty();
			          end;
            end;
      $1f00:begin
                dirty:=0;
			          if (self.charrombank[2]<>(val and $0f)) then dirty:=dirty or 1;
			          if (self.charrombank[3]<>((val shr 4) and $0f)) then dirty:=dirty or 2;
			          if (dirty<>0) then begin
				          self.charrombank[2]:=val and $0f;
				          self.charrombank[3]:=(val shr 4) and $0f;
				          //for (i = 0; i < 0x1800; i++)
				          {
					          int bank = (m_ram[i] & 0x0c) >> 2;
					          if ((bank == 2 && (dirty & 1)) || (bank == 3 && (dirty & 2)))
						        m_tilemap[(i & 0x1800) >> 11]->mark_tile_dirty(i & 0x7ff);
				          }
			          end;
            end;
      $3d80:begin // Surprise Attack uses offset 0x3d80 in rom test
			            // mirroring this write, breaks Surprise Attack in game tilemaps
                self.charrombank_2[0]:=val and $0f;
			          self.charrombank_2[1]:=(val shr 4) and $0f;
            end;
      $3f00:begin // Surprise Attack uses offset 0x3f00 in rom test
			// mirroring this write, breaks Surprise Attack in game tilemaps
			          self.charrombank_2[2]:=val and $0f;
			          self.charrombank_2[3]:=(val shr 4) and $0f;
            end;
    end;
end;
end;

function k052109_chip.word_r(direccion:word):word;
begin
	word_r:=self.read(direccion+$2000) or (self.read(direccion) shl 8);
end;

procedure k052109_chip.word_w(direccion,valor:word;access:boolean);
begin
if access then self.write(direccion+$2000,valor and $ff)
  else self.write(direccion,valor shr 8);
end;

function k052109_chip.is_irq_enabled:boolean;
begin
  is_irq_enabled:=self.irq_enabled;
end;

procedure k052109_chip.update_all_tile(layer:byte);
var
  f,pos_x,pos_y,nchar,color,bank:word;
  flip_x,flip_y:boolean;
  flags,priority:word;
const
  video_const:array[0..2,0..2] of word=(
  (0,$2000,$4000),($800,$2800,$4800),($1000,$3000,$5000));
begin
for f:=0 to $7ff do begin
  pos_x:=f mod 64;
  pos_y:=f div 64;
	nchar:=self.ram[f+video_const[layer,1]]+256*self.ram[f+video_const[layer,2]];
	color:=self.ram[f+video_const[layer,0]];
	flags:=0;
	priority:=0;
	bank:=self.charrombank[(color and $0c) shr 2];
	if self.has_extra_video_ram then bank:=(color and $0c) shr 2; // kludge for X-Men */
	color:=(color and $f3) or ((bank and $03) shl 2);
	bank:=bank shr 2;
	self.k052109_cb(layer,bank,nchar,color,flags,priority);
  flip_x:=(flags and 1)<>0;
  flip_y:=(flags and 2)<>0;
	// if the callback set flip X but it is not enabled, turn it off */
	if ((self.tileflip_enable and 1)=0) then flip_x:=false;
	// if flip Y is enabled and the attribute but is set, turn it on */
	if (((color and $02)<>0) and ((self.tileflip_enable and 2)<>0)) then flip_y:=true;
  put_gfx_trans_flip(pos_x*8,pos_y*8,nchar,color shl 4,self.pant[layer],0,flip_x,flip_y);
	//tileinfo.category = priority;
end;
end;

procedure k052109_chip.calc_scroll_1;
var
  xscroll,yscroll,offs:word;
begin
if ((self.scrollctrl and $03)=$02) then begin
    yscroll:=self.ram[$180c];
		self.scroll_y[1,0]:=yscroll;
		for offs:=0 to $ff do begin
			xscroll:=self.ram[$1a00+(2*(offs and $fff8))]+256*self.ram[$1a00+(2*(offs and $fff8)+1)];
			xscroll:=xscroll-6;
      self.scroll_x[1,(offs+yscroll) and $ff]:=xscroll;
		end;
    self.scroll_tipo[1]:=0;
	end else if ((self.scrollctrl and $03)=$03) then begin
		yscroll:=self.ram[$180c];
		self.scroll_y[1,0]:=yscroll;
		for offs:=0 to $ff do begin
			xscroll:=self.ram[$1a00+(2*offs)]+256*self.ram[$1a00+(2*offs+1)];
			xscroll:=xscroll-6;
      self.scroll_x[1,(offs+yscroll) and $ff]:=xscroll;
		end;
    self.scroll_tipo[1]:=1;
	end else if ((self.scrollctrl and $04)=$04) then begin
		//UINT8 *scrollram = &m_ram[0x1800];

		//m_tilemap[1]->set_scroll_rows(1);
		//m_tilemap[1]->set_scroll_cols(512);
		//xscroll = m_ram[0x1a00] + 256 * m_ram[0x1a01];
		//xscroll -= 6;
		//m_tilemap[1]->set_scrollx(0, xscroll);
		//for (offs = 0; offs < 512; offs++)
		{
			yscroll = scrollram[offs / 8];
			m_tilemap[1]->set_scrolly((offs + xscroll) & 0x1ff, yscroll);
		}
    self.scroll_tipo[1]:=2;
	end else begin
    self.scroll_x[1,0]:=(self.ram[$1a00]+(self.ram[$1a01] shl 8))-6;
		self.scroll_y[1,0]:=self.ram[$180c];
    self.scroll_tipo[1]:=3;
	end;
end;

procedure k052109_chip.calc_scroll_2;
var
  xscroll,yscroll,offs:word;
begin
if ((self.scrollctrl and $18)=$10) then begin
    yscroll:=self.ram[$380c];
		self.scroll_y[2,0]:=yscroll;
		for offs:=0 to $ff do begin
			xscroll:=self.ram[$3a00+(2*(offs and $fff8))]+256*self.ram[$3a00+(2*(offs and $fff8)+1)];
			xscroll:=xscroll-6;
      self.scroll_x[2,(offs+yscroll) and $ff]:=xscroll;
		end;
    self.scroll_tipo[2]:=0;
	end else if ((self.scrollctrl and $18)=$18) then begin
    yscroll:=self.ram[$380c];
		self.scroll_y[2,0]:=yscroll;
		for offs:=0 to $ff do begin
			xscroll:=self.ram[$3a00+(2*offs)]+256*self.ram[$3a00+(2*offs+1)];
			xscroll:=xscroll-6;
      self.scroll_x[2,(offs+yscroll) and $ff]:=xscroll;
		end;
    self.scroll_tipo[2]:=1;
	end else if ((self.scrollctrl and $20)=$20) then begin
		//UINT8 *scrollram = &m_ram[0x3800];

		//m_tilemap[2]->set_scroll_rows(1);
		//m_tilemap[2]->set_scroll_cols(512);
		//xscroll = m_ram[0x3a00] + 256 * m_ram[0x3a01];
		//xscroll -= 6;
		//m_tilemap[2]->set_scrollx(0, xscroll);
		//for (offs = 0; offs < 512; offs++)
		{
			yscroll = scrollram[offs / 8];
			m_tilemap[2]->set_scrolly((offs + xscroll) & 0x1ff, yscroll);
		}
    self.scroll_tipo[2]:=2;
	end else begin
    self.scroll_x[2,0]:=(self.ram[$3a00]+(self.ram[$3a01] shl 8))-6;
		self.scroll_y[2,0]:=self.ram[$380c];
    self.scroll_tipo[2]:=3;
	end;
end;

procedure k052109_chip.draw_tiles;
begin
  self.update_all_tile(0);
  self.update_all_tile(1);
  self.update_all_tile(2);
end;

procedure k052109_chip.update_scroll;
begin
  self.calc_scroll_1;
  self.calc_scroll_2;
end;

end.
