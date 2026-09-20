shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// -----------------------------------------------------------------------------
// Multi-Scale Terrain & Ground Shader with Altitude Spatial References
// -----------------------------------------------------------------------------

group_uniforms Palette;
uniform vec4 ground_color_primary : source_color = vec4(0.24, 0.28, 0.32, 1.0);
uniform vec4 ground_color_secondary : source_color = vec4(0.15, 0.18, 0.22, 1.0);
uniform vec4 ground_color_mineral : source_color = vec4(0.38, 0.34, 0.28, 1.0);

group_uniforms Textures;
uniform sampler2D macro_noise_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D micro_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D micro_rough_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D runway_corridor_tex : source_color, filter_linear_mipmap, repeat_enable;

group_uniforms Scaling;
uniform float macro_scale : hint_range(0.00005, 0.005, 0.00005) = 0.0006;
uniform float micro_scale : hint_range(0.01, 1.0, 0.01) = 0.12;
uniform float normal_depth : hint_range(0.0, 4.0, 0.1) = 2.0;
uniform float detail_fade_dist : hint_range(100.0, 3000.0, 50.0) = 900.0;

group_uniforms SpatialGrid;
uniform bool enable_grid = true;
uniform float grid_spacing : hint_range(20.0, 500.0, 10.0) = 100.0;
uniform float sub_grid_spacing : hint_range(5.0, 100.0, 5.0) = 25.0;
uniform vec4 grid_color : source_color = vec4(0.0, 0.85, 1.0, 0.25);
uniform vec4 sub_grid_color : source_color = vec4(0.1, 0.45, 0.65, 0.10);

group_uniforms Corridor;
uniform bool enable_corridor = true;
uniform float corridor_width : hint_range(20.0, 300.0, 10.0) = 80.0;
uniform float corridor_start_z : hint_range(-1000.0, 1000.0, 50.0) = 250.0;
uniform float corridor_end_z : hint_range(-6000.0, -500.0, 100.0) = -3200.0;
uniform float corridor_tile_length : hint_range(50.0, 500.0, 10.0) = 160.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w_pos = v_world_pos.xz;
	float cam_dist = length(CAMERA_POSITION_WORLD - v_world_pos);
	
	// Detail weight fades as altitude/distance increases to prevent moiré
	float detail_weight = 1.0 - smoothstep(30.0, detail_fade_dist, cam_dist);
	
	// -------------------------------------------------------------------------
	// 1. Macro Color Variation (Dual-phase rotated noise)
	// -------------------------------------------------------------------------
	vec2 macro_uv1 = w_pos * macro_scale;
	vec2 macro_uv2 = vec2(-w_pos.y, w_pos.x) * (macro_scale * 1.57) + vec2(0.41, 0.73);
	
	float n1 = texture(macro_noise_tex, macro_uv1).r;
	float n2 = texture(macro_noise_tex, macro_uv2).r;
	float macro_noise = mix(n1, n2, 0.42);
	
	// Dual blend: Primary -> Secondary -> Mineral
	vec3 base_albedo = mix(ground_color_primary.rgb, ground_color_secondary.rgb, smoothstep(0.3, 0.7, macro_noise));
	float mineral_mask = smoothstep(0.68, 0.88, n1 * n2 * 1.8);
	base_albedo = mix(base_albedo, ground_color_mineral.rgb, mineral_mask);
	
	// -------------------------------------------------------------------------
	// 2. Micro Normal & Roughness (Multi-octave gravel & cracks)
	// -------------------------------------------------------------------------
	vec2 micro_uv = w_pos * micro_scale;
	vec3 norm_map = texture(micro_normal_tex, micro_uv).rgb;
	
	// Layered secondary high-frequency octave for crisp pebbles under 40m
	if (detail_weight > 0.2) {
		vec3 norm_octave2 = texture(micro_normal_tex, micro_uv * 2.83).rgb;
		norm_map = normalize(mix(norm_map, norm_octave2, 0.35));
	}
	
	NORMAL_MAP = norm_map;
	NORMAL_MAP_DEPTH = normal_depth * detail_weight;
	
	// Roughness modulation
	float micro_rough = texture(micro_rough_tex, micro_uv).r;
	ROUGHNESS = mix(0.88, micro_rough, detail_weight * 0.75);
	METALLIC = 0.08;
	
	// -------------------------------------------------------------------------
	// 3. Aerospace Distance Grid (Sub-grids for distance & speed parallax)
	// -------------------------------------------------------------------------
	if (enable_grid && cam_dist < 1800.0) {
		// Major grid (100m)
		vec2 grid_uv = abs(fract(w_pos / grid_spacing - 0.5) - 0.5) / fwidth(w_pos / grid_spacing);
		float line_major = min(grid_uv.x, grid_uv.y);
		float grid_major = 1.0 - min(line_major, 1.0);
		
		// Minor sub-grid (25m)
		vec2 sub_grid_uv = abs(fract(w_pos / sub_grid_spacing - 0.5) - 0.5) / fwidth(w_pos / sub_grid_spacing);
		float line_minor = min(sub_grid_uv.x, sub_grid_uv.y);
		float grid_minor = 1.0 - min(line_minor, 1.0);
		
		float grid_fade = 1.0 - smoothstep(200.0, 1600.0, cam_dist);
		float sub_grid_fade = 1.0 - smoothstep(40.0, 450.0, cam_dist);
		
		// Blend major grid
		base_albedo = mix(base_albedo, grid_color.rgb, grid_major * grid_color.a * grid_fade);
		EMISSION += grid_color.rgb * (grid_major * grid_color.a * grid_fade * 1.8);
		
		// Blend minor sub-grid
		base_albedo = mix(base_albedo, sub_grid_color.rgb, grid_minor * sub_grid_color.a * sub_grid_fade);
	}
	
	// -------------------------------------------------------------------------
	// 4. Tactical Flight Corridor & Runway Axis
	// -------------------------------------------------------------------------
	if (enable_corridor) {
		float half_w = corridor_width * 0.5;
		if (abs(w_pos.x) <= half_w && w_pos.y <= corridor_start_z && w_pos.y >= corridor_end_z) {
			// Normalize UV within corridor
			float u = (w_pos.x / corridor_width) + 0.5;
			float v = fract((w_pos.y - corridor_start_z) / -corridor_tile_length);
			vec4 corr_sample = texture(runway_corridor_tex, vec2(u, v));
			
			// Tarmac bed darkening beneath corridor
			vec3 tarmac_color = mix(base_albedo * 0.65, vec3(0.08, 0.09, 0.11), 0.7);
			float edge_soft = smoothstep(half_w, half_w - 6.0, abs(w_pos.x));
			base_albedo = mix(base_albedo, tarmac_color, edge_soft * 0.85);
			
			// Overlay markings with emission
			if (corr_sample.a > 0.05) {
				base_albedo = mix(base_albedo, corr_sample.rgb, corr_sample.a * edge_soft);
				EMISSION += corr_sample.rgb * (corr_sample.a * edge_soft * 1.2);
			}
		}
	}
	
	ALBEDO = base_albedo;
}
