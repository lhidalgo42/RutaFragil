class_name DataMirror

## Keeps res://data/<doc>.json as the mirror of <doc>.tres (D44).
## Canonical format: JSON.stringify(data, "\t") with default sort_keys, so a
## regenerated mirror is byte-identical and git shows real drift only.

static func write_mirror(res: Resource, doc_id: String, json_path: String) -> Error:
	var envelope: Dictionary = {doc_id: ResourceJsonCodec.to_dictionary(res)}
	var text: String = JSON.stringify(envelope, "\t") + "\n"
	return JsonFile.write_text(json_path, text)


## True when the file's section for doc_id holds the same values as res.
## Dictionary == is strict about int vs float values (verified on 4.7.2), and
## the resource side holds ints and Dictionary[String, int] while the parsed
## JSON side holds floats in untyped dictionaries. To compare semantically,
## the resource values are canonicalized through a JSON round trip first, so
## both sides are untyped dictionaries of floats.
static func check_mirror(
	res: Resource, doc_id: String, json_path: String, report: DataLoadReport
) -> bool:
	var source: String = "mirror:" + json_path
	if not FileAccess.file_exists(json_path):
		report.add_error(source, "mirror file not found")
		return false
	var errors_before: int = report.errors.size()
	var raw: Dictionary = JsonFile.read_object(json_path, report, source)
	if report.errors.size() != errors_before:
		return false  # read_object already recorded why
	var section_v: Variant = raw.get(doc_id, null)
	if not (section_v is Dictionary):
		report.add_error(source, "missing object section '%s'" % doc_id)
		return false
	var section: Dictionary = section_v
	var current: Dictionary = ResourceJsonCodec.to_dictionary(res)
	var canonical_json: JSON = JSON.new()
	var parse_err: Error = canonical_json.parse(JSON.stringify(current))
	if parse_err != OK or not (canonical_json.data is Dictionary):
		report.add_error(source, "cannot canonicalize the resource values")
		return false
	var canonical: Dictionary = canonical_json.data
	if section == canonical:
		return true
	report.add_error(source, "mirror is out of sync with the resource")
	return false
