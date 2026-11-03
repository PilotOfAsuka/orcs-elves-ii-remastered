// Exact Java int32 pixel kernels. Pure buffer arithmetic; no DOM or game rules.
(function(root) {
  function decode(text) {
    const raw=atob(text), bytes=new Uint8Array(raw.length);
    for(let i=0;i<raw.length;i++) bytes[i]=raw.charCodeAt(i);
    return new Int32Array(bytes.buffer);
  }
  function encode(words) {
    const bytes=new Uint8Array(words.buffer,words.byteOffset,words.byteLength);
    let raw='';
    for(let i=0;i<bytes.length;i+=32768) raw+=String.fromCharCode(...bytes.subarray(i,i+32768));
    return btoa(raw);
  }
  function render(pixels,texels,commands) {
    let c=0;
    while(c<commands.length) {
      const mode=commands[c++];
      if(mode===10){const start=commands[c++],rows=commands[c++],width=commands[c++];
        const row=commands.subarray(c,c+width);c+=width;
        for(let y=0;y<rows;y++)pixels.set(row,start+y*width);
        continue;
      }
      let pixel=commands[c++],position=commands[c++];
      const step=commands[c++],stride=commands[c++],count=commands[c++],pal=c;c+=16;
      for(let n=0;n<count;n++) {
        if(pixel<0||pixel>=pixels.length)throw Error('pixel bounds');
        let color=0;
        if(mode!==8) {
          const index=position>>(mode===-1?12:13);
          if(index<0||index>=texels.length)throw Error('texture bounds');
          const texel=mode===-1?texels[index]:(texels[index]>>((position>>10)&4))&15;
          if(texel<0||texel>=16)throw Error('palette bounds');
          color=commands[pal+texel];
        }
        const old=pixels[pixel];
        switch(mode) {
          case -1:case 0:pixels[pixel]=color;break;
          case 1:pixels[pixel]=0xff000000|(((old&0xfefefe)>>1)+((old&0xfcfcfc)>>2)+color);break;
          case 3:pixels[pixel]=0xff000000|(color+((old&0xfcfcfc)>>2));break;
          case 4:{const sum=((old&0xfefefe)+color)|0, carry=sum&0x1010100;
            pixels[pixel]=(sum&0xfffefefe)|(carry>>1)|(carry>>2)|(carry>>3);break;}
          case 8:{const grey=((((old>>16)&255)*3+((old>>8)&255)*6+(old&255))/20)|0;
            pixels[pixel]=0xff000000|(grey<<16)|(grey<<8)|grey;break;}
          case 9:pixels[pixel]=0xff000000|(((((old>>16)&255)*((color>>16)&255))<<8)&0xff0000)|((((old>>8)&255)*((color>>8)&255))&0xff00)|((((old&255)*(color&255))>>8)&255);break;
          default:throw Error('unsupported pixel mode');
        }
        if(mode!==8)position=(position+step)|0;
        pixel=(pixel+stride)|0;
      }
    }
    return pixels;
  }
  function wallColumns(p,pixels,texels) {
    const v=p.vertices,depth=p.depth,lo=p.lower,hi=p.upper,wrap=x=>x|0;
    let extent=wrap(v[3]-v[0]);
    if(extent<=0)return {empty:0,depth};
    extent=wrap(Math.trunc(2147483647/extent)<<1);
    const sy=wrap(Number((BigInt(wrap(v[4]-v[1]))*BigInt(extent))>>16n));
    const su=wrap(Number((BigInt(wrap(v[5]-v[2]))*BigInt(extent))>>16n));
    let x=Math.max(wrap(v[0]+65535)>>16,lo[0]),end=Math.min(wrap(v[3]+65535)>>16,hi[0]);
    const delta=wrap((x<<16)-v[0]);
    let u=wrap(v[2]+wrap(Number((BigInt(delta)*BigInt(su))>>16n)));
    let y=wrap(v[1]+wrap(Number((BigInt(delta)*BigInt(sy))>>16n)));
    let empty=1,s3=p.texture,s2=p.texture2,flipped=0;
    while(x<end) {
      let distance=wrap(Math.trunc(0x40000000/y)<<2);
      const column=wrap(Number((BigInt(u)*BigInt(distance))>>32n))&63;
      if(distance<=depth[x]) {
        if((p.flags&0x10000)===0)depth[x]=distance;
        distance>>=3;
        let texel=wrap(s3+(column<<6)),height=p.multi?p.ceiling:64,screen=-1;
        const floor=p.multi&&((p.flags&0x2000)!==0)?64:p.floor;
        if(p.multi)screen=wrap(p.center-(wrap(Math.imul(wrap(height-p.camera+p.offset),y)+32768)>>17));
        while(height>floor) {
          let length=64,oldHeight=wrap(height+p.offset);
          if((p.flags&0x80000)!==0&&wrap(height+p.offset)>p.ceiling) {
            length=wrap(64-wrap(height+p.offset-(p.multi?p.ceiling:p.clipped)));
            texel=wrap(texel+(wrap(wrap(height+p.offset-p.ceiling)*64)>>6));
            height=wrap((p.multi?p.ceiling:p.clipped)-p.offset);
          }
          if(wrap((p.multi?oldHeight:wrap(height+p.offset))-length)<floor)length=wrap((p.multi?oldHeight:wrap(height+p.offset))-floor);
          if(length<=0&&!p.multi)continue;
          if(length>0){
          let count=Math.imul(length,y)>>17;
          if(screen===-1)screen=wrap(p.center-(wrap(Math.imul(wrap(height-p.camera+p.offset),y)+32768)>>17));
          let position=texel<<12;
          if(screen<lo[1]) {
            position=wrap(position+Math.imul(distance,wrap(lo[1]-screen)));
            count=wrap(count-wrap(lo[1]-screen));screen=lo[1];
          }
          if(wrap(screen+count)>hi[1])count=wrap(hi[1]-screen);
          if(count>0) {
            empty=0;
            if(!p.suppressed) {
              let pixel=wrap(x+Math.imul(screen,p.width));
              for(let n=0;n<count;n++) {
                pixels[pixel]=(flipped?p.palette2:p.palette)[texels[position>>12]];
                pixel=wrap(pixel+p.width);position=wrap(position+distance);
              }
            }
          }
          screen=wrap(screen+count);
          }
          height=wrap(height-64);
          if(p.multi){const swap=s3;s3=s2;s2=swap;flipped^=1;texel=wrap(s3+(column<<6));}
        }
      }
      y=wrap(y+sy);u=wrap(u+su);x++;
    }
    return {empty,depth,flipped};
  }
  function spriteColumns(p,pixels,texels,e) {
    const v=p.vertices,lo=p.lower,hi=p.upper,wrap=x=>x|0;
    const extent=wrap(v[3]-v[0]);
    if(extent<=0)return {empty:1};
    const sy=wrap(Number((BigInt(wrap(v[4]-v[1]))<<16n)/BigInt(extent)));
    const su=wrap(Number((BigInt(wrap(v[5]-v[2]))<<16n)/BigInt(extent)));
    let x=Math.max(wrap(v[0]+65535)>>16,lo[0]),end=Math.min(wrap(v[3]+65535)>>16,hi[0]);
    const delta=wrap((x<<16)-v[0]),shape=p.shape,table=shape+4;
    let u=wrap(v[2]+wrap(Number((BigInt(delta)*BigInt(su))>>16n)));
    let y=wrap(v[1]+wrap(Number((BigInt(delta)*BigInt(sy))>>16n)));
    let offset=(e[shape]&65535)|(e[shape+1]<<16),lastColumn=0,empty=1;
    while(x<end) {
      const distance=wrap(Math.trunc(0x40000000/y)<<2);
      let step=p.scale?wrap(Number((BigInt(p.scale)<<16n)/BigInt(y))):distance;
      const column=wrap(Number((BigInt(u)*BigInt(step))>>32n));
      if(distance<=p.depth[x]) {
        while(lastColumn!==column) {
          const direction=lastColumn<column?1:-1;
          let edge=shape+e[lastColumn<column?table+lastColumn:table+lastColumn-1]+2,length=0;
          while((e[edge]&255)!==127){length=wrap(length+(e[edge]>>8));edge++;}
          offset=wrap(offset+Math.imul(length,direction));lastColumn+=direction;
        }
        let texel=offset;step>>=3;
        let edge=shape+e[table+column]+2;
        const cameraOffset=Math.imul(wrap(p.camera-wrap(p.shift-32)),y)>>17;
        const bottom=wrap(p.center+(Math.imul(wrap(p.camera-p.floor),y)>>17));
        const top=wrap(p.center+(Math.imul(wrap(p.camera-p.ceiling),y)>>17));
        while((e[edge]&255)!==127) {
          const run=e[edge++],length=run>>8;
          const height=(p.flags&0x1000000)!==0?wrap((run&255)+length):64-(run&255);
          let count=p.scale?(Math.trunc(Math.imul(y,length)/p.scale)>>1):(Math.imul(y,length)>>17);
          let screen=p.scale?wrap(p.center-(Math.trunc(Math.imul(y,height)/p.scale)>>1)+cameraOffset):wrap(p.center-(Math.imul(y,height)>>17)+cameraOffset);
          if((p.flags&0x80000)!==0&&screen<top){const clip=wrap(top-screen);count=wrap(count-clip);texel=wrap(texel+clip);screen=top;}
          if((p.effects&1)===0&&wrap(screen+count)>bottom)count=wrap(bottom-screen);
          let position=texel<<12;
          if((p.flags&0x1000000)!==0)position=wrap(position+Math.imul(step,wrap(count-1)));
          if(screen<lo[1]){position=wrap(position+Math.imul(step,wrap(lo[1]-screen)));count=wrap(count-wrap(lo[1]-screen));screen=lo[1];}
          if(wrap(screen+count)>hi[1])count=wrap(hi[1]-screen);
          if(count>0){
            empty=0;
            if([0,1,3,4,8,9].includes(p.mode))render(pixels,texels,[p.mode,wrap(x+Math.imul(screen,p.width)),position,(p.flags&0x1000000)!==0?wrap(-step):step,p.width,count,...p.palette]);
          }
          texel=wrap(texel+length);
        }
      }
      y=wrap(y+sy);u=wrap(u+su);x++;
    }
    return {empty};
  }
  root.OERaster={decode,encode,render,wallColumns,spriteColumns,edges:null,texels:new Int32Array(0),pixels:null,
    start(base){this.pixels=decode(base);},
    feed(commands){render(this.pixels,this.texels,decode(commands));},
    columns(input){return JSON.stringify(wallColumns(JSON.parse(input),this.pixels,this.texels));},
    sprites(input){return JSON.stringify(spriteColumns(JSON.parse(input),this.pixels,this.texels,this.edges));},
    finish(){
      const pixels=this.pixels,rgba=new Int32Array(pixels.length);
      for(let i=0;i<pixels.length;i++){const p=pixels[i];rgba[i]=0xff000000|((p&255)<<16)|(p&0xff00)|((p>>>16)&255);}
      this.pixels=null;
      return encode(pixels)+'|'+encode(rgba);
    },
    run(base,commands){this.start(base);this.feed(commands);return this.finish();}
  };
  if(typeof module!=='undefined')module.exports=root.OERaster;
})(typeof window!=='undefined'?window:globalThis);
