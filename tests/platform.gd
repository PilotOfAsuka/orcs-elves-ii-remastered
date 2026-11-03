extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func call_api(session: OEGameSession, owner: String, name: String, desc: String, object: Variant, args: Array) -> Variant:
	return session.platform.invoke({"owner":owner,"name":name,"desc":desc},object,args,{})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := OEGameSession.new(false)
	var bridge := session.platform
	var stream := bridge.stream(PackedByteArray([255,128,0,127]))
	check(call_api(session,"java/io/DataInputStream","readUnsignedByte","()I",stream,[])==255,"unsigned input byte")
	check(call_api(session,"java/io/DataInputStream","readByte","()B",stream,[])==-128,"signed input byte")
	var target := session.vm.new_array("[B",2)
	check(call_api(session,"java/io/InputStream","read","([B)I",stream,[target])==2,"whole-array input")
	check(target.data==[0,127],"input contents")
	var output := JObject.new("java/io/ByteArrayOutputStream")
	call_api(session,"java/io/ByteArrayOutputStream","<init>","()V",output,[])
	var writer := JObject.new("java/io/DataOutputStream")
	call_api(session,"java/io/DataOutputStream","<init>","(Ljava/io/OutputStream;)V",writer,[output])
	call_api(session,"java/io/DataOutputStream","writeInt","(I)V",writer,[0x89abcdef])
	check(output.data==[-119,-85,-51,-17],"big-endian shared output buffer")
	var buffer := JObject.new("java/lang/StringBuffer")
	call_api(session,"java/lang/StringBuffer","<init>","(I)V",buffer,[600])
	check(buffer.data=="","StringBuffer capacity constructor")
	call_api(session,"java/lang/StringBuffer","append","(C)Ljava/lang/StringBuffer;",buffer,[1046])
	check(buffer.data=="Ж","Cyrillic character append")
	var other := JObject.new("java/lang/StringBuffer")
	other.data=" текст"
	call_api(session,"java/lang/StringBuffer","append","(Ljava/lang/Object;)Ljava/lang/StringBuffer;",buffer,[other])
	check(buffer.data=="Ж текст","StringBuffer append object contents")
	var empty := session.vm.new_array("[B",0)
	check(call_api(session,"java/io/InputStream","read","([B)I",stream,[empty])==0,"zero-length input at EOF")
	var image := Image.create(3,2,false,Image.FORMAT_RGBA8)
	var graphics := OEMidpGraphics.new(image)
	graphics.set_clip(1,0,1,2)
	var pixels := session.vm.new_array("[I",6)
	pixels.data = [0xff0000,0x00ff00,0x0000ff,0xffffff,0x112233,0xabcdef]
	bridge.draw_rgb(graphics,[pixels,0,3,0,0,3,2,0])
	check(image.get_pixel(1,0)==Color.GREEN,"drawRGB color and clipping")
	check(image.get_pixel(0,0)==Color.BLACK,"drawRGB outside clip")
	check(image.get_pixel(1,1)==Color8(17,34,51),"drawRGB scan stride")
	var sheet := Image.create(2,1,false,Image.FORMAT_RGBA8)
	sheet.set_pixel(0,0,Color.RED)
	sheet.set_pixel(1,0,Color.BLUE)
	var source := JObject.new("javax/microedition/lcdui/Image")
	source.data = sheet
	graphics.set_clip(0,0,3,2)
	bridge.draw_region(graphics,[source,0,0,2,1,2,0,0,20])
	check(image.get_pixel(0,0)==Color.BLUE and image.get_pixel(1,0)==Color.RED,"drawRegion mirror")
	var store := call_api(session,"javax/microedition/rms/RecordStore","openRecordStore","(Ljava/lang/String;Z)Ljavax/microedition/rms/RecordStore;",null,["test",1]) as JObject
	call_api(session,"javax/microedition/rms/RecordStore","addRecord","([BII)I",store,[target,0,2])
	check(session.saves.records.get("test")==[0,127],"RMS record contents")
	session.close()
	print(JSON.stringify({"checks":14,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
