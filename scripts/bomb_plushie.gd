extends "res://scripts/plushie_body.gd"
const Definition := preload("res://data/actors/bomb.gd")
const TEXTURE := preload("res://assets/template/bombs/puff_bomb.webp")
const BADGE_FONT_SIZE := 24
const BADGE_BORDER_WIDTH := 4.0
const BADGE_TEXT_CLEARANCE := 8.0
var fuse_remaining := Definition.FUSE_SECONDS
var armed := false
var detonation_requested := false

static func bomb_resources_valid() -> bool:
    if not FileAccess.file_exists("res://assets/template/bombs/manifest.json"): return false
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/template/bombs/manifest.json"))
    if not (data is Dictionary and data.get("outline") is Array and data.outline.size() >= 8): return false
    for point in data.outline:
        if not point is Array or point.size() != 2: return false
        for number in point:
            if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 0.6: return false
    return true

func configure(_new_tier: int, owner_game: Node) -> void:
    tier = Definition.TIER
    manager = owner_game
    texture_asset = TEXTURE
    render_span = Definition.SPAN
    render_size = TEXTURE.get_size() * (render_span / maxf(TEXTURE.get_width(),TEXTURE.get_height()))
    _configure_outline()
    _configure_physics(1.2)
    # Compound plushie silhouettes can report several contact points per neighbor.
    max_contacts_reported = 256

func release() -> void:
    super.release()
    armed = true
    fuse_remaining = Definition.FUSE_SECONDS

func _physics_process(delta: float) -> void:
    advance_fuse(delta)

func advance_fuse(delta: float) -> void:
    if not armed or held or destroy_pending or detonation_requested: return
    if not is_instance_valid(manager) or manager.is_frozen(): return
    fuse_remaining = maxf(0.0,fuse_remaining-maxf(0.0,delta))
    if fuse_remaining <= 0.00001:
        detonation_requested = true
        manager.request_bomb_detonation(self,get_colliding_bodies())

# Measure in world pixels against the same silhouettes used by physics.
func reaches(other: PlushieBody) -> bool:
    var bomb_edge := global_transform * outline
    var other_edge := other.global_transform * other.outline
    if bomb_edge.is_empty() or other_edge.is_empty(): return false
    if Geometry2D.is_point_in_polygon(bomb_edge[0],other_edge) or Geometry2D.is_point_in_polygon(other_edge[0],bomb_edge): return true
    for i in range(bomb_edge.size()):
        var a := bomb_edge[i]
        var b := bomb_edge[(i+1)%bomb_edge.size()]
        for j in range(other_edge.size()):
            var c := other_edge[j]
            var d := other_edge[(j+1)%other_edge.size()]
            if Geometry2D.segment_intersects_segment(a,b,c,d) != null: return true
            if a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d)) <= Definition.BLAST_MARGIN or b.distance_to(Geometry2D.get_closest_point_to_segment(b,c,d)) <= Definition.BLAST_MARGIN or c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)) <= Definition.BLAST_MARGIN or d.distance_to(Geometry2D.get_closest_point_to_segment(d,a,b)) <= Definition.BLAST_MARGIN: return true
    return false

func _draw() -> void:
    super._draw()
    if not armed or destroy_pending or not is_instance_valid(manager): return
    var text := str(maxi(1,ceili(fuse_remaining)))
    var font: Font = manager.locale.font
    var extent := Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,BADGE_FONT_SIZE).x,font.get_height(BADGE_FONT_SIZE))
    # The full line rectangle, including its corners, must clear the circular
    # stroke by eight viewport pixels even when the physical board is tiny.
    var radius := ceilf(extent.length()*0.5+BADGE_TEXT_CLEARANCE+BADGE_BORDER_WIDTH*0.5)
    var projection := get_viewport().canvas_transform
    var center := projection * (global_position-Vector2(0,render_size.y*0.5))-Vector2(0,radius+4)
    var glass: Rect2 = projection * manager.tank_rect
    glass.size.y -= 28*projection.y.length()
    var safe := glass.grow(-radius-2)
    center = center.clamp(safe.position,safe.end)
    draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse()*Transform2D(0,center))
    draw_circle(Vector2.ZERO,radius,Color("fff8ed"))
    draw_arc(Vector2.ZERO,radius,-PI*0.5,-PI*0.5+TAU*fuse_remaining/Definition.FUSE_SECONDS,36,Color("bd6389"),BADGE_BORDER_WIDTH,true)
    var baseline := (font.get_ascent(BADGE_FONT_SIZE)-font.get_descent(BADGE_FONT_SIZE))*0.5
    draw_string(font,Vector2(-extent.x*0.5,baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,BADGE_FONT_SIZE,Color("593c49"))
    draw_set_transform_matrix(Transform2D.IDENTITY)
