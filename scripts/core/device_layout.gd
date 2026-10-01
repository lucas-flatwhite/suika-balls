extends RefCounted
## Browser/native detection and safe-area data; tests can select a device profile.
var mobile := false
var force_mobile := -1
var safe_insets := Vector4.ZERO # left, top, right, bottom in viewport pixels
var portrait_blocked := false
var css_viewport := Vector2i.ZERO
var app_visible := true

func refresh(view: Vector2) -> void:
    mobile = OS.has_feature("android") or OS.has_feature("ios")
    var browser_blocked = null
    if OS.has_feature("web"):
        var raw = JavaScriptBridge.eval("JSON.stringify(window.MushiesDevice || {})",true)
        var data = JSON.parse_string(raw) if raw is String else null
        if data is Dictionary:
            mobile = bool(data.get("mobile",false))
            app_visible = bool(data.get("visible",true))
            var size = data.get("viewport",[])
            if size is Array and size.size() == 2:
                css_viewport = Vector2i(maxi(1,int(size[0])),maxi(1,int(size[1])))
            browser_blocked = data.get("portraitBlocked",null)
            var inset = data.get("safeInsets",[0,0,0,0])
            if inset is Array and inset.size() == 4:
                safe_insets = Vector4(float(inset[0]),float(inset[1]),float(inset[2]),float(inset[3]))
    if force_mobile >= 0: mobile = force_mobile == 1
    portrait_blocked = mobile and view.x > view.y
    if browser_blocked is bool and force_mobile < 0: portrait_blocked = browser_blocked

func use_mobile_hud(view: Vector2) -> bool:
    # Portrait previews and desktop-UA tablets need the same full-height playfield.
    # Device detection controls orientation locking, not access to the touch layout.
    return mobile or view.x < view.y

func multiplayer_allowed(view: Vector2) -> bool:
    return local_splitscreen_allowed(view)

func local_splitscreen_allowed(view: Vector2) -> bool:
    return not mobile and view.x > view.y

static func apply_window_scale(window: Window,logical_size:Vector2i) -> void:
    if logical_size.x <= 0 or logical_size.y <= 0: return
    # Godot's Web canvas uses device pixels; controls and safe insets use CSS pixels.
    # Canvas-item scaling retains sharp Retina rendering and correct input coordinates.
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_size = logical_size
