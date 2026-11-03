class_name OERuntimeMetrics
extends RefCounted
## Opt-in diagnostics (?perf=1). Measures wall time, not virtual JVM time.
var enabled: bool=false
var events: Array=[]
var pending: Dictionary={}
var last_publish: int=0
var ticks: int=0
var vm_us: int=0
var ui_us: int=0
var max_gap: int=0
var last_tick: int=0
var max_vm: int=0

func pose(vm: OEVM) -> Array:
	return [vm.get_static("a","h","I"),vm.get_static("a","i","I"),vm.get_static("a","j","I"),vm.get_static("a","k","I")]

func key(vm: OEVM, screen: JObject, raw: int) -> void:
	if not enabled: return
	if not pending.is_empty(): finish("overlap")
	pending={"key":raw,"began":Time.get_ticks_usec(),"pose":pose(vm),"revision":int(screen.extra.get("world_revision",-1)),"first_ms":-1}

func finish(reason: String) -> void:
	var event: Dictionary=pending.duplicate()
	event.elapsed_ms=snappedf((Time.get_ticks_usec()-int(event.began))/1000.0,0.1)
	event.erase("began");event.reason=reason
	events.append(event)
	if events.size()>12: events.pop_front()
	pending={}

func tick(vm: OEVM, screen: JObject, elapsed_us: int) -> void:
	if not enabled: return
	var now: int=Time.get_ticks_usec()
	if last_tick>0: max_gap=maxi(max_gap,now-last_tick)
	last_tick=now;ticks+=1;vm_us+=elapsed_us;max_vm=maxi(max_vm,elapsed_us)
	if pending.is_empty(): return
	var revision: int=int(screen.extra.get("world_revision",-1))
	if revision>int(pending.revision):
		if int(pending.first_ms)<0: pending.first_ms=snappedf((now-int(pending.began))/1000.0,0.1)
		var p: Array=pose(vm)
		var target: Array=[vm.get_static("a","l","I"),vm.get_static("a","m","I"),vm.get_static("a","n","I"),vm.get_static("a","q","I")]
		if p==target and (p!=pending.pose or int(pending.key) not in [49,50,51,52,54,56]): finish("settled")
	if not pending.is_empty() and now-int(pending.began)>10000000: finish("timeout")

func publish(extra_ui_us: int) -> void:
	if not enabled: return
	ui_us+=extra_ui_us
	var now: int=Time.get_ticks_msec()
	if now-last_publish<500: return
	var report: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"vm_ms":snappedf(vm_us/float(maxi(1,ticks))/1000.0,0.1),"ui_ms":snappedf(ui_us/float(maxi(1,ticks))/1000.0,0.1),"worst_vm_ms":snappedf(max_vm/1000.0,0.1),"frame_gap_ms":snappedf(max_gap/1000.0,0.1),"inputs":events}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('oe-perf').textContent="+JSON.stringify(JSON.stringify(report)))
	last_publish=now;ticks=0;vm_us=0;ui_us=0;max_gap=0;max_vm=0
