class_name QRCode
extends RefCounted

## QRCode: Pure GDScript QR Code Generator (ISO/IEC 18004 Standard)
## Zero external dependencies. Generates Godot Image and ImageTexture for in-engine display.

# Galois Field GF(256) Tables for Reed-Solomon Error Correction
static var _gf_exp: PackedInt32Array = PackedInt32Array()
static var _gf_log: PackedInt32Array = PackedInt32Array()
static var _tables_initialized: bool = false

# Error correction codewords per block (Version 1 to 10, Level L)
# [total_data_bytes, ec_codewords_per_block, num_blocks]
const VERSION_INFO_L = {
	1: [19, 7, 1],
	2: [34, 10, 1],
	3: [55, 15, 1],
	4: [80, 20, 1],
	5: [108, 26, 1],
	6: [136, 18, 2],
	7: [156, 20, 2],
	8: [194, 24, 2],
	9: [232, 30, 2],
	10: [274, 18, 4]
}

# Alignment pattern center locations for versions 1 to 10
const ALIGNMENT_LOCATIONS = {
	1: [],
	2: [6, 18],
	3: [6, 22],
	4: [6, 26],
	5: [6, 30],
	6: [6, 34],
	7: [6, 22, 38],
	8: [6, 24, 42],
	9: [6, 26, 46],
	10: [6, 28, 50]
}

# Pre-computed format info bits for Level L masks 0..7 (with BCH 15,5 error correction)
const FORMAT_INFO_L = [
	0x77C4, 0x72F3, 0x7DAA, 0x789D, 0x662F, 0x6318, 0x6C41, 0x6976
]

static func _init_gf_tables() -> void:
	if _tables_initialized:
		return
	_gf_exp.resize(512)
	_gf_log.resize(256)
	var x = 1
	for i in range(255):
		_gf_exp[i] = x
		_gf_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D # Primitive polynomial x^8 + x^4 + x^3 + x^2 + 1
	for i in range(255, 512):
		_gf_exp[i] = _gf_exp[i - 255]
	_tables_initialized = true

static func _gf_mul(x: int, y: int) -> int:
	if x == 0 or y == 0:
		return 0
	return _gf_exp[_gf_log[x] + _gf_log[y]]

static func _poly_mul(p1: PackedByteArray, p2: PackedByteArray) -> PackedByteArray:
	var coeff = PackedByteArray()
	coeff.resize(p1.size() + p2.size() - 1)
	for i in range(p1.size()):
		for j in range(p2.size()):
			coeff[i + j] ^= _gf_mul(p1[i], p2[j])
	return coeff

static func _gen_poly(degree: int) -> PackedByteArray:
	var poly = PackedByteArray([1])
	for i in range(degree):
		var term = PackedByteArray([1, _gf_exp[i]])
		poly = _poly_mul(poly, term)
	return poly

static func _poly_mod(divident: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result = divident.duplicate()
	while (result.size() - divisor.size()) >= 0:
		var coeff = result[0]
		for i in range(divisor.size()):
			result[i] ^= _gf_mul(divisor[i], coeff)
		var offset = 0
		while offset < result.size() and result[offset] == 0:
			offset += 1
		result = result.slice(offset)
	return result

static func _rs_encode(data: PackedByteArray, degree: int) -> PackedByteArray:
	_init_gf_tables()
	var gen_poly = _gen_poly(degree)
	var padded = PackedByteArray()
	padded.resize(data.size() + degree)
	for i in range(data.size()):
		padded[i] = data[i]
	var remainder = _poly_mod(padded, gen_poly)
	var buff = PackedByteArray()
	buff.resize(degree)
	var start = degree - remainder.size()
	for i in range(remainder.size()):
		buff[start + i] = remainder[i]
	return buff

## Generates a Godot ImageTexture containing the QR Code
static func get_texture(text: String, scale: int = 8, border: int = 4) -> ImageTexture:
	var img = get_image(text, scale, border)
	if not img:
		return null
	return ImageTexture.create_from_image(img)

## Generates a Godot Image containing the QR Code
static func get_image(text: String, scale: int = 8, border: int = 4) -> Image:
	var matrix = generate_matrix(text)
	if matrix.is_empty():
		return null
		
	var qr_size = matrix.size()
	var total_size = (qr_size + border * 2) * scale
	
	var img = Image.create(total_size, total_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	
	var black = Color.BLACK
	for y in range(qr_size):
		for x in range(qr_size):
			if matrix[y][x]:
				for sy in range(scale):
					for sx in range(scale):
						var px = (border + x) * scale + sx
						var py = (border + y) * scale + sy
						img.set_pixel(px, py, black)
	return img

## Generates the 2D boolean array [y][x] for the QR Code
static func generate_matrix(text: String) -> Array:
	_init_gf_tables()
	var raw_bytes = text.to_utf8_buffer()
	var data_len = raw_bytes.size()
	
	# 1. Select appropriate QR version
	var version = 0
	for v in range(1, 11):
		if VERSION_INFO_L[v][0] >= data_len + 3: # 4 bit mode + 8 bit count + data
			version = v
			break
			
	if version == 0:
		push_error("[QRCode] Text payload too large for compact QR generator (Max 270 bytes).")
		return []
		
	var total_data_cap = VERSION_INFO_L[version][0]
	var ec_per_block = VERSION_INFO_L[version][1]
	var num_blocks = VERSION_INFO_L[version][2]
	var matrix_size = 17 + version * 4
	
	# 2. Build bitstream (Byte mode: 0100)
	var bitstream: Array[int] = []
	bitstream.append_array([0, 1, 0, 0])
	
	var count_bits = 8 if version < 10 else 16
	for i in range(count_bits - 1, -1, -1):
		bitstream.append((data_len >> i) & 1)
		
	for b in raw_bytes:
		for i in range(7, -1, -1):
			bitstream.append((b >> i) & 1)
			
	var term_bits = min(4, total_data_cap * 8 - bitstream.size())
	for i in range(term_bits):
		bitstream.append(0)
		
	while bitstream.size() % 8 != 0:
		bitstream.append(0)
		
	var pad_bytes = [0xEC, 0x11]
	var pad_idx = 0
	while bitstream.size() < total_data_cap * 8:
		var pb = pad_bytes[pad_idx % 2]
		for i in range(7, -1, -1):
			bitstream.append((pb >> i) & 1)
		pad_idx += 1
		
	var data_codewords = PackedByteArray()
	for i in range(0, bitstream.size(), 8):
		var byte_val = 0
		for j in range(8):
			byte_val = (byte_val << 1) | bitstream[i + j]
		data_codewords.append(byte_val)
		
	# 3. Reed-Solomon Error Correction Blocks
	var data_blocks: Array[PackedByteArray] = []
	var ec_blocks: Array[PackedByteArray] = []
	var block_size = total_data_cap / num_blocks
	
	for b in range(num_blocks):
		var start = b * block_size
		var end = start + block_size
		if b == num_blocks - 1:
			end = total_data_cap
		var blk_data = data_codewords.slice(start, end)
		data_blocks.append(blk_data)
		ec_blocks.append(_rs_encode(blk_data, ec_per_block))
		
	# Interleave data codewords & EC codewords
	var final_stream = PackedByteArray()
	var max_data_blk_len = 0
	for blk in data_blocks:
		max_data_blk_len = max(max_data_blk_len, blk.size())
		
	for i in range(max_data_blk_len):
		for blk in data_blocks:
			if i < blk.size():
				final_stream.append(blk[i])
				
	for i in range(ec_per_block):
		for blk in ec_blocks:
			final_stream.append(blk[i])
			
	var final_bits: Array[int] = []
	for b in final_stream:
		for i in range(7, -1, -1):
			final_bits.append((b >> i) & 1)
			
	# 4. Construct Matrix & Place Functional Patterns
	var modules: Array = []
	var is_function: Array = []
	for y in range(matrix_size):
		var row: Array[bool] = []
		var f_row: Array[bool] = []
		row.resize(matrix_size)
		f_row.resize(matrix_size)
		row.fill(false)
		f_row.fill(false)
		modules.append(row)
		is_function.append(f_row)
		
	# Place Finder Patterns (7x7) + Separators
	_place_finder(modules, is_function, 0, 0, matrix_size)
	_place_finder(modules, is_function, matrix_size - 7, 0, matrix_size)
	_place_finder(modules, is_function, 0, matrix_size - 7, matrix_size)
	
	# Timing patterns (horizontal & vertical at row/col 6)
	for i in range(8, matrix_size - 8):
		var val = (i % 2 == 0)
		if not is_function[6][i]:
			modules[6][i] = val
			is_function[6][i] = true
		if not is_function[i][6]:
			modules[i][6] = val
			is_function[i][6] = true
			
	# Alignment Patterns (if Version >= 2)
	var align_coords = ALIGNMENT_LOCATIONS[version]
	for cy in align_coords:
		for cx in align_coords:
			if (cx <= 8 and cy <= 8) or (cx >= matrix_size - 9 and cy <= 8) or (cx <= 8 and cy >= matrix_size - 9):
				continue
			_place_alignment(modules, is_function, cx, cy)
			
	# Dark module (row matrix_size - 8, col 8)
	modules[matrix_size - 8][8] = true
	is_function[matrix_size - 8][8] = true
	
	# Reserve Format Info modules
	_reserve_format_info(is_function, matrix_size)
	
	# 5. Place Data Codewords (Zig-Zag upward/downward in 2-column pairs)
	var bit_idx = 0
	var total_bits = final_bits.size()
	var right = matrix_size - 1
	var upward = true
	
	while right > 0:
		if right == 6: # Skip vertical timing column
			right -= 1
		var y_range = range(matrix_size - 1, -1, -1) if upward else range(matrix_size)
		for y in y_range:
			for x in [right, right - 1]:
				if not is_function[y][x]:
					if bit_idx < total_bits:
						modules[y][x] = (final_bits[bit_idx] == 1)
						bit_idx += 1
					else:
						modules[y][x] = false
		upward = not upward
		right -= 2
		
	# 6. Apply Standard Mask 0: (row + col) % 2 == 0
	var mask_id = 0
	for y in range(matrix_size):
		for x in range(matrix_size):
			if not is_function[y][x]:
				if (x + y) % 2 == 0:
					modules[y][x] = not modules[y][x]
					
	# 7. Write Format Info (Level L + Mask 0)
	_write_format_info(modules, FORMAT_INFO_L[mask_id], matrix_size)
	
	return modules

static func _place_finder(modules: Array, is_func: Array, top_left_x: int, top_left_y: int, size: int) -> void:
	for dy in range(-1, 8):
		for dx in range(-1, 8):
			var x = top_left_x + dx
			var y = top_left_y + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				is_func[y][x] = true
				if dx >= 0 and dx <= 6 and dy >= 0 and dy <= 6:
					var is_black = (dx == 0 or dx == 6 or dy == 0 or dy == 6 or (dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4))
					modules[y][x] = is_black
				else:
					modules[y][x] = false # Separator

static func _place_alignment(modules: Array, is_func: Array, cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x = cx + dx
			var y = cy + dy
			is_func[y][x] = true
			var is_black = (abs(dx) == 2 or abs(dy) == 2 or (dx == 0 and dy == 0))
			modules[y][x] = is_black

static func _reserve_format_info(is_func: Array, size: int) -> void:
	for i in range(9):
		is_func[8][i] = true
		is_func[i][8] = true
	for i in range(8):
		is_func[8][size - 1 - i] = true
		is_func[size - 1 - i][8] = true

static func _write_format_info(modules: Array, format_val: int, size: int) -> void:
	for i in range(15):
		var mod = ((format_val >> i) & 1) == 1
		# Vertical placement
		if i < 6:
			modules[i][8] = mod
		elif i < 8:
			modules[i + 1][8] = mod
		else:
			modules[size - 15 + i][8] = mod
			
		# Horizontal placement
		if i < 8:
			modules[8][size - i - 1] = mod
		elif i < 9:
			modules[8][15 - i - 1 + 1] = mod
		else:
			modules[8][15 - i - 1] = mod
			
	# Dark module (always dark)
	modules[size - 8][8] = true
