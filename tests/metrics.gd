extends SceneTree
func _initialize() -> void:
	var meter:=OERuntimeMetrics.new();meter.enabled=true
	meter.ticks=2;meter.vm_us=4000;meter.ui_us=3000;meter.ui_frames=3;meter.last_publish=Time.get_ticks_msec()-1000
	meter.publish(1000)
	var mixed: bool=meter.last_report.vm_ms==2.0 and meter.last_report.ui_ms==1.0
	meter.ui_us=3000;meter.ui_frames=3;meter.last_publish=Time.get_ticks_msec()-1000
	meter.publish(1000)
	var paused: bool=meter.last_report.vm_ms==0.0 and meter.last_report.ui_ms==1.0
	print(JSON.stringify({"mixed":mixed,"paused":paused,"report":meter.last_report}));quit(0 if mixed and paused else 1)
