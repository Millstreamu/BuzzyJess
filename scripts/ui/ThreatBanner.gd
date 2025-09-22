extends Control
class_name ThreatBanner

const RESULT_DISPLAY_SECONDS := 4.0
const SUCCESS_COLOR := Color(0.56, 0.85, 0.52)
const FAIL_COLOR := Color(0.86, 0.38, 0.34)
const NEUTRAL_COLOR := Color(1.0, 0.95, 0.75)

enum BannerState { HIDDEN, THREAT_WARNING, THREAT_RESULT, COOLDOWN, BOSS_WARNING, BOSS_PHASE_ACTIVE, BOSS_PHASE_RESULT }

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/Layout/Name
@onready var power_value: Label = $Panel/Layout/Stats/PowerValue
@onready var timer_value: Label = $Panel/Layout/Stats/TimerValue
@onready var progress_bar: ProgressBar = $Panel/Layout/Progress
@onready var result_label: Label = $Panel/Layout/Result

var _state: int = BannerState.HIDDEN
var _end_time: float = 0.0
var _result_clear_time: float = 0.0
var _pending_cooldown: float = 0.0
var _cooldown_end_time: float = 0.0
var _current_id: StringName = StringName("")
var _boss_phase: int = 0

func _ready() -> void:
    visible = false
    set_process(false)
    _apply_panel_style()
    if typeof(Events) == TYPE_OBJECT:
        if not Events.threat_warning_started.is_connected(_on_threat_warning_started):
            Events.threat_warning_started.connect(_on_threat_warning_started)
        if not Events.threat_resolved.is_connected(_on_threat_resolved):
            Events.threat_resolved.connect(_on_threat_resolved)
        if not Events.threat_cooldown_started.is_connected(_on_threat_cooldown_started):
            Events.threat_cooldown_started.connect(_on_threat_cooldown_started)
        if not Events.boss_warning_started.is_connected(_on_boss_warning_started):
            Events.boss_warning_started.connect(_on_boss_warning_started)
        if not Events.boss_phase_started.is_connected(_on_boss_phase_started):
            Events.boss_phase_started.connect(_on_boss_phase_started)
        if not Events.boss_phase_resolved.is_connected(_on_boss_phase_resolved):
            Events.boss_phase_resolved.connect(_on_boss_phase_resolved)
        if not Events.game_over.is_connected(_on_game_over):
            Events.game_over.connect(_on_game_over)

func _process(_delta: float) -> void:
    var now: float = Time.get_unix_time_from_system()
    match _state:
        BannerState.THREAT_WARNING, BannerState.BOSS_WARNING:
            var remaining: float = max(_end_time - now, 0.0)
            _update_timer_display(remaining)
        BannerState.THREAT_RESULT, BannerState.BOSS_PHASE_RESULT:
            if _result_clear_time > 0.0 and now >= _result_clear_time:
                if _pending_cooldown > 0.0:
                    _begin_cooldown(_pending_cooldown)
                else:
                    _hide_banner()
        BannerState.COOLDOWN:
            var cooldown_remaining: float = max(_cooldown_end_time - now, 0.0)
            if cooldown_remaining <= 0.0:
                _hide_banner()
            else:
                _update_timer_display(cooldown_remaining)
        BannerState.BOSS_PHASE_ACTIVE:
            pass
        BannerState.HIDDEN:
            set_process(false)

func _apply_panel_style() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.08, 0.12, 0.92)
    style.border_color = Color(1.0, 0.78, 0.32)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    result_label.visible = false
    progress_bar.visible = false

func _on_threat_warning_started(id: StringName, power: int, end_time: float) -> void:
    _pending_cooldown = 0.0
    _current_id = id
    _state = BannerState.THREAT_WARNING
    var display_name: String = ConfigDB.get_threat_display_name(id)
    name_label.text = display_name
    power_value.text = String(power)
    _show_countdown(end_time)
    _set_result("", NEUTRAL_COLOR, false)
    _set_banner_visible(true)

func _on_threat_resolved(id: StringName, success: bool, power: int, defense: int) -> void:
    if _current_id != id:
        _current_id = id
    _state = BannerState.THREAT_RESULT
    power_value.text = String(power)
    progress_bar.visible = false
    timer_value.text = "--"
    var text := success
        ? "DEFENDED! %d / %d" % [defense, power]
        : "BREACH! %d / %d" % [defense, power]
    var color := success ? SUCCESS_COLOR : FAIL_COLOR
    _set_result(text, color, true)
    var now: float = Time.get_unix_time_from_system()
    _result_clear_time = success ? now + RESULT_DISPLAY_SECONDS : -1.0
    if not success:
        _pending_cooldown = 0.0
    _set_banner_visible(true)

func _on_threat_cooldown_started(seconds: int) -> void:
    if _state != BannerState.THREAT_RESULT:
        return
    var duration: float = float(max(seconds, 0))
    if duration <= 0.0:
        if _result_clear_time <= 0.0:
            _hide_banner()
        else:
            _pending_cooldown = 0.0
        return
    if _result_clear_time > 0.0:
        _pending_cooldown = duration
    else:
        _begin_cooldown(duration)

func _on_boss_warning_started(end_time: float) -> void:
    _current_id = StringName("Boss")
    _state = BannerState.BOSS_WARNING
    name_label.text = "Boss Incoming"
    power_value.text = "-"
    _show_countdown(end_time)
    _set_result("", NEUTRAL_COLOR, false)
    _set_banner_visible(true)

func _on_boss_phase_started(phase: int, power: int) -> void:
    _boss_phase = phase
    _state = BannerState.BOSS_PHASE_ACTIVE
    name_label.text = "Boss Phase %d" % phase
    power_value.text = String(power)
    progress_bar.visible = false
    timer_value.text = "--"
    _set_result("Checking defenses...", NEUTRAL_COLOR, true)
    _result_clear_time = 0.0
    _set_banner_visible(true)

func _on_boss_phase_resolved(phase: int, success: bool, power: int, defense: int) -> void:
    if phase != _boss_phase:
        _boss_phase = phase
    _state = BannerState.BOSS_PHASE_RESULT
    var text := success
        ? "PHASE %d CLEARED %d / %d" % [phase, defense, power]
        : "PHASE %d FAILED %d / %d" % [phase, defense, power]
    var color := success ? SUCCESS_COLOR : FAIL_COLOR
    _set_result(text, color, true)
    var now: float = Time.get_unix_time_from_system()
    _result_clear_time = success ? now + RESULT_DISPLAY_SECONDS : -1.0
    _pending_cooldown = 0.0
    _set_banner_visible(true)

func _on_game_over(_reason: String) -> void:
    if _state == BannerState.THREAT_RESULT or _state == BannerState.BOSS_PHASE_RESULT:
        return
    _hide_banner()

func _begin_cooldown(duration: float) -> void:
    if duration <= 0.0:
        _hide_banner()
        return
    _pending_cooldown = 0.0
    _state = BannerState.COOLDOWN
    name_label.text = "Next Threat"
    power_value.text = "-"
    progress_bar.visible = true
    progress_bar.max_value = duration
    _cooldown_end_time = Time.get_unix_time_from_system() + duration
    _end_time = _cooldown_end_time
    _update_timer_display(duration)
    _set_result("", NEUTRAL_COLOR, false)
    _set_banner_visible(true)

func _show_countdown(end_time: float) -> void:
    _end_time = end_time
    var remaining: float = max(end_time - Time.get_unix_time_from_system(), 0.0)
    progress_bar.visible = true
    progress_bar.max_value = max(remaining, 0.1)
    _update_timer_display(remaining)

func _update_timer_display(seconds: float) -> void:
    progress_bar.value = seconds
    timer_value.text = _format_time(seconds)

func _set_result(text: String, color: Color, show: bool) -> void:
    result_label.visible = show and not text.is_empty()
    result_label.text = text
    result_label.modulate = color

func _set_banner_visible(value: bool) -> void:
    visible = value
    set_process(value)

func _hide_banner() -> void:
    _state = BannerState.HIDDEN
    _pending_cooldown = 0.0
    _result_clear_time = 0.0
    progress_bar.visible = false
    result_label.visible = false
    visible = false
    set_process(false)

func _format_time(seconds: float) -> String:
    var total: int = int(ceil(max(seconds, 0.0)))
    var minutes: int = total / 60
    var rem: int = total % 60
    return "%02d:%02d" % [minutes, rem]
*** End File
