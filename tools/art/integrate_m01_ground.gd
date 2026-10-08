extends SceneTree

const STAGE := "res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/"
const OUTPUT := "res://assets/art/prerendered/m01_sunset_palms/runtime/ground_v1/"

func _initialize() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE+"ground_layer_contract_v3.json"))
	var source_audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/m01_ground_projection_audit.json"))
	var compressed_audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/m01_ground_compressed_projection_audit.json"))
	var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/m01_ground_runtime_review_compressed.json"))
	assert(source_audit.passed and compressed_audit.passed)
	assert(source_audit.image_sha256 == FileAccess.get_sha256(STAGE+contract.image))
	assert(compressed_audit.image_sha256 == FileAccess.get_sha256("res://build/m01_ground_s3tc_decoded.png"))
	assert(contract.source_level_sha256 == FileAccess.get_sha256("res://levels/m01_sunset_palms.json"))
	assert(review.compressed and review.with_ground.median_ms <= review.baseline.median_ms*1.10)
	var image := Image.load_from_file(STAGE+contract.image)
	assert(image.compress(Image.COMPRESS_S3TC) == OK)
	assert(image.get_data_size() == int(review.texture_bytes))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var texture := ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,OUTPUT+"ground.res") == OK)
	var reloaded := load(OUTPUT+"ground.res") as Texture2D
	assert(reloaded != null and reloaded.get_size() == Vector2(4352,3904))
	contract.image = "ground.res"
	contract.runtime_approved = true
	contract.pending = []
	contract.source_image_sha256 = source_audit.image_sha256
	contract.texture_sha256 = FileAccess.get_sha256(OUTPUT+"ground.res")
	contract.texture_bytes = image.get_data_size()
	contract.validation = "Full source and decoded-alpha audit; paired frozen-scene GPU review. Physics remains native."
	var file := FileAccess.open(OUTPUT+"runtime_contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(contract,"\t"))
	file.close()
	print("M01 GROUND INTEGRATION: compressed native texture saved, 16990208 texture bytes")
	quit(0)
