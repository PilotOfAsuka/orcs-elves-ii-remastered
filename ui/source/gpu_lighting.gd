class_name OEGPULighting extends RefCounted
## Persistent textures on Godot's existing WebGL context; no GPU readback.
var material: ShaderMaterial
var xy: ImageTexture
var zna: ImageTexture
var shadows: ImageTexture
var contact: ImageTexture
var dimensions:=Vector2i.ZERO
var shadow_revision: int=-1
var contact_revision: int=-1

func _init() -> void:
	material=ShaderMaterial.new()
	material.shader=preload("res://source/lighting.gdshader")

func byte_image(raw: Variant, size: Vector2i) -> Image:
	var data: PackedByteArray=raw if raw is PackedByteArray else JavaScriptBridge.js_buffer_to_packed_byte_array(raw)
	if data.size()!=size.x*size.y*4:return null
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,data)

func update(brew: JavaScriptObject, size: Vector2i) -> bool:
	var next_xy:=byte_image(brew.gpuBuffer("xy"),size)
	var next_zna:=byte_image(brew.gpuBuffer("zna"),size)
	if next_xy==null or next_zna==null:return false
	if size!=dimensions:
		xy=ImageTexture.create_from_image(next_xy);zna=ImageTexture.create_from_image(next_zna);dimensions=size
		material.set_shader_parameter("surface_xy",xy);material.set_shader_parameter("surface_zna",zna)
	else:
		xy.update(next_xy);zna.update(next_zna)
	var revision: int=int(brew.gpuShadowRevision())
	if revision!=shadow_revision:
		var next_shadows:=byte_image(brew.gpuBuffer("shadows"),Vector2i(1024,384))
		if next_shadows==null:return false
		if shadows==null:
			shadows=ImageTexture.create_from_image(next_shadows);material.set_shader_parameter("shadow_field",shadows)
		else:shadows.update(next_shadows)
		shadow_revision=revision
	var next_contact_revision: int=int(brew.gpuContactRevision())
	if next_contact_revision!=contact_revision:
		var next_contact:=byte_image(brew.gpuBuffer("contact"),Vector2i(129,387))
		if next_contact==null:return false
		if contact==null:
			contact=ImageTexture.create_from_image(next_contact);material.set_shader_parameter("contact_field",contact)
		else:contact.update(next_contact)
		contact_revision=next_contact_revision
	var p: Array=JSON.parse_string(str(brew.gpuParameters()))
	if p.size()!=112:return false
	material.set_shader_parameter("camera",Vector4(p[4],p[5],p[6],p[3]))
	material.set_shader_parameter("forward_axis",Vector2(p[7],p[8]))
	material.set_shader_parameter("processing",Vector3(p[9],p[10],p[11]))
	material.set_shader_parameter("raster_size",Vector2(size))
	material.set_shader_parameter("floor_ceiling",Vector2(p[12],p[13]))
	material.set_shader_parameter("light_count",int(p[0]))
	var positions:=PackedVector4Array();var colours:=PackedVector4Array();var halos:=PackedVector4Array()
	for j in range(8):
		var i: int=16+j*12
		positions.append(Vector4(p[i],p[i+1],p[i+2],p[i+3]))
		colours.append(Vector4(p[i+4],p[i+5],p[i+6],p[i+7]))
		halos.append(Vector4(p[i+8],p[i+9],p[i+10],p[i+11]))
	material.set_shader_parameter("source_position",positions)
	material.set_shader_parameter("source_colour",colours)
	material.set_shader_parameter("source_halo",halos)
	return true
